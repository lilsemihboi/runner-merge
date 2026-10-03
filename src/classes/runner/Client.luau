--[[
	RunnerClient
	=====================================
	A single client-simulated runner car. No physics, no per-car Heartbeat:
	RunnerManager drives every car from ONE loop via update(now).

	Movement is fully deterministic from the shared server clock:
		progress = ((now - startClock) / travelTime + phase) % 1
	so every client (and the server, when validating gates) computes the
	exact same position without any replication traffic.

	`phase` comes from the car's own runner entry rather than from its slot in
	the roster, so a purchase or a merge never repositions a car that is still
	on the roster.
]]

local Runner = {}
Runner.__index = Runner

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local PathData = require(ReplicatedStorage.Shared.Classes.Runner.PathData)
local RunnerUtils = require(ReplicatedStorage.Shared.Classes.Runner.RunnerUtils)
local Trails = require(ReplicatedStorage.Shared.Modules.Items.Trails)

local RunnersFolder = ReplicatedStorage.Assets.Entities
local RUNNER_CLEARANCE = 0.25
local INVERTED_CLEARANCE = 0.5

local function getRunnerCFrame(path: PathData.Path, distance: number): CFrame
	local pathCFrame = PathData.sample(path, distance)
	local invertedAlpha = math.clamp(-pathCFrame.UpVector.Y, 0, 1)
	return pathCFrame + pathCFrame.UpVector * (RUNNER_CLEARANCE + INVERTED_CLEARANCE * invertedAlpha)
end

function Runner.new(config: RunnerConfig): Runner
	local self = setmetatable({
		plotId = config.plotId,
		runnerId = config.runnerId,
		level = config.level,
		carSpeedMultiplier = config.carSpeedMultiplier,
		runnerSpeedLevel = config.runnerSpeedLevel,
		speed = RunnerUtils.getRunnerSpeed(config.level, config.runnerSpeedLevel),
		incomePerLap = RunnerUtils.getRunnerIncomePerLap(config.level),
		path = config.path,
		startClock = config.startClock,
		phase = config.phase,
		gateCount = config.gateCount,
		selectedTrail = config.selectedTrail,
		trailsVisible = config.trailsVisible ~= false,
		isOwner = config.isOwner,
		active = config.active,
		visible = true,
		travelTime = 0,
		prevDistance = 0,
		prevLap = 0,
		janitor = Janitor.new(),
	}, Runner) :: Runner

	self:_refreshTravelTime()
	self:_createModel()
	local now = workspace:GetServerTimeNow()
	self.prevDistance = self:getDistance(now)
	self.prevLap = self:getLapCount(now)

	return self
end

function Runner.getLapCount(self: Runner, current: number): number
	if self.travelTime <= 0 then
		return 0
	end
	return math.floor((current - self.startClock) / self.travelTime + self.phase)
end

function Runner._refreshTravelTime(self: Runner): ()
	self.travelTime = self.path.length / math.max(1, self.speed * self.carSpeedMultiplier)
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

	local template = RunnersFolder:FindFirstChild(RunnerUtils.getModelName(self.level))
	if not template or not template:IsA("Model") then
		warn(`No runner model for level {self.level}`)
		return
	end

	local model = template:Clone()
	self.model = model
	self.janitor:Add(model, "Destroy", "model")
	self:_applySelectedTrail()

	model:PivotTo(getRunnerCFrame(self.path, self:getDistance(workspace:GetServerTimeNow())))

	if self.active and self.visible then
		model.Parent = self:_resolveContainer()
	end
end

function Runner._applySelectedTrail(self: Runner): ()
	local model = self.model
	if not model then
		return
	end

	local trail = model:FindFirstChild("Trail", true)
	if not trail or not trail:IsA("Trail") then
		return
	end

	local trailInfo = if self.selectedTrail then Trails[self.selectedTrail] else nil
	trail.Enabled = trailInfo ~= nil and self.trailsVisible

	if trailInfo then
		trail.Color = trailInfo.trailColorSequence
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
function Runner.update(self: Runner, now: number): ({ number }?, number)
	if not self.active or not self.visible or self.path.length <= 0 then
		return nil, 0
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

		model:PivotTo(getRunnerCFrame(self.path, distance))
	end

	local crossedGates: { number }? = nil
	local lapsCompleted = 0

	if self.isOwner then
		if self.gateCount > 0 then
			crossedGates = self:_getCrossedGates(self.prevDistance, distance)
		end

		local lapCount = self:getLapCount(now)
		lapsCompleted = lapCount - self.prevLap
		self.prevLap = lapCount
	end

	self.prevDistance = distance

	return crossedGates, lapsCompleted
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

	local now = workspace:GetServerTimeNow()
	self.prevDistance = self:getDistance(now)
	self.prevLap = self:getLapCount(now)
