local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)

local pendingReward = Vide.source(nil)
local isDoublePurchasePromptOpen = Vide.source(false)

return {
	pendingReward = pendingReward,
	isDoublePurchasePromptOpen = isDoublePurchasePromptOpen,
	actions = {
		setPendingReward = function(newReward)
			pendingReward(newReward)
		end,
		clearPendingReward = function()
			pendingReward(nil)
		end,
		setDoublePurchasePromptOpen = function(isOpen)
			isDoublePurchasePromptOpen(isOpen == true)
		end,
	},
}
