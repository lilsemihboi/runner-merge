local AutoRejoinServer = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Networker = require(ReplicatedStorage.Packages.Networker)
local SafeTeleport = require(ReplicatedStorage.Shared.Modules.Platform.SafeTeleport)

local PLACE_ID = game.PlaceId

function AutoRejoinServer.init(self: AutoRejoinServer)
	self.networker = Networker.server.new("AutoRejoinService", self, { self.autoRejoin })
end

function AutoRejoinServer.autoRejoin(_self: any, player: Player)
	if RunService:IsStudio() then
		return
	end

	SafeTeleport(PLACE_ID, { player })
end

type AutoRejoinServer = typeof(AutoRejoinServer) & {
	networker: Networker.Server,
}

return AutoRejoinServer :: AutoRejoinServer
