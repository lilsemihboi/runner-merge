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

export type MergeSource = {
	runnerIndex: number?,
	resultId: number?,
}

export type MergeOperation = {
	id: number,
	sourceLevel: number,
	resultLevel: number,
	leftSource: MergeSource,
	rightSource: MergeSource,
}

return nil
