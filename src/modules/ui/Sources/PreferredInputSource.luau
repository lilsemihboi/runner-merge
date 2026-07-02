local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Charm = require(ReplicatedStorage.Packages.Charm)

local preferredInput = Charm.atom(UserInputService.PreferredInput)

UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
	preferredInput(UserInputService.PreferredInput)
end)

return preferredInput