end

function Runner.setVisible(self: Runner, visible: boolean): ()
	if self.visible == visible then
		return
	end

	self.visible = visible

	local model = self.model
	if not model then
		return
	end

	if not visible then
		model.Parent = nil
		return
	end

	local now = workspace:GetServerTimeNow()
	self.prevDistance = self:getDistance(now)
	self.prevLap = self:getLapCount(now)
	if self.active then
		model.Parent = self:_resolveContainer()
	end
end

function Runner.setSelectedTrail(self: Runner, selectedTrail: number?): ()
	if self.selectedTrail == selectedTrail then
		return
	end

	self.selectedTrail = selectedTrail
	self:_applySelectedTrail()
end

function Runner.setTrailsVisible(self: Runner, trailsVisible: boolean): ()
	if self.trailsVisible == trailsVisible then
		return
	end

	self.trailsVisible = trailsVisible
	self:_applySelectedTrail()
end

function Runner._refreshSpeed(self: Runner): ()
	self.speed = RunnerUtils.getRunnerSpeed(self.level, self.runnerSpeedLevel)
	self:_refreshTravelTime()
end

-- Re-syncs deterministic parameters after a roster or upgrade change.
-- Only movement or gate changes reset prevDistance to avoid phantom crossings.
function Runner.configure(
	self: Runner,
	startClock: number,
	phase: number,
	gateCount: number,
	runnerSpeedLevel: number,
	carSpeedMultiplier: number,
	path: PathData.Path,
	selectedTrail: number?
): ()
	local shouldResetDistance = self.startClock ~= startClock
		or self.phase ~= phase
		or self.path ~= path
		or self.carSpeedMultiplier ~= carSpeedMultiplier
		or self.gateCount ~= gateCount
		or self.runnerSpeedLevel ~= runnerSpeedLevel

	self.startClock = startClock
	self.phase = phase
	self.path = path
	self.carSpeedMultiplier = carSpeedMultiplier
	self.gateCount = gateCount
	self.runnerSpeedLevel = runnerSpeedLevel
	self:_refreshSpeed()
	self:setSelectedTrail(selectedTrail)

	if shouldResetDistance then
		local now = workspace:GetServerTimeNow()
		self.prevDistance = self:getDistance(now)
		self.prevLap = self:getLapCount(now)
	end
end

function Runner.updateLevel(self: Runner, newRunnerLevel: number): ()
	if self.level == newRunnerLevel then
		return
	end

	self.level = newRunnerLevel
	self:_refreshSpeed()
	self.incomePerLap = RunnerUtils.getRunnerIncomePerLap(newRunnerLevel)

	local now = workspace:GetServerTimeNow()
	self:_createModel()
	self.prevDistance = self:getDistance(now)
	self.prevLap = self:getLapCount(now)
end

function Runner.destroy(self: Runner): ()
	self.janitor:Destroy()
	self.model = nil
end

export type RunnerConfig = {
	plotId: number,
	runnerId: number,
	level: number,
	path: PathData.Path,
	startClock: number,
	carSpeedMultiplier: number,
	phase: number,
	gateCount: number,
	runnerSpeedLevel: number,
	isOwner: boolean,
	active: boolean,
	selectedTrail: number?,
	trailsVisible: boolean?,
}

export type Runner = typeof(setmetatable(
	{} :: {
		plotId: number,
		runnerId: number,
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
		selectedTrail: number?,
		trailsVisible: boolean,
		travelTime: number,
		prevDistance: number,
		prevLap: number,
		isOwner: boolean,
		carSpeedMultiplier: number,
		active: boolean,
		visible: boolean,
		janitor: Janitor.Janitor,
	},
	Runner
))

return Runner
