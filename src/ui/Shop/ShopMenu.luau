--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
local Menu = require(ReplicatedStorage.Shared.UI.App.Components.Menu)
local SpecialOffers = require(ReplicatedStorage.Shared.UI.Shop.Frames.SpecialOffers)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

local function shopContent()
	return Frame({
		Size = usePx.offset(1008, 686),
		Position = usePx.udim2(0, 0, 0, 116),
		BackgroundTransparency = 1,

		SpecialOffers(),
	})
end

return {
	menuId = "Shop",
	alwaysMounted = false,
	Component = function()
		return Menu.Component({
			menuId = "Shop",
			Title = "Shop",
			Scale = 1,

			shopContent(),
		})
	end,
}
