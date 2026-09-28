local ReplicatedStorage = game:GetService("ReplicatedStorage")

local _Rarities = require(ReplicatedStorage.Shared.Modules.Items.Rarities)

--[=[
	Exclusive cars are premium runners that cannot be obtained by merging and
	cannot themselves be merged. Their level lives in a reserved band, well
	above the regular car levels, so an exclusive can never collide with a
	merged regular car's level, which keeps the client/server determinism
	contract in `RunnerUtils.sanitizeRunners` intact.

	Ids must be >= `ID_BASE`. Regular cars occupy 1..40 and grow upward over
	time, so the gap between 40 and `ID_BASE` is deliberate headroom.

	`incomePerLap` and `speed` are required rather than derived. Exclusive ids are
	metadata keys rather than progression levels, so applying the regular formula
	would make their income depend on an implementation detail.
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
		imageId = "rbxassetid://115409101765569",
		incomePerLap = 150_000,
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
