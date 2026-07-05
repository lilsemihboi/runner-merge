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

return RunnerUtils
