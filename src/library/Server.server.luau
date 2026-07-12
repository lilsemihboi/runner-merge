local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local AutoRejoinServiceServer = require(ServerScriptService.Services.AutoRejoinService.AutoRejoinServiceServer)
local DataTemplate = require(ReplicatedStorage.Shared.Modules.Game.DataTemplate)
local MonetizationServiceServer = require(ServerScriptService.Services.MonetizationService.MonetizationServiceServer)
local OfflineEarningsServiceServer = require(ServerScriptService.Services.OfflineEarningsService.OfflineEarningsServiceServer)
local PlotServiceServer = require(ServerScriptService.Services.PlotService.PlotServiceServer)
local Products = require(ReplicatedStorage.Shared.Services.MonetizationService.Modules.Products)
require(ServerScriptService.Services.MonetizationService.Modules.ProductServerCallbacks)
local ProfileServiceServer = require(ServerScriptService.Services.ProfileService.ProfileServiceServer)
local RunnerServiceServer = require(ServerScriptService.Services.RunnerService.RunnerServiceServer)
local SoundServiceServer = require(ServerScriptService.Services.SoundService.SoundServiceServer)

local DataService = require(ReplicatedStorage.Packages.DataService).server

DataService:init({
	resetData = false,
	useMock = false,
	template = DataTemplate,
	profileStoreIndex = RunService:IsStudio() and "__test__" or "__production__",
})
MonetizationServiceServer:init({
	products = Products :: any,
})
ProfileServiceServer:init()
RunnerServiceServer:init()
PlotServiceServer:init()
OfflineEarningsServiceServer:init()
AutoRejoinServiceServer:init()
SoundServiceServer:init()
