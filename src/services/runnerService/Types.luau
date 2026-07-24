export type PublicUpgrades = {
	gates: number,
	runnerSpeed: number,
	cashBonus: number,
}

export type RunnerPlotSnapshot = {
	plotId: number,
	owner: Player,
	levels: { number },
	startClock: number,
	gateCount: number,
	runnerSpeedLevel: number,
	carSpeedMultiplier: number,
	upgrades: PublicUpgrades,
}

export type MergeOperation = {
	sourceLevel: number,
	resultLevel: number,
}

return nil
