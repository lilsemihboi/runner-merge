local RebirthService = {}

local ConfigService = game:GetService("ConfigService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Networker = require(ReplicatedStorage.Packages.Networker)
local ProfileServiceServer = require(ServerScriptService.Services.ProfileService.ProfileServiceServer)
local RebirthServiceUtils = require(ReplicatedStorage.Shared.Services.RebirthService.RebirthServiceUtils)

function RebirthService.init(self: RebirthService)
	self.networker = Networker.server.new("RebirthService", self, {
		self.rebirth,
	})
end

function RebirthService.rebirth(_self: RebirthService, player: Player)
	assert(player, "Player doesn't exist.")

	local profile = ProfileServiceServer.getProfile(player)

	local playerRebirths = profile:getRebirths()
	local nextRebirth = playerRebirths + 1

	local nextRebirthCost = RebirthServiceUtils.calculateCashRequirement(nextRebirth)

	if profile:getCash() < nextRebirthCost then
		return "NOT_ENOUGH_CASH"
	end

	profile:resetCash()
	profile:setExtraGateCount(0)
	profile:resetUpgrades()

	-- Config based A/B Test
	local configSuccess, shouldAutoBuyFirstGate = pcall(function()
		local config = ConfigService:GetConfigForPlayerAsync(player)
		return config:GetValue("auto_buy_first_gate") == true
	end)

	if configSuccess and shouldAutoBuyFirstGate then
		profile:giveUpgrade("gates")
	end

	-- Award

	profile:giveRebirth()
	profile:setMultiplier(RebirthServiceUtils.getCashMultiplierForRebirth(nextRebirth))

	if nextRebirth <= 80 and nextRebirth % 2 == 0 then
		profile:giveSpawnLevel()
	end

	return "SUCCESS"
end

type RebirthService = typeof(RebirthService) & {
	networker: Networker.Server,
}

return RebirthService :: RebirthService
