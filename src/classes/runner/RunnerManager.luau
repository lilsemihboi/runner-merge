--[[
	RunnerManager
	=====================================
	The single client-side authority for ALL runner simulation. There is no
	server Heartbeat and no physics replication: the server only broadcasts
	each plot's roster + startClock ("start" signal) and this manager
	simulates every car locally inside ONE Heartbeat loop.

	Server -> client (Networker dispatch):
		setRunners(plotId, owner, levels, startClock, gateCount)
		removePlot(plotId)
	Client -> server:
		fetch("requestState") -- late-join sync
		fire("reportGate", plotId, runnerIndex, gateId) -- owner gate crossings

	Task 2: updateReplication() culls other players' plots by bounds. The
	local player's own plot is ALWAYS simulated; other plots only while the
	local character stands within that plot's runway bounds.
]]

local RunnerManager = {}
RunnerManager.__index = RunnerManager

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Configuration = require(ReplicatedStorage.Shared.Modules.Game.Configuration)
local Networker = require(ReplicatedStorage.Packages.Networker)
local PathData = require(ReplicatedStorage.Shared.Classes.Runner.PathData)
local RunnerClient = require(ReplicatedStorage.Shared.Classes.Runner.RunnerClient)
local RunnerServiceTypes = require(ReplicatedStorage.Shared.Services.RunnerService.RunnerServiceTypes)

local BOUNDS_CHECK_INTERVAL = 0.2
local PATH_RETRY_INTERVAL = 1

function RunnerManager.new(): RunnerManager
	local self = setmetatable({
		runners = {},
		plots = {},
		boundsCooldown = 0,
	}, RunnerManager) :: RunnerManager

	self.networker = Networker.client.new("RunnerService", self :: any)
	self:start()

	task.spawn(function()
		local snapshots: { RunnerServiceTypes.RunnerPlotSnapshot } = self.networker:fetch("requestState")
		if typeof(snapshots) ~= "table" then
			return
		end

		for _, snapshot in snapshots do
			-- live broadcasts may already have arrived while fetching; they win
			if not self.plots[snapshot.plotId] then
				self:setRunners(snapshot.plotId, snapshot.owner, snapshot.levels, snapshot.startClock, snapshot.gateCount)
			end
		end
	end)

	return self
end

function RunnerManager.start(self: RunnerManager)
	if self.updateConn then
		return
	end

	self.updateConn = RunService.Heartbeat:Connect(function(dt)
		self:update(dt)
	end)
end

function RunnerManager.stop(self: RunnerManager)
	if self.updateConn then
		self.updateConn:Disconnect()
		self.updateConn = nil
	end
end

-- Server "start" signal: full roster snapshot for one plot. Reconciles the
-- RunnerClient pool (create / updateLevel / destroy) instead of rebuilding.
function RunnerManager.setRunners(self: RunnerManager, plotId: number, owner: Player, levels: { number }, startClock: number, gateCount: number): ()
	local state = self.plots[plotId]
	if not state then
		state = {
			plotId = plotId,
			owner = owner,
			levels = levels,
			startClock = startClock,
			gateCount = gateCount,
			active = owner == Players.LocalPlayer,
		}
		self.plots[plotId] = state
		self.runners[plotId] = {}
	else
		state.owner = owner
		state.levels = levels
		state.startClock = startClock
		state.gateCount = gateCount
	end

	local path = PathData.get(plotId)
	if not path or path.length <= 0 then
		-- plot geometry not replicated to this client yet; retry shortly
		self:_schedulePathRetry(state)
		return
	end

	local isOwner = owner == Players.LocalPlayer
	local count = #levels
	local cars = self.runners[plotId]

	for index, car in cars do
		if index > count then
			car:destroy()
			cars[index] = nil
		end
	end

	for index = 1, count do
		local phase = (index - 1) / count
		local car = cars[index]

		if car then
			car.isOwner = isOwner
			car:updateLevel(levels[index])
			car:configure(startClock, phase, gateCount)
		else
			cars[index] = RunnerClient.new({
				plotId = plotId,
				index = index,
				level = levels[index],
				path = path,
				startClock = startClock,
				phase = phase,
				gateCount = gateCount,
				isOwner = isOwner,
				active = state.active,
			})
		end
	end
end

