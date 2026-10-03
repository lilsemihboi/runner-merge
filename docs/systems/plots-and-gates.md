# Plots and Gates

## Overview

A **plot** is the per-player base. `PlotService` (`src/services/plotService/Server.luau`) claims one `workspace._PLOTS.<plotId>` model per joining player, then `PlotServer` (`src/classes/plot/Server.luau`) turns it into a playable base; `PlotClient` (`src/classes/plot/Client.luau`) builds the interactive client UI on top.

| Piece | File | Realm |
| --- | --- | --- |
| Claim/lifecycle service | `src/services/plotService/Server.luau` | Server |
| Plot server object | `src/classes/plot/Server.luau` | Server |
| Plot client UI | `src/classes/plot/Client.luau` | Client |
| Gate model placement | `src/classes/gate/Server.luau` | Server |
| Types | `src/services/plotService/Types.luau` | Shared |

## Lifecycle

1. `PlotService.init` creates `Networker.server.new("PlotService", self)` and a `ServicePlayerData` slot `{ plot = nil }`.
2. On `playerAdded` (`ServicePlayerData` callback, wired automatically): `_claimPlot` picks the first unclaimed `Model` in `workspace._PLOTS` and marks it claimed. No plot → `player:Kick("Failed to claim plot!")`.
3. `PlotServer.new(player, plotId)` runs. It is wrapped in `xpcall`; on failure the plot is destroyed and the error re-thrown. It then fires `initPlot` with `{ player, plotId }`.
4. `PlotClient.new(plotData)` builds all client-side visuals and interactions when the local player's `initPlot` arrives.
5. On `playerRemoving`: `plot:destroy()`, release the claimed plot, fire `destroyPlot`, clear `self.plots[player]`.

`PlotServer` is defensive about players leaving mid-creation: `assert(player.Parent == Players, …)` inside the setup, guarded `pcall`s in `destroy`, and a `_isDestroyed` idempotency flag.

## PlotServer

Created with a **per-player** networker: `` Networker.server.new(`plot_{player.UserId}`, self, { … }) `` plus `networker:addRecipient(player)`. Every endpoint starts with `assert(player == self.player, "You dont own the base!")`.

| Endpoint | Kind | Effect |
| --- | --- | --- |
| `upgrade(upgradeId)` | fetch | Validates id/cap/cash, charges, `profile:giveUpgrade` |
| `addRunner(runnerAmount)` | fetch | Validates `1, 5, 25, 50` (other values trigger a universe-wide `Players:BanAsync`), charges batch price, grants spawn-level runners |
| `merge()` | fire | Runs the merge cascade; auto-merge also triggers at 20 runners |
| `teleportToBase()` | fire | Teleports the character to `plotModel.Spawn` |
| `giveGroupReward()` | fetch | Group-join gate (group `113923204`), once per save: `+0.05` customMultiplier, `$15,000`, runner level 4 |
| `upgradeGatesWithPass()` | fetch | VIP + maxed cash gates → `+1` extra gate |

Setup work:

