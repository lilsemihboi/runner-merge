local Blocks = {}
Blocks.rollTime = 4.5

--[[
	Loot weights are authored so each crate's entries sum to 100, which makes every
	weight readable as a literal percentage. Two rules govern the tables below:

	1. Rarity hierarchy is preserved. Secret is always the rarest outcome in every
	   crate, and no crate ever guarantees a top-tier drop. The Secret tier climbs
	   0.15% (Wood) -> 3% (Void), a 20x improvement that still leaves Secret rare.
	2. Loot pools widen with crate tier instead of drop rates exploding. Early
	   crates draw from a narrow pool; later crates unlock the full 17 trails, so
	   reaching a rarity gets easier while landing a *specific* trail stays hard.

	Trail ids are ordered by trailMultiplier, so rarity bands are contiguous:
	  Common     1 Smoke, 2 Rust, 3 Denim, 4 Green
	  Rare       5 Ocean, 6 Ember, 7 Toxic
	  Epic       8 Black and White, 9 Amethyst, 10 Sunset, 11 Frostbite
	  Legendary  12 Golden Hour, 13 Nebula
	  Mythic     14 Plasma, 15 Aurora
	  Secret     16 Prismatic, 17 Rainbow
]]
Blocks.blocks = {
	-- Common 71 | Rare 21 | Epic 6 | Legendary 1.4 | Mythic 0.45 | Secret 0.15
	-- Starter pool: no Green, no Toxic, and Rainbow is absent entirely.
	[1] = {
		lapsRequirement = 5,
		blockWeight = 30,
		blockName = "Wood Crate",
		loot = {
			[1] = 28,
			[2] = 24,
			[3] = 19,
			[5] = 12,
			[6] = 9,
			[8] = 6,
			[12] = 1.4,
			[14] = 0.45,
			[16] = 0.15,
		},
	},

	-- Common 63 | Rare 25 | Epic 9 | Legendary 2 | Mythic 0.7 | Secret 0.3
	-- Adds Amethyst to the Epic pool.
	[2] = {
		lapsRequirement = 10,
		blockWeight = 35,
		blockName = "Iron Crate",
		loot = {
			[1] = 25,
			[2] = 21,
			[3] = 17,
			[5] = 14,
			[6] = 11,
			[8] = 5.5,
			[9] = 3.5,
			[12] = 2,
			[14] = 0.7,
			[16] = 0.3,
		},
	},

	-- Common 55 | Rare 27 | Epic 12 | Legendary 4 | Mythic 1.5 | Secret 0.5
	-- Adds Green, Toxic, Sunset, Nebula and Aurora.
	[3] = {
		lapsRequirement = 25,
		blockWeight = 15,
		blockName = "Golden Crate",
		loot = {
			[1] = 17,
			[2] = 15,
			[3] = 13,
			[4] = 10,
			[5] = 11,
			[6] = 9,
			[7] = 7,
			[8] = 5,
			[9] = 4,
			[10] = 3,
			[12] = 2.5,
			[13] = 1.5,
			[14] = 1,
			[15] = 0.5,
			[16] = 0.5,
		},
	},

	-- Common 47 | Rare 29 | Epic 15 | Legendary 6 | Mythic 2.2 | Secret 0.8
	-- Adds Frostbite, completing every pool except Secret.
	[4] = {
		lapsRequirement = 50,
		blockWeight = 12.5,
		blockName = "Forest Crate",
		loot = {
			[1] = 14,
			[2] = 13,
			[3] = 11,
			[4] = 9,
			[5] = 11,
			[6] = 10,
			[7] = 8,
			[8] = 5,
			[9] = 4,
			[10] = 3.5,
			[11] = 2.5,
			[12] = 3.5,
			[13] = 2.5,
			[14] = 1.4,
			[15] = 0.8,
			[16] = 0.8,
		},
	},

	-- Common 40 | Rare 30 | Epic 18 | Legendary 7.5 | Mythic 3.3 | Secret 1.2
	-- Rainbow enters the pool here at 0.2%. Full 17-trail pool from this crate on.
	[5] = {
		lapsRequirement = 75,
		blockWeight = 5,
		blockName = "Lucky Crate",
		loot = {
			[1] = 12,
			[2] = 11,
			[3] = 9,
			[4] = 8,
			[5] = 11,
			[6] = 10,
			[7] = 9,
			[8] = 5.5,
			[9] = 5,
			[10] = 4,
			[11] = 3.5,
			[12] = 4.5,
			[13] = 3,
			[14] = 2,
			[15] = 1.3,
			[16] = 1,
			[17] = 0.2,
		},
	},

	-- Common 34 | Rare 30 | Epic 20 | Legendary 10 | Mythic 4.3 | Secret 1.7
	[6] = {
		lapsRequirement = 100,
		blockWeight = 2,
		blockName = "Saturn Crate",
		loot = {
			[1] = 10,
			[2] = 9,
			[3] = 8,
			[4] = 7,
			[5] = 11,
			[6] = 10,
			[7] = 9,
			[8] = 6,
			[9] = 5.5,
			[10] = 4.5,
			[11] = 4,
			[12] = 6,
			[13] = 4,
			[14] = 2.5,
			[15] = 1.8,
			[16] = 1.3,
			[17] = 0.4,
		},
	},

	-- Common 29 | Rare 30 | Epic 22 | Legendary 11.5 | Mythic 5.3 | Secret 2.2
	[7] = {
		lapsRequirement = 200,
		blockWeight = 0.25,
		blockName = "Star Crate",
		loot = {
			[1] = 8,
			[2] = 8,
			[3] = 7,
			[4] = 6,
			[5] = 11,
			[6] = 10,
			[7] = 9,
			[8] = 6.5,
			[9] = 6,
			[10] = 5,
			[11] = 4.5,
			[12] = 6.5,
			[13] = 5,
			[14] = 3,
			[15] = 2.3,
			[16] = 1.6,
			[17] = 0.6,
		},
	},

	-- Common 25 | Rare 29 | Epic 24 | Legendary 13 | Mythic 6.4 | Secret 2.6
	[8] = {
		lapsRequirement = 450,
		blockWeight = 0.15,
		blockName = "Grass Crate",
		loot = {
			[1] = 7,
			[2] = 7,
			[3] = 6,
			[4] = 5,
			[5] = 10.5,
			[6] = 9.5,
			[7] = 9,
			[8] = 7,
			[9] = 6.5,
			[10] = 5.5,
			[11] = 5,
			[12] = 7.5,
			[13] = 5.5,
			[14] = 3.6,
			[15] = 2.8,
			[16] = 1.8,
			[17] = 0.8,
		},
	},

	-- Common 22 | Rare 28 | Epic 25 | Legendary 14.5 | Mythic 7.5 | Secret 3
	-- Best rollable crate: Rainbow peaks at 1%, so it stays a 1-in-100 moment.
	[9] = {
		lapsRequirement = 500,
		blockWeight = 0.1,
		blockName = "Void Crate",
		loot = {
			[1] = 6,
			[2] = 6,
			[3] = 5,
			[4] = 5,
			[5] = 10,
			[6] = 9,
			[7] = 9,
			[8] = 7,
			[9] = 6.5,
			[10] = 6,
			[11] = 5.5,
			[12] = 8,
			[13] = 6.5,
			[14] = 4.2,
			[15] = 3.3,
			[16] = 2,
			[17] = 1,
		},
	},

	-- Exclusive crates
	-- Epic 46 | Legendary 30 | Mythic 16 | Secret 8
	-- Premium pool intentionally drops Common and Rare, but still never guarantees
	-- a Secret. Rainbow at 2.5% is the best rate in the game and remains a chase.
	[10] = {
		lapsRequirement = 200,
		blockWeight = 0,
		blockName = "Spike Crate",
		loot = {
			[8] = 13,
			[9] = 12,
			[10] = 11,
			[11] = 10,
			[12] = 17,
			[13] = 13,
			[14] = 9,
			[15] = 7,
			[16] = 5.5,
			[17] = 2.5,
		},
	},
} :: {
	[number]: {
		lapsRequirement: number,
		blockWeight: number,
		blockName: string,
		loot: { [number]: number }, -- trailId : chance
	},
}

