local RunnerUtils = {}

function RunnerUtils.getRunnerSpeed(runnerLevel: number)
	local level = math.max(1, math.floor(runnerLevel))
	local baseSpeed = 8
	local speed = baseSpeed + math.floor((level - 1) ^ 1.35 * 0.8)

	return speed
end

function RunnerUtils.getRunnerIncomePerLap(runnerLevel: number)
	local level = math.max(1, math.floor(runnerLevel))

	if level <= 2 then
		return 1 + (level - 1) * 2
	end

	return math.floor(20 * (2 ^ (level - 3)))
end

-- +10% income per cashBonus upgrade level (cap 10 -> 2.0x max)
function RunnerUtils.getCashBonusMultiplier(cashBonusLevel: number): number
	local level = math.max(0, math.floor(cashBonusLevel))

	return 1 + level * 0.1
end

-- The runners data array may contain holes/garbage; client and server MUST
-- sanitize identically so the deterministic phase (index / count) matches.
function RunnerUtils.sanitizeLevels(runners: { number? }?): { number }
	local levels: { number } = {}
	if type(runners) ~= "table" then
		return levels
	end

	for _, runnerLevel in ipairs(runners) do
		if typeof(runnerLevel) == "number" then
			levels[#levels + 1] = runnerLevel
		end
	end

	return levels
end

return RunnerUtils
