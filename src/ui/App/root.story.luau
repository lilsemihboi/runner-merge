local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataTemplate = require(ReplicatedStorage.Shared.Modules.Game.DataTemplate)
local Root = require(ReplicatedStorage.Shared.UI.Hud.Root)
local Vide = require(ReplicatedStorage.Packages.Vide)
local DataService = require(ReplicatedStorage.Packages.DataService).client

return function(parent)
	DataService:init(DataTemplate)

	local destroy = Vide.mount(Root, parent)

	return function()
		destroy()
	end
end
