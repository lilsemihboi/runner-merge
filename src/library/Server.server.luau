--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local BlockServiceServer = require(ServerScriptService.Services.BlockService.BlockServiceServer)
local CodeServiceServer = require(ServerScriptService.Services.CodeService.CodeServiceServer)
local DataTemplate = require(ReplicatedStorage.Shared.Modules.Game.DataTemplate)
local FriendServiceServer = require(ServerScriptService.Services.FriendService.FriendServiceServer)
local InventoryServiceServer = require(ServerScriptService.Services.InventoryService.InventoryServiceServer)
local MonetizationServiceServer = require(ServerScriptService.Services.MonetizationService.MonetizationServiceServer)
local OfflineEarningsServiceServer = require(ServerScriptService.Services.OfflineEarningsService.OfflineEarningsServiceServer)
local PlotServiceServer = require(ServerScriptService.Services.PlotService.PlotServiceServer)
local Products = require(ReplicatedStorage.Shared.Services.MonetizationService.Modules.Products)
local ServerCallbacks = require(ServerScriptService.Services.CodeService.ServerCallbacks)
require(ServerScriptService.Services.MonetizationService.Modules.ProductServerCallbacks)
local ProfileServiceServer = require(ServerScriptService.Services.ProfileService.ProfileServiceServer)
local RebirthServiceServer = require(ServerScriptService.Services.RebirthService.RebirthServiceServer)
local RouteServiceServer = require(ServerScriptService.Services.RouteService.RouteServiceServer)
local RunnerServiceServer = require(ServerScriptService.Services.RunnerService.RunnerServiceServer)
local StockServiceServer = require(ServerScriptService.Services.StockService.StockServiceServer)

local DataService = require(ReplicatedStorage.Packages.DataService).server

local function initializeOptionalFeature(featureName, initialize)
	task.spawn(function()
		local success, problem = xpcall(initialize, debug.traceback)
		if not success then
			warn(`[Startup] Optional server feature "{featureName}" failed to initialize and was disabled:\n{problem}`)
		end
	end)
end

DataService:init({
	resetData = false,
	useMock = false,
	template = DataTemplate,
	profileStoreIndex = RunService:IsStudio() and "__test__" or "__production__",
})

-- First after data: funnel step 1 is logged on PlayerAdded, so this must be
-- listening before any other service can yield on player setup. It also owns
-- the Gamebeast handle every other service sends markers through, which has to
-- exist before those services can fire anything.
initializeOptionalFeature("AnalyticsService", function()
	require(ServerScriptService.Services.AnalyticsService.AnalyticsServiceServer):init()
end)

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
initializeOptionalFeature("LeaderboardService", function()
	require(ServerScriptService.Services.LeaderboardService.LeaderboardServiceServer):init()
end)
initializeOptionalFeature("AutoRejoinService", function()
	require(ServerScriptService.Services.AutoRejoinService.AutoRejoinServiceServer):init()
end)
initializeOptionalFeature("NotificationService", function()
	require(ServerScriptService.Services.NotificationService.NotificationServiceServer):init()
end)
initializeOptionalFeature("SoundService", function()
	require(ServerScriptService.Services.SoundService.SoundServiceServer):init()
end)
initializeOptionalFeature("SettingsService", function()
	require(ServerScriptService.Services.SettingsService.SettingsServiceServer):init()
end)
initializeOptionalFeature("TutorialService", function()
	require(ServerScriptService.Services.TutorialService.TutorialServiceServer):init()
end)
initializeOptionalFeature("TitleService", function()
	require(ServerScriptService.Services.TitleService.TitleServiceServer):init()
end)
initializeOptionalFeature("GeneralNotificationsService", function()
	require(ServerScriptService.Services.GeneralNotificationsService.GeneralNotificationsServiceServer):init()
end)
