local ReplicatedStorage = game:GetService("ReplicatedStorage")

local _Rarities = require(ReplicatedStorage.Shared.Modules.Items.Rarities)

--[=[
	Exclusive cars are premium runners that cannot be obtained by merging and
	cannot themselves be merged. They live in a reserved id band so that the
	`runners` data array stays a plain `{ number }`, which keeps the
	client/server deterministic phase contract in `RunnerUtils.sanitizeLevels`
	intact.

	Ids must be >= `ID_BASE`. Regular cars occupy 1..40 and grow upward over
	time, so the gap between 40 and `ID_BASE` is deliberate headroom.

	`incomePerLap` and `speed` are required rather than derived. The regular
	formulas in `RunnerUtils` scale as `level ^ 2.5`, so an id of 1001 would
	otherwise pay out roughly 3.2 billion per lap.
]=]

local ID_BASE = 1000

-- Named ids so grant sites never hardcode a magic number.
local ids = {
	exclusiveCar = 1001,
}

local ExclusiveCars = {}

export type ExclusiveCar = {
	name: string,
	imageId: string,
	incomePerLap: number,
	speed: number,
	rarity: keyof<typeof(_Rarities)>,
}

local cars: { [number]: ExclusiveCar } = {
	[ids.exclusiveCar] = {
		name = "Merci G63",
		imageId = "rbxassetid://0",
		incomePerLap = 6_700_000,
		speed = 83,
		rarity = "Secret",
	},
}

ExclusiveCars.cars = cars
ExclusiveCars.ids = ids
ExclusiveCars.ID_BASE = ID_BASE

--[=[
	Returns true when the given runner id refers to an exclusive car.

	This is the single predicate used to keep exclusives out of the merge
	system, so callers should never compare against `ID_BASE` directly.

	@param runnerId number
	@return boolean
]=]
function ExclusiveCars.isExclusive(runnerId: number): boolean
	return cars[runnerId] ~= nil
end

--[=[
	Returns the definition for an exclusive car, or nil when the id is a
	regular car.

	@param runnerId number
	@return ExclusiveCar?
]=]
function ExclusiveCars.get(runnerId: number): ExclusiveCar?
	return cars[runnerId]
end

return ExclusiveCars
