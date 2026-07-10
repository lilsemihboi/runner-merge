local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataTemplate = require(ReplicatedStorage.Shared.Modules.Game.DataTemplate)
local RootUI = require(script.Parent.RootUI)
local Vide = require(ReplicatedStorage.Packages.Vide)
local DataService = require(ReplicatedStorage.Packages.DataService).client

return function(parent)
	DataService:init(DataTemplate)
	DataService:set("cash", 20200)

	local destroy = Vide.mount(RootUI, parent)

	return function()
		destroy()
	end
end
