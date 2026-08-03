local Blocks = {}
Blocks.rollTime = 4.5

Blocks.blocks = {
	[1] = {
		lapsRequirement = 5,
		blockWeight = 30,
		blockName = "Wood Crate",
		loot = {
			[1] = 60,
			[2] = 30,
			[3] = 10,
		},
	},
	[2] = {
		lapsRequirement = 10,
		blockWeight = 35,
		blockName = "Iron Crate",
		loot = {
			[1] = 40,
			[2] = 40,
			[3] = 20,
		},
	},
	[3] = {
		lapsRequirement = 25,
		blockWeight = 15,
		blockName = "Golden Crate",
		loot = {
			[1] = 30,
			[2] = 50,
			[3] = 20,
		},
	},
	[4] = {
		lapsRequirement = 50,
		blockWeight = 12.5,
		blockName = "Forest Crate",
		loot = {
			[1] = 25,
			[2] = 50,
			[3] = 25,
		},
	},
	[5] = {
		lapsRequirement = 75,
		blockWeight = 5,
		blockName = "Lucky Crate",
		loot = {
			[2] = 40,
			[3] = 60,
		},
	},

	[6] = {
		lapsRequirement = 100,
		blockWeight = 2,
		blockName = "Saturn Crate",
		loot = {
			[2] = 20,
			[3] = 80,
		},
	},

	[7] = {
		lapsRequirement = 200,
		blockWeight = 0.25,
		blockName = "Star Crate",
		loot = {
			[2] = 10,
			[3] = 90,
		},
	},

	[8] = {
		lapsRequirement = 450,
		blockWeight = 0.15,
		blockName = "Grass Crate",
		loot = {
			[2] = 5,
			[3] = 95,
		},
	},

	[9] = {
		lapsRequirement = 500,
		blockWeight = 0.1,
		blockName = "Void Crate",
		loot = {
			[2] = 2.5,
			[3] = 97.5,
		},
	},

	-- Exclusive crates
	[10] = {
		lapsRequirement = 200,
		blockWeight = 0,
		blockName = "Spike Crate",
		loot = {
			[3] = 100,
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
	for blockId, entry in Blocks.blocks do
		acc += math.max(0, entry.blockWeight or 0)
		if random <= acc then
			return blockId
		end
	end

	return #Blocks.blocks
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
	for trailId, entry in crate.loot do
		acc += math.max(0, entry or 0)
		if random <= acc then
			return trailId
		end
	end

	return #crate.loot
end

return Blocks
