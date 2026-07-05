local Runner = {}
Runner.__index = Runner

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local RunnerUtils = require(ReplicatedStorage.Shared.Classes.Runner.RunnerUtils)

local RunnersFolder = ReplicatedStorage.Assets.Entities

function Runner.new(runnerLevel: number, plotId: number): Runner
	local runnerAmountOverflow = runnerLevel < #RunnersFolder:GetChildren()
	assert(runnerAmountOverflow, `No runner model for {runnerLevel}`)

	local self = setmetatable({
		runnerLevel = runnerLevel,
		runnerSpeed = RunnerUtils.getRunnerSpeed(runnerLevel),
		runnerIncomePerLap = RunnerUtils.getRunnerIncomePerLap(runnerLevel),
		janitor = Janitor.new(),
		plotId = plotId,
	}, Runner) :: Runner

	self:_createRunnerModel()

	return self
end

function Runner._createRunnerModel(self: Runner): ()
	local runnerId = tostring(self.runnerLevel)

	local model = RunnersFolder:FindFirstChild(runnerId)
	if not model then
		return
	end

	local clonedModel = model:Clone()
	self.runnerModel = clonedModel
	self.janitor:Add(clonedModel, "Destroy")

	local plotsFolder = workspace:FindFirstChild("_PLOTS")
	if not plotsFolder then
		return
	end

	local plotModel = plotsFolder:FindFirstChild(tostring(self.plotId))
	if not plotModel then
		return
	end

	local folder = plotModel:WaitForChild("_TEMP") :: Folder

	(clonedModel :: Instance).Parent = folder

	return
end

function Runner.updateLevel(self: Runner, newRunnerLevel: number): ()
	self.runnerLevel = newRunnerLevel
	self.runnerSpeed = RunnerUtils.getRunnerSpeed(newRunnerLevel)
	self.runnerIncomePerLap = RunnerUtils.getRunnerIncomePerLap(newRunnerLevel)

	if self.runnerModel then
		self.runnerModel = nil
	end

	self.janitor:Cleanup()

	self:_createRunnerModel()
end

function Runner.destroy(self: Runner): ()
	self.janitor:Destroy()

	return
end

export type Runner = typeof(setmetatable(
	{} :: {
		runnerLevel: number,
		runnerSpeed: number,
		runnerIncomePerLap: number,
		runnerModel: Instance?,
		janitor: Janitor.Janitor,
		plotId: number,
	},
	Runner
))

return Runner
