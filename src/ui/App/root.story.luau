local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataTemplate = require(ReplicatedStorage.Shared.Modules.Game.DataTemplate)
local Root = require(ReplicatedStorage.Shared.UI.Hud.Root)
local Vide = require(ReplicatedStorage.Packages.Vide)
local DataService = require(ReplicatedStorage.Packages.DataService).client
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

local function StoryRoot()
	usePx.usePx()
	return Root()
end

return function(parent)
	DataService:init(DataTemplate)
	DataService:set("cash", 20200)

	local destroy = Vide.mount(StoryRoot, parent)

	return function()
		destroy()
	end
end
