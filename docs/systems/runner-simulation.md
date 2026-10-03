# Runner Simulation

> [!CAUTION]
> This is the most invariant-heavy system in the codebase. Before changing anything here, read the whole page. Client and server must compute **identical** positions from the same inputs, or gate income validation silently drops legitimate payouts (or pays exploiters).

## Responsibility split

| Side | Owns | Never does |
| --- | --- | --- |
| Server (`src/services/runnerService/Server.luau`) | Plot roster snapshots + deltas, `startClock`, per-runner `phase` re-anchoring, lap accounting anchors, authoritative gate/lap validation, income payout, VIP/x2 pushes | No `Heartbeat`, no models, no physics, no per-frame work |
| Client (`src/classes/runner/RunnerManager.luau`, `Client.luau`) | All movement, models, trails, merge animations, income indicators, culling | Deciding rewards (server recomputes everything) |

## Determinism contract

Both sides derive a runner's position from the shared clock:

```
speed      = RunnerUtils.getRunnerSpeed(level, runnerSpeedLevel) * carSpeedMultiplier
travelTime = path.length / max(1, speed)
lane       = RunnerUtils.getRunnerLane(plotId, runnerId, laneCount)
phase      = entry.phase          -- owned by the runner, never derived from the roster
progress   = ((workspace:GetServerTimeNow() - startClock) / travelTime + phase) % 1
distance   = progress * path.length
```

| Input | Source | Notes |
| --- | --- | --- |
| `id` | `entry.id` (persisted) | Stable per car and never reused; defines lane (`getRunnerLane(plotId, runnerId, …)`) |
| `level` | `entry.level`, sanitized by `RunnerUtils.sanitizeRunners` | Client and server MUST sanitize identically (holes/garbage dropped, order preserved) |
| `phase` | `entry.phase` (persisted, 0..1) | Assigned once at creation from the widest gap (`nextPhase`); never re-spaced, only re-anchored in place when the car's level changes (see below) |
| `runnerSpeedLevel` | `profile:getUpgradeLevel("runnerSpeed")` | Speed multiplier `1 + 0.1 * level`, cap 10 |
| `carSpeedMultiplier` | x2 Speed gamepass → `2`, else `1` | Pushed in snapshots/deltas and via `networker:set` |
| `path` | `PathData.get(plotId, lane)` | Cache-invalidated when the Runway instance is replaced (route change) |
| `startClock` | Server: `workspace:GetServerTimeNow()` at registration / route change / uniform speed-factor rebase | Broadcast: full snapshots and delta scalars |

Speed and income formulas (`src/classes/runner/Utils.luau`):

- Regular runner income per lap: `10 * level^3`.
- Regular runner speed: `8 + floor((level - 1)^1.35 * 0.8)`.
- Exclusive car: `incomePerLap` and `speed` come from `ExclusiveCars.get(id)` (id 1001 has 150,000 / 83).
- Model name: `math.min(MAX_REGULAR_CAR_ID = 40, level)`; income keeps scaling past 40. Exclusive ids are looked up verbatim.

## Position continuity (no teleporting)

A car must never jump because the roster or its speed changed. Three rules enforce that:

1. **Identity and phase live on the runner, not on its slot.** Buying appends `{ id = nextRunnerId, level, phase = nextPhase(entries) }` (midpoint of the widest gap); merges and bump rewrites preserve ids. Surviving cars are never re-spaced, and lane is a pure function of `(plotId, id)`.
2. **Anchors are computed at send time, against what clients actually hold.** `_broadcastPlot` first calls `_rebaseStartClock` (uniform factor changes), then `_reanchorChangedLevels` (any car whose level changed since the last message), then builds the snapshot/delta. Broadcasts can be delayed for seconds by a merge effect while clients keep the old trajectory, so anchoring at mutation time would still produce a jump when the message finally lands.
3. **The merge result keeps the left input's id.** `Plot.merge` stores the surviving level while the phase is re-anchored server-side before sending: `phase' = (progressOld − (now − startClock)/travelTimeNew) % 1`. The client receives the new level and phase in the same message, and the replacement model is created after `configure` applies them, so the faster car continues from where its input stood. The same path covers rebirth bumps (`_bumpLowLevelRunners`), which have no merge animation to hide a jump.
4. **Uniform speed-factor changes rebase `startClock` exactly, at send time.** `_rebaseStartClock` uses the last clock clients were sent: `startClock' = lastSentClock − (now − lastSentClock) * (oldFactor / newFactor)` with `oldFactor` coming from `lastSentScalars`. Because `travelTime` scales with `1/factor`, every car keeps `(now − startClock) * factor` constant, and both sides switch on the identical value.

