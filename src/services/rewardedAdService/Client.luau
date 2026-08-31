const RewardedAdService = {}

const AdService = game:GetService("AdService")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Networker = require(ReplicatedStorage.Packages.Networker)

--[=[
	Ad availability results that mean the ad platform cannot serve the player an
	ad right now. Anything else (such as `IsAvailable`) is treated as usable.
]=]
const INELIGIBLE_RESULTS = {
	Enum.AdAvailabilityResult.PlayerIneligible,
	Enum.AdAvailabilityResult.DeviceIneligible,
	Enum.AdAvailabilityResult.PublisherIneligible,
	Enum.AdAvailabilityResult.ExperienceIneligible,
}

const function isAdIneligible(response: Enum.AdAvailabilityResult?)
	for _, inEligibleResult in ipairs(INELIGIBLE_RESULTS) do
		if response == inEligibleResult then
			return true
		end
	end

	return false
end

function RewardedAdService.init(self: RewardedAdService)
	self.networker = Networker.client.new("RewardedAdService", self)
end

function RewardedAdService.playAd(self: RewardedAdService): (boolean, Enum.ShowAdResult?)
	return self.networker:fetch("playAd")
end

function RewardedAdService.canClaimAdReward(self: RewardedAdService): boolean
	return self.networker:fetch("hasClaimedRewardThisSession") == false
end

--[=[
	Returns whether the player can watch the rewarded ad right now: the session
	reward is unclaimed and the ad platform reports one as available.
]=]
function RewardedAdService.canShowAd(self: RewardedAdService): boolean
	if not self:canClaimAdReward() then
		return false
	end

	local isSuccess, response = pcall(function()
		return AdService:GetAdAvailabilityNowAsync(Enum.AdFormat.RewardedVideo)
	end)

	if isSuccess and response.AdAvailabilityResult == Enum.AdAvailabilityResult.IsAvailable then
		return true
	end

	if isAdIneligible(response) then
		return false
	end

	return false
end

type RewardedAdService = typeof(RewardedAdService) & {
	networker: Networker.Client,
}

return RewardedAdService :: RewardedAdService
