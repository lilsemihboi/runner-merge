--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Frame = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.Frame)
local Menu = require(ReplicatedStorage.Shared.UI.App.Components.Menu)
local TextLabel = require(ReplicatedStorage.Shared.Modules.Ui.Primitives.TextLabel)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

local function container()
	return Frame({
		Size = usePx.offset(1008 * 0.9, 686 * 0.9),
		Position = usePx.udim2(0, 0, 0, 116 * 0.9),
		BackgroundTransparency = 1,

		-- LIMITED TIME! textlabel [1]

		-- <font color="rgb(0,255,0)">Like</font> and <font color="rgb(255,255,0)">Favorite</font> the game! [2]

		-- ImageLabel for like and favorite

		-- Join our <font color="rgb(0,255,255)">Community</font>!

		-- Frame Container For Rewards inside an ui list layout similar to exclusive car pack

		-- Claim Button Green [LAST] if success then setopenedmenu nil
	})
end

return {
	menuId = "GroupRewards",
	alwaysMounted = false,
	Component = function()
		return Menu.Component({
			menuId = "GroupRewards",
			Title = "Group Rewards",
			Scale = 0.9,

			container(),
		})
	end,
}
