--!nonstrict

const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Charm = require(ReplicatedStorage.Packages.Charm)
const Vide = require(ReplicatedStorage.Packages.Vide)
const DataService = require(ReplicatedStorage.Packages.DataService).client
const GetDataSource = require(ReplicatedStorage.Shared.Modules.Ui.Sources.GetDataSource)

const TutorialServiceClient = require(ReplicatedStorage.Shared.Services.TutorialService.TutorialServiceClient)
const PlotServiceClient = require(ReplicatedStorage.Shared.Services.PlotService.PlotServiceClient)

const TutorialSlice = require(script.Parent.TutorialSlice)
const CratesSlice = require(ReplicatedStorage.Shared.UI.Crates.CratesSlice)
const Menu = require(ReplicatedStorage.Shared.UI.App.Components.Menu)
const SideButtons = require(ReplicatedStorage.Shared.UI.Hud.SideButtons)

const useInstructor = require(script.Parent.Components.useInstructor)
const useArrowNavigator = require(script.Parent.Components.useArrowNavigator)
const UINavigator = require(script.Parent.Components.UINavigator)

const uiTarget = Vide.source(nil :: GuiObject?)
const cursorSide = Vide.source("bottom" :: "top" | "bottom" | "left" | "right")
const instructorTextSource: Vide.Source<string> = Vide.source("") :: Vide.Source<string>

local plotModel: Model = nil :: any
local arrowNav = nil :: any
local currentAttachments = {
	upgradeTable = nil :: Attachment?,
	runnerButton = nil :: Attachment?,
	mergeButton = nil :: Attachment?,
	luckyBlock = nil :: Attachment?,
}

const function getOrCreateAttachment(key: string, parent: BasePart): Attachment
	if currentAttachments[key] then
		return currentAttachments[key] :: Attachment
	end

	local att = parent:FindFirstChild("TutorialArrow") :: Attachment?
	if not att then
		att = Instance.new("Attachment")
		att.Name = "TutorialArrow"
		att.Parent = parent
	end

	currentAttachments[key] = att
	return att :: Attachment
end

const function clearNavigators()
	if arrowNav then
		arrowNav.navigateTo(nil)
	end
	uiTarget(nil)
end

local tutorialSteps: { [number]: () -> () }

