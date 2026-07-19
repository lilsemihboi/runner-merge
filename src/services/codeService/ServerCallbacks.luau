local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CarIds = require(ReplicatedStorage.Shared.Modules.Items.CarIds)
local NotificationServiceServer = require(ServerScriptService.Services.NotificationService.NotificationServiceServer)
local ProfileServiceServer = require(ServerScriptService.Services.ProfileService.ProfileServiceServer)

local callbacks = {}

function callbacks.currency(player: Player, amount: number)
	local profile = ProfileServiceServer.getProfile(player)
	profile:giveCash(amount)

	NotificationServiceServer:sendNotification(player, "rbxassetid://117630190830410", amount)
end

function callbacks.runner(player: Player, level: number)
	local profile = ProfileServiceServer.getProfile(player)
	profile:giveRunner(level)

	NotificationServiceServer:sendNotification(player, CarIds[level].imageId, 1)
end

return callbacks
