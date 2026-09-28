local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Type-only: runner entries are defined next to their sanitizing helpers.
local _RunnerUtils = require(ReplicatedStorage.Shared.Classes.Runner.RunnerUtils)

export type RunnerPlotSnapshot = {
	plotId: number,
	owner: Player,
	runners: { _RunnerUtils.RunnerEntry },
	startClock: number,
	gateCount: number,
	runnerSpeedLevel: number,
	carSpeedMultiplier: number,
	routeId: number,
	selectedTrail: number?,
}

-- Sources are addressed by runner id, never by array slot: the roster is
-- rewritten by every merge, so an index would point at a different car.
export type MergeSource = {
	runnerId: number?,
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
