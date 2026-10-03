# Services Catalog

Every service under `src/services/`, its Networker contract, and the player data it touches. Networker semantics: `fetch` → server method (returns a value), `fire` → server method (no result), `fireAll`/`fire(player, …)` → client method with the same name, `set(player, key, value)` → writes a client module field. Server methods receive `player` as the first argument. `networker:dispatch` is not used in this repo.

> Reminder: instance names are generated (`src/services/stockService/Server.luau` → `ServerScriptService.Services.StockService.StockServiceServer`). Folder names in this table are source folders; the "Networker id" column is the runtime channel name and sometimes differs.

| Service | Files | Server id | Client id | Client-callable (server method) | Server → client | Player data keys | Dependencies / notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `analyticsService` | `Server`, `Client`, `Markers`, `OnboardingFunnel` | `AnalyticsService` | `AnalyticsService` | fire `logOnboardingStep`, `logStoreOpened`, `logProductViewed`, `logPurchaseStarted`, `logPurchaseDeclined` | — | reads tutorial/runners/upgrades/stats/rebirths/cash/route | Gamebeast SDK, Roblox `AnalyticsService`; validates + throttles all client events |
| `autoRejoinService` | `Server`, `Client` | `AutoRejoinService` | `AutoRejoinService` | fire `autoRejoin` | — | — | `SafeTeleport`; no-ops in Studio |
| `blockService` | `Server`, `Client` | `BlockService` | `BlockService` | fetch `openCrate`, `openAutoCrate`, `getAutoRollState`, `toggleAutoRoll` | fire `updateAutoRollState`, `beginPurchasedRolls`; fireAll `announceDrop` | `luckyBlockInQueue`, `lapsLeftToAcquire`, `autoCrateOpen`, `inventory`, `selectedTrail` | Monetization (gamepass), Profile, GeneralNotifications, Blocks/Trails |
| `codeService` | `Server`, `Client`, `ServerCallbacks`, `Utils` | `CodeService` | `CodeService` | fetch `redeem` | — | `_codes` (not in template); ServicePlayerData `redeeming` | Own DataStore `Codes`; callbacks injected via `init(ServerCallbacks)` |
| `friendService` | `Server`, `Client` | `FriendService` | `FriendService` | fetch `getFriendCount` | fire `setFriendCount` | ServicePlayerData `friendsInServer` | Income friend multiplier |
| `generalNotificationsService` | `Server`, `Client` | **`UtilitiesService`** | **`UtilitiesService`** | — | fire `displayNotification` | — | Name differs from folder |
| `inventoryService` | `Server`, `Client` | `InventoryService` | `InventoryService` | fetch `selectTrail` | — | `selectedTrail`, `inventory` | Trail selection UI |
| `leaderboardService` | `Server`, `Client`, `Utils`, `LeaderboardSlice`, `LeaderboardUI` | `LeaderboardService` | `LeaderboardService` | fetch `getLeaderboards` | fireAll `leaderboardUpdated` | reads `stats.totalCashEarned`, `rebirths`, `stats.timePlayed` | 3 OrderedDataStores with `__test__`/`__production__` prefix |
| `monetizationService` | `Server`, `Client`, `Utils`, `Modules/Products`, `Modules/ProductServerCallbacks`, `Hooks/useProduct`, `Hooks/useGamepass` | `MonetizationService` | `MonetizationService` | fetch `promptGift` | fire `_receivedGift` | `__gamepasses`, `__oneTimePurchases`, `__purchaseCooldowns`, `__giftReceiver`, `__processedPurchases` (dynamic); ServicePlayerData `giftingTo` | Stock, Analytics, Sound, GeneralNotifications, BlockService callbacks; Discord proxy |
| `notificationService` | `Server`, `Client` | `NotificationService` | `NotificationService` | — | fire `serverNotification` | — | Used by code callbacks |
| `offlineEarningsService` | `Server`, `Client`, `Utils`, `OfflineEarningsSlice` | **`OfflineEarnings`** | **`OfflineEarnings`** | fetch `requestBegin`, `requestClaim` | — | `offlineEarnings*`, `stats.lastLogoutTime`, multipliers | Monetization (double product), Plot, Profile |
| `plotService` | `Server`, `Client`, `Types` | `PlotService` | `PlotService` | — | fire `initPlot` | ServicePlayerData `plot` | Creates `PlotServer` per player; `PlotServiceClient.destroyPlot` exists but is never fired |
| `profileService` | `Server` | — (no Networker) | — | — | — | reconciler + `stats`, leaderstats | Server-only data layer |
| `rebirthService` | `Server`, `Client`, `Utils` | `RebirthService` | `RebirthService` | fetch `rebirth` | — | `cash`, `upgrades.*`, `extraGates`, `rebirths`, `cashMultiplier`, `runnerSpawnLevel` | ConfigService A/B flag; route watcher reacts to rebirths |
| `rewardedAdService` | `Server`, `Client` | `RewardedAdService` | `RewardedAdService` | fetch `playAd`, `hasClaimedRewardThisSession` | — | — | AdService + `adHeartCrate` product; one claim per session |
| `routeService` | `Server`, `Client`, `Utils`, `GetBestRoute` | `RouteService` | `RouteService` | fetch `selectRoute` | — | `selectedRoute`, `rebirths` signal | Plot (runway/gates), RunnerService reset |
| `runnerService` | `Server`, `Types` (client half: `classes/runner/RunnerManager`) | `RunnerService` | `RunnerService` (registered by `RunnerManager`) | fetch `requestState`, `requestPlot`; fire `reportGate`, `reportLap` | fireAll `setRunners`, `applyRunnerDelta`, `removePlot`, `playMergeEffect`; set `vipMultiplier`, `doubleCashMultiplier` | reads runners/gates/route/trail/multipliers; writes `lapsLeftToAcquire` | Friend, Monetization, Profile; determinism contract; diff-based broadcasts with revision-chained deltas |
| `settingsService` | `Server`, `Client`, `Utils`, `SettingsInitializer`, `Hooks/useSetting` | `SettingsService` | `SettingsService` | fire `set` | — | `settings.*` (sounds/music 0–100, trails/moneyIndicator boolean) | Validators in Utils |
| `soundService` | `Server`, `Client`, `CarEngineInitializer` | **`SFXService`** | **`SFXService`** | — | fire/fireAll `play` | — | Name differs from folder; client refuses to restart looped sounds |
| `stockService` | `Server`, `Client`, `Utils`, `StockSlice`, `Hooks/useStock` | `StockService` | `StockService` | fetch `getStocks` | fireAll `stockChanged` | — | DataStore `(prefix)Stock_v1` key `GlobalStock`; consumed by monetization prompts |
| `titleService` | `Server`, `Client`, `Utils` | — (no Networker) | — | — | `player:SetAttribute("TitleId", …)` | — | VIP/group titles |
| `tutorialService` | `Server`, `Client` | `TutorialService` | `TutorialService` | fire `saveStage`, `finishTutorial` | — | writes `tutorial.step` / `tutorial.finished` via `ProfileServer` | Emits `tutorialStarted`/`tutorialStep`/`tutorialFinished`; client (`TutorialRoot`) drives step detection |

