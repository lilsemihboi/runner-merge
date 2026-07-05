local Runner = {}
Runner.__index = Runner

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
	self:_startMoving()

	return self
end

function Runner._getWaypointPositions(self: Runner): { Vector3 }
	local plotsFolder = workspace:FindFirstChild("_PLOTS")
	if not plotsFolder then
		return {}
	end

	local plotModel = plotsFolder:FindFirstChild(tostring(self.plotId))
	if not plotModel then
		return {}
	end

	local runwayModel = plotModel:FindFirstChild("Runway")
	if not runwayModel then
		return {}
	end

	local waypointsFolder = runwayModel:FindFirstChild("waypoints")
	if not waypointsFolder then
		return {}
	end

	local attachments: { Attachment } = {}
	for _, child in ipairs(waypointsFolder:GetChildren()) do
		if child:IsA("Attachment") then
			attachments[#attachments + 1] = child :: Attachment
		end
	end

	table.sort(attachments, function(firstAttachment: Attachment, secondAttachment: Attachment)
		local firstNumber = tonumber(firstAttachment.Name)
		local secondNumber = tonumber(secondAttachment.Name)

		if firstNumber and secondNumber then
			return firstNumber < secondNumber
		end

		return firstAttachment.Name < secondAttachment.Name
	end)

	local positions: { Vector3 } = {}
	for _, attachment in ipairs(attachments) do
		positions[#positions + 1] = attachment.WorldCFrame.Position
	end

	return positions
end

function Runner._buildSmoothPath(_self: Runner, positions: { Vector3 }): { Vector3 }
	if #positions < 2 then
		return positions
	end

	local sampledPath = {}
	local samplesPerSegment = 12

	for index = 1, #positions - 1 do
		local previousPosition = positions[math.max(1, index - 1)]
		local currentPosition = positions[index]
		local nextPosition = positions[index + 1]
		local futurePosition = positions[math.min(#positions, index + 2)]

		for step = 0, samplesPerSegment do
			local alpha = step / samplesPerSegment
			local catmullRomPoint = (
				0.5
				* (
					(2 * currentPosition)
					+ ((-previousPosition + nextPosition) * alpha)
					+ ((2 * previousPosition - 5 * currentPosition + 4 * nextPosition - futurePosition) * (alpha * alpha))
					+ ((-previousPosition + 3 * currentPosition - 3 * nextPosition + futurePosition) * (alpha * alpha * alpha))
				)
			)
			sampledPath[#sampledPath + 1] = catmullRomPoint
		end
	end

	return sampledPath
end

function Runner._startMoving(self: Runner): ()
	local positions = self:_getWaypointPositions()
	local path = self:_buildSmoothPath(positions)
	if #path < 2 then
		return
	end

	local totalDistance = 0
	for index = 2, #path do
		totalDistance += (path[index] - path[index - 1]).Magnitude
	end

	if totalDistance <= 0 then
		return
	end

	local travelTime = totalDistance / math.max(1, self.runnerSpeed)
	local startTime = os.clock()
	local connection: RBXScriptConnection?
	connection = RunService.Heartbeat:Connect(function()
		if not self.runnerModel or not self.runnerModel.Parent then
			if connection then
				connection:Disconnect()
			end
			return
		end

		local elapsed = os.clock() - startTime
		local progress = (elapsed / travelTime) % 1
		local distanceTraveled = progress * totalDistance
		local traveledDistance = 0
		local currentPoint = path[1]
		local nextPoint = path[2]

		for index = 2, #path do
			local segmentLength = (path[index] - path[index - 1]).Magnitude
			if traveledDistance + segmentLength >= distanceTraveled then
				currentPoint = path[index - 1]
				nextPoint = path[index]
				local segmentProgress = (distanceTraveled - traveledDistance) / math.max(segmentLength, 1e-4)
				local point = currentPoint:Lerp(nextPoint, segmentProgress)
				local direction = nextPoint - currentPoint
				local lookDirection = direction.Unit
				if lookDirection.Magnitude < 1e-4 then
					lookDirection = Vector3.new(0, 0, 1)
				end

				local cframe = CFrame.lookAt(point, point + lookDirection)
				if self.runnerModel:IsA("Model") then
					(self.runnerModel :: Model):PivotTo(cframe)
				end
				return
			end

			traveledDistance += segmentLength
		end
	end)

	self.janitor:Add(connection, "Disconnect")
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
	self:_startMoving()

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
