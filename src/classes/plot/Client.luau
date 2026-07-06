local Plot = {}
Plot.__index = Plot

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Charm = require(ReplicatedStorage.Packages.Charm)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Networker = require(ReplicatedStorage.Packages.Networker)
local DataService = require(ReplicatedStorage.Packages.DataService).client
local FormatCurrency = require(ReplicatedStorage.Shared.Modules.Ui.FormatCurrency)
local GetDataSource = require(ReplicatedStorage.Shared.Modules.Ui.Sources.GetDataSource)
local PlotServiceTypes = require(ReplicatedStorage.Shared.Services.PlotService.PlotServiceTypes)
local Ripple = require(ReplicatedStorage.Packages.Ripple)
local UpgradeUtils = require(ReplicatedStorage.Shared.Modules.Items.UpgradeUtils)

function Plot.new(plotData: PlotServiceTypes.PlotData): Plot
	local self = setmetatable({
		plotId = plotData.plotId,
		plotModel = workspace._PLOTS:WaitForChild(tostring(plotData.plotId)),
		player = plotData.player,
		janitor = Janitor.new(),
		mergeButtons = {},
		registeredButtons = {},
	}, Plot) :: Plot
	self.networker = Networker.client.new(`plot_{self.player.Name}`, self)

	self:setupButtons()
	self:setupUpgradeBoard()
	self:_updateMergeButtonState()

	self.janitor:Add(
		DataService:getChangedSignal({ "runners" }):Connect(function(newRunners)
			self:_onRunnersChanged(newRunners)
		end),
		"Disconnect"
	)

	self.janitor:Add(
		DataService:getIndexChangedSignal({ "runners" }):Connect(function()
			self:_updateMergeButtonState()
		end),
		"Disconnect"
	)

	self.janitor:Add(
		DataService:getArrayInsertedSignal({ "runners" }):Connect(function()
			self:_updateMergeButtonState()
		end),
		"Disconnect"
	)

	self.janitor:Add(
		DataService:getArrayRemovedSignal({ "runners" }):Connect(function()
			self:_updateMergeButtonState()
		end),
		"Disconnect"
	)

	return self
end

function Plot.setupUpgradeBoard(self: Plot)
	local upgradeBoardUI =
		self.plotModel:WaitForChild("UpgradeTable"):WaitForChild("UpgradeTable"):WaitForChild("UpgradePart"):WaitForChild("SurfaceGui"):WaitForChild("Frame")

	local function setupUpgradeFrame(
		upgradeFrame: typeof(workspace._PLOTS["1"].UpgradeTable.UpgradeTable.UpgradePart.SurfaceGui.Frame.gates),
		upgradeId: string
	)
		if upgradeId ~= "gates" and upgradeId ~= "runnerSpeed" and upgradeId ~= "cashBonus" then
			return
		end

		local levelAtomForUpgrade = GetDataSource({ "upgrades", upgradeId })

		local function changeLevelStatus(newLevel: number)
			upgradeFrame.level.Text = `Level {newLevel}/{UpgradeUtils.levelCaps[upgradeId]}`
			local nextLevel = newLevel + 1
			if newLevel == UpgradeUtils.levelCaps[upgradeId] then
				upgradeFrame.nextLevel.Text = "MAX LEVEL"
				upgradeFrame.UpgradeButton.BTN_Surface.TXT_ButtonLabel.Text = "MAX"
			else
				upgradeFrame.nextLevel.Text = `{newLevel} → {nextLevel}`
				local cost = UpgradeUtils.calculateUpgradeCost(upgradeId, nextLevel)
				upgradeFrame.UpgradeButton.BTN_Surface.TXT_ButtonLabel.Text = cost == 0 and "FREE" or FormatCurrency(cost, true)
			end
		end

		changeLevelStatus(levelAtomForUpgrade())

		self.janitor:Add(Charm.subscribe(levelAtomForUpgrade, function(newLevel)
			changeLevelStatus(newLevel)
		end))

		self.janitor:Add(
			upgradeFrame.UpgradeButton.Activated:Connect(function()
				local result = self.networker:fetch("upgrade", upgradeId)

				if result == "SUCCESS" then
					return
				elseif result == "WRONG_UPGRADE_ID" then
					print("Wrong upgrade id")
					--TODO: Alert
				elseif result == "MAX_LEVEL" then
					--TODO: Alert
					print("Max level")
				elseif result == "NOT_ENOUGH_CASH" then
					--TODO: Alert
					print("Not enough cahs")
				end
			end),
			"Disconnect"
		)
	end

	for _, upgradeFrame: typeof(workspace._PLOTS["1"].UpgradeTable.UpgradeTable.UpgradePart.SurfaceGui.Frame.gates) in upgradeBoardUI:GetChildren() do
		if not upgradeFrame:IsA("Frame") then
			continue
		end
		local upgradeId = upgradeFrame.Name

		setupUpgradeFrame(upgradeFrame, upgradeId)
	end
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

	self.janitor:Add(
		buttonTop.Touched:Connect(function(hit: BasePart)
			local character = self.player.Character
			if not character or not hit:IsDescendantOf(character) then
				return
			end

			if not character:FindFirstChildOfClass("Humanoid") then
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
					if buttonType == "Merge" then
						self:_updateMergeButtonState()
						return
					end

					local resetTween = TweenService:Create(buttonTop, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Color = originalColor,
					})
					resetTween:Play()
				end
			end)

			task.delay(0.25, function()
				if buttonTop and buttonTop.Parent then
					if buttonType == "Merge" then
						self:_updateMergeButtonState()
					else
						buttonTop.Color = originalColor
					end
				end
			end)

			spring:setGoal(0.5)

			task.delay(0.1, function()
				spring:setGoal(0)
			end)
		end),
		"Disconnect"
	)