## Class networkers

| Class | Id | Endpoints | Notes |
| --- | --- | --- | --- |
| `src/classes/plot/Server.luau` | `plot_{player.UserId}` | `merge`, `upgrade`, `addRunner`, `teleportToBase`, `giveGroupReward`, `upgradeGatesWithPass` | `addRecipient(player)`; every method asserts ownership; `addRunner` bans invalid amounts |
| `src/classes/plot/Client.luau` | `plot_{player.UserId}` | same (fetch/fire) | Destroyed with the plot |
| `src/classes/runner/RunnerManager.luau` | `RunnerService` | `requestState`, `requestPlot`, `reportGate`, `reportLap` | Client half of `runnerService` |

No other class creates a Networker; `GateServer`, `ProfileServer`, `RunnerClient`, `PathData`, `MergeEffects`, `RunnerUtils` are plain modules.

## Initialization matrix

**Server direct** (`src/library/Server.server.luau`): `DataService` → `StockService` → `MonetizationService` (+ `productProcessed` wiring) → `ProfileService` → `InventoryService` → `BlockService` → `CodeService` → `FriendService` → `RewardedAdService` → `RunnerService` → `PlotService` → `RouteService` → `OfflineEarningsService` → `RebirthService`.

**Server optional** (`initializeOptionalFeature`): `AnalyticsService` (first, special), `LeaderboardService`, `AutoRejoinService`, `NotificationService`, `SoundService`, `SettingsService`, `TutorialService`, `TitleService`, `GeneralNotificationsService`.

**Client direct**: `DataService` → `AnalyticsServiceClient` (bespoke wrapper) → `InventoryServiceClient` → `BlockServiceClient` → `StockServiceClient` → `MonetizationServiceClient` → `OfflineEarningsServiceClient` → `PlotServiceClient` → `RouteServiceClient` → `RebirthServiceClient` → `FriendServiceClient` → `RewardedAdServiceClient` → `RunnerManager.new()` → `MountUI()`.

**Client optional**: `CodeService`, `SoundService`, `NotificationService`, `LeaderboardService`, `AutoRejoinService`, `Feedback`, `SettingsService` + `SettingsInitializer`, music, `CarEngineInitializer`, `TitleService`, `TutorialService`, `GeneralNotificationsService`.

## Data keys outside `DataTemplate`

Persisted but written dynamically — never rename:

- `_codes` (codes a player has redeemed).
- `__gamepasses`, `__oneTimePurchases`, `__purchaseCooldowns`, `__processedPurchases`, `__giftReceiver` (monetization).

## ServicePlayerData slots

`codeService` `{ redeeming }`, `friendService` `{ friendsInServer }`, `monetizationService` `{ giftingTo }`, `plotService` `{ plot }`.

## Unusual contracts worth remembering

- **Name mismatches:** `soundService → "SFXService"`, `generalNotificationsService → "UtilitiesService"`, `offlineEarningsService → "OfflineEarnings"`.
- **Per-player fan-out:** `plot_{UserId}` (owner only), `monetizationService._receivedGift`, `generalNotificationsService.displayNotification`, `notificationService.serverNotification`, `plotService.initPlot`.
- **Broadcast:** `runnerService.setRunners/applyRunnerDelta/removePlot/playMergeEffect`, `stockService.stockChanged`, `leaderboardService.leaderboardUpdated`, `blockService.announceDrop`.
- **Non-standard transport:** `titleService` uses a player attribute; `profileService` has no networking at all.
- **Input hardening:** `runnerService` and `plotService`/`Plot` validate everything; `analyticsService` throttles; `settingsService` asserts valid paths; `leaderboardService` asserts DataStore success.

## Related

- [Architecture overview](../architecture/overview.md)
- [Adding a service guide](../guides/adding-a-service.md)
- [Adding a network endpoint guide](../guides/adding-a-network-endpoint.md)