The re-anchored phase is written back to the profile (via `DataService:set`), so gate validation, lap accounting and offline earnings all read the value the client renders.

Route changes are the one deliberate reset: the path itself is replaced, so `startClock` is reset and a full snapshot is forced.

## Files that must stay in sync

Any change to movement/validation touches these together:

| File | Role |
| --- | --- |
| `src/classes/runner/Utils.luau` | Shared speed/income/lane/sanitize/nextPhase helpers — the single source both sides use |
| `src/classes/runner/Client.luau` | Client per-car movement, gate/lap detection, model parenting |
| `src/classes/runner/RunnerManager.luau` | One `Heartbeat`, id-keyed roster reconciliation, delta application, resync, replication culling, report sends |
| `src/services/runnerService/Server.luau` | Snapshot/delta broadcasts, send-time `_rebaseStartClock` / `_reanchorChangedLevels`, `reportGate` / `reportLap` validation, lap anchors |
| `src/classes/runner/PathData.luau` | Catmull-Rom path + gate distances (shared) |
| `src/classes/runner/MergeEffects.luau` | Cosmetic merge animation; sources addressed by runner id; durations must match `RunnerService` constants |
| `src/services/runnerService/Types.luau` | Snapshot/delta/merge operation types |
| `src/modules/game/DataTemplate.luau` + `src/services/profileService/Server.luau` | `{ id, level, phase }` schema + `nextRunnerId`; legacy-save migration assigns `id` = position in the compacted array, `phase = (position − 1) / count` (old save loads with zero movement) |

Checklist for a movement change: update `RunnerUtils`; make sure `RunnerClient.getDistance` and `RunnerService._getRunnerTiming` still agree; verify both use the entry's own `id`/`phase`; verify send-time anchoring (`_rebaseStartClock` + `_reanchorChangedLevels`) still matches the client's `configure` swap; re-test late join (`requestState`), gap recovery (`requestPlot`) and route change (`resetForRouteChange`).

## Server broadcasts

Traffic is diff-based. The server keeps the last state every client acknowledged (`lastSentRunners` + `lastSentScalars`) and ships only what changed:

- `setRunners(plotId, owner, runners, startClock, gateCount, runnerSpeedLevel, carSpeedMultiplier, routeId, selectedTrail, rev)` — full snapshot. Sent on first registration, route change, late join (`requestState`), gap recovery (`requestPlot`), and when a diff covers ≥ `FULL_SYNC_RATIO` (50%) of the roster (or ≥ 4 cars).
- `applyRunnerDelta(plotId, baseRev, rev, removedIds, upserts, scalars)` — the common path (purchase, merge, bump, upgrade, trail, gates). A merge of two cars is roughly one removal + one upsert.
- `removePlot(plotId)` — plot unregistered.
- Both message kinds carry a monotonic per-plot `rev`; deltas are chained through `baseRev`. A client whose state is not at `baseRev` fetches `requestPlot(plotId)` for a fresh full snapshot instead of silently drifting (`requestPlot` returns the same snapshot shape as `requestState`).
- `RunnerService._broadcastPlot` is debounced through `_scheduleBroadcast` (`task.defer`), because merges rewrite the array with many signals in one frame.
- Broadcasts are paused while a merge effect is active and resume with a (usually tiny) delta.
- Roster changes clear `gateAwards` (now keyed by `runnerId_gateId`) and re-anchor `lapClocks` (keyed by runner id).
- `_anchorLapClocks` keeps each runner's fraction of the current lap, so a faster `travelTime` never retroactively recounts past time as laps.
- `resetForRouteChange` resets `startClock`, invalidates the cached last-sent state, and forces a full snapshot.

## Client simulation

- `RunnerManager.update` runs one `Heartbeat`. Bounds culling runs every `BOUNDS_CHECK_INTERVAL = 0.2` s: the local player's own plot is **always** active; other plots only while the character is inside the plot's Runway bounding box (plus `Configuration.RUNNER_BOUNDS_PADDING = 15`).
- `setRunners` / `applyRunnerDelta` reconcile the car pool **by id** (`_reconcileCars`): create / `updateLevel` / `configure` / destroy. A reconcile that does not change a car's entry does not move it.
- Inactive/invisible cars are unparented and skipped by `update` (zero per-frame cost).
- `RunnerClient` handles placement along the path (`PathData.sample` returns a CFrame; the car is raised by `RUNNER_CLEARANCE = 0.25` plus an inverted-surface correction), trail color/visibility from `Trails` and `settings.trails`, `prevDistance`/`prevLap` tracking, and model swaps on level change.
- `getRunnerCFrame` uses the sampled CFrame's `UpVector`, so 360° tracks keep cars on the surface.
- Income indicators (`_showIncomeIndicator`) float a `+$` billboard above the gate attachment when `settings.moneyIndicator` is on; they only show for the active plot's owner crossings.
- Deltas are revision-checked before applying (`rev > state.rev` and `baseRev == state.rev`); fetch responses are additionally guarded by a per-plot generation counter so a response that crosses a plot removal cannot resurrect a dead plot.

