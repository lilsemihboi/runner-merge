--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataService = require(ReplicatedStorage.Packages.DataService).server
local ExclusiveCars = require(ReplicatedStorage.Shared.Modules.Items.ExclusiveCars)
local Products = require(ReplicatedStorage.Shared.Services.MonetizationService.Modules.Products)
local ServerScriptService = game:GetService("ServerScriptService")
local BlockServiceServer = require(ServerScriptService.Services.BlockService.BlockServiceServer)
local GeneralNotificationsServiceServer = require(ServerScriptService.Services.GeneralNotificationsService.GeneralNotificationsServiceServer)
local ProfileServiceServer = require(ServerScriptService.Services.ProfileService.ProfileServiceServer)
const SoundServiceServer = require(ServerScriptService.Services.SoundService.SoundServiceServer)
local RebirthServiceUtils = require(ReplicatedStorage.Shared.Services.RebirthService.RebirthServiceUtils)

Products.doubleOfflineEarnings.callback = function(player: Player)
	local reward = DataService:get(player, "offlineEarnings")
	if typeof(reward) ~= "number" or reward <= 0 then
		-- The receipt must still be granted so Roblox does not retry it forever.
		return
	end

	if DataService:get(player, "offlineEarningsDoubled") == true then
		return
	end

	local alreadyPaid = DataService:get(player, "offlineEarningsPaid") == true
	DataService:set(player, "offlineEarningsDoubled", true)
	DataService:set(player, "offlineEarnings", reward * 2)

	local profile = ProfileServiceServer.getProfile(player)
	if alreadyPaid then
		-- The original reward was paid when the menu opened, so only add its
		-- matching half now.
		profile:giveCash(reward)
	else
		DataService:set(player, "offlineEarningsPaid", true)
		profile:giveCash(reward * 2)
	end

	return
end

Products.carBundle1.callback = function(player: Player)
	local profile = ProfileServiceServer.getProfile(player)

	--14,15,16
	profile:giveRunner(14)
	profile:giveRunner(15)
	profile:giveRunner(16)

	return
end

Products.x5Spin.callback = function(player: Player)
	local profile = ProfileServiceServer.getProfile(player)

	profile:addSpin(5)

	return
end

Products.x3Spin.callback = function(player: Player)
	local profile = ProfileServiceServer.getProfile(player)

	profile:addSpin(3)

	return
end

Products.x1Spin.callback = function(player: Player)
	local profile = ProfileServiceServer.getProfile(player)

	profile:addSpin(1)

	return
end

Products.starterPack.callback = function(player: Player)
	local profile = ProfileServiceServer.getProfile(player)

	--Level 6 car
	profile:giveRunner(6)
	-- 50k money
	profile:giveCash(50_000)
	-- +20% multiplier
	profile:addCustomMultiplier(0.2)

	return
end

Products.extraGate1.callback = function(player: Player)
	local profile = ProfileServiceServer.getProfile(player)
	local extraGateCount = profile:getExtraGateCount()

	if extraGateCount ~= 0 then
		return
	end

	profile:setExtraGateCount(1)
	return
end

Products.extraGate2.callback = function(player: Player): boolean
	local profile = ProfileServiceServer.getProfile(player)

	local extraGateCount = profile:getExtraGateCount()

	if extraGateCount ~= 1 then
		GeneralNotificationsServiceServer:sendNotification(player, "You need to buy Gate I first. Purchase Failed. 🥹")
		return false
	end

	profile:setExtraGateCount(2)
	return true
end

Products.skipRebirth.callback = function(player: Player)
	local profile = ProfileServiceServer.getProfile(player)

	local playerRebirths = profile:getRebirths()
	local nextRebirth = playerRebirths + 1

	-- Award
	profile:giveRebirth()
	profile:setMultiplier(RebirthServiceUtils.getCashMultiplierForRebirth(nextRebirth))

	if nextRebirth <= 80 and nextRebirth % 2 == 0 then
		profile:giveSpawnLevel()
	end

	pcall(function()
		SoundServiceServer:play(player, "rebirth")
	end)

	return
end

-- 20%, 50%, 125%
Products.cashPack1.callback = function(player: Player)
	local profile = ProfileServiceServer.getProfile(player)

	local percent = 0.20

	local playerCash = profile:getCash()
	if playerCash < 10000 then
		playerCash = 10000
	end

	local result = playerCash * percent

	profile:giveCash(math.floor(result))

	return
end

Products.cashPack2.callback = function(player: Player)
	local profile = ProfileServiceServer.getProfile(player)

	local percent = 0.50

	local playerCash = profile:getCash()
	if playerCash < 10000 then
		playerCash = 10000
	end

	local result = playerCash * percent

	profile:giveCash(math.floor(result))

	return
end

Products.cashPack3.callback = function(player: Player)
	local profile = ProfileServiceServer.getProfile(player)

	local percent = 1.25

	local playerCash = profile:getCash()
	if playerCash < 10000 then
		playerCash = 10000
	end

	local result = playerCash * percent

	profile:giveCash(math.floor(result))

	return
end

Products.cashPack4.callback = function(player: Player)
	local profile = ProfileServiceServer.getProfile(player)

	--One billion
	profile:giveCash(1_000_000_000)

	return
end

Products.exclusiveCar.callback = function(player: Player)
	local profile = ProfileServiceServer.getProfile(player)

	profile:giveExclusiveRunner(ExclusiveCars.ids.exclusiveCar)

	return
end

--[=[
	Robux crates. Each product maps to one of the crates that cannot be earned on the track
	(`blockWeight = 0`), and the x3 variants simply grant three rolls of the same crate.

	`grantPurchasedCrate` rolls, grants, and pushes the results to the client, so the reel
	starts spinning as soon as the receipt clears. It returns false when nothing could be
	granted, which makes the purchase soft-fail instead of being retried forever.
]=]
const CRATE_PRODUCTS: { [string]: { crateId: number, rolls: number } } = {
	crate1 = { crateId = 10, rolls = 1 },
	crate2 = { crateId = 11, rolls = 1 },
	crate3 = { crateId = 12, rolls = 1 },
	x3crate1 = { crateId = 10, rolls = 3 },
	x3crate2 = { crateId = 11, rolls = 3 },
	x3crate3 = { crateId = 12, rolls = 3 },
	adHeartCrate = { crateId = 13, rolls = 1 },
}

for productKey, crate in CRATE_PRODUCTS do
	Products[productKey].callback = function(player: Player): boolean
		return BlockServiceServer:grantPurchasedCrate(player, crate.crateId, crate.rolls)
	end
end

return nil
