--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Menu = require(ReplicatedStorage.Shared.UI.App.Components.Menu)

return {
	menuId = "Inventory",
	alwaysMounted = false,
	Component = function()
		return Menu.Component({
			menuId = "Inventory",
			Title = "Inventory",
			Scale = 0.90,
		})
	end,
}