tutorialSteps = {
	-- Step 1: Buy a Gate Upgrade
	[1] = function()
		TutorialSlice.states.localTutorialStage(1)

		const gateUpgradeSource = GetDataSource({ "upgrades", "gates" })

		if gateUpgradeSource() >= 1 then
			TutorialServiceClient:saveStage(2)
			tutorialSteps[2]()
			return
		end

		instructorTextSource("Buy a gate!")

		local upgradePart = plotModel.UpgradeTable.UpgradeTable.UpgradePart
		local att = getOrCreateAttachment("upgradeTable", upgradePart)
		arrowNav.navigateTo(att)
		uiTarget(upgradePart.SurfaceGui.Frame.gates)
		cursorSide("bottom")

		local connection: (() -> ())?

		connection = Charm.subscribe(gateUpgradeSource, function(state)
			if state < 1 then
				return
			end
			clearNavigators()
			TutorialServiceClient:saveStage(2)
			tutorialSteps[2]()

			if connection ~= nil then
				connection()
			end
		end)
	end,

	-- Step 2: Buy Your First Runner
	[2] = function()
		TutorialSlice.states.localTutorialStage(2)
		instructorTextSource("")

		const runnersSource = GetDataSource("runners")

		if #runnersSource() >= 1 then
			TutorialServiceClient:saveStage(3)
			tutorialSteps[3]()
			return
		end

		instructorTextSource("Buy a car!")

		local runnerButton = plotModel.Buttons.Runner["1"].ButtonTrigger
		local att = getOrCreateAttachment("runnerButton", runnerButton)
		arrowNav.navigateTo(att)

		local connection: (() -> ())?

		connection = Charm.subscribe(runnersSource, function(state: {})
			if #state < 1 then
				return
			end

			clearNavigators()
			TutorialServiceClient:saveStage(3)
			tutorialSteps[3]()

			if connection ~= nil then
				connection()
			end
		end)
	end,

	-- Step 3: Wait for Earnings
	[3] = function()
		TutorialSlice.states.localTutorialStage(3)
		instructorTextSource("Wait for your car to cross the gate and earn money!")

		const cash = GetDataSource("cash")

		local connection: (() -> ())?

		connection = Charm.subscribe(cash, function(state: number, previous: number)
			if state == previous then
				return
			end
			TutorialServiceClient:saveStage(4)
			tutorialSteps[4]()

			if connection ~= nil then
				connection()
			end
		end)
	end,

	-- Step 4: Buy 2 More Runners (Dynamic Text)
	[4] = function()
		TutorialSlice.states.localTutorialStage(4)
		instructorTextSource("")

		const runnersSource = GetDataSource("runners")

		if #runnersSource() >= 3 then
			TutorialServiceClient:saveStage(5)
			tutorialSteps[5]()
			return
		end

		local runnersNeeded = Charm.computed(function()
			return math.max(0, 3 - #runnersSource())
		end)

		local disconnect = Charm.effect(function()
			local needed = runnersNeeded()
			if needed > 0 then
				local plural = needed > 1 and "s" or ""
				instructorTextSource(`Buy {needed} more car{plural}!`)
			end
		end)

		if currentAttachments.runnerButton then
			arrowNav.navigateTo(currentAttachments.runnerButton)
		end

		local connection: (() -> ())?

		connection = Charm.subscribe(runnersSource, function(state: {})
			if #state < 3 then
				return
			end

			clearNavigators()
			TutorialServiceClient:saveStage(5)
			tutorialSteps[5]()

			if connection ~= nil then
				connection()
			end
			disconnect()
		end)
	end,

	-- Step 5: Merge Two Runners
	[5] = function()
		TutorialSlice.states.localTutorialStage(5)
		instructorTextSource("")

		const runnersSource = GetDataSource("runners")

		local hasHigherRunner = false
		for _, level in runnersSource() do
			if level > 1 then
				hasHigherRunner = true
				break
			end
		end

		if hasHigherRunner then
			TutorialServiceClient:saveStage(6)
			tutorialSteps[6]()
			return
		end

		instructorTextSource("Merge two cars into a better one!")

		local mergeButton = plotModel.Buttons.Merge.Merge.ButtonTrigger
		local att = getOrCreateAttachment("mergeButton", mergeButton)
		arrowNav.navigateTo(att)

		local connection: (() -> ())?

		connection = Charm.subscribe(runnersSource, function(state: {})
			local hasHigher = false
			for _, level in state do
				if level > 1 then
					hasHigher = true
					break
				end
			end

			if not hasHigher then
				return
			end

			clearNavigators()
			TutorialServiceClient:saveStage(6)
			tutorialSteps[6]()

			if connection ~= nil then
				connection()
			end
		end)
	end,

	-- Step 6: Complete 5 Laps
	[6] = function()
		TutorialSlice.states.localTutorialStage(6)
		instructorTextSource("")

		const lapsSource = GetDataSource({ "lapsLeftToAcquire" })

		local lapsLeft = lapsSource()
		if lapsLeft == nil or lapsLeft <= 0 then
			TutorialServiceClient:saveStage(7)
			tutorialSteps[7]()
			return
		end

		instructorTextSource("Let your cars complete laps to unlock a Crate!")

		clearNavigators()

		local connection: (() -> ())?

		connection = Charm.subscribe(lapsSource, function(state: number?)
			if state ~= nil and state > 0 then
				return
			end

			TutorialServiceClient:saveStage(7)
			tutorialSteps[7]()

			if connection ~= nil then
				connection()
			end
		end)
	end,

	-- Step 7: Open Lucky Block
	[7] = function()
		TutorialSlice.states.localTutorialStage(7)
		instructorTextSource("Open the Crate!")

		local luckyBlockSpawn = plotModel.LuckyBlock.CrateSpawn
		local att = getOrCreateAttachment("luckyBlock", luckyBlockSpawn)
		arrowNav.navigateTo(att)

		local connection: (() -> ())?

		connection = Charm.subscribe(CratesSlice.states.cratesScreenOpen, function(state: boolean)
			if not state then
				return
			end

			clearNavigators()
			TutorialServiceClient:saveStage(8)
			tutorialSteps[8]()

			if connection ~= nil then
				connection()
			end
		end)
	end,

	-- Step 8: Open Inventory (After Lucky Block Screen Closes)
	[8] = function()
		TutorialSlice.states.localTutorialStage(8)
		instructorTextSource("")

		-- The inventory button only mounts once the stage reaches 8, so its ref
		-- is usually still empty at this point. Reading it once would silently
		-- do nothing, so the prompt waits for the instance to appear.
		local destroyPromptEffect: (() -> ())? = nil

		local function showInventoryPrompt()
			if destroyPromptEffect ~= nil then
				return
			end

			instructorTextSource("Open your Inventory to equip the trail!")

			destroyPromptEffect = Vide.root(function()
				Vide.effect(function()
					local inventoryButton = SideButtons.tutorialButtonRefs.inventory()
					if inventoryButton then
						uiTarget(inventoryButton)
						cursorSide("right")
					end
				end)
			end)
		end

		-- Already satisfied? (menu already open on Inventory)
		if Menu.openedMenu() == "Inventory" then
			tutorialSteps[9]()
			return
		end

		-- If crates screen is already closed, show the prompt immediately.
		-- Otherwise wait for it to close (Charm atom -> Charm.subscribe).
		local screenConnection: (() -> ())? = nil

		if not CratesSlice.states.cratesScreenOpen() then
			showInventoryPrompt()
		else
			screenConnection = Charm.subscribe(CratesSlice.states.cratesScreenOpen, function(state: boolean)
				if state then
					return
				end

				showInventoryPrompt()

				if screenConnection ~= nil then
					screenConnection()
					screenConnection = nil
				end
			end)
		end

		-- Wait for player to open Inventory (Vide source -> root + effect for a disconnector)
		local destroyMenuEffect: (() -> ())? = nil

		destroyMenuEffect = Vide.root(function()
			Vide.effect(function()
				if Menu.openedMenu() ~= "Inventory" then
					return
				end

				clearNavigators()
				tutorialSteps[9]()

				if screenConnection ~= nil then
					screenConnection()
					screenConnection = nil
				end

				if destroyPromptEffect ~= nil then
					destroyPromptEffect()
					destroyPromptEffect = nil
				end

				if destroyMenuEffect ~= nil then
					destroyMenuEffect()
					destroyMenuEffect = nil
				end
			end)
		end)
	end,

	-- Step 9: Equip a Trail
	[9] = function()
		TutorialSlice.states.localTutorialStage(9)
		instructorTextSource("")

		const selectedTrailSource = GetDataSource("selectedTrail")

		if selectedTrailSource() ~= nil then
			TutorialServiceClient:saveStage(10)
			tutorialSteps[10]()
			return
		end

		instructorTextSource("Equip your new trail!")

		clearNavigators()

		local connection: (() -> ())?

		connection = Charm.subscribe(selectedTrailSource, function(state)
			if state == nil then
				return
			end

			TutorialServiceClient:saveStage(10)
			tutorialSteps[10]()

			if connection ~= nil then
				connection()
			end
		end)
	end,

	-- Step 10: Save $1,000
	[10] = function()
		TutorialSlice.states.localTutorialStage(10)
		instructorTextSource("")

		const cashSource = GetDataSource("cash")

		if cashSource() >= 1000 then
			TutorialServiceClient:saveStage(11)
			tutorialSteps[11]()
			return
		end

		instructorTextSource(`Save up <font color="rgb(0,255,0)">$1,000</font>!`)

		Menu.closeCurrentMenu()
		clearNavigators()

		local connection: (() -> ())?

		connection = Charm.subscribe(cashSource, function(state: number)
			if state < 1000 then
				return
			end

			TutorialServiceClient:saveStage(11)
			tutorialSteps[11]()

			if connection ~= nil then
				connection()
			end
		end)
	end,

	-- Step 11: Open Rebirth Menu
	[11] = function()
		TutorialSlice.states.localTutorialStage(11)
		instructorTextSource("You should rebirth to progress faster! You won't lose your cars.")

		local destroyScope: (() -> ())? = nil

		destroyScope = Vide.root(function()
			Vide.effect(function()
				local rebirthButton = SideButtons.tutorialButtonRefs.rebirth()
				if rebirthButton then
					uiTarget(rebirthButton)
					cursorSide("right")
				end
			end)

			-- Watch for the player opening the Rebirth menu
			Vide.effect(function()
				if Menu.openedMenu() ~= "Rebirth" then
					return
				end

				clearNavigators()
				tutorialSteps[12]()

				if destroyScope ~= nil then
					destroyScope()
					destroyScope = nil
				end
			end)
		end)
	end,

	-- Step 12: Rebirth
	[12] = function()
		TutorialSlice.states.localTutorialStage(12)
		instructorTextSource("Click the rebirth button!")

		clearNavigators()

		const rebirthsSource = GetDataSource("rebirths")
		local initialRebirths = rebirthsSource()

		local connection: (() -> ())?

		connection = Charm.subscribe(rebirthsSource, function(state: number)
			if state <= initialRebirths then
				return
			end

			TutorialServiceClient:saveStage(13)
			tutorialSteps[13]()

			if connection ~= nil then
				connection()
			end
		end)
	end,

	-- Step 13: Finish
	[13] = function()
		TutorialSlice.states.localTutorialStage(13)
		instructorTextSource("Great job! Keep earning, upgrading, and rebirthing!")

		task.delay(3, function()
			TutorialServiceClient:finishTutorial()
			instructorTextSource("")
		end)
	end,
}

return function(): any
	DataService:waitForData()

	local savedStage = DataService:get({ "tutorial", "step" })

	TutorialSlice.states.localTutorialStage(savedStage)
	if TutorialSlice.states.isTutorialFinished() then
		return
	end

	local plot = PlotServiceClient:getPlot()
	if not plot then
		return
	end
	plotModel = plot.plotModel

	arrowNav = useArrowNavigator()
	UINavigator({
		Target = uiTarget,
		Cursor = true,
		CursorSide = cursorSide,
	})

	-- Parents itself to PlayerGui so it can sit above the navigator's dimming
	-- via DisplayOrder, so it is deliberately not returned as a RootUI child.
	useInstructor(instructorTextSource)

	if savedStage == 13 then
		TutorialServiceClient:finishTutorial()
	else
		tutorialSteps[savedStage]()
	end

	return nil
end
