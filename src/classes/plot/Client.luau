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
local BlockServiceClient = require(ReplicatedStorage.Shared.Services.BlockService.BlockServiceClient)
local Blocks = require(ReplicatedStorage.Shared.Modules.Items.Blocks)
local CratesSlice = require(ReplicatedStorage.Shared.UI.Crates.CratesSlice)
local ErrorMessage = require(ReplicatedStorage.Shared.Modules.Ui.Components.ErrorMessage)
local ExclusiveCars = require(ReplicatedStorage.Shared.Modules.Items.ExclusiveCars)
local FormatCurrency = require(ReplicatedStorage.Shared.Modules.Ui.FormatCurrency)
local GeneralNotificationsServiceClient = require(ReplicatedStorage.Shared.Services.GeneralNotificationsService.GeneralNotificationsServiceClient)
local GetDataSource = require(ReplicatedStorage.Shared.Modules.Ui.Sources.GetDataSource)
local InfoEnums = require(ReplicatedStorage.Shared.Modules.Utils.InfoEnums)
local Menu = require(ReplicatedStorage.Shared.UI.App.Components.Menu)
local MonetizationServiceClient = require(ReplicatedStorage.Shared.Services.MonetizationService.MonetizationServiceClient)
local PlotServiceTypes = require(ReplicatedStorage.Shared.Services.PlotService.PlotServiceTypes)
local Products = require(ReplicatedStorage.Shared.Services.MonetizationService.Modules.Products)
local Rarities = require(ReplicatedStorage.Shared.Modules.Items.Rarities)
local Ripple = require(ReplicatedStorage.Packages.Ripple)
local RouteServiceUtils = require(ReplicatedStorage.Shared.Services.RouteService.RouteServiceUtils)
local RunnerUtils = require(ReplicatedStorage.Shared.Classes.Runner.RunnerUtils)
local Runners = require(ReplicatedStorage.Shared.Modules.Items.Runners)
local SoundServiceClient = require(ReplicatedStorage.Shared.Services.SoundService.SoundServiceClient)
local StockSlice = require(ReplicatedStorage.Shared.Services.StockService.StockSlice)
local Trails = require(ReplicatedStorage.Shared.Modules.Items.Trails)
local UpgradeUtils = require(ReplicatedStorage.Shared.Modules.Items.UpgradeUtils)
local _DataTemplate = require(ReplicatedStorage.Shared.Modules.Game.DataTemplate)
const TutorialSlice = require(ReplicatedStorage.Shared.UI.Tutorial.TutorialSlice)

local RUNNER_ENABLED_COLOR = Color3.fromRGB(11, 138, 20)
local BUTTON_DISABLED_COLOR = Color3.fromRGB(136, 136, 136)
local LIMITED_CAR_PRODUCT_KEY = "exclusiveCar"

const isTutorialFinished = TutorialSlice.states.isTutorialFinished
const localTutorialStage = TutorialSlice.states.localTutorialStage

type RunnerButton = {
	buttonTop: BasePart,
	runnerAmount: number,
	moneyText: TextLabel,
}

type BlockState = {
	blockId: number?,
	lapsLeft: number?,
}

