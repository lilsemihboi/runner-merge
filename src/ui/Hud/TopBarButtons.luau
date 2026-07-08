local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
		print("Settings Button Called")
	end)

	return function()
		settingsButton:destroy()
	end
end
