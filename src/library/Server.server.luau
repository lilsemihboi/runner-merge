--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local AutoRejoinServiceServer = require(ServerScriptService.Services.AutoRejoinService.AutoRejoinServiceServer)
local BlockServiceServer = require(ServerScriptService.Services.BlockService.BlockServiceServer)
local CodeServiceServer = require(ServerScriptService.Services.CodeService.CodeServiceServer)
local DataTemplate = require(ReplicatedStorage.Shared.Modules.Game.DataTemplate)
local FriendServiceServer = require(ServerScriptService.Services.FriendService.FriendServiceServer)
local GeneralNotificationsServiceServer = require(ServerScriptService.Services.GeneralNotificationsService.GeneralNotificationsServiceServer)
local InventoryServiceServer = require(ServerScriptService.Services.InventoryService.InventoryServiceServer)
local LeaderboardServiceServer = require(ServerScriptService.Services.LeaderboardService.LeaderboardServiceServer)
local MonetizationServiceServer = require(ServerScriptService.Services.MonetizationService.MonetizationServiceServer)
local NotificationServiceServer = require(ServerScriptService.Services.NotificationService.NotificationServiceServer)
local OfflineEarningsServiceServer = require(ServerScriptService.Services.OfflineEarningsService.OfflineEarningsServiceServer)
local PlotServiceServer = require(ServerScriptService.Services.PlotService.PlotServiceServer)
local Products = require(ReplicatedStorage.Shared.Services.MonetizationService.Modules.Products)
local ServerCallbacks = require(ServerScriptService.Services.CodeService.ServerCallbacks)
require(ServerScriptService.Services.MonetizationService.Modules.ProductServerCallbacks)
local ProfileServiceServer = require(ServerScriptService.Services.ProfileService.ProfileServiceServer)
local RebirthServiceServer = require(ServerScriptService.Services.RebirthService.RebirthServiceServer)
local RouteServiceServer = require(ServerScriptService.Services.RouteService.RouteServiceServer)
local RunnerServiceServer = require(ServerScriptService.Services.RunnerService.RunnerServiceServer)
local SettingsServiceServer = require(ServerScriptService.Services.SettingsService.SettingsServiceServer)
local SoundServiceServer = require(ServerScriptService.Services.SoundService.SoundServiceServer)
local StockServiceServer = require(ServerScriptService.Services.StockService.StockServiceServer)
local TitleServiceServer = require(ServerScriptService.Services.TitleService.TitleServiceServer)
local TutorialServiceServer = require(ServerScriptService.Services.TutorialService.TutorialServiceServer)

local DataService = require(ReplicatedStorage.Packages.DataService).server

DataService:init({
	resetData = false,
	useMock = false,
	template = DataTemplate,
	profileStoreIndex = RunService:IsStudio() and "__test__" or "__production__",
})

StockServiceServer:init({
	products = Products :: any,
})
MonetizationServiceServer:init({
	products = Products :: any,
})

-- Wired here rather than inside either service: monetization reads stock to
-- gate purchase prompts, so stock must not require monetization back.
MonetizationServiceServer.productProcessed:Connect(function(_player, receiptInfo)
	StockServiceServer:consumeByProductId(receiptInfo.ProductId)
end)

ProfileServiceServer:init()
InventoryServiceServer:init()
BlockServiceServer:init()
CodeServiceServer:init(ServerCallbacks :: any)
--CodeServiceServer:add("mantle2026", {active = true,expiration = 1798675200, reward = "currency", params = {15_000}})
FriendServiceServer:init()
RunnerServiceServer:init()
PlotServiceServer:init()
RouteServiceServer:init()
OfflineEarningsServiceServer:init()
RebirthServiceServer:init()
LeaderboardServiceServer:init()
AutoRejoinServiceServer:init()
NotificationServiceServer:init()
SoundServiceServer:init()
SettingsServiceServer:init()
TutorialServiceServer:init()
TitleServiceServer:init()
GeneralNotificationsServiceServer:init()
