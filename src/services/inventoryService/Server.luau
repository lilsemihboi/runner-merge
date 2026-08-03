local InventoryService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Networker = require(ReplicatedStorage.Packages.Networker)
local ProfileServiceServer = require(ServerScriptService.Services.ProfileService.ProfileServiceServer)

function InventoryService.init(self: InventoryService)
	self.networker = Networker.server.new("InventoryService", self, {
		self.selectTrail,
	})
end

function InventoryService.selectTrail(_self: InventoryService, player: Player, trailId: number?)
	if trailId ~= nil and (typeof(trailId) ~= "number" or trailId % 1 ~= 0) then
		return false, "ERROR"
	end

	local profile = ProfileServiceServer.getProfile(player)
	if not profile:selectTrail(trailId) then
		return false, "ERROR"
	end

	return true, "SUCCESS"
end

type InventoryService = typeof(InventoryService) & {
	networker: Networker.Server,
}

return InventoryService :: InventoryService
