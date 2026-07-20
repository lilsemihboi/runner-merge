--!nonstrict

local Plot = {}
Plot.__index = Plot

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Charm = require(ReplicatedStorage.Packages.Charm)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Networker = require(ReplicatedStorage.Packages.Networker)
local DataService = require(ReplicatedStorage.Packages.DataService).client
local ErrorMessage = require(ReplicatedStorage.Shared.Modules.Ui.Components.ErrorMessage)
local FormatCurrency = require(ReplicatedStorage.Shared.Modules.Ui.FormatCurrency)
local GetDataSource = require(ReplicatedStorage.Shared.Modules.Ui.Sources.GetDataSource)
local InfoEnums = require(ReplicatedStorage.Shared.Modules.Utils.InfoEnums)
local MonetizationServiceClient = require(ReplicatedStorage.Shared.Services.MonetizationService.MonetizationServiceClient)
local PlotServiceTypes = require(ReplicatedStorage.Shared.Services.PlotService.PlotServiceTypes)
local Products = require(ReplicatedStorage.Shared.Services.MonetizationService.Modules.Products)
local Ripple = require(ReplicatedStorage.Packages.Ripple)
local Runners = require(ReplicatedStorage.Shared.Modules.Items.Runners)
local SoundServiceClient = require(ReplicatedStorage.Shared.Services.SoundService.SoundServiceClient)
local UpgradeUtils = require(ReplicatedStorage.Shared.Modules.Items.UpgradeUtils)
local _DataTemplate = require(ReplicatedStorage.Shared.Modules.Game.DataTemplate)

local RUNNER_ENABLED_COLOR = Color3.fromRGB(11, 138, 20)
local BUTTON_DISABLED_COLOR = Color3.fromRGB(136, 136, 136)

type RunnerButton = {
	buttonTop: BasePart,
	runnerAmount: number,
	moneyText: TextLabel,
}

function Plot.new(plotData: PlotServiceTypes.PlotData): Plot
	local self = setmetatable({
		plotId = plotData.plotId,
		plotModel = workspace._PLOTS:WaitForChild(tostring(plotData.plotId)),
		player = plotData.player,
		janitor = Janitor.new(),
		mergeButtons = {},
		runnerButtons = {},
		registeredButtons = {},
		upgradeButtons = {},
	}, Plot) :: Plot
	self.networker = Networker.client.new(`plot_{self.player.Name}`, self)

	self:setupButtons()
	self:setupUpgradeBoard()
	self:setupStarterPack()
	self:_updateMergeButtonState()
	self:_updateRunnerButtonPrices()
	self:_updateUpgradeButtonPrices()

	local runnersBought = GetDataSource("runnerPurchases")
	self.janitor:Add(Charm.subscribe(runnersBought, function()
		self:_updateRunnerButtonPrices()
	end))

	local cashAtom = GetDataSource("cash")
	self.janitor:Add(Charm.subscribe(cashAtom, function()
		self:_updateRunnerButtonPrices()
		self:_updateUpgradeButtonPrices()
	end))

	local upgradesAtom = GetDataSource({ "upgrades" })

	self.janitor:Add(Charm.subscribe(upgradesAtom, function()
		self:_updateUpgradeButtonPrices()
	end))

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