function RunnerManager.removePlot(self: RunnerManager, plotId: number): ()
	local cars = self.runners[plotId]
	if cars then
		for _, car in cars do
			car:destroy()
		end
	end

	self.runners[plotId] = nil
	self.plots[plotId] = nil
end

function RunnerManager._schedulePathRetry(self: RunnerManager, state: PlotState): ()
	if state.pathRetryScheduled then
		return
	end

	state.pathRetryScheduled = true
	task.delay(PATH_RETRY_INTERVAL, function()
		state.pathRetryScheduled = false
		if self.plots[state.plotId] ~= state then
			return
		end

		self:setRunners(state.plotId, state.owner, state.levels, state.startClock, state.gateCount)
	end)
end

function RunnerManager._getPlotBounds(_self: RunnerManager, state: PlotState): (CFrame?, Vector3?)
	if state.boundsCf and state.boundsSize then
		return state.boundsCf, state.boundsSize
	end

	local plotsFolder = workspace:FindFirstChild("_PLOTS")
	local plotModel = if plotsFolder then plotsFolder:FindFirstChild(tostring(state.plotId)) else nil
	if not plotModel or not plotModel:IsA("Model") then
		return nil, nil
	end

	local boundsCf: CFrame
	local boundsSize: Vector3

	local runwayModel = plotModel:FindFirstChild("Runway")
	if runwayModel and runwayModel:IsA("Model") then
		boundsCf, boundsSize = runwayModel:GetBoundingBox()
	else
		boundsCf, boundsSize = plotModel:GetBoundingBox()
	end

	state.boundsCf = boundsCf
	state.boundsSize = boundsSize

	return boundsCf, boundsSize
end

function RunnerManager._isWithinPlotBounds(self: RunnerManager, state: PlotState, position: Vector3): boolean
	local boundsCf, boundsSize = self:_getPlotBounds(state)
	if not boundsCf or not boundsSize then
		return false
	end

	local padding = Configuration.RUNNER_BOUNDS_PADDING
	local relativePos = boundsCf:PointToObjectSpace(position)

	return math.abs(relativePos.X) <= boundsSize.X / 2 + padding and math.abs(relativePos.Z) <= boundsSize.Z / 2 + padding
end

-- Task 2: replication culling. Own plot is always active; other players'
-- plots are only simulated while the local character is inside their bounds.
function RunnerManager.updateReplication(self: RunnerManager): ()
	local character = Players.LocalPlayer.Character
	local position = if character then character:GetPivot().Position else nil

	for plotId, state in self.plots do
		local isOwner = state.owner == Players.LocalPlayer
		local withinBounds = position ~= nil and self:_isWithinPlotBounds(state, position :: Vector3)
		local active = isOwner or withinBounds

		if state.active == active then
			continue
		end

		state.active = active

		local cars = self.runners[plotId]
		if cars then
			for _, car in cars do
				car:setActive(active)
			end
		end
	end
end

function RunnerManager.update(self: RunnerManager, dt: number): ()
	self.boundsCooldown -= dt
	if self.boundsCooldown <= 0 then
		self.boundsCooldown = BOUNDS_CHECK_INTERVAL
		self:updateReplication()
	end

	local now = workspace:GetServerTimeNow()
	for plotId, cars in self.runners do
		local state = self.plots[plotId]
		if not state or not state.active then
			continue
		end

		for index, car in cars do
			local crossedGates = car:update(now)
			if not crossedGates then
				continue
			end

			for _, gateId in crossedGates do
				self.networker:fire("reportGate", plotId, index, gateId)
			end
		end
	end
end

function RunnerManager.destroy(self: RunnerManager): ()
	self.networker:destroy()
	self:stop()

	for plotId in self.plots do
		self:removePlot(plotId)
	end
end

type PlotState = {
	plotId: number,
	owner: Player,
	levels: { number },
	startClock: number,
	gateCount: number,
	active: boolean,
	boundsCf: CFrame?,
	boundsSize: Vector3?,
	pathRetryScheduled: boolean?,
}

export type RunnerManager = typeof(setmetatable(
	{} :: {
		runners: { [number]: { [number]: RunnerClient.Runner } },
		plots: { [number]: PlotState },
		networker: Networker.Client,
		updateConn: RBXScriptConnection?,
		boundsCooldown: number,
	},
	RunnerManager
))

return RunnerManager
