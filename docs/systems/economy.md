# Economy and Progression

Costs, income, and multipliers. Numeric values live in code; this page tells you **which** code owns each number and what must change together.

| Concern | Owner file |
| --- | --- |
| Income/speed formulas | `src/classes/runner/Utils.luau` |
| Upgrade costs/caps | `src/modules/items/UpgradeUtils.luau` |
| Runner purchase price | `src/modules/items/Runners.luau` |
| Trail multipliers | `src/modules/items/Trails.luau` |
| Exclusive cars | `src/modules/items/ExclusiveCars.luau` |
| Route numbers | `src/services/routeService/Utils.luau` |
| Rebirth costs/multiplier | `src/services/rebirthService/Utils.luau` |
| Payout assembly | `src/services/runnerService/Server.luau` (`reportGate`) + `src/classes/runner/RunnerManager.luau` (display) |

## Income multipliers

Every multiplier that feeds a gate payout:

| Multiplier | Formula | Source | Offline earnings? |
| --- | --- | --- | --- |
| `cashBonus` | `1 + 0.1 * level` (cap 10 → ×2.0) | `upgrades.cashBonus` | Yes |
| Friends | `1 + friendCount * FRIENDS_PER_TICK / 100` (+10% each) | `friendService`, `Configuration.FRIENDS_PER_TICK = 10` | **No** |
| Rebirth (`cashMultiplier`) | `1 + 0.05 * rebirths` | `RebirthService` / `skipRebirth` | Yes |
| Custom (`customMultiplier`) | starter pack `+0.2`, group reward `+0.05` | `ProductServerCallbacks`, `Plot.giveGroupReward` | Yes |
| VIP | `1.5` | pass `vip` | Yes |
| x2 Cash | `2` | pass `x2Cash` | **No** |
| Trail | selected trail multiplier (1.10–9.99) | `Trails` + `selectedTrail` | Yes |
| Route | route `cashMultiplier` (1–3.82) | `RouteServiceUtils` | Yes |
| x2 Speed | `2` on speed (not a per-gate multiplier) | pass `x2Speed` | **No** |

Authoritative payout is in `RunnerService.reportGate`; the client income indicator in `RunnerManager._showIncomeIndicator` mirrors it. The server floors at `math.max(1, …)`, the client at 0. Offline earnings (`src/services/offlineEarningsService/Server.luau`) uses the same set minus friends/x2 Cash/x2 Speed, applies `OFFLINE_EARNINGS_MULTIPLIER = 0.7`, and floors the result. **Change all three together** or displayed numbers drift from payouts (and the balance report stops matching the game).

## Upgrades

`UpgradeUtils.calculateUpgradeCost(upgradeId, nextLevel, rebirths)`:

| Upgrade | Cost | Cap | Effect |
| --- | --- | --- | --- |
| `gates` | level 1: `0`; level 2: `50`; else `roundToTens(5000 * 2.5^(level-3))` | `route.cashGateCap` (route-dependent) | Each gate pays once per lap |
| `runnerSpeed` | `roundToTens(300 * 1.95^level * 0.5 * 1.4^rebirths)` | 10 | ×`1 + 0.1 * level` speed |
| `cashBonus` | `roundToTens(500 * 2^level * 0.5 * 1.4^rebirths)` | 10 | ×`1 + 0.1 * level` income |

- `roundToTens(v) = floor((v + 5) / 10) * 10`.
- Gate upgrades ignore rebirth count; the other two scale with `0.5 * 1.4^rebirths`.
- Server enforcement is `Plot.upgrade` (`src/classes/plot/Server.luau`), including the route cash-gate cap. Client prices come from the same functions (`PlotClient`, `UpgradeUtils.updateLevelCaps`).
- `UpgradeUtils.levelCaps.gates` is a client-side display atom set to `route.gateCap`; it is **not** server validation. Server gates cap at `cashGateCap`.

### Gate counts

```
cashGates = clamp(upgrades.gates, 0, route.cashGateCap)
extra     = (upgrades.gates >= route.cashGateCap)
            and clamp(extraGates, 0, route.gateCap - route.cashGateCap) or 0
activeGateCount = cashGates + extra
```

Extra gates require VIP and maxed cash gates (`Plot.upgradeGatesWithPass`) or the `extraGate1`/`extraGate2` products (`extraGate2` requires `extraGates == 1`). Gates beyond `cashGateCap` are built from the exclusive gate template.

## Runners

- Income per lap: regular `10 * level^3`; exclusive car `incomePerLap` (Merci G63 = 150,000).
- Merge rule: two equal levels → one of `level + 1`, cascading until stable; exclusives never merge. Auto-merge at 20 runners.
- Purchase price (`Runners.calculateRunnerPrice`): fixed table for the first 15 purchases (`0, 1, 3, 10, 15, 25, 35, 50, 70, 95, 130, 175, 235, 315, 420`), then `max(roundToFives(420 * 1.06^(n-15)), previous + 5)`. Batch price sums the individual prices for `currentPurchases + 1 .. +amount`.
- `runnerPurchases` is the price index and increments from **every** grant path (shop, codes, starter pack, car bundle, group reward). Exclusive cars bypass it.
- `index[tostring(level)] = true` tracks first unlocks for the Index menu, including `"1001"` for exclusives.
- Models come from `ReplicatedStorage.Assets.Entities.<id>`; `RunnerUtils.getModelName` clamps regular ids at 40 while income keeps scaling (a known long-tail balance issue).

