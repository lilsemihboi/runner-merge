--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
local Menu = require(ReplicatedStorage.Shared.UI.App.Components.Menu)
local SideButton = require(ReplicatedStorage.Shared.UI.App.Components.SideButton)
local Vide = require(ReplicatedStorage.Packages.Vide)
local useOrder = require(ReplicatedStorage.Shared.UI.App.Hooks.useOrder)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

return function()
	local nextOrder = useOrder()

	return Frame({
		Size = usePx.offset(145, 750),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = usePx.udim2(0, 38, 500 / 1080, 0),
		BackgroundTransparency = 1,
		Visible = function()
			return Menu.openedMenu() == nil
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
			menuId = "shop",
			notify = Vide.source(true),
		}),

		-- Index Button
		SideButton({
			layoutOrder = nextOrder(),
			icon = "rbxassetid://126166120946266",
			menuId = "index",
			notify = Vide.source(true),
		}),

		-- Rebirth Button
		SideButton({
			layoutOrder = nextOrder(),
			icon = "rbxassetid://137794920489098",
			menuId = "rebirth",
		}),
	})
end
