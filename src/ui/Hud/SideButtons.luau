--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
local GeneralNotificationsServiceClient = require(ReplicatedStorage.Shared.Services.GeneralNotificationsService.GeneralNotificationsServiceClient)
local HudSlice = require(script.Parent.HudSlice)
local Menu = require(ReplicatedStorage.Shared.UI.App.Components.Menu)
local RebirthServiceUtils = require(ReplicatedStorage.Shared.Services.RebirthService.RebirthServiceUtils)
local SideButton = require(ReplicatedStorage.Shared.UI.App.Components.SideButton)
local Trails = require(ReplicatedStorage.Shared.Modules.Items.Trails)
local Vide = require(ReplicatedStorage.Packages.Vide)
const VideCharm = require(ReplicatedStorage.Packages.VideCharm)
local getVideDataSource = require(ReplicatedStorage.Shared.UI.App.Hooks.getVideDataSource)
local useOrder = require(ReplicatedStorage.Shared.UI.App.Hooks.useOrder)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)
const TutorialSlice = require(ReplicatedStorage.Shared.UI.Tutorial.TutorialSlice)

local rebirthToastShown = Vide.source(false)

-- Tutorial button refs (exposed for tutorial navigation)
const tutorialButtonRefs = {
	inventory = Vide.source(nil),
	rebirth = Vide.source(nil),
}

--- Stores `instance` in `ref` and returns it, for capturing a child inline.
const function captureRef(ref: (any) -> (), instance: Instance): Instance
	ref(instance)
	return instance
end

const function SideButtonsComponent()
	local nextOrder = useOrder()
	local shopNotify = Vide.source(true)
	local cash = getVideDataSource("cash")
	local inventory = getVideDataSource("inventory")
	local rebirths = getVideDataSource("rebirths")
	local inventoryNotify = Vide.source(false)
	local canRebirth = Vide.derive(function()
		return (cash() or 0) >= RebirthServiceUtils.calculateCashRequirement((rebirths()) + 1)
	end)

	local previousInventory: { number }? = nil
	Vide.effect(function()
		local currentInventory = inventory() or {}
		if previousInventory == nil then
			previousInventory = table.clone(currentInventory)
			return
		end

		local previousQuantities: { [number]: number } = {}
		local bestOwnedMultiplier = 1
		for _, trailId in previousInventory do
			previousQuantities[trailId] = (previousQuantities[trailId] or 0) + 1

			local trailInfo = Trails[trailId]
			if trailInfo then
				bestOwnedMultiplier = math.max(bestOwnedMultiplier, trailInfo.trailMultiplier)
			end
		end

		for _, trailId in currentInventory do
			local trailInfo = Trails[trailId]
			local previousQuantity = previousQuantities[trailId] or 0
			if trailInfo and previousQuantity > 0 then
				previousQuantities[trailId] = previousQuantity - 1
			elseif trailInfo and trailInfo.trailMultiplier > bestOwnedMultiplier then
				inventoryNotify(true)
				break
			end
		end

		previousInventory = table.clone(currentInventory)
	end)

	local wasInventoryOpen = false
	Vide.effect(function()
		local isInventoryOpen = Menu.openedMenu() == "Inventory"
		if isInventoryOpen then
			wasInventoryOpen = true
		elseif wasInventoryOpen then
			inventoryNotify(false)
			wasInventoryOpen = false
		end
	end)

	const isTutorialFinished = VideCharm.useAtom(TutorialSlice.states.isTutorialFinished)
	const localTutorialStage = VideCharm.useAtom(TutorialSlice.states.localTutorialStage)

	Vide.effect(function()
		local isEligible = canRebirth()
		local toastWasShown = Vide.untrack(rebirthToastShown)
		if isEligible == toastWasShown then
			return
		end

		rebirthToastShown(isEligible)

		if isEligible then
			task.defer(GeneralNotificationsServiceClient.displayNotification, GeneralNotificationsServiceClient, "You can rebirth now!", {
				Prefix = {
					Image = "rbxassetid://137794920489098",
				},
			})
		end
	end)

	local sidebarPositionTarget = Vide.derive(function()
		if Menu.openedMenu() == nil then
			-- Ekranda
			return usePx.udim2(0, 38, 500 / 1080, 0)()
		else
			-- Sola doğru kay
			return UDim2.fromScale(-1, 500 / 1080)
		end
	end)
	local sidebarPosition = Vide.spring(sidebarPositionTarget, 0.35, 0.8)

	return Frame({
		Size = usePx.offset(145, 750),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = sidebarPosition,
		BackgroundTransparency = 1,
		Visible = function()
			if HudSlice.showEverything() then
				return true
			else
				return false
			end
		end,

		Vide.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = usePx.udim(0, 30),
		}),

		-- Store Button
		SideButton({
			layoutOrder = nextOrder(),
			icon = "rbxassetid://71053646250865",
			menuId = "Shop",
			notify = shopNotify,
			onNotifyClick = function()
				shopNotify(false)
			end,
			visible = function()
				return isTutorialFinished() or localTutorialStage() >= 10
			end,
		}),

		-- Index Button
		SideButton({
			layoutOrder = nextOrder(),
			icon = "rbxassetid://126166120946266",
			menuId = "Index",
		}),

		-- Inventory Button
		-- The ref is taken from the returned instance rather than a
		-- `Vide.action` child: SideButton builds its own props table for Button
		-- and never forwards array children, so an action passed here would be
		-- dropped and the ref would stay empty.
		captureRef(
			tutorialButtonRefs.inventory,
			SideButton({
				layoutOrder = nextOrder(),
				icon = "rbxassetid://115230651228881",
				menuId = "Inventory",
				notify = inventoryNotify,
				visible = function()
					return isTutorialFinished() or localTutorialStage() >= 8
				end,
			})
		),

		-- Rebirth Button
		captureRef(
			tutorialButtonRefs.rebirth,
			SideButton({
				layoutOrder = nextOrder(),
				icon = "rbxassetid://137794920489098",
				menuId = "Rebirth",
				notificationStyle = "dot",
				notify = canRebirth,
				visible = function()
					return isTutorialFinished() or localTutorialStage() >= 11
				end,
			})
		),
	})
end

return {
	Component = SideButtonsComponent,
	tutorialButtonRefs = tutorialButtonRefs,
}
