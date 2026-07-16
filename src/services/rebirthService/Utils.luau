local RebirthUtils = {}

local BASE_PRICE = 1_000
local CASH_MULTIPLIER_REBIRTH = 0.05

function RebirthUtils.calculateCashRequirement(rebirthLevel: number)
	return BASE_PRICE * (10 ^ (rebirthLevel - 1))
end

function RebirthUtils.getCashMultiplierForRebirth(rebirthLevel: number)
	return 1 + (CASH_MULTIPLIER_REBIRTH * rebirthLevel)
end

return RebirthUtils
