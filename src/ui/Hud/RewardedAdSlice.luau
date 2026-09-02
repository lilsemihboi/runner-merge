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

-- Ad availability can change while playing (the session reward gets claimed, the
-- ad platform runs out), so keep re-checking so the sidebar button and shop
-- banner stay accurate without the player having to reopen the shop.
const REFRESH_INTERVAL = 30

task.spawn(function()
	while true do
		task.wait(REFRESH_INTERVAL)
		RewardedAdSlice.refresh()
	end
end)

return RewardedAdSlice
