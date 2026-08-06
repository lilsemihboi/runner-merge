-- ============================================
--          Player Data Template
-- ============================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Blocks = require(ReplicatedStorage.Shared.Modules.Items.Blocks)

export type DataSchema = {
	cash: number,
	cashMultiplier: number,
	customMultiplier: number,

	selectedRoute: number,
	spins: number,

	isGroupRewardClaimed: boolean,

	rebirths: number,

	runnerPurchases: number,
	runners: { number },
	runnerSpawnLevel: number,

	index: { number },
	inventory: { number },

	selectedTrail: number?,

	luckyBlockInQueue: number,
	lapsLeftToAcquire: number?,

	offlineEarnings: number?,
	offlineEarningsPaid: boolean?,
	offlineEarningsDoubled: boolean?,

	upgrades: {
		gates: number,
		runnerSpeed: number,
		cashBonus: number,
	},
	extraGates: number,

	tutorial: {
		step: number,
		finished: boolean,
	},

	stats: {
		timePlayed: number,
		totalCashEarned: number,
		lastLogoutTime: number?,
	},

	settings: {
		sounds: number,
		music: number,
		trails: boolean,
	},
}

return {
	cash = 0,
	cashMultiplier = 1,
	customMultiplier = 1,

	selectedRoute = 1,
	spins = 0,

	rebirths = 0,

	runnerPurchases = 0,
	runners = {},
	runnerSpawnLevel = 1,

	index = {},
	inventory = {},

	selectedTrail = nil,

	luckyBlockInQueue = 1,
	lapsLeftToAcquire = Blocks.getBlock(1).lapsRequirement,

	offlineEarnings = nil,

	isGroupRewardClaimed = false,

	upgrades = {
		gates = 0,
		runnerSpeed = 0,
		cashBonus = 0,
	},
	extraGates = 0,

	tutorial = {
		step = 1,
		finished = false,
	},

	stats = {
		timePlayed = 0,
		totalCashEarned = 0,
	},

	settings = {
		sounds = 100,
		music = 100,
		trails = true,
	},
} :: DataSchema
