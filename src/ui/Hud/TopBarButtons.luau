local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Menu = require(ReplicatedStorage.Shared.UI.App.Components.Menu)
local Topbarplus = require(ReplicatedStorage.Packages.Topbarplus)
local assets = require(ReplicatedStorage.Shared.Modules.Items.assets)

return function()
	local settingsButton = Topbarplus.new()
	settingsButton:bindToggleKey(Enum.KeyCode.DPadLeft)
	settingsButton:setImage(assets.images.settings)
	settingsButton:setImageScale(0.6)
	settingsButton:oneClick(true)
	settingsButton:align("Left")
	settingsButton:bindEvent("selected", function()
		Menu.setOpenedMenu("Settings")
	end)

	return function()
		settingsButton:destroy()
	end
end
