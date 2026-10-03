# Runner Simulation

> [!CAUTION]
> This is the most invariant-heavy system in the codebase. Before changing anything here, read the whole page. Client and server must compute **identical** positions from the same inputs, or gate income validation silently drops legitimate payouts (or pays exploiters).

## Responsibility split

| Side | Owns | Never does |
| --- | --- | --- |
| Server (`src/services/runnerService/Server.luau`) | Plot roster snapshots, `startClock`, lap accounting anchors, authoritative gate/lap validation, income payout, VIP/x2 pushes | No `Heartbeat`, no models, no physics, no per-frame work |
| Client (`src/classes/runner/RunnerManager.luau`, `Client.luau`) | All movement, models, trails, merge animations, income indicators, culling | Deciding rewards (server recomputes everything) |

## Determinism contract

Both sides derive a runner's position from the shared clock:

```
speed      = RunnerUtils.getRunnerSpeed(level, runnerSpeedLevel) * carSpeedMultiplier
travelTime = path.length / max(1, speed)
phase      = (index - 1) / #levels          -- index is 1-based position in the roster
progress   = ((workspace:GetServerTimeNow() - startClock) / travelTime + phase) % 1
distance   = progress * path.length
```

| Input | Source | Notes |
| --- | --- | --- |
| `level` | `profile:getRunners()`, sanitized by `RunnerUtils.sanitizeLevels` | Client and server MUST sanitize identically (holes/NaN dropped, order preserved) |
| `runnerSpeedLevel` | `profile:getUpgradeLevel("runnerSpeed")` | Speed multiplier `1 + 0.1 * level`, cap 10 |
| `carSpeedMultiplier` | x2 Speed gamepass → `2`, else `1` | Pushed in the snapshot and via `networker:set` |
| `path` | `PathData.get(plotId, lane)` | Cache-invalidated when the Runway instance is replaced (route change) |
| `lane` | `RunnerUtils.getRunnerLane(plotId, index, laneCount)` | Deterministic hash: `(plotId * 92821 + index * 68917) % 2147483647 % laneCount + 1` |
| `startClock` | Server: `workspace:GetServerTimeNow()` at registration / route change | Broadcast to every client |

Speed and income formulas (`src/classes/runner/Utils.luau`):

- Regular runner income per lap: `10 * level^3`.
- Regular runner speed: `8 + floor((level - 1)^1.35 * 0.8)`.
- Exclusive car: `incomePerLap` and `speed` come from `ExclusiveCars.get(id)` (id 1001 has 150,000 / 83).
- Model name: `math.min(MAX_REGULAR_CAR_ID = 40, level)`; income keeps scaling past 40. Exclusive ids are looked up verbatim.

## Files that must stay in sync

Any change to movement/validation touches these together:

| File | Role |
| --- | --- |
| `src/classes/runner/Utils.luau` | Shared speed/income/lane/sanitize formulas — the single source both sides use |
| `src/classes/runner/Client.luau` | Client per-car movement, gate/lap detection, model parenting |
| `src/classes/runner/RunnerManager.luau` | One `Heartbeat`, roster reconciliation, replication culling, report sends |
| `src/services/runnerService/Server.luau` | Snapshot broadcasts, `reportGate` / `reportLap` validation, lap anchors |
| `src/classes/runner/PathData.luau` | Catmull-Rom path + gate distances (shared) |
| `src/classes/runner/MergeEffects.luau` | Cosmetic merge animation; durations must match `RunnerService` constants |
| `src/services/runnerService/Types.luau` | Snapshot/merge operation types |

Checklist for a movement change: update `RunnerUtils`; make sure `RunnerClient.getDistance` and `RunnerService._getRunnerTiming` still agree; verify `phase` uses the sanitized roster; re-test late join (`requestState`) and route change (`resetForRouteChange`).

## Server broadcasts

`RunnerManager.setRunners(plotId, owner, levels, startClock, gateCount, runnerSpeedLevel, carSpeedMultiplier, routeId, selectedTrail)` reconciles a per-plot car pool (create / `updateLevel` / `configure` / destroy) rather than rebuilding it.

- `RunnerService._broadcastPlot` is debounced through `_scheduleBroadcast` (`task.defer`), because merges rewrite the array with many signals in one frame.
- Broadcasts are paused while a merge effect is active and resume with a fresh snapshot.
- Roster/speed changes clear `gateAwards` (indices and phases are reassigned) and re-anchor `lapClocks`.
- `_anchorLapClocks` keeps each runner's fraction of the current lap, so a faster `travelTime` never retroactively recounts past time as laps.
- `resetForRouteChange` resets `startClock` and re-broadcasts.
- `requestState` returns every plot snapshot for late joiners; live broadcasts received while fetching win (the manager skips plots it already knows).