## Server validation

`reportGate(player, plotId, runnerId, gateId)` drops the report unless **all** hold:

- `plotId`, `runnerId`, `gateId` are integers; the calling player owns the plot state.
- A runner with exactly that id exists in the player's roster (an id from the middle of a merge can only credit the car it belongs to — or nothing).
- `gateId` is within `profile:getActiveGateCount()`.
- The deterministic distance since the gate is `<= timing.speed * 2` seconds of travel (tolerance covers ping/frame time).
- The same `(runnerId, gateId)` pair has not paid within `travelTime * 0.85`.

Invalid reports are silently dropped. Income is paid through `profile:giveCash` only.

`reportLap(player, plotId, runnerId)`:

- Ignored while a merge effect is active (roster is mid-rewrite).
- The first report anchors `lapClocks[runnerId] = now` (no credit).
- Only whole laps are credited; the leftover fraction carries over. `_spendLaps` decrements `lapsLeftToAcquire` (clamped to 0).

Anti-exploit notes: clients can only ask for a gate/lap they could have legitimately reached; the server never trusts reported distances, counts, or amounts. `Plot.addRunner` additionally bans impossible runner amounts. Do not weaken these guards.

## Route changes and paths

`PathData` builds one Catmull-Rom path per `(plot, lane)` from `Runway.waypoints/lane<N>` attachment CFrames and projects `gateAttachments` onto it to get `gateDistances`. The cache is a single slot per plot and is invalidated when the live Runway instance changes (`invalidateIfModelChanged`), which is exactly what a route change does. If you edit Runway assets, keep waypoint attachment names numeric-ordered and gate attachments numeric (`gateId`).

`getLaneCount` returns 0 if the Runway has not replicated yet; `RunnerManager._reconcileCars` then schedules a retry (`PATH_RETRY_INTERVAL = 1`) and `RunnerService._getRunnerTiming` simply fails validation — safe, but if you see "no runners on other plots", check the Runway first.

## Merge effect timing

`RunnerService` computes the animation duration from the operation DAG (`MERGE_INPUT_DURATION = 0.28`, `MERGE_RESULT_DURATION = 0.42`, `MERGE_ROOT_STAGGER = 0.12`, `MERGE_EFFECT_TRAIL_DURATION = 0.2`) and only resumes broadcasts after it. `MergeEffects.luau` uses the same constants (`INPUT_TWEEN`, `RESULT_TWEEN`, `ROOT_OPERATION_STAGGER`). If you change one side, change both.

## Merge cascade (identity rules)

`Plot.merge` pairs equal non-exclusive levels repeatedly until stable. The **left** input of each pair survives:

- its `id` carries over (lane and `gateAwards` key family stay valid),
- its `level` becomes `level + 1`,
- its phase is re-anchored server-side at broadcast time (`_reanchorChangedLevels`) so the faster car continues from where it stood.

The right input's id disappears from the roster. `MergeOperation.leftSource/rightSource` address cars by `runnerId` (never by array slot), so the cosmetic effect can look up the exact models being merged.

## Change map

| You want to… | Touch |
| --- | --- |
| Change runner speed/income | `src/classes/runner/Utils.luau` (both sides use it) + re-verify payout/display docs |
| Add an exclusive car | `src/modules/items/ExclusiveCars.luau` + `ReplicatedStorage.Assets.Entities.<id>` + stock/product wiring |
| Change how positions are sampled | `PathData.sample` + `RunnerClient.getRunnerCFrame` + `RunnerService._getRunnerTiming` |
| Change gate tolerance/cooldowns | `RunnerService` constants + consider exploit review |
| Change merge visuals | `MergeEffects.luau` + `RunnerService.getMergeEffectDuration` |
| Change the wire protocol | `RunnerService._broadcastPlot` + `RunnerManager.setRunners`/`applyRunnerDelta` + `RunnerServiceTypes` |

## Related

- [Plots and gates](plots-and-gates.md)
- [Economy](economy.md) — multipliers and trails
- [Data flow · income](../architecture/data-flow.md#income-gate-crossings)
- [Gotchas](../reference/gotchas.md)
