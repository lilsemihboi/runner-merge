local Runners = {}

local RUNNER_BASE_COST = 5
local RUNNER_GROWTH = 1.35

local function roundToTens(value: number): number
	return math.floor((value + 5) / 10) * 10
end

--[[
    @param runnerAmount number -- Your car amount + add runner amount (first runner is free)
]]
function Runners.calculateRunnerPrice(runnerAmount: number): number
	local amount = math.max(1, math.floor(runnerAmount))

	if amount == 1 then
		return 0
	end

	return roundToTens(RUNNER_BASE_COST * (RUNNER_GROWTH ^ (amount - 2)))
end

return Runners
