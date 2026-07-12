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

return nil