## Client simulation

- `RunnerManager.update` runs one `Heartbeat`. Bounds culling runs every `BOUNDS_CHECK_INTERVAL = 0.2` s: the local player's own plot is **always** active; other plots only while the character is inside the plot's Runway bounding box (plus `Configuration.RUNNER_BOUNDS_PADDING = 15`).
- Inactive/invisible cars are unparented and skipped by `update` (zero per-frame cost).
- `RunnerClient` handles placement along the path (`PathData.sample` returns a CFrame; the car is raised by `RUNNER_CLEARANCE = 0.25` plus an inverted-surface correction), trail color/visibility from `Trails` and `settings.trails`, `prevDistance`/`prevLap` tracking, and model swaps on level change.
- `getRunnerCFrame` uses the sampled CFrame's `UpVector`, so 360° tracks keep cars on the surface.
- Income indicators (`_showIncomeIndicator`) float a `+$` billboard above the gate attachment when `settings.moneyIndicator` is on; they only show for the active plot's owner crossings.

## Server validation

`reportGate(player, plotId, runnerIndex, gateId)` drops the report unless **all** hold:

- `plotId`, `runnerIndex`, `gateId` are integers; the calling player owns the plot state.
- `gateId` is within `profile:getActiveGateCount()`.
- The deterministic distance since the gate is `<= timing.speed * 2` seconds of travel (tolerance covers ping/frame time).
- The same `(runnerIndex, gateId)` pair has not paid within `travelTime * 0.85`.

Invalid reports are silently dropped. Income is paid through `profile:giveCash` only.

`reportLap(player, plotId, runnerIndex)`:

- Ignored while a merge effect is active (roster indices are mid-rewrite).
- The first report anchors `lapClocks[runnerIndex] = now` (no credit).
- Only whole laps are credited; the leftover fraction carries over. `_spendLaps` decrements `lapsLeftToAcquire` (clamped to 0).

Anti-exploit notes: clients can only ask for a gate/lap they could have legitimately reached; the server never trusts reported distances, counts, or amounts. `Plot.addRunner` additionally bans impossible runner amounts. Do not weaken these guards.

## Route changes and paths

`PathData` builds one Catmull-Rom path per `(plot, lane)` from `Runway.waypoints/lane<N>` attachment CFrames and projects `gateAttachments` onto it to get `gateDistances`. The cache is a single slot per plot and is invalidated when the live Runway instance changes (`invalidateIfModelChanged`), which is exactly what a route change does. If you edit Runway assets, keep waypoint attachment names numeric-ordered and gate attachments numeric (`gateId`).

`getLaneCount` returns 0 if the Runway has not replicated yet; `RunnerManager.setRunners` then schedules a retry (`PATH_RETRY_INTERVAL = 1`) and `RunnerService._getRunnerTiming` simply fails validation — safe, but if you see "no runners on other plots", check the Runway first.

## Merge effect timing

`RunnerService` computes the animation duration from the operation DAG (`MERGE_INPUT_DURATION = 0.28`, `MERGE_RESULT_DURATION = 0.42`, `MERGE_ROOT_STAGGER = 0.12`, `MERGE_EFFECT_TRAIL_DURATION = 0.2`) and only resumes broadcasts after it. `MergeEffects.luau` uses the same constants (`INPUT_TWEEN`, `RESULT_TWEEN`, `ROOT_OPERATION_STAGGER`). If you change one side, change both.

## Change map

| You want to… | Touch |
| --- | --- |
| Change runner speed/income | `src/classes/runner/Utils.luau` (both sides use it) + re-verify payout/display docs |
| Add an exclusive car | `src/modules/items/ExclusiveCars.luau` + `ReplicatedStorage.Assets.Entities.<id>` + stock/product wiring |
| Change how positions are sampled | `PathData.sample` + `RunnerClient.getRunnerCFrame` + `RunnerService._getRunnerTiming` |
| Change gate tolerance/cooldowns | `RunnerService` constants + consider exploit review |
| Change merge visuals | `MergeEffects.luau` + `RunnerService.getMergeEffectDuration` |

## Related

- [Plots and gates](plots-and-gates.md)
- [Economy](economy.md) — multipliers and trails
- [Data flow · income](../architecture/data-flow.md#income-gate-crossings)
- [Gotchas](../reference/gotchas.md)
