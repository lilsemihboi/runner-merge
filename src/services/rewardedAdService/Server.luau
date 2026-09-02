const RewardedAdService = {}

const AdService = game:GetService("AdService")
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Networker = require(ReplicatedStorage.Packages.Networker)
const Products = require(ReplicatedStorage.Shared.Services.MonetizationService.Modules.Products)

function RewardedAdService.init(self: RewardedAdService)
	self.networker = Networker.server.new("RewardedAdService", self, {
		self.playAd,
		self.hasClaimedRewardThisSession,
	})
	self.playersClaimedRewardThisSession = {}

	Players.PlayerRemoving:Connect(function(player: Player)
		if self.playersClaimedRewardThisSession[player] then
			self.playersClaimedRewardThisSession[player] = nil
		end
	end)
end

--[=[
    Plays ad if something wents wrong it aborts and returns  
]=]
function RewardedAdService.playAd(self: RewardedAdService, player: Player): (boolean, Enum.ShowAdResult?)
	if self.playersClaimedRewardThisSession[player] == true then
		return false, nil
	end

	const success, result = pcall(function()
		local reward = AdService:CreateAdRewardFromDevProductId(Products.adHeartCrate.id)
		return AdService:ShowRewardedVideoAdAsync(player, reward, 636257121902409)
	end)

	if success and result == Enum.ShowAdResult.ShowCompleted then
		self.playersClaimedRewardThisSession[player] = true
	end

	return success, result
end

--[=[
	Returns whether the player already claimed the rewarded ad reward for this
	server session.
]=]
function RewardedAdService.hasClaimedRewardThisSession(self: RewardedAdService, player: Player): boolean
	return self.playersClaimedRewardThisSession[player] == true
end

type RewardedAdService = typeof(RewardedAdService) & {
	networker: Networker.Server,
	playersClaimedRewardThisSession: { [Player]: true? },
}

return RewardedAdService :: RewardedAdService