## Trails

`src/modules/items/Trails.luau`, ids 1–17, `trailMultiplier` 1.10 (Smoke) → 9.99 (Rainbow), rarity bands Common/Rare/Epic/Legendary/Mythic/Secret. The multiplier applies only while the trail is equipped (`selectedTrail`); none equipped = ×1.

Ownership lives in `inventory` (array, duplicates allowed). `giveTrail` ignores unknown ids; `selectTrail` rejects unknown/unowned ids. There is no salvage/sink yet.

## Routes

`src/services/routeService/Utils.luau`:

| Id | gateCap | cashGateCap | rebirthReq | cashMultiplier |
| --- | --- | --- | --- | --- |
| 1 | 10 | 8 | 0 | 1.00 |
| 2 | 12 | 10 | 1 | 1.25 |
| 3 | 14 | 12 | 2 | 1.50 |
| 4 | 16 | 14 | 3 | 2.09 |
| 5 | 18 | 16 | 5 | 3.62 |
| 6 | 20 | 18 | 7 | 3.80 |
| 7 | 27 | 25 | 9 | 3.82 |

- Selection: `fetch("selectRoute")` validates existence, current selection, and `rebirthRequirement`; `_applyRoute` rebuilds the runway, resets runner timing, rebuilds gates.
- Auto-advance: `_watchRebirths` reacts to rebirths and moves players to the new best route only if they were on the previous best (`GetBestRoute`, fallback route 1).
- Runway models live in `ReplicatedStorage.Assets.Runways.Runway<id>`; each route's gate count must cover its `gateCap` attachments.

## Rebirth

`RebirthService` (`src/services/rebirthService/Server.luau`) + `Utils.luau`:

- Requirement: `calculateCashRequirement(rebirths + 1)` — `1,000 / 10,000 / 100,000 / 500,000 / 2,000,000 / 10,000,000` for levels 1–6, then `10,000,000 * 1.45^(level-6)`.
- On success: `cash = 0`, upgrades and extra gates reset, `rebirths += 1`, `cashMultiplier = 1 + 0.05 * rebirths`, and `runnerSpawnLevel += 1` when the new rebirth count is even and ≤ 80. Runners, inventory, index, and `runnerPurchases` are kept.
- `auto_buy_first_gate` (ConfigService A/B flag) re-grants the free first gate after the wipe.
- `skipRebirth` product grants the same rebirth/multiplier/spawn-level rewards with **no wipe**; it does not run the A/B grant.
- The spawn-level +1 rule is duplicated in `RebirthService.Server`, `ProductServerCallbacks`, `RebirthMenu` (display), and the Python simulator — update all four.

## Group reward

`Plot.giveGroupReward`: group `113923204`, once per save: `+0.05` customMultiplier, `$15,000`, runner level 4. The runner grant increments `runnerPurchases` (by design — free runners raise prices).

## Balance tooling (`tools/`, `balance/`)

A Python Monte-Carlo economy simulator used to tune balance without Studio:

```powershell
pip install -r requirements.txt
python -m tools.run_balance                # full run: 10k runs, 7-day horizon
python -m tools.run_balance --quick        # fast run
python -m tools.run_balance --skip-optimizer
python -m tools.run_balance --output balance/balance-13-08-26/balance_results
```

- `tools/economy_config.py` mirrors route/trail/crate/behavior tables from Luau; `tools/economy_simulator.py` models the loop; `tools/balance_analysis.py` scores results; `tools/balance_optimizer.py` searches parameter overlays; `tools/run_balance.py` is the CLI.
- Output: `balance_report.md` (in the output directory's parent) plus JSON/CSV and 16 PNGs.
- `balance/balance-13-08-26/` is a dated snapshot; its `balance_results/routes.json` predates the current route multipliers (report says 1.75–2.50 for routes 4–7, code says 2.09–3.82). Treat the report as historical.

> [!WARNING]
> The simulator re-implements the economy and is already out of sync with the runtime in several places (upgrade base costs/growth, rebirth growth, route requirements, runner price growth). Re-derive formulas from the Luau files before trusting new results, and update both copies when balance changes.

## Gotchas

- Three copies of the income formula exist (server payout, client indicator, offline). Keep them in sync.
- Gates have two caps from two sources: `cashGateCap` (upgrades, server enforced) and `gateCap` (total, extra gates).
- Rebirth wipes cash entirely (not just the cost) and resets upgrades; skip-rebirth is strictly premium.
- `runnerPurchases` is bumped by free grants; decide explicitly for any new grant path.
- `index` keys are strings; `hasUnlockedRunner` and UI depend on it.
- Exclusive ids start at `ID_BASE = 1000`; never compare to `ID_BASE` directly — use `ExclusiveCars.isExclusive`.
- Trail duplicates accumulate with no sink; `selectedTrail` is optional.
- After adding/renaming item files, run `npm run build:rojo` so require paths match generated names.

## Related

- [Runner simulation](runner-simulation.md)
- [Crates and stock](crates-and-stock.md)
- [Monetization](monetization.md)
- [Changing game balance guide](../guides/changing-game-balance.md)