function Plot._setupUpgradeButtonFX(
	_self: Plot,
	button: typeof(workspace._PLOTS["1"].UpgradeTable.UpgradeTable.UpgradePart.SurfaceGui.Frame.gates.UpgradeButton)
)
	local UIScale = Instance.new("UIScale")
	UIScale.Parent = button

	local spring = Ripple.createSpring(
		1,
		{
			start = true,
			dampingRatio = 0.7,
			frequency = 4,
		} :: Ripple.SpringOptions
	)

	spring:onChange(function(value)
		UIScale.Scale = value
	end)

	button.MouseEnter:Connect(function()
		SoundServiceClient:play("uiEnter")
		spring:setGoal(1.1)
	end)

	button.MouseLeave:Connect(function()
		spring:setGoal(1)
	end)

	button.SelectionGained:Connect(function()
		spring:setGoal(1.1)
	end)

	button.SelectionLost:Connect(function()
		spring:setGoal(1)
	end)

	button.MouseButton1Down:Connect(function()
		SoundServiceClient:play("uiClick")
		spring:setGoal(0.9)
	end)

	button.MouseButton1Up:Connect(function()
		spring:setGoal(1.1)
	end)
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

		self:_setupUpgradeButtonFX(upgradeFrame.UpgradeButton)

		self.janitor:Add(
			upgradeFrame.UpgradeButton.Activated:Connect(function()
				local result = self.networker:fetch("upgrade", upgradeId)

				if result ~= "SUCCESS" then
					if InfoEnums[result] then
						ErrorMessage.add(InfoEnums[result])
					else
						ErrorMessage.add(InfoEnums.ERROR)
					end
				end
			end),
			"Disconnect"
		)

		self.upgradeButtons[upgradeFrame.UpgradeButton] = upgradeId
		self:_updateUpgradeButtonPrices()
	end

	for _, upgradeFrame: typeof(workspace._PLOTS["1"].UpgradeTable.UpgradeTable.UpgradePart.SurfaceGui.Frame.gates) in upgradeBoardUI:GetChildren() do
		if not upgradeFrame:IsA("Frame") then
			continue
		end
		local upgradeId = upgradeFrame.Name

		setupUpgradeFrame(upgradeFrame, upgradeId)
	end
end

function Plot.setupStarterPack(self: Plot)
	--[[
		When you touch it it will prompt product purchase,
		When one time purchase completed destroy the model
	]]
	local owns = Charm.atom(MonetizationServiceClient:ownsOneTimePurchase(Products.starterPack))

	if owns() then
		-- Destroy
		self.plotModel.StarterPack:Destroy()
		return
	end

	self.janitor:Add(
		MonetizationServiceClient:getProductInfoChangedSignal(Products.starterPack):Connect(function()
			owns(MonetizationServiceClient:ownsOneTimePurchase(Products.starterPack))
		end),
		"Disconnect"
	)

	self.janitor:Add(Charm.subscribe(owns, function(state)
		if state == true then
			self.plotModel.StarterPack:Destroy()
			return
		end
	end))

	self.janitor:Add(
		self.plotModel.StarterPack.Hitbox.Touched:Connect(function(hit: BasePart)
			if hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid") then
				local player = Players:GetPlayerFromCharacter(hit.Parent)

				if player == Players.LocalPlayer then
					MonetizationServiceClient:promptProduct(Products.starterPack)
				end
			end
		end),
		"Disconnect"
	)
end

