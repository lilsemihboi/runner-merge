local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SettingsServiceClient = require(ReplicatedStorage.Shared.Services.SettingsService.SettingsServiceClient)
local SettingsServiceUtils = require(ReplicatedStorage.Shared.Services.SettingsService.SettingsServiceUtils)
local Vide = require(ReplicatedStorage.Packages.Vide)
local getVideDataSource = require(ReplicatedStorage.Shared.UI.App.Hooks.getVideDataSource)

return function(path: string | { string })
	local settingsPath = Vide.derive(function()
		return SettingsServiceUtils.convertPathToSettingPath(path)
	end)

	local value = getVideDataSource(settingsPath())

	local function setValue(newValue)
		SettingsServiceClient:set(path, newValue)
	end

	return value, setValue
end