end

function Plot._tryRegisterButton(self: Plot, button: Instance): ()
	if self.registeredButtons[button] then
		return
	end

	if not button:IsA("BasePart") then
		return
	end

	if not button:IsDescendantOf(self.plotModel) then
		return
	end

	if not CollectionService:HasTag(button, "ButtonTrigger") and button.Name ~= "ButtonTrigger" and button.Name ~= "#ButtonTrigger" then
		return
	end

	local buttonModel = button.Parent
	local buttonGroup = buttonModel and buttonModel.Parent

	if not buttonModel or not buttonGroup then
		return
	end

	local buttonType = buttonGroup.Name

	if buttonType == "Runner" then
		local runnerAmount = tonumber(buttonModel.Name)
		if not runnerAmount then
			warn(`Runner button {button:GetFullName()} has invalid amount model name {buttonModel.Name}`)
			return
		end

		self.registeredButtons[button] = true
		self:_registerTypeButton(button, "Runner", runnerAmount)
	elseif buttonType == "Merge" then
		self.registeredButtons[button] = true
		self:_registerTypeButton(button, "Merge")
		self.mergeButtons[#self.mergeButtons + 1] = button
		self:_updateMergeButtonState()
	end
end

function Plot.setupButtons(self: Plot): ()
	local buttonsFolder: Folder = self.plotModel:WaitForChild("Buttons")

	for _, button in buttonsFolder:GetDescendants() do
		self:_tryRegisterButton(button)
	end

	for _, button in CollectionService:GetTagged("ButtonTrigger") do
		self:_tryRegisterButton(button)
	end

	self.janitor:Add(
		buttonsFolder.DescendantAdded:Connect(function(descendant)
			task.defer(function()
				self:_tryRegisterButton(descendant)
			end)
		end),
		"Disconnect"
	)

	self.janitor:Add(
		CollectionService:GetInstanceAddedSignal("ButtonTrigger"):Connect(function(instance)
			task.defer(function()
				self:_tryRegisterButton(instance)
			end)
		end),
		"Disconnect"
	)
end

function Plot._hasMergeableRunners(_self: Plot, runners: { number? }?): boolean
	if type(runners) ~= "table" then
		return false
	end

	local sortedLevels: { number } = {}
	for _, runnerLevel in ipairs(runners) do
		if typeof(runnerLevel) == "number" then
			sortedLevels[#sortedLevels + 1] = runnerLevel
		end
	end

	if #sortedLevels < 2 then
		return false
	end

	table.sort(sortedLevels)

	for index = 1, #sortedLevels - 1 do
		if sortedLevels[index] == sortedLevels[index + 1] then
			return true
		end
	end

	return false
end

function Plot._setMergeButtonColor(_self: Plot, buttonTop: BasePart, enabled: boolean): ()
	local targetColor = if enabled then Color3.fromRGB(255, 157, 0) else Color3.fromRGB(136, 136, 136)
	buttonTop.Color = targetColor
end

function Plot._updateMergeButtonState(self: Plot): ()
	local runners = DataService:get({ "runners" })
	local canMerge = self:_hasMergeableRunners(runners)

	for _, buttonTop in ipairs(self.mergeButtons) do
		if buttonTop and buttonTop.Parent then
			self:_setMergeButtonColor(buttonTop, canMerge)
		end
	end
end

function Plot._onRunnersChanged(self: Plot, _newRunners: any): ()
	self:_updateMergeButtonState()
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
		mergeButtons: { [number]: BasePart },
		registeredButtons: { [Instance]: boolean },
	},
	Plot
))

return Plot
