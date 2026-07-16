local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local AutoRejoinServiceServer = require(ServerScriptService.Services.AutoRejoinService.AutoRejoinServiceServer)
local DataTemplate = require(ReplicatedStorage.Shared.Modules.Game.DataTemplate)
local FriendServiceServer = require(ServerScriptService.Services.FriendService.FriendServiceServer)
local LeaderboardServiceServer = require(ServerScriptService.Services.LeaderboardService.LeaderboardServiceServer)
local MonetizationServiceServer = require(ServerScriptService.Services.MonetizationService.MonetizationServiceServer)
local OfflineEarningsServiceServer = require(ServerScriptService.Services.OfflineEarningsService.OfflineEarningsServiceServer)
local PlotServiceServer = require(ServerScriptService.Services.PlotService.PlotServiceServer)
local Products = require(ReplicatedStorage.Shared.Services.MonetizationService.Modules.Products)
require(ServerScriptService.Services.MonetizationService.Modules.ProductServerCallbacks)
local ProfileServiceServer = require(ServerScriptService.Services.ProfileService.ProfileServiceServer)
local RebirthServiceServer = require(ServerScriptService.Services.RebirthService.RebirthServiceServer)
local RunnerServiceServer = require(ServerScriptService.Services.RunnerService.RunnerServiceServer)
local SettingsServiceServer = require(ServerScriptService.Services.SettingsService.SettingsServiceServer)
local SoundServiceServer = require(ServerScriptService.Services.SoundService.SoundServiceServer)
local TitleServiceServer = require(ServerScriptService.Services.TitleService.TitleServiceServer)

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
FriendServiceServer:init()
RunnerServiceServer:init()
PlotServiceServer:init()
OfflineEarningsServiceServer:init()
RebirthServiceServer:init()
LeaderboardServiceServer:init()
AutoRejoinServiceServer:init()
SoundServiceServer:init()
SettingsServiceServer:init()
TitleServiceServer:init()
