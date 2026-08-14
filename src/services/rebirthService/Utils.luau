local RebirthUtils = {}

local ENDGAME_GROWTH = 1.30
local CASH_MULTIPLIER_REBIRTH = 0.05

local ROUTE_PROGRESSION_PRICES = {
	[1] = 1_000,
	[2] = 10_000,
	[3] = 100_000,
	[4] = 500_000,
	[5] = 2_000_000,
	[6] = 10_000_000,
}

function RebirthUtils.calculateCashRequirement(rebirthLevel: number)
	local routeProgressionPrice = ROUTE_PROGRESSION_PRICES[rebirthLevel]
	if routeProgressionPrice then
		return routeProgressionPrice
	end

	return ROUTE_PROGRESSION_PRICES[6] * (ENDGAME_GROWTH ^ (rebirthLevel - 6))
end

function RebirthUtils.getCashMultiplierForRebirth(rebirthLevel: number)
	return 1 + (CASH_MULTIPLIER_REBIRTH * rebirthLevel)
end

return RebirthUtils
