# Changing Game Balance

Balance numbers live in Luau files (runtime) and are mirrored in the Python simulator (`tools/`). A change is only complete when all copies agree.

## Where the numbers live

| Number | File |
| --- | --- |
| Runner income/speed | `src/classes/runner/Utils.luau` |
| Upgrade costs/caps/effects | `src/modules/items/UpgradeUtils.luau` |
| Runner purchase prices | `src/modules/items/Runners.luau` |
| Trail multipliers/loot weights | `src/modules/items/Trails.luau`, `src/modules/items/Blocks.luau` |
| Route caps/multipliers/requirements | `src/services/routeService/Utils.luau` |
| Rebirth costs/multiplier/spawn rule | `src/services/rebirthService/Utils.luau` (+ `RebirthService.Server`, `ProductServerCallbacks`, `RebirthMenu` for the spawn rule) |
| Product effects (cash packs, starter, gates) | `src/services/monetizationService/modules/ProductServerCallbacks.luau` |
| Analytics/offline constants | `src/services/offlineEarningsService/Server.luau` |
| Simulator mirrors | `tools/economy_config.py`, `tools/economy_simulator.py` |

## Things that must stay in sync

1. **Income formula exists in three places**: server payout (`RunnerService.reportGate`), client display (`RunnerManager._showIncomeIndicator`), offline earnings (`OfflineEarningsService`). Offline intentionally omits friends/x2 Cash/x2 Speed and applies ×0.7.
2. **Upgrade cost formula exists in two places**: `UpgradeUtils` and `tools/economy_simulator.py`. The simulator is currently out of date (base costs/growth and rebirth scaling differ) — fix it while you're there.
3. **Rebirth spawn-level rule (`even` and `≤ 80`) exists in four places**: `RebirthService.Server`, `ProductServerCallbacks`, `RebirthMenu` (display), and the simulator.
4. **Route numbers exist in two places**: `RouteServiceUtils` and `tools/economy_config.py`.
5. **Trails/crates exist in two places**: the Luau modules and `tools/economy_config.py`.
6. **Exclusive car stats exist in two places**: `ExclusiveCars.luau` and constants in `tools/economy_simulator.py`.

## Workflow

1. **Decide the target metric first.** The simulator scores route unlock time, endgame time, wealth distribution, and pay-to-win. State which one the change should move.
2. Change the Luau source.
3. Mirror the change in `tools/economy_config.py` / `tools/economy_simulator.py`.
4. Run the simulator and sanity-check:
   ```powershell
   pip install -r requirements.txt
   python -m tools.run_balance --quick
   ```
   (Full run: `python -m tools.run_balance`. Output goes to `balance_results` by default; the report lands next to the output folder.)
5. Test in Studio:
   - upgrades cost what the UI says (client prices come from the same functions, so a mismatch means you edited one side only);
   - income matches the floating indicator (server rounds once, floors at 1);
   - rebirth wipe/reset and route auto-advance still work;
   - offline earnings roughly match 70% of equivalent active play.
6. Update docs: [`../systems/economy.md`](../systems/economy.md) tables and any guide quoting values.
7. `stylua src`, `selene src`.

## Notes

- Existing players keep their saved cash/upgrades; balance changes only affect future costs/payouts. There is no migration.
- Data-migration rules live in [`../systems/player-data.md`](../systems/player-data.md).
- Do not add balance constants to `DataTemplate`; the template is persistence, not tuning.
- The checked-in `balance/` report is a historical snapshot. Re-run rather than quote it.
