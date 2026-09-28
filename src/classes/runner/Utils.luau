local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ExclusiveCars = require(ReplicatedStorage.Shared.Modules.Items.ExclusiveCars)

local MAX_REGULAR_CAR_ID = 40

local RunnerUtils = {}

-- One owned car. `id` is unique per player and survives every roster rewrite,
-- `phase` is its own position along the lane (0..1) assigned once at creation.
-- Both are deliberately independent of how many runners exist, so buying or
-- merging only ever affects the cars it involves.
export type RunnerEntry = {
	id: number,
	level: number,
	phase: number,
}

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

function RunnerUtils.getRunnerLane(plotId: number, runnerId: number, laneCount: number): number
	if laneCount <= 1 then
		return 1
	end

	-- Deterministik: aynı (plotId, runnerId) her zaman aynı şeride düşer,
	-- ekstra network verisi taşımaya gerek kalmadan client/server eşleşir.
	local hash = (plotId * 92821 + runnerId * 68917) % 2147483647

	return (hash % laneCount) + 1
end

function RunnerUtils.getRunnerIncomePerLap(runnerLevel: number)
	local exclusiveCar = ExclusiveCars.get(runnerLevel)
	if exclusiveCar then
		return exclusiveCar.incomePerLap
	end

	local level = math.max(1, math.floor(runnerLevel))

	return 10 * (level ^ 3)
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

-- The runners data array may contain holes/garbage, so anything that derives a
-- car's identity from it (id -> lane, phase) must go through the same filter.
-- Values are copied, so callers can sort or rewrite freely.
function RunnerUtils.sanitizeRunners(runners: { any }?): { RunnerEntry }
	local entries: { RunnerEntry } = {}
	if type(runners) ~= "table" then
		return entries
	end

	for _, runner in ipairs(runners) do
		if typeof(runner) == "table" and typeof(runner.id) == "number" and typeof(runner.level) == "number" and typeof(runner.phase) == "number" then
			entries[#entries + 1] = { id = runner.id, level = runner.level, phase = runner.phase % 1 }
		end
	end

	return entries
end

function RunnerUtils.levelsOf(entries: { RunnerEntry }): { number }
	local levels: { number } = {}

	for _, entry in ipairs(entries) do
		levels[#levels + 1] = entry.level
	end

	return levels
end

function RunnerUtils.findRunner(entries: { RunnerEntry }, runnerId: number): RunnerEntry?
	for _, entry in ipairs(entries) do
		if entry.id == runnerId then
			return entry
		end
	end

	return nil
end

-- The position for a brand-new runner: the midpoint of the widest gap between
-- the runners that already exist. Existing phases are never rewritten, which is
-- what keeps a purchase from re-spacing the whole roster - the trade-off is
-- that spacing stays close to even instead of exactly even.
function RunnerUtils.nextPhase(entries: { RunnerEntry }): number
	local phases: { number } = {}
	for _, entry in ipairs(entries) do
		phases[#phases + 1] = entry.phase % 1
	end

	if #phases == 0 then
		return 0
	end

	table.sort(phases)

	-- Start from the wrap-around gap (last -> first across the lap boundary).
	local largestGap = phases[1] + 1 - phases[#phases]
	local gapStart = phases[#phases]

	for index = 1, #phases - 1 do
		local gap = phases[index + 1] - phases[index]
		if gap > largestGap then
			largestGap = gap
			gapStart = phases[index]
		end
	end

	return (gapStart + largestGap / 2) % 1
end

return RunnerUtils