function Plot.teleportToBase(self: Plot): ()
	self.networker:fire("teleportToBase")
	return
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
				local result = self.networker:fetch("addRunner", runnerAmount)

				if result ~= "SUCCESS" then
					if InfoEnums[result] then
						ErrorMessage.add(InfoEnums[result])
					else
						ErrorMessage.add(InfoEnums.ERROR)
					end
				end
			else
				self.networker:fire("merge")
			end
			SoundServiceClient:play("buttonTouch")
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

					self:_updateRunnerButtonPrices()
				end
			end)

			task.delay(0.25, function()
				if buttonTop and buttonTop.Parent then
					if buttonType == "Merge" then
						self:_updateMergeButtonState()
					else
						self:_updateRunnerButtonPrices()
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

function Plot._registerRunnerButton(self: Plot, buttonTop: BasePart, buttonModel: Instance, runnerAmount: number)
	local attachment = buttonModel:FindFirstChild("Attachment")
	if not attachment then
		return
	end

	local billboardGui = attachment:FindFirstChild("BillboardGui")
	if not billboardGui then
		return
	end

	local moneyText: TextLabel = billboardGui:FindFirstChild("Money") :: TextLabel
	if not moneyText then
		return
	end

	self.runnerButtons[#self.runnerButtons + 1] = {
		buttonTop = buttonTop,
		runnerAmount = runnerAmount,
		moneyText = moneyText,
	}

	self:_updateRunnerButtonPrices()
end

function Plot._updateUpgradeButtonPrices(self: Plot)
	local cash = DataService:get("cash")

	if typeof(cash) ~= "number" then
		return
	end

	for
		upgradeButton: typeof(workspace._PLOTS["1"].UpgradeTable.UpgradeTable.UpgradePart.SurfaceGui.Frame.gates.UpgradeButton),
		upgradeId: keyof<typeof(_DataTemplate.upgrades)>
	in self.upgradeButtons do
		local currentUpgradeLevel: number = DataService:get({ "upgrades", upgradeId })
		local nextUpgradeLevel: number = currentUpgradeLevel + 1
		local upgradeCost = UpgradeUtils.calculateUpgradeCost(upgradeId, nextUpgradeLevel)

		if UpgradeUtils.levelCaps[upgradeId] <= currentUpgradeLevel then
			-- MAX

			upgradeButton.BTN_Surface.FX_BackgroundGradient.Rotation = 180
			upgradeButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
			upgradeButton.FX_DropShadow.Color = Color3.fromRGB(92, 115, 103)
			upgradeButton.BTN_Surface.FX_BackgroundGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 30, 86)),
				ColorSequenceKeypoint.new(0.16, Color3.fromRGB(161, 30, 255)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(30, 180, 255)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(49, 255, 30)),
				ColorSequenceKeypoint.new(0.66, Color3.fromRGB(255, 255, 30)),
				ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 143, 30)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 30, 86)),
			})

			continue
		end

		if cash >= upgradeCost then
			-- Affordable

			upgradeButton.BTN_Surface.FX_BackgroundGradient.Rotation = 90
			upgradeButton.BackgroundColor3 = Color3.fromRGB(0, 95, 21)
			upgradeButton.FX_DropShadow.Color = Color3.fromRGB(0, 121, 0)
			upgradeButton.BTN_Surface.FX_BackgroundGradient.Color = ColorSequence.new(Color3.fromRGB(124, 172, 78))
			continue
		else
			-- Not enough cash

			upgradeButton.BTN_Surface.FX_BackgroundGradient.Rotation = 90
			upgradeButton.BackgroundColor3 = Color3.fromRGB(41, 29, 45)
			upgradeButton.FX_DropShadow.Color = Color3.fromRGB(116, 96, 96)
			upgradeButton.BTN_Surface.FX_BackgroundGradient.Color = ColorSequence.new(Color3.fromRGB(71, 71, 71))

			continue
		end
	end
end

function Plot._updateRunnerButtonPrices(self: Plot)
	local runnerPurchases = DataService:get("runnerPurchases")
	local cash = DataService:get("cash")
	if typeof(runnerPurchases) ~= "number" or typeof(cash) ~= "number" then
		return
	end

	for _, runnerButton in self.runnerButtons do
		if not runnerButton.buttonTop.Parent then
			continue
		end

		if not runnerButton.moneyText.Parent then
			continue
		end

		local cost = Runners.calculateRunnerBatchPrice(runnerPurchases, runnerButton.runnerAmount)
		runnerButton.moneyText.Text = if cost == 0 then "Free" else FormatCurrency(cost, true)
		runnerButton.buttonTop.Color = if cash >= cost then RUNNER_ENABLED_COLOR else BUTTON_DISABLED_COLOR
	end
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
		self:_registerRunnerButton(button, buttonModel, runnerAmount)
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
		runnerButtons: { [number]: RunnerButton },
		registeredButtons: { [Instance]: boolean },
		upgradeButtons: { [GuiButton]: string },
	},
	Plot
))

return Plot
