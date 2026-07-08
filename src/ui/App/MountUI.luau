local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RootUI = require(ReplicatedStorage.Shared.UI.App.RootUI)
local TopBarButtons = require(ReplicatedStorage.Shared.UI.Hud.TopBarButtons)
local Vide = require(ReplicatedStorage.Packages.Vide)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

return function()
	TopBarButtons()
	return Vide.mount(RootUI, playerGui)
end
