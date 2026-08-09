local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ExclusiveCars = require(ReplicatedStorage.Shared.Modules.Items.ExclusiveCars)

local MAX_REGULAR_CAR_ID = 40

local RunnerUtils = {}

function RunnerUtils.getRunnerSpeed(runnerLevel: number, runnerSpeedLevel: number?)
	local speedUpgradeLevel = if typeof(runnerSpeedLevel) == "number" then runnerSpeedLevel else 0
	local exclusiveCar = ExclusiveCars.get(runnerLevel)
	local speed

	if exclusiveCar then
		speed = exclusiveCar.speed
	else
		local level = math.max(1, math.floor(runnerLevel))
		local baseSpeed = 8
		speed = baseSpeed + math.floor((level - 1) ^ 1.35 * 0.8)
	end

	return speed * RunnerUtils.getRunnerSpeedMultiplier(speedUpgradeLevel)
end

-- Runner models live in `ReplicatedStorage.Assets.Entities` keyed by id. Regular
-- ids clamp to the highest authored model; exclusives are looked up verbatim.
function RunnerUtils.getModelName(runnerLevel: number): string
	if ExclusiveCars.isExclusive(runnerLevel) then
		return tostring(runnerLevel)
	end

	local level = math.max(1, math.floor(runnerLevel))

	return tostring(math.min(MAX_REGULAR_CAR_ID, level))
end

function RunnerUtils.getRunnerLane(plotId: number, index: number, laneCount: number): number
	if laneCount <= 1 then
		return 1
	end

	-- Deterministik: aynı (plotId, index) her zaman aynı şeride düşer,
	-- ekstra network verisi taşımaya gerek kalmadan client/server eşleşir.
	local hash = (plotId * 92821 + index * 68917) % 2147483647

	return (hash % laneCount) + 1
end

function RunnerUtils.getRunnerIncomePerLap(runnerLevel: number)
	local exclusiveCar = ExclusiveCars.get(runnerLevel)
	if exclusiveCar then
		return exclusiveCar.incomePerLap
	end

	local level = math.max(1, math.floor(runnerLevel))

	if level <= 2 then
		return 1 + (level - 1) * 2
	end

	return math.floor(100 * ((level - 2) ^ 2.5))
end

-- +10% income per cashBonus upgrade level (cap 10 -> 2.0x max)
function RunnerUtils.getCashBonusMultiplier(cashBonusLevel: number): number
	local level = math.max(0, math.floor(cashBonusLevel))

	return 1 + level * 0.1
end

-- +10% runner speed per runnerSpeed upgrade level (cap 10 -> 2.0x max)
function RunnerUtils.getRunnerSpeedMultiplier(runnerSpeedLevel: number): number
	local level = math.max(0, math.floor(runnerSpeedLevel))

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
