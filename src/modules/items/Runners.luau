local Runners = {}

local RUNNER_GROWTH = 1.16
local MIN_PRICE_INCREASE = 5
local CUSTOM_RUNNER_PRICE_COUNT = 15

local CUSTOM_RUNNER_PRICES = {
	[1] = 0,
	[2] = 2,
	[3] = 5,
	[4] = 10,
	[5] = 15,
	[6] = 25,
	[7] = 35,
	[8] = 50,
	[9] = 70,
	[10] = 95,
	[11] = 130,
	[12] = 175,
	[13] = 235,
	[14] = 315,
	[15] = 420,
}

local function roundToFives(value: number): number
	return math.floor((value + 2.5) / 5) * 5
end

--[[
    @param runnerAmount number -- Total lifetime runner purchase number (first runner is free)
]]
function Runners.calculateRunnerPrice(runnerAmount: number): number
	local amount = math.max(1, math.floor(runnerAmount))
	local customPrice = CUSTOM_RUNNER_PRICES[amount]

	if customPrice then
		return customPrice
	end

	local previousPrice = Runners.calculateRunnerPrice(amount - 1)
	local formulaStartPrice = CUSTOM_RUNNER_PRICES[CUSTOM_RUNNER_PRICE_COUNT]
	local formulaPrice = roundToFives(formulaStartPrice * (RUNNER_GROWTH ^ (amount - CUSTOM_RUNNER_PRICE_COUNT)))

	return math.max(formulaPrice, previousPrice + MIN_PRICE_INCREASE)
end

--[[
	@param currentPurchases number -- Current lifetime runner purchases
	@param purchaseAmount number -- Amount of runners being bought now
]]
function Runners.calculateRunnerBatchPrice(currentPurchases: number, purchaseAmount: number): number
	local currentAmount = math.max(0, math.floor(currentPurchases))
	local amountToBuy = math.max(0, math.floor(purchaseAmount))
	local totalCost = 0

	for index = currentAmount + 1, currentAmount + amountToBuy do
		totalCost += Runners.calculateRunnerPrice(index)
	end

	return totalCost
end

return Runners
