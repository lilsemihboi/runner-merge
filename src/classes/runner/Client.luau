--[[
	RunnerClient
	=====================================
	A single client-simulated runner car. No physics, no per-car Heartbeat:
	RunnerManager drives every car from ONE loop via update(now).

	Movement is fully deterministic from the shared server clock:
		progress = ((now - startClock) / travelTime + phase) % 1
	so every client (and the server, when validating gates) computes the
	exact same position without any replication traffic.
]]

local Runner = {}
Runner.__index = Runner

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local PathData = require(ReplicatedStorage.Shared.Classes.Runner.PathData)
local RunnerUtils = require(ReplicatedStorage.Shared.Classes.Runner.RunnerUtils)

local RunnersFolder = ReplicatedStorage.Assets.Entities

function Runner.new(config: RunnerConfig): Runner
	local self = setmetatable({
		plotId = config.plotId,
		index = config.index,
		level = config.level,
		runnerSpeedLevel = config.runnerSpeedLevel,
		speed = RunnerUtils.getRunnerSpeed(config.level, config.runnerSpeedLevel),
		incomePerLap = RunnerUtils.getRunnerIncomePerLap(config.level),
		path = config.path,
		startClock = config.startClock,
		phase = config.phase,
		gateCount = config.gateCount,
		isOwner = config.isOwner,
		active = config.active,
		travelTime = 0,
		prevDistance = 0,
		janitor = Janitor.new(),
	}, Runner) :: Runner

	self:_refreshTravelTime()
	self:_createModel()
	self.prevDistance = self:getDistance(workspace:GetServerTimeNow())

	return self
end

function Runner._refreshTravelTime(self: Runner): ()
	self.travelTime = self.path.length / math.max(1, self.speed)
end

function Runner._resolveContainer(self: Runner): Instance?
	if self.container and self.container.Parent then
		return self.container
	end

	local plotsFolder = workspace:FindFirstChild("_PLOTS")
	if not plotsFolder then
		return nil
	end

	local plotModel = plotsFolder:FindFirstChild(tostring(self.plotId))
	if not plotModel then
		return nil
	end

	local container = plotModel:FindFirstChild("_TEMP")
	self.container = container

	return container
end

function Runner._createModel(self: Runner): ()
	self.janitor:Remove("model")
	self.model = nil

	local template = RunnersFolder:FindFirstChild(tostring(math.min(40, self.level)))
	if not template or not template:IsA("Model") then
		warn(`No runner model for level {self.level}`)
		return
	end

	local model = template:Clone()
	self.model = model
	self.janitor:Add(model, "Destroy", "model")

	local position, direction = PathData.sample(self.path, self:getDistance(workspace:GetServerTimeNow()))
	model:PivotTo(CFrame.lookAt(position, position + direction))

	if self.active then
		model.Parent = self:_resolveContainer()
	end
end

function Runner.getDistance(self: Runner, now: number): number
	if self.path.length <= 0 or self.travelTime <= 0 then
		return 0
	end

	local progress = ((now - self.startClock) / self.travelTime + self.phase) % 1

	return progress * self.path.length
end

function Runner._getCrossedGates(self: Runner, fromDistance: number, toDistance: number): { number }?
	local length = self.path.length
	local travelled = (toDistance - fromDistance) % length
	if travelled <= 0 then
		return nil
	end

	local crossedGates: { number }? = nil
	for gateId = 1, self.gateCount do
		local gateDistance = self.path.gateDistances[gateId]
		if not gateDistance then
			continue
		end

		local delta = (gateDistance - fromDistance) % length
		if delta > 0 and delta <= travelled then
			crossedGates = crossedGates or {}
			table.insert(crossedGates :: { number }, gateId)
		end
	end

	return crossedGates
end

-- Advances the car to its deterministic position for `now`.
-- Returns the gate ids crossed since the previous update (owner cars only).
function Runner.update(self: Runner, now: number): { number }?
	if not self.active or self.path.length <= 0 then
		return nil
	end

	local distance = self:getDistance(now)

	local model = self.model
	if model then
		if not model.Parent then
			local container = self:_resolveContainer()
			if container then
				model.Parent = container
			end
		end

		local position, direction = PathData.sample(self.path, distance)
		model:PivotTo(CFrame.lookAt(position, position + direction))
	end

	local crossedGates: { number }? = nil
	if self.isOwner and self.gateCount > 0 then
		crossedGates = self:_getCrossedGates(self.prevDistance, distance)
	end

	self.prevDistance = distance

	return crossedGates
end

-- Task 2: bounds based replication toggle. Inactive cars are unparented
-- and skipped by update() entirely (zero cost while out of bounds).
function Runner.setActive(self: Runner, active: boolean): ()
	if self.active == active then
		return
	end

	self.active = active

	if not active then
		if self.model then
			self.model.Parent = nil
		end
		return
	end

	self.prevDistance = self:getDistance(workspace:GetServerTimeNow())
end

-- Re-syncs the deterministic parameters after a roster/upgrade change.
-- Resets prevDistance so phase/speed shifts never produce phantom gate crossings.
function Runner._refreshSpeed(self: Runner): ()
	self.speed = RunnerUtils.getRunnerSpeed(self.level, self.runnerSpeedLevel)
	self:_refreshTravelTime()
end

function Runner.configure(self: Runner, startClock: number, phase: number, gateCount: number, runnerSpeedLevel: number): ()
	self.startClock = startClock
	self.phase = phase
	self.gateCount = gateCount
	self.runnerSpeedLevel = runnerSpeedLevel
	self:_refreshSpeed()
	self.prevDistance = self:getDistance(workspace:GetServerTimeNow())
end

function Runner.updateLevel(self: Runner, newRunnerLevel: number): ()
	if self.level == newRunnerLevel then
		return
	end

	self.level = newRunnerLevel
	self:_refreshSpeed()
	self.incomePerLap = RunnerUtils.getRunnerIncomePerLap(newRunnerLevel)

	self:_createModel()
	self.prevDistance = self:getDistance(workspace:GetServerTimeNow())
end

function Runner.destroy(self: Runner): ()
	self.janitor:Destroy()
	self.model = nil
end

export type RunnerConfig = {
	plotId: number,
	index: number,
	level: number,
	path: PathData.Path,
	startClock: number,
	phase: number,
	gateCount: number,
	runnerSpeedLevel: number,
	isOwner: boolean,
	active: boolean,
}

export type Runner = typeof(setmetatable(
	{} :: {
		plotId: number,
		index: number,
		level: number,
		runnerSpeedLevel: number,
		speed: number,
		incomePerLap: number,
		path: PathData.Path,
		model: Model?,
		container: Instance?,
		startClock: number,
		phase: number,
		gateCount: number,
		travelTime: number,
		prevDistance: number,
		isOwner: boolean,
		active: boolean,
		janitor: Janitor.Janitor,
	},
	Runner
))

return Runner
