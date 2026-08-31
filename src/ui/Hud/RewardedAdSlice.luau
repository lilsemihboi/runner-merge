local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RewardedAdServiceClient = require(ReplicatedStorage.Shared.Services.RewardedAdService.RewardedAdServiceClient)
local Vide = require(ReplicatedStorage.Packages.Vide)

-- Whether the player can watch the rewarded ad right now: the session reward is
-- unclaimed and the ad platform has one available. Shared by the sidebar button
-- and the shop banner; starts hidden until the async checks answer.
local canShowAd = Vide.source(false)

local RewardedAdSlice = {
	canShowAd = canShowAd,
}

-- Re-checks eligibility with the server and updates the shared source. Cheap to
-- call on every shop open; the server answers from memory.
function RewardedAdSlice.refresh()
	task.spawn(function()
		canShowAd(RewardedAdServiceClient:canShowAd())
	end)
end

return RewardedAdSlice
