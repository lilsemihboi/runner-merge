local SoundService = game:GetService("SoundService")

local SettingsServiceClient = require(script.Parent.SettingsServiceClient)

return function()
	SettingsServiceClient:subscribe("music", function(value: number)
		SoundService:WaitForChild("Music").Volume = (value / 100) * 0.25
	end)

	SettingsServiceClient:subscribe("sounds", function(value: number)
		SoundService:WaitForChild("SFX").Volume = (value / 100) * 0.75
	end)
end
