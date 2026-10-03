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
	-- Monotonic per-plot revision. Both full snapshots and deltas carry it so a
	-- late joiner can never apply a state that is older than what it already has.
	rev: number,
}

-- Scalar fields of a plot; everything a delta may need to update besides the
-- runner roster itself. `selectedTrailChanged` is explicit because the trail
-- can legitimately be set to `nil` (toggle off), which a missing table key
-- could not distinguish from "unchanged".
export type RunnerPlotScalars = {
	startClock: number?,
	gateCount: number?,
	runnerSpeedLevel: number?,
	carSpeedMultiplier: number?,
	routeId: number?,
	selectedTrailChanged: boolean?,
	selectedTrail: number?,
}

-- Deltas are chained through their revisions: `baseRev` is the revision the
-- message was diffed against and `rev` is the new one. A client whose state
-- does not sit at `baseRev` knows it missed a message and asks for a resync.
export type RunnerPlotDelta = {
	plotId: number,
	baseRev: number,
	rev: number,
	removedIds: { number },
	upserts: { _RunnerUtils.RunnerEntry },
	scalars: RunnerPlotScalars?,
}

-- Sources are addressed by runner id, never by array slot: the roster is
-- rewritten by every merge, so a slot would point at a different car.
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