- `_setupStreaming`: makes the plot and every descendant `PersistentPerPlayer` so vehicles/geometry stream for the owner (`_removePersistentPlayer` on destroy).
- `_TEMP` folder: container for client-spawned models/effects (cloned by `RunnerClient`/`MergeEffects`).
- `setupSign`: player portrait + name on `Sign.PlayerTable.SurfaceGui`.
- `buildRunway(routeId)`: clones `ReplicatedStorage.Assets.Runways.Runway<routeId>`, names it `Runway`, pivots to `plotModel.RouteSpawn`, and janitor-keys it as `"runway"` so route changes replace it.
- `buildCrate(crateId)`: clones `ReplicatedStorage.Assets.Blocks.<crateId>`, scales by `CRATE_SCALE = 0.649`, pivots to `plotModel.LuckyBlock.CrateSpawn`. `_watchCrate` rebuilds it when `luckyBlockInQueue` changes (client hides crate UI on other players' plots).
- `_checkForGates` / `rebuildAllGates`: create `GateServer` objects for `1..getActiveGateCount()`; gates beyond the route's `cashGateCap` use the exclusive template. Rebuilds on `upgrades.gates`/`extraGates` changes and after route changes.
- `_watchRunners`: inserts trigger auto-merge at 20 runners.
- `_watchRunnerSpawnLevel`: bumps runners below the new spawn level (merge → flatten → merge).
- Group reward / merge analytics: `Markers.runnerMerged` once per cascade.

### Merging (server logic)

`Plot.merge`:

1. Collect numeric levels with their original `runnerIndex` (sources).
2. Sort ascending; repeatedly pair equal levels into `level + 1` until stable. Each pairing becomes a `MergeOperation` with `leftSource`/`rightSource`, supporting cascades (a result can feed the next merge).
3. Exclusive cars are skipped (`ExclusiveCars.isExclusive`), including duplicates.
4. Rewrite the `runners` array; register newly reached levels in `index`.
5. `RunnerServiceServer:beginMergeEffect` → `playMergeEffect`; the effect duration is computed from the operation DAG and broadcasts resume after it.

### Runner purchases (server logic)

`Plot.addRunner` accepts only `1`, `5`, `25`, `50`; anything else is treated as an exploit and permanently bans the account (`Players:BanAsync`, `Duration = -1`). Cost comes from `Runners.calculateRunnerBatchPrice(runnerPurchases, amount)`; runners are granted at `runnerSpawnLevel`. `runnerPurchases` increments for every grant path (shop, codes, starter pack, car bundle, group reward), so free grants also raise future prices; exclusive cars are the only exception.

## Client plot UI

`PlotClient` (`src/classes/plot/Client.luau`) owns all interactive world UI for the local player's base:

| Area | Function | Watches |
| --- | --- | --- |
| Upgrade board prices/inputs | `setupUpgradeBoard`, `_updateUpgradeButtonPrices` | `upgrades.*`, `selectedRoute`, cash |
| Crates / lap progress / prompt | `setupBlocks`, `_hideCrateUIOnOtherPlots` | `luckyBlockInQueue`, `lapsLeftToAcquire`, `CratesSlice` |
| Route selection pad | `setupRoutes` | `selectedRoute` |
| Group chest | `setupGroupRewardsChest`, `claimGroupRewards` | `isGroupRewardClaimed` |
| Starter pack stand | `setupStarterPack` | ownership/one-time state |
| Limited car storefront | `setupLimitedCar` | `StockSlice` (`useStock`), torn down at 0 |
| Runner/merge buttons | `setupButtons`, `_registerRunnerButton`, `_updateRunnerButtonPrices`, `_updateMergeButtonState` | cash, runners, tutorial stage |
| Teleport button | `teleportToBase` | — |

Client checks are UX only. Every action is re-validated server-side (`upgrade`, `addRunner`, `merge`, …). Tutorial gating hides plot buttons until the relevant stage (see [`tutorial.md`](tutorial.md)).

## Scene structure (place-managed)

`workspace._PLOTS.<plotId>` models are authored in the place. The names below are relied on by code:

| Path | Used by |
| --- | --- |
| `Spawn`, `RouteSpawn`, `RoutesSpawn`, `GroupChestSpawn`, `StarterPackSpawn`, `LimitedCarSpawn` (Attachments) | Teleports, runway/crate/stand pivots |
| `Sign.PlayerTable.SurfaceGui.Frame` | `Plot.setupSign` |
| `UpgradeTable.UpgradeTable.UpgradePart` (+ `SurfaceGui.Frame.gates`) | Upgrade board; tutorial stage 1 |
| `Buttons.Merge.Merge`, `Buttons.Runner.<n>` (Models with `ButtonTrigger`) | Merge/runner buttons; tutorial stages 2/4/5 |
| `LuckyBlock.CrateSpawn`, `LuckyBlock.Billboard` | Crate placement/UI; tutorial stage 7 |
| `Decoration` | Cosmetic only |

Gate and crate **models** come from `ReplicatedStorage.Assets.Gates` and `ReplicatedStorage.Assets.Blocks`; runner models from `ReplicatedStorage.Assets.Entities`. None of these are in Git.

## Gotchas

- The claimed plot model name is the plot id (`"1"`…`"6"`, `Configuration.PLOT_COUNT = 6`); `_claimPlot` accepts any Model, so adding/removing plot models in the place changes capacity.
- `plotModel` is the source of truth for positions; renaming children breaks code silently. Grep the child name before renaming anything.
- Gate attachments must exist under `Runway.gateAttachments.<gateId>` BEFORE `GateServer.placeGate` runs; gates created for a missing attachment are skipped.
- `buildRunway` janitor-keys the model as `"runway"`; the old model is destroyed by `Janitor:Remove("runway")`, not by direct `Destroy` — keep that pattern.
- `Plot.destroy` must stay idempotent; it runs on error paths (xpcall) and on player removal.
- Streaming: plot descendants are made `PersistentPerPlayer`. If you add models at runtime, `_setupStreaming`'s `DescendantAdded` hook picks them up — don't move runtime content outside `_PLOTS`.
- Client UI mounts only for the local owner's plot; other plots are simulation-only.

## Related

- [Runner simulation](runner-simulation.md)
- [Economy](economy.md) — upgrade costs and routes
- [Crates and stock](crates-and-stock.md)
- [UI](ui.md)
