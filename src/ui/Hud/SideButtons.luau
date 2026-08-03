--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
local GeneralNotificationsServiceClient = require(ReplicatedStorage.Shared.Services.GeneralNotificationsService.GeneralNotificationsServiceClient)
local HudSlice = require(script.Parent.HudSlice)
local Menu = require(ReplicatedStorage.Shared.UI.App.Components.Menu)
local RebirthServiceUtils = require(ReplicatedStorage.Shared.Services.RebirthService.RebirthServiceUtils)
local SideButton = require(ReplicatedStorage.Shared.UI.App.Components.SideButton)
local Vide = require(ReplicatedStorage.Packages.Vide)
local getVideDataSource = require(ReplicatedStorage.Shared.UI.App.Hooks.getVideDataSource)
local useOrder = require(ReplicatedStorage.Shared.UI.App.Hooks.useOrder)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

local rebirthToastShown = Vide.source(false)

return function()
	local nextOrder = useOrder()
	local shopNotify = Vide.source(true)
	local cash = getVideDataSource("cash")
	local rebirths = getVideDataSource("rebirths")
	local canRebirth = Vide.derive(function()
		return (cash() or 0) >= RebirthServiceUtils.calculateCashRequirement((rebirths()) + 1)
	end)

	Vide.effect(function()
		local isEligible = canRebirth()
		local toastWasShown = Vide.untrack(rebirthToastShown)
		if isEligible == toastWasShown then
			return
		end

		rebirthToastShown(isEligible)

		if isEligible then
			task.defer(GeneralNotificationsServiceClient.displayNotification, GeneralNotificationsServiceClient, "You can rebirth now!")
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
		}),

		-- Index Button
		SideButton({
			layoutOrder = nextOrder(),
			icon = "rbxassetid://126166120946266",
			menuId = "Index",
		}),

		-- Inventory Button

		SideButton({
			layoutOrder = nextOrder(),
			icon = "rbxassetid://115230651228881",
			menuId = "Inventory",
		}),

		-- Rebirth Button
		SideButton({
			layoutOrder = nextOrder(),
			icon = "rbxassetid://137794920489098",
			menuId = "Rebirth",
			notify = canRebirth,
		}),
	})
end
