--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Menu = require(ReplicatedStorage.Shared.UI.App.Components.Menu)

return {
	menuId = "OfflineRewards",
	alwaysMounted = false,
	Component = function()
		return Menu.Component({
			menuId = "OfflineRewards",
			Title = "Offline Rewards",
			Scale = 0.75,
		})
	end,
}