function Plot.new(plotData: PlotServiceTypes.PlotData): Plot
	-- The plot can be assigned before the initial profile snapshot reaches the
	-- client. Build data-backed UI only after persisted values are available.
	DataService:waitForData()

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
	self.networker = Networker.client.new(`plot_{self.player.UserId}`, self)

	self:setupButtons()
	self:setupUpgradeBoard()
	self:setupStarterPack()
	self:setupLimitedCar()
	self:setupGroupRewardsChest()
	self:setupRoutes()
	self:setupBlocks()
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
	self.janitor:Add(Charm.subscribe(GetDataSource("rebirths"), function()
		self:_updateUpgradeButtonPrices()
	end))

	self.janitor:Add(
		DataService:getChangedSignal({ "runners" }):Connect(function()
			self:_updateMergeButtonState()
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

--[=[
	Resolves the character `hit` belongs to, and only when that character is this
	plot's owner. Returns nil for anything else.

	This deliberately avoids reading `Player.Character`. That property is
	replicated, so on the client it is still nil or still the *previous* character
	for a few frames after a respawn, while the new character's parts are already
	generating Touched events. Any touch landing in that window fails the check and
	is dropped, and because Touched only fires on a fresh contact the trigger then
	stays dead until the player physically steps off and back on. The server
	teleports the character onto the plot on every CharacterAdded, so landing on a
	hitbox inside that exact window is common enough to explain the intermittency.

	Walking up from the touching part sidesteps the property entirely, and also
	resolves parts nested in accessories and tools, which `hit.Parent` alone misses.
]=]
function Plot._getTouchingCharacter(self: Plot, hit: BasePart): Model?
	local instance: Instance? = hit

	while instance and instance ~= workspace do
		if instance:IsA("Model") and instance:FindFirstChildOfClass("Humanoid") then
			-- Character models are named after their player, and usernames are
			-- unique, so this identifies the owner without the replication race.
			return if instance.Name == self.player.Name then instance else nil
		end

		instance = instance.Parent
	end

	return nil
end

--[=[
	Clones a plot prop from `ReplicatedStorage.Assets.Plot` onto the plot.

	Plots only carry an `Attachment` marker per prop instead of the prop itself,
	which keeps them out of server replication and lets a prop the player can
	never use go unbuilt. The marker's `WorldCFrame` carries the authored
	rotation, which is flipped on the far row of plots, and `PivotTo` reproduces
	the original placement exactly.

	@param assetName string -- template name, matched by a `{assetName}Spawn` marker
	@return Model? -- nil when the plot has no marker or the template is missing
]=]
function Plot._spawnPlotAsset(self: Plot, assetName: string): Model?
	local marker = self.plotModel:FindFirstChild(`{assetName}Spawn`)
	local template = ReplicatedStorage.Assets.Plot:FindFirstChild(assetName)

	if not (marker and marker:IsA("Attachment") and template) then
		return nil
	end

	local asset = template:Clone() :: Model
	-- Place before parenting so the prop never renders at the template's origin.
	asset:PivotTo(marker.WorldCFrame)
	asset.Parent = self.plotModel

	return asset
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
	local upgradeSurfaceGui = upgradeBoardUI.Parent :: SurfaceGui
	upgradeSurfaceGui.MaxDistance = 0

	UpgradeUtils.updateLevelCaps()

	local extraGates = GetDataSource({ "extraGates" })
	local selectedRouteAtom = GetDataSource({ "selectedRoute" })
	local rebirths = GetDataSource("rebirths")

	local function setupUpgradeFrame(
		upgradeFrame: typeof(workspace._PLOTS["1"].UpgradeTable.UpgradeTable.UpgradePart.SurfaceGui.Frame.gates),
		upgradeId: string
	)
		if upgradeId ~= "gates" and upgradeId ~= "runnerSpeed" and upgradeId ~= "cashBonus" then
			return
		end

		local levelAtomForUpgrade = GetDataSource({ "upgrades", upgradeId })
		local function changeLevelStatus(rawLevel: number)
			if upgradeId == "gates" then
				local route = RouteServiceUtils[selectedRouteAtom()]
				if not route then
					return
				end

				local cashGateCount = math.clamp(rawLevel, 0, route.cashGateCap)
				local activeExtraGateCount = if cashGateCount >= route.cashGateCap then math.clamp(extraGates(), 0, route.gateCap - route.cashGateCap) else 0
				local totalGateCount = cashGateCount + activeExtraGateCount

				upgradeFrame.level.Text = `Level {totalGateCount}/{route.gateCap}`
				if cashGateCount >= route.cashGateCap then
					upgradeFrame.nextLevel.Text = if totalGateCount >= route.gateCap then "MAX LEVEL" else `{totalGateCount} → {totalGateCount + 1}`
					upgradeFrame.UpgradeButton.BTN_Surface.TXT_ButtonLabel.Text = "MAX"
					return
				end

				local nextCashGateLevel = rawLevel + 1
				local cost = UpgradeUtils.calculateUpgradeCost(upgradeId, nextCashGateLevel, rebirths())
				upgradeFrame.nextLevel.Text = `{cashGateCount} → {cashGateCount + 1}`
				upgradeFrame.UpgradeButton.BTN_Surface.TXT_ButtonLabel.Text = cost == 0 and "FREE" or FormatCurrency(cost, true)
				return
			end

			upgradeFrame.level.Text = `Level {rawLevel}/{UpgradeUtils.levelCaps[upgradeId]()}`
			local nextLevel = rawLevel + 1
			if rawLevel >= UpgradeUtils.levelCaps[upgradeId]() then
				upgradeFrame.nextLevel.Text = "MAX LEVEL"
				upgradeFrame.UpgradeButton.BTN_Surface.TXT_ButtonLabel.Text = "MAX"
			else
				local currentMultiplier = if upgradeId == "runnerSpeed"
					then RunnerUtils.getRunnerSpeedMultiplier(rawLevel)
					else RunnerUtils.getCashBonusMultiplier(rawLevel)
				local nextMultiplier = if upgradeId == "runnerSpeed"
					then RunnerUtils.getRunnerSpeedMultiplier(nextLevel)
					else RunnerUtils.getCashBonusMultiplier(nextLevel)
				local currentBonus = math.round((currentMultiplier - 1) * 100)
				local nextBonus = math.round((nextMultiplier - 1) * 100)
				upgradeFrame.nextLevel.Text = `+{currentBonus}% → +{nextBonus}%`
				local cost = UpgradeUtils.calculateUpgradeCost(upgradeId, nextLevel, rebirths())
				upgradeFrame.UpgradeButton.BTN_Surface.TXT_ButtonLabel.Text = cost == 0 and "FREE" or FormatCurrency(cost, true)
			end
		end

		if upgradeId ~= "gates" then
			self.janitor:Add(Charm.subscribe(levelAtomForUpgrade, function(newLevel)
				changeLevelStatus(newLevel)
			end))
			self.janitor:Add(Charm.subscribe(rebirths, function()
				changeLevelStatus(levelAtomForUpgrade())
			end))
		end

		if upgradeId == "gates" then
			local extraFrame = upgradeFrame:WaitForChild("Extra") :: Frame
			local vipButton = extraFrame:WaitForChild("vip") :: GuiButton
			local singularButton = extraFrame:WaitForChild("singular") :: GuiButton

			local function updateSingularButtonPrice(extraGateCount: number)
				local route = RouteServiceUtils[selectedRouteAtom()]
				local maxExtraGateCount = if route then route.gateCap - route.cashGateCap else 0
				local nextGateNumber = extraGateCount + 1
				local product = if extraGateCount < maxExtraGateCount then Products[`extraGate{nextGateNumber}`] else nil

				if product then
					singularButton.BTN_Surface.TXT_ButtonLabel.Text = MonetizationServiceClient:getProductCostString(product)
				else
					singularButton.BTN_Surface.TXT_ButtonLabel.Text = "MAX"
				end
			end

			for tier = 1, 2 do
				local product = Products[`extraGate{tier}`]
				if product then
					self.janitor:Add(
						MonetizationServiceClient:getProductInfoChangedSignal(product):Connect(function()
							if singularButton.Parent then
								updateSingularButtonPrice(extraGates())
							end
						end),
						"Disconnect"
					)
				end
			end

			vipButton.Activated:Connect(function()
				local ownsVip = MonetizationServiceClient:ownsGamepass(Products.vip)

				if not ownsVip then
					MonetizationServiceClient:promptProduct(Products.vip)
					return
				end

				local success, response = self.networker:fetch("upgradeGatesWithPass")
				if not success then
					if InfoEnums[response] then
						ErrorMessage.add(InfoEnums[response])
					else
						ErrorMessage.add(InfoEnums.ERROR)
					end
				else
					GeneralNotificationsServiceClient:displayNotification("Successfully placed extra gate.")
				end
			end)

			singularButton.Activated:Connect(function()
				local nextExtraGate = extraGates() + 1
				if not Products[`extraGate{nextExtraGate}`] then
					return
				end

				local nextGateProduct = Products[`extraGate{nextExtraGate}`]
				MonetizationServiceClient:promptProduct(nextGateProduct)
			end)

			self:_setupUpgradeButtonFX(vipButton)
			self:_setupUpgradeButtonFX(singularButton)

			local function updateGateButtonVisibility(rawLevel: number)
				local route = RouteServiceUtils[selectedRouteAtom()]
				if not route then
					upgradeFrame.UpgradeButton.Visible = true
					extraFrame.Visible = false
					return
				end

				local cashGateCount = math.clamp(rawLevel, 0, route.cashGateCap)
				local cashCapReached = cashGateCount >= route.cashGateCap
				local activeExtraGateCount = if cashCapReached then math.clamp(extraGates(), 0, route.gateCap - route.cashGateCap) else 0
				local isFullyMaxed = cashGateCount + activeExtraGateCount >= route.gateCap

				upgradeFrame.UpgradeButton.Visible = not cashCapReached or isFullyMaxed
				extraFrame.Visible = cashCapReached and not isFullyMaxed
			end

			local function renderGateUpgradeState()
				local rawLevel = levelAtomForUpgrade()
				changeLevelStatus(rawLevel)
				updateGateButtonVisibility(rawLevel)
				updateSingularButtonPrice(extraGates())
				self:_updateUpgradeButtonPrices()
			end

			self.janitor:Add(Charm.subscribe(extraGates, function()
				renderGateUpgradeState()
			end))

			self.janitor:Add(Charm.subscribe(levelAtomForUpgrade, function()
				renderGateUpgradeState()
			end))

			self.janitor:Add(Charm.subscribe(selectedRouteAtom, function()
				renderGateUpgradeState()
			end))

			renderGateUpgradeState()
		else
			changeLevelStatus(levelAtomForUpgrade())
		end

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

--[=[
	Strips every other plot's crate stand down to just the model.

	The crate model is built on the server so everyone can see what their
	neighbours are working toward, but the billboard's lap progress and the
	prompt's open action only mean anything to the plot's owner. PlotClient is
	only ever constructed for the local player's own plot, so any other stand
	belongs to somebody else.
]=]
function Plot._hideCrateUIOnOtherPlots(self: Plot)
	local function hideFor(plotModel: Instance)
		if plotModel == self.plotModel then
			return
		end

		local luckyBlock = plotModel:FindFirstChild("LuckyBlock")
		if not luckyBlock then
			return
		end

		-- Addressed by their authored paths rather than a recursive search, so a
		-- crate model that ships its own gui or prompt is left untouched.
		local billboard = luckyBlock:FindFirstChild("Billboard")
		local billboardGui = billboard and billboard:FindFirstChild("BillboardGui")
		if billboardGui and billboardGui:IsA("BillboardGui") then
			billboardGui.Enabled = false
		end

		local crateSpawn = luckyBlock:FindFirstChild("CrateSpawn")
		local proximityPrompt = crateSpawn and crateSpawn:FindFirstChild("ProximityPrompt")
		if proximityPrompt and proximityPrompt:IsA("ProximityPrompt") then
			proximityPrompt.Enabled = false
		end

		local autoOpenCrate = crateSpawn and crateSpawn:FindFirstChild("autoOpenCrate")
		if autoOpenCrate and autoOpenCrate:IsA("ProximityPrompt") then
			autoOpenCrate.Enabled = false
		end
	end

	for _, plotModel in workspace._PLOTS:GetChildren() do
		hideFor(plotModel)
	end

	-- Plot models are authored into the place file rather than streamed in, but
	-- this keeps a late-replicating stand from showing up with its UI intact.
	self.janitor:Add(workspace._PLOTS.ChildAdded:Connect(hideFor), "Disconnect")
end

function Plot.setupBlocks(self: Plot)
	local blockInQueue = GetDataSource({ "luckyBlockInQueue" })
	local lapsLeftToAcquire = GetDataSource({ "lapsLeftToAcquire" })

	local autoOpenPrompt = self.plotModel.LuckyBlock.CrateSpawn.autoOpenCrate
	local billboardFrame = self.plotModel.LuckyBlock.Billboard.BillboardGui.Frame
	local crateNameLabel = billboardFrame.TextLabel
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "AutoRollStatus"
	statusLabel.BackgroundTransparency = 1
	statusLabel.Size = UDim2.fromScale(1, 0.25)
	statusLabel.LayoutOrder = -2
	statusLabel.Font = crateNameLabel.Font
	statusLabel.TextColor3 = Color3.new(1, 1, 1)
	statusLabel.TextScaled = true
	statusLabel.TextStrokeTransparency = 0
	statusLabel.Text = ""
	statusLabel.Visible = false
	statusLabel.Parent = billboardFrame
	self.janitor:Add(statusLabel, "Destroy")

	local autoRollEnabled = Charm.atom(BlockServiceClient:getAutoRollState())
	local isAutoOpenPending = false
	local statusToken = 0
	local isAutoRollPromptEnabled = Charm.computed(function()
		return isTutorialFinished() or localTutorialStage() >= 10
	end)

	local promptEnabled = Charm.computed(function()
		local blockId = blockInQueue()
		local lapsLeft = lapsLeftToAcquire()
		local isRollScreenOn = CratesSlice.states.cratesScreenOpen()

		local baseCondition = blockId ~= nil and lapsLeft ~= nil and not (lapsLeft > 0) and not isRollScreenOn
		local tutorialAllows = isTutorialFinished() or localTutorialStage() >= 7

		return baseCondition and tutorialAllows and not autoRollEnabled()
	end)

	local previousBlockId

	local function updateAutoOpenPrompt()
		local ownsPass = MonetizationServiceClient:ownsGamepass(Products.autoRollCrate)
		autoOpenPrompt.ObjectText = "Auto Roll"
		autoOpenPrompt.Enabled = isAutoRollPromptEnabled()
		autoOpenPrompt.ActionText = if ownsPass
			then (if autoRollEnabled() then "ON" else "OFF")
			else `OFF ({MonetizationServiceClient:getProductCostString(Products.autoRollCrate)})`
	end

	local function showCrateStatus(text: string, color: Color3?)
		statusLabel.Text = text
		statusLabel.TextColor3 = color or Color3.new(1, 1, 1)
		statusLabel.Visible = true
	end

	local function clearCrateStatus()
		statusLabel.Text = ""
		statusLabel.Visible = false
		previousBlockId = nil
	end

	local function updateUIState(blockId: number?, lapsLeft: number?)
		if blockId == nil then
			previousBlockId = blockId

			-- Name and progress

			crateNameLabel.Text = ""
			self.plotModel.LuckyBlock.Billboard.BillboardGui.Frame.Bar.CanvasGroup.TextLabel.Text = "0/0 Laps"
			self.plotModel.LuckyBlock.Billboard.BillboardGui.Frame.Bar.CanvasGroup.Bar.Size = UDim2.fromScale(0, 0)

			return
		end

		local blockInfo = Blocks.getBlock(blockId)

		if blockId ~= previousBlockId then
			previousBlockId = blockId
			-- Name
			crateNameLabel.Text = blockInfo.blockName
		end

		self.plotModel.LuckyBlock.Billboard.BillboardGui.Frame.Bar.CanvasGroup.TextLabel.Text =
			`{blockInfo.lapsRequirement - lapsLeft}/{blockInfo.lapsRequirement} Laps`
		self.plotModel.LuckyBlock.Billboard.BillboardGui.Frame.Bar.CanvasGroup.Bar.Size =
			UDim2.fromScale(math.clamp((blockInfo.lapsRequirement - lapsLeft) / blockInfo.lapsRequirement, 0, 1), 1)
	end

	local function getBlockState(): BlockState
		return {
			blockId = blockInQueue(),
			lapsLeft = lapsLeftToAcquire(),
		}
	end

	local function tryAutoOpen(state: BlockState)
		if not autoRollEnabled() or isAutoOpenPending or CratesSlice.states.cratesScreenOpen() then
			return
		end
		if state.blockId == nil or state.lapsLeft == nil or state.lapsLeft > 0 then
			return
		end

		isAutoOpenPending = true
		task.spawn(function()
			local response = BlockServiceClient:openAutoCrate()
			if response ~= "SUCCESS" then
				isAutoOpenPending = false
				task.delay(0.25, function()
					tryAutoOpen(getBlockState())
				end)
			end
		end)
	end

	-- Announces a crate once, either when its laps run out or, on the first
	-- evaluation, because the player joined with it already rollable.
	--
	-- Requiring the crate id to be unchanged is what separates "this crate's laps
	-- ran out" from "a different crate was just queued". The two keys replicate as
	-- independent atoms, so a newly queued crate can still be observed alongside
	-- the previous crate's spent lap count of zero. A freshly queued crate always
	-- carries laps to run, so nothing legitimate is suppressed.
	local function notifyWhenRollable(state: BlockState, previousState: BlockState?)
		if autoRollEnabled() then
			return
		end

		if state.blockId == nil or state.lapsLeft == nil or state.lapsLeft > 0 then
			return
		end

		if previousState and not (previousState.blockId == state.blockId and (previousState.lapsLeft or 0) > 0) then
			return
		end

		local blockInfo = Blocks.getBlock(state.blockId)
		if blockInfo == nil then
			return
		end

		task.defer(GeneralNotificationsServiceClient.displayNotification, GeneralNotificationsServiceClient, `You can roll {blockInfo.blockName} now!`)
	end

	self:_hideCrateUIOnOtherPlots()
	self.plotModel.LuckyBlock.Billboard.BillboardGui.Enabled = true
	updateAutoOpenPrompt()

	self.janitor:Add(Charm.subscribe(promptEnabled, function(enabled: boolean)
		self.plotModel.LuckyBlock.CrateSpawn.ProximityPrompt.Enabled = enabled
	end))
	self.plotModel.LuckyBlock.CrateSpawn.ProximityPrompt.Enabled = promptEnabled()

	self.janitor:Add(
		self.plotModel.LuckyBlock.CrateSpawn.ProximityPrompt.Triggered:Connect(function(player: Player)
			if player ~= Players.LocalPlayer then
				return
			end

			BlockServiceClient:openCrate()
		end),
		"Disconnect"
	)

	self.janitor:Add(
		autoOpenPrompt.Triggered:Connect(function(player: Player)
			if player ~= Players.LocalPlayer then
				return
			end

			if not MonetizationServiceClient:ownsGamepass(Products.autoRollCrate) then
				MonetizationServiceClient:promptProduct(Products.autoRollCrate)
				return
			end

			local response, enabled = BlockServiceClient:toggleAutoRoll()
			if response == "SUCCESS" then
				autoRollEnabled(enabled)
				updateAutoOpenPrompt()
				tryAutoOpen(getBlockState())
			end
		end),
		"Disconnect"
	)

	self.janitor:Add(BlockServiceClient.autoRollStateChanged:Connect(function(enabled: boolean)
		autoRollEnabled(enabled)
		updateAutoOpenPrompt()
		tryAutoOpen(getBlockState())
	end))

	self.janitor:Add(MonetizationServiceClient:getProductInfoChangedSignal(Products.autoRollCrate):Connect(updateAutoOpenPrompt))
	self.janitor:Add(Charm.subscribe(isAutoRollPromptEnabled, updateAutoOpenPrompt))

	self.janitor:Add(BlockServiceClient.crateRollStatusChanged:Connect(function(text: string?, roll: CratesSlice.Roll?)
		if text then
			statusToken += 1
			if text == "ROLLED" and roll then
				local trail = Trails[roll.trailId]
				if trail then
					local token = statusToken
					showCrateStatus(`Rolled {trail.trailName} Trail [{trail.trailRarity}]`, Rarities[trail.trailRarity])
					task.delay(Blocks.revealHold, function()
						if token ~= statusToken then
							return
						end
						clearCrateStatus()
						updateUIState(blockInQueue(), lapsLeftToAcquire())
						isAutoOpenPending = false
						tryAutoOpen(getBlockState())
					end)
				end
			else
				showCrateStatus(text)
			end
		else
			isAutoOpenPending = false
			clearCrateStatus()
			updateUIState(blockInQueue(), lapsLeftToAcquire())
		end
	end))

	self.janitor:Add(Charm.listen(getBlockState, function(state, prevState)
		updateUIState(state.blockId, state.lapsLeft)
		notifyWhenRollable(state, prevState)
		tryAutoOpen(state)
	end))

	self.janitor:Add(Charm.subscribe(CratesSlice.states.cratesScreenOpen, function(isOpen: boolean)
		if not isOpen then
			tryAutoOpen(getBlockState())
		end
	end))
end

--[=[
	Plot-side route pedestal.

	The pedestal is cloned from ReplicatedStorage and carries its own
	`RouteSpawn` marker, so the shrunken preview of the selected route lands in
	the right spot on every plot without the pedestal being replicated.
]=]
function Plot.setupRoutes(self: Plot)
	local pedestal = self:_spawnPlotAsset("Routes")
	if not pedestal then
		return
	end

	self.janitor:Add(pedestal, "Destroy")

	local selectedRouteSource = GetDataSource({ "selectedRoute" })
	local runwayPreview: Model? = nil

	local function placeRunwayPreview(routeId: number)
		if runwayPreview then
			runwayPreview:Destroy()
			runwayPreview = nil
		end

		local routeTemplate = ReplicatedStorage.Assets.Runways:FindFirstChild(`Runway{routeId}`)

		if not routeTemplate then
			return
		end

		local preview: Model = routeTemplate:Clone()

		preview:ScaleTo(0.1)

		for _, basePart in preview:GetDescendants() do
			if not basePart:IsA("BasePart") then
				continue
			end

			basePart.CanCollide = false
		end

		preview:PivotTo(pedestal.RouteSpawn.WorldCFrame)
		preview.Parent = pedestal
		runwayPreview = preview
	end

	placeRunwayPreview(selectedRouteSource())

	self.janitor:Add(Charm.subscribe(selectedRouteSource, placeRunwayPreview))

	self.janitor:Add(
		pedestal.Hitbox.Touched:Connect(function(hit: BasePart)
			if not self:_getTouchingCharacter(hit) then
				return
			end

			if Menu.openedMenu() == "Routes" or Menu.openedMenu() == "OfflineRewards" then
				return
			end
			Menu.setOpenedMenu("Routes")
		end),
		"Disconnect"
	)
end

function Plot.claimGroupRewards(self: Plot): boolean
	local success, result = self.networker:fetch("giveGroupReward")

	if not success then
		if InfoEnums[result] then
			ErrorMessage.add(InfoEnums[result])
		else
			ErrorMessage.add(InfoEnums.ERROR)
		end
	else
		GeneralNotificationsServiceClient:displayNotification("Successfully claimed group reward 🥳!")
	end

	return success
end

--[=[
	Plot-side group reward chest.

	The chest is cloned from ReplicatedStorage only while the reward is
	unclaimed, so a claimed reward leaves nothing on the plot to clean up.
]=]
function Plot.setupGroupRewardsChest(self: Plot)
	local isGroupRewardClaimed = GetDataSource({ "isGroupRewardClaimed" })

	if isGroupRewardClaimed() then
		return
	end

	local chest = self:_spawnPlotAsset("GroupChest")
	if not chest then
		return
	end

	self.janitor:Add(chest, "Destroy")

	self.janitor:Add(
		chest.Hitbox.Touched:Connect(function(hit: BasePart)
			if not self:_getTouchingCharacter(hit) then
				return
			end

			if Menu.openedMenu() == "GroupRewards" or Menu.openedMenu() == "OfflineRewards" then
				return
			end
			Menu.setOpenedMenu("GroupRewards")
		end),
		"Disconnect"
	)

	self.janitor:Add(Charm.subscribe(isGroupRewardClaimed, function(newState: boolean)
		if newState == true then
			chest:Destroy()
			return
		end
	end))
end

--[=[
	Plot-side storefront for the starter pack.

	The model is cloned from ReplicatedStorage only while the pack is still
	available, so an owned pack is never built onto the plot in the first place.
]=]
function Plot.setupStarterPack(self: Plot)
	local owns = Charm.atom(MonetizationServiceClient:ownsOneTimePurchase(Products.starterPack))

	if owns() then
		return
	end

	local storefront = self:_spawnPlotAsset("StarterPack")
	if not storefront then
		return
	end

	self.janitor:Add(storefront, "Destroy")

	local moneyLabel = storefront.Attachment.BillboardGui:WaitForChild("Money")
	moneyLabel.Text = MonetizationServiceClient:getProductCostString(Products.starterPack)

	self.janitor:Add(
		MonetizationServiceClient:getProductInfoChangedSignal(Products.starterPack):Connect(function()
			if moneyLabel.Parent then
				moneyLabel.Text = MonetizationServiceClient:getProductCostString(Products.starterPack)
			end

			owns(MonetizationServiceClient:ownsOneTimePurchase(Products.starterPack))
		end),
		"Disconnect"
	)

	self.janitor:Add(Charm.subscribe(owns, function(state)
		if state == true then
			storefront:Destroy()
			return
		end
	end))

	self.janitor:Add(
		storefront.Hitbox.Touched:Connect(function(hit: BasePart)
			if not self:_getTouchingCharacter(hit) then
				return
			end

			MonetizationServiceClient:promptProduct(Products.starterPack)
		end),
		"Disconnect"
	)
end

--[=[
	Plot-side storefront for the limited exclusive car.

	The model is cloned from ReplicatedStorage only while stock remains, so a
	sold-out car is never built onto the plot, and it is torn down again the
	moment the last unit sells. It ships without a hitbox because its child
	models are visual only, so one is generated from the model bounds.
]=]
function Plot.setupLimitedCar(self: Plot)
	local product = Products.exclusiveCar
	local stockLimit = product.stock
	local storefrontJanitor = self.janitor:Add(Janitor.new(), "Destroy")

	local isDisplayed = false
	local stockLabel: TextLabel? = nil

	local function isSoldOut(): boolean
		return StockSlice.isSoldOut(LIMITED_CAR_PRODUCT_KEY)
	end

	local function updateStock()
		if not (stockLabel and stockLabel.Parent) then
			return
		end

		local remaining = StockSlice.getRemaining(LIMITED_CAR_PRODUCT_KEY)
		stockLabel.Text = if stockLimit then `{math.max(0, remaining)}/{stockLimit}` else ""
	end

	local function display()
		local storefront = self:_spawnPlotAsset("LimitedCar")
		if not storefront then
			return
		end

		isDisplayed = true
		storefrontJanitor:Add(storefront, "Destroy")

		local billboard = storefront:WaitForChild("UIAttachment"):WaitForChild("BillboardGui")
		local priceLabel = billboard:WaitForChild("price") :: TextLabel
		stockLabel = billboard:WaitForChild("stock") :: TextLabel

		local function updatePrice()
			if priceLabel.Parent then
				priceLabel.Text = MonetizationServiceClient:getProductCostString(product)
			end
		end

		updatePrice()
		updateStock()

		storefrontJanitor:Add(MonetizationServiceClient:getProductInfoChangedSignal(product):Connect(updatePrice), "Disconnect")

		local hitbox = Instance.new("Part")
		local boundsCFrame, boundsSize = storefront:GetBoundingBox()
		hitbox.Name = "Hitbox"
		hitbox.Size = boundsSize
		hitbox.CFrame = boundsCFrame
		hitbox.Anchored = true
		hitbox.CanCollide = false
		hitbox.Transparency = 1
		hitbox.CastShadow = false
		hitbox.CanQuery = false
		hitbox.Parent = storefront

		storefrontJanitor:Add(
			hitbox.Touched:Connect(function(hit: BasePart)
				if not self:_getTouchingCharacter(hit) then
					return
				end

				-- The server revalidates stock before granting, so this only avoids
				-- showing a purchase prompt that is guaranteed to be refused.
				if isSoldOut() then
					ErrorMessage.add(InfoEnums.OUT_OF_STOCK)
					return
				end

				MonetizationServiceClient:promptProduct(product)
			end),
			"Disconnect"
		)
	end

	--[[
		Sold counts arrive after the plot is built, so the first synced update is
		what decides whether the car is ever cloned. Later updates keep the stock
		label current and remove the display once the last unit sells.
	]]
	local function syncDisplay()
		if not StockSlice.states.isSynced() then
			return
		end

		if isSoldOut() then
			isDisplayed = false
			stockLabel = nil
			storefrontJanitor:Cleanup()
			return
		end

		if isDisplayed then
			updateStock()
			return
		end

		display()
	end

	syncDisplay()

	self.janitor:Add(Charm.subscribe(StockSlice.states.soldCounts, syncDisplay))
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
			if not self:_getTouchingCharacter(hit) then
				return
			end

			local now = os.clock()
			if now - lastTrigger < 0.75 then
				return
			end

			if not isTutorialFinished() then
				if buttonType == "Runner" then
					if runnerAmount == 1 and localTutorialStage() < 2 then
						return
					elseif runnerAmount >= 5 and localTutorialStage() < 4 then
						return
					end
				elseif buttonType == "Merge" then
					if localTutorialStage() < 5 then
						return
					end
				end
			end

			-- Armed only once the touch is actually going to act, so a touch that the
			-- tutorial gate above rejects cannot swallow the next valid one.
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
	local rebirths = DataService:get("rebirths")
	if typeof(cash) ~= "number" then
		return
	end

	for
		upgradeButton: typeof(workspace._PLOTS["1"].UpgradeTable.UpgradeTable.UpgradePart.SurfaceGui.Frame.gates.UpgradeButton),
		upgradeId: keyof<typeof(_DataTemplate.upgrades)>
	in self.upgradeButtons do
		local currentUpgradeLevel: number = DataService:get({ "upgrades", upgradeId })
		local levelCap = UpgradeUtils.levelCaps[upgradeId]()
		if upgradeId == "gates" then
			local route = RouteServiceUtils[DataService:get({ "selectedRoute" })]
			if route then
				levelCap = route.cashGateCap
			end
		end

		local nextUpgradeLevel: number = currentUpgradeLevel + 1
		local upgradeCost = UpgradeUtils.calculateUpgradeCost(upgradeId, nextUpgradeLevel, rebirths)
		local buttonLabel = upgradeButton.BTN_Surface.TXT_ButtonLabel

		if levelCap <= currentUpgradeLevel then
			-- MAX
			buttonLabel.Text = "MAX"

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

		buttonLabel.Text = if upgradeCost == 0 then "FREE" else FormatCurrency(upgradeCost, true)

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

	-- Must mirror the pairing rule in `Plot.merge` on the server, otherwise the
	-- merge button lights up for a merge that will never happen.
	for index = 1, #sortedLevels - 1 do
		if sortedLevels[index] == sortedLevels[index + 1] and not ExclusiveCars.isExclusive(sortedLevels[index]) then
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
