local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataService = require(ReplicatedStorage.Packages.DataService).server
local Products = require(ReplicatedStorage.Shared.Services.MonetizationService.Modules.Products)
local ServerScriptService = game:GetService("ServerScriptService")
local ProfileServiceServer = require(ServerScriptService.Services.ProfileService.ProfileServiceServer)

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

return nil
