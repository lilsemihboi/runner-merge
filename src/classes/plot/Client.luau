local Plot = {}
Plot.__index = Plot

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Networker = require(ReplicatedStorage.Packages.Networker)
local PlotServiceTypes = require(ReplicatedStorage.Shared.Services.PlotService.PlotServiceTypes)
local Ripple = require(ReplicatedStorage.Packages.Ripple)

function Plot.new(plotData: PlotServiceTypes.PlotData): Plot
	local self = setmetatable({
		plotId = plotData.plotId,
		plotModel = workspace._PLOTS:WaitForChild(tostring(plotData.plotId)),
		player = plotData.player,
		janitor = Janitor.new(),
	}, Plot) :: Plot
	self.networker = Networker.client.new(`plot_{self.player.Name}`, self)

	self:setupButtons()

	return self
end

function Plot._registerTypeButton(self: Plot, buttonTop: BasePart, buttonType: "Runner" | "Merge", runnerAmount: number?)
	local lastTrigger = 0
	local baseCFrame = buttonTop.CFrame
	local spring = Ripple.createSpring(
		0,
		{
			start = true,
			dampingRatio = 0.9,
			frequency = 3.5,
		} :: Ripple.SpringOptions
	)

	spring:onChange(function(value)
		buttonTop.CFrame = baseCFrame * CFrame.new(0, -value, 0)
	end)

	buttonTop.Touched:Connect(function(hit: BasePart)
		if hit.Parent and not hit.Parent:FindFirstChildOfClass("Humanoid") then
			return
		end

		if hit.Parent ~= self.player.Character then
			return
		end

		local now = os.clock()
		if now - lastTrigger < 0.75 then
			return
		end
		lastTrigger = now

		if buttonType == "Runner" then
			self.networker:fire("addRunner", runnerAmount)
		else
			self.networker:fire("merge")
		end

		local originalColor = buttonTop.Color
		local flashTween = TweenService:Create(buttonTop, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = Color3.new(1, 1, 1),
		})
		flashTween:Play()

		task.delay(0.12, function()
			if buttonTop and buttonTop.Parent then
				local resetTween = TweenService:Create(buttonTop, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Color = originalColor,
				})
				resetTween:Play()
			end
		end)

		spring:setGoal(0.5)

		task.delay(0.1, function()
			spring:setGoal(0)
		end)
	end)
end

function Plot.setupButtons(self: Plot): ()
	local buttonsFolder: Folder = self.plotModel:WaitForChild("Buttons")

	for _, button in buttonsFolder:QueryDescendants("#ButtonTrigger") do
		if not button:IsA("BasePart") then
			continue
		end

		local buttonModel = button.Parent
		local buttonGroup = buttonModel and buttonModel.Parent

		if not buttonModel or not buttonGroup then
			continue
		end

		local buttonType = buttonGroup.Name

		if buttonType == "Runner" then
			local runnerAmount = tonumber(buttonModel.Name)
			self:_registerTypeButton(button, "Runner", runnerAmount)
		else
			self:_registerTypeButton(button, "Merge")
		end
	end
end

function Plot.destroy(self: Plot): ()
	self.networker:destroy()
	self.janitor:Destroy()
end

export type Plot = typeof(setmetatable(
	{} :: {
		plotId: number,
		plotModel: typeof(workspace._PLOTS["1"]),
		player: Player,
		networker: Networker.Client,
		janitor: Janitor.Janitor,
	},
	Plot
))

return Plot