local function totalWeight(loot: { [number]: number }): number
	local sum = 0
	for _, entry in loot do
		sum += math.max(0, entry or 0)
	end
	return sum
end

local function totalWeightOfBlocks(): number
	local sum = 0
	for _, entry in Blocks.blocks do
		sum += math.max(0, entry.blockWeight or 0)
	end
	return sum
end

function Blocks.getBlock(crateId: number)
	return Blocks.blocks[crateId]
end

function Blocks.rollBlock(rng: number): number?
	local total = totalWeightOfBlocks()
	if total <= 0 then
		return nil
	end

	local random = rng * total
	local acc = 0
	local lastEligible: number? = nil

	for blockId, entry in Blocks.blocks do
		local weight = math.max(0, entry.blockWeight or 0)
		if weight > 0 then
			acc += weight
			lastEligible = blockId
			if random <= acc then
				return blockId
			end
		end
	end

	return lastEligible
end

function Blocks.rollTrail(crateId: number, rng: number): number?
	local crate = Blocks.blocks[crateId]

	if crate == nil or crate.loot == nil then
		return nil
	end

	local total = totalWeight(crate.loot)
	if total <= 0 then
		return nil
	end

	local random = rng * total
	local acc = 0
	local lastEligible: number? = nil

	for trailId, entry in crate.loot do
		local weight = math.max(0, entry or 0)
		if weight > 0 then
			acc += weight
			lastEligible = trailId
			if random <= acc then
				return trailId
			end
		end
	end

	return lastEligible
end

--[[
	Returns the drop chance of a trail in a crate as a percentage, or 0 when the
	crate does not stock that trail. Callers format the result directly, so this
	must always return a number.
]]
function Blocks.getOdds(crateId: number, selectedTrailId: number): number
	local crate = Blocks.getBlock(crateId)
	if crate == nil or crate.loot == nil then
		return 0
	end

	local total = totalWeight(crate.loot)
	if total <= 0 then
		return 0
	end

	return math.max(0, crate.loot[selectedTrailId] or 0) / total * 100
end

return Blocks
