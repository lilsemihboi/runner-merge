# Player Data

All persistent player state lives in one profile store, defined by `src/modules/game/DataTemplate.luau` and managed through `DataService` (leifstout/dataservice) plus the `ProfileServer` wrapper.

> [!IMPORTANT]
> `DataTemplate` is a persistence schema. Only **add** fields with safe defaults. Renaming or removing a field orphans saved data; the join-time reconciler never deletes or migrates keys. See [Migrations](#migrations).

## DataService basics

`DataService:init` is called first in both entrypoints:

```lua
DataService:init({
	resetData = false,
	useMock = false,
	template = DataTemplate,
	profileStoreIndex = RunService:IsStudio() and "__test__" or "__production__",
})
```

| API | Use |
| --- | --- |
| `DataService:get(player, path)` | Read a value (`"cash"` or `{ "upgrades", "gates" }`) |
| `DataService:set(player, path, value)` | Replace a value |
| `DataService:update(player, path, fn)` | Transform a value |
| `DataService:arrayInsert(player, path, value, index?)` / `arrayRemove(player, path, index?)` | Array edits that emit insert/removed signals |
| `DataService:getChangedSignal(player, path)` | Fires with `(newValue, oldValue)` on changes |
| `DataService:getArrayInsertedSignal(player, path)` / `getArrayRemovedSignal` | Array-specific signals (used by `RunnerService`, `Plot._watchRunners`) |
| `DataService:waitForData(player)` | Yields until the profile is loaded |
| `DataService:hasProfile(player)` | Non-yielding profile existence check |
| `DataService:onPlayerInit(fn)` | Hook fired after data load (used by `profileService` to reconcile) |
| `DataService:addPlayerRemovingCallback(fn)` | Runs before save on leave (stats, cleanup) |
| `DataService:sendGlobalMessage(key, userId, data)` / `addGlobalCallback(key, fn)` | Cross-server messaging (gifts) |

Paths are either a string for top-level fields or an array for nested fields. Keys prefixed with `__` (monetization) or `_` (codes) are written dynamically and are **not** in `DataTemplate`.

## DataTemplate fields

| Field | Default | Written by |
| --- | --- | --- |
| `cash` | `0` | `Profile.giveCash` (income, rewards, purchases, refunds) |
| `cashMultiplier` | `1` | Rebirth (`Profile.setMultiplier`) |
| `customMultiplier` | `1` | Starter pack `+0.2`, group reward `+0.05` (`Profile.addCustomMultiplier`) |
| `selectedRoute` | `1` | `RouteService` via `Profile.setRoute` |
| `spins` | `0` | Spin products (`Profile.addSpin`); no consumer yet |
| `isGroupRewardClaimed` | `false` | `Plot.giveGroupReward` |
| `rebirths` | `0` | `Profile.giveRebirth` |
| `runnerPurchases` | `0` | `Profile.giveRunner` (+amount); price index for batch pricing |
| `runners` | `{}` | One `{ id, level, phase }` entry per owned car; `Profile.giveRunner`/`giveExclusiveRunner` append, merges rewrite. Migrated on load from the old bare-level array (`id` = position in the compacted array, `phase = (position − 1) / count`; ids offset above existing entries in a mixed save) |
| `nextRunnerId` | `0` | Monotonic id counter (`Profile.allocateRunnerId`); ids are never reused |
| `runnerSpawnLevel` | `1` | `Profile.giveSpawnLevel` (even rebirths ≤ 80) |
| `index` | `{}` | `index[tostring(level)] = true` on first unlock (regular and exclusive ids) |
| `inventory` | `{}` | `Profile.giveTrail` (array; duplicates are copies) |
| `selectedTrail` | `nil` | `Profile.selectTrail` |
| `luckyBlockInQueue` | `1` | `Profile.setCrateInQueue` (next crate id) |
| `lapsLeftToAcquire` | `Blocks.getBlock(1).lapsRequirement` = `5` | `setCrateInQueue`, `RunnerService._spendLaps` |
| `autoCrateOpen` | `false` | Auto-roll gamepass purchase/toggle |
| `offlineEarnings` | `nil` | `OfflineEarnings._create`; cleared on claim/logout |
| `offlineEarningsPaid` | `nil` (not in the default table) | Offline claim flow |
| `offlineEarningsDoubled` | `nil` (not in the default table) | `doubleOfflineEarnings` product |
| `upgrades.gates` | `0` | `Plot.upgrade`; reset on rebirth |
| `upgrades.runnerSpeed` | `0` | `Plot.upgrade`; reset on rebirth |
| `upgrades.cashBonus` | `0` | `Plot.upgrade`; reset on rebirth |
| `extraGates` | `0` | VIP extra-gate upgrade/product; reset on rebirth |
| `tutorial.step` | `1` | `Profile.stepTutorial` |
| `tutorial.finished` | `false` | `Profile.finishTutorial` |
| `stats.timePlayed` | `0` | Player-removing callback adds session seconds |
| `stats.totalCashEarned` | `0` | `Profile.giveCash` (positive amounts only) |
| `stats.lastLogoutTime` | absent (optional) | Player-removing callback (`os.time()`) |
| `settings.sounds` / `settings.music` | `100` | Settings service (0–100) |
| `settings.trails` / `settings.moneyIndicator` | `true` | Settings service (booleans) |

## ProfileServer API

`src/classes/profile/Server.luau` is the only sanctioned way services mutate player data. It wraps `DataService` and keeps derived values consistent.

Getters: `getCash`, `getRebirths`, `getRunners`, `getUpgradeLevel`, `getRoute`, `getExtraGateCount`, `getActiveGateCount`, `getCrateInQueue`, `getLapsLeftToAcquire`, `getSelectedTrail`, `hasTrail`, `hasUnlockedRunner`, `getTutorialStep`, `getIsTutorialFinished`.

Mutators: `giveCash`, `addSpin`, `resetCash`, `resetUpgrades`, `giveRebirth`, `setMultiplier`, `setRoute`, `addCustomMultiplier`, `setExtraGateCount`, `setCrateInQueue`, `giveSpawnLevel`, `giveTrail`, `selectTrail`, `giveRunner`, `giveExclusiveRunner`, `giveUpgrade`, `stepTutorial`, `finishTutorial`.

Notes:

- `giveCash` updates `stats.totalCashEarned` only for positive amounts.
- `giveRunner` increments `runnerPurchases`, marks `index`, and inserts spawn-level entries (`createRunnerEntry`: fresh `nextRunnerId`, phase at the widest gap); `giveExclusiveRunner` deliberately does **not** touch `runnerPurchases`.
- `setCrateInQueue` writes `lapsLeftToAcquire` **before** `luckyBlockInQueue` so the client never briefly pairs a new crate with the old spent lap count.
- `getActiveGateCount` only counts extra gates once cash gates are maxed; see [`economy.md`](economy.md).
- New mutators should follow the same shape: validate → `DataService` write → keep derived state (multipliers, index) consistent.

## ProfileService lifecycle

`src/services/profileService/Server.luau`:

- `init` creates profiles for players already in the server and on `PlayerAdded`.
- `ProfileServer.new(player)` waits for data; failures warn.
- `getProfile(player)` returns immediately if cached, otherwise waits on a `profileCreationSignal` until that player's profile exists. It can yield — call it from server code that can wait.
- `initLeaderstats` builds the `leaderstats` folder (`Cash`, `Rebirths` StringValues) and keeps them updated from change signals.
- `DataService:onPlayerInit` recursively reconciles missing keys from `DataTemplate` (clones tables for table defaults). It does **not** recompute derived values: e.g. if `cashMultiplier` is missing on an old save it is set to `1`, not to `1 + 0.05 * rebirths`.
- `addPlayerRemovingCallback` updates `stats.lastLogoutTime`/`stats.timePlayed` and clears offline-earnings keys; profiles are removed from the cache.

## ServicePlayerData

`ServicePlayerData` (leifstout/serviceplayerdata) stores **ephemeral** per-service, per-player state that should not persist. Examples in this repo:

| Service | Slot |
| --- | --- |
| `codeService` | `{ redeeming = false }` |
| `friendService` | `{ friendsInServer = 0 }` |
| `monetizationService` | `{ giftingTo = nil }` |
| `plotService` | `{ plot = nil }` |

Use it for locks, in-flight flags, and session counters. Use the profile for anything the player should keep.

## Migrations

- Adding a field: add it to `DataSchema` and the default table in `DataTemplate.luau`. Existing players get the default on join.
- Optional fields (`number?`): keep them out of the defaults if `nil` has meaning (`offlineEarnings*`, `lastLogoutTime`).
- Renaming/removing: don't. Add the new field and stop reading the old one; the reconciler will never delete saved keys.
- Counting fields must be explicit about semantics. `runnerPurchases` is a price index, not a purchase counter, and every runner grant path (including free ones) increments it. `index` keys are strings, including exclusive ids like `"1001"`.
- Run data-affecting changes against the Studio `__test__` store (`profileStoreIndex`), never assume production data exists in Studio.

## Gotchas

- Reading `DataService` at module scope can deadlock before `DataService:init()`; do it in `task.spawn` (see `TutorialSlice.luau`).
- `DataService:get` on an offline/nonexistent player errors or yields depending on call; guard with `hasProfile`/`waitForData` where relevant.
- Dynamic keys (`__gamepasses`, `__oneTimePurchases`, `__purchaseCooldowns`, `__processedPurchases`, `_codes`) are part of the persisted contract even though they are not in `DataTemplate`. Never rename them.
- The reconciler runs `table.clone` on missing table defaults, but existing tables are merged recursively — keep defaults type-compatible.

## Related

- [Economy](economy.md)
- [Monetization](monetization.md)
- [Services catalog](../services/catalog.md)
