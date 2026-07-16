local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataTemplate = require(ReplicatedStorage.Shared.Modules.Game.DataTemplate)
local MonetizationServiceClient = require(ReplicatedStorage.Shared.Services.MonetizationService.MonetizationServiceClient)
local Products = require(ReplicatedStorage.Shared.Services.MonetizationService.Modules.Products)
local RootUI = require(script.Parent.RootUI)
local SettingsInitializer = require(ReplicatedStorage.Shared.Services.SettingsService.SettingsInitializer)
local SettingsServiceClient = require(ReplicatedStorage.Shared.Services.SettingsService.SettingsServiceClient)
local Vide = require(ReplicatedStorage.Packages.Vide)
local DataService = require(ReplicatedStorage.Packages.DataService).client

return function(parent)
	DataService:init(DataTemplate)
	DataService:set("cash", 3196)
	DataService:set("rebirths", 1)
	DataService:set({ "index", "40" }, true)

	MonetizationServiceClient:init(Products :: any)
	SettingsServiceClient:init()
	SettingsInitializer()
	local destroy = Vide.mount(RootUI, parent)

	return function()
		destroy()
	end
end
