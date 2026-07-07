-- ============================================
--          Player Data Template
-- ============================================

export type DataSchema = {
	cash: number,
	rebirths: number,
	runnerPurchases: number,

	runners: { number },

	upgrades: {
		gates: number,
		runnerSpeed: number,
		cashBonus: number,
	},

	tutorial: {
		step: number,
		finished: boolean,
	},

	stats: {
		timePlayed: number,
		totalCashEarned: number,
		lastLogoutTime: number,
	},
}

return {
	cash = 0,
	rebirths = 0,
	runnerPurchases = 0,
	runners = {},

	upgrades = {
		gates = 0,
		runnerSpeed = 0,
		cashBonus = 0,
	},

	tutorial = {
		step = 1,
		finished = false,
	},

	stats = {
		timePlayed = 0,
		totalCashEarned = 0,
		lastLogoutTime = 0,
	},
} :: DataSchema
