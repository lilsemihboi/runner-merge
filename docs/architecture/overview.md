# Architecture Overview

Merge Cars is a merge-runner tycoon. The design has three load-bearing ideas:

1. **The server owns the economy.** Cash, upgrades, runners, trails, purchases, and wins are only ever written by server code. Clients send intents; the server validates them.
2. **Clients own runner visuals.** There is no server `Heartbeat`, no physics replication, and no per-car networking. The server broadcasts a plot snapshot; every client simulates every active plot locally from a shared clock. The server validates reported gate crossings by recomputing the same deterministic math.
3. **State is data-driven and replicated as data.** Player state lives in a single profile (`DataTemplate`), read live by client UI through Charm atoms. Service-to-service communication is direct Lua on the server and `Networker` remotes across the boundary.

## Runtime topology

| Runtime | Source | Generated instance | Role |
| --- | --- | --- | --- |
| Server | `src/library/Server.server.luau` | `ServerScriptService.Server` | Initializes `DataService`, then every service; service modules are required explicitly |
| Client | `src/library/Client.client.luau` | `StarterPlayer.StarterPlayerScripts.Client` | Initializes client halves, starts `RunnerManager`, mounts the UI |

Both entrypoints are `--!nonstrict`; every other module is strict via `.luaurc` (`{"languageMode": "strict"}`).

`src/library/` is excluded from the Rojo tree generator and mapped explicitly. Adding a file under `src/services/<name>/` does **not** wire it into the game — you must require and initialize it in the entrypoints. See [`guides/adding-a-service.md`](../guides/adding-a-service.md).

## Boot sequence

### Server (`src/library/Server.server.luau`)

| Order | Step | Why it is here |
| --- | --- | --- |
| 1 | `DataService:init({ template = DataTemplate, profileStoreIndex = RunService:IsStudio() and "__test__" or "__production__" })` | Everything else assumes player profiles and data signals exist |
| 2 | `initializeOptionalFeature("AnalyticsService", …)` | Must listen for `PlayerAdded` before any other service yields on player setup, and owns the Gamebeast handle others send markers through |
| 3 | `StockServiceServer:init({ products })` | Monetization prompt guards read stock |
| 4 | `MonetizationServiceServer:init({ products })` | Receipts/ownership; product keys are backfilled here |
| 5 | `MonetizationServiceServer.productProcessed:Connect(… StockServiceServer:consumeByProductId)` | Wired in the entrypoint so StockService does not require Monetization back (avoids a cycle) |
| 6 | `ProfileService`, `InventoryService`, `BlockService` | Core player systems |
| 7 | `CodeService:init(ServerCallbacks)`, `FriendService`, `RewardedAdService`, `RunnerService`, `PlotService`, `RouteService`, `OfflineEarningsService`, `RebirthService` | Gameplay/economy services |
| 8 | Optional wrappers: `LeaderboardService`, `AutoRejoinService`, `NotificationService`, `SoundService`, `SettingsService`, `TutorialService`, `TitleService`, `GeneralNotificationsService` | Wrapped in `initializeOptionalFeature` (`task.spawn` + `xpcall`): a failure warns and disables the feature instead of killing startup |

`require(ServerScriptService.Services.MonetizationService.Modules.ProductServerCallbacks)` runs for its side effects (it attaches product callbacks to the shared `Products` table) before any service init.

### Client (`src/library/Client.client.luau`)

| Order | Step | Why it is here |
| --- | --- | --- |
| 1 | `DataService:init()` | All replicated data reads need it |
| 2 | `AnalyticsServiceClient:init()` (bespoke `xpcall` wrapper, not the helper) | Other client code sends markers |
| 3 | `InventoryServiceClient`, `BlockServiceClient` | — |
| 4 | `StockServiceClient:init()` **before** `MonetizationServiceClient:init(Products)` | Monetization cost text reads stock as soon as it initializes |
| 5 | `MonetizationServiceClient`, `OfflineEarningsServiceClient`, `PlotServiceClient`, `RouteServiceClient`, `RebirthServiceClient`, `FriendServiceClient`, `RewardedAdServiceClient` | — |
| 6 | `RunnerManager.new()` | Starts the single client simulation `Heartbeat` |
| 7 | Optional wrappers: `CodeService`, `SoundService`, `NotificationService`, `LeaderboardService`, `AutoRejoinService`, `Feedback`, `SettingsService` (+ `SettingsInitializer()`), music, `CarEngineInitializer`, `TitleService`, `TutorialService` | Failures warn and disable the feature |
| 8 | `MountUI()`; then `GeneralNotificationsServiceClient:init()` | Mounts all UI roots (including `TutorialRoot`) |
| 9 | `MonetizationServiceClient.giftReceived:Connect(...)` | Wires the gift popup into `ShopSlice`/menu |

> [!NOTE]
> `initializeOptionalFeature` runs features through `task.spawn`, so "initialized first" means "started first". Keep the ordering above; several comments in the entrypoints explain why.

## Service pattern

A service is a plain module table with an `init` method. The pattern (see `src/services/codeService/Server.luau` for a compact example):

```lua
function CodeService.init(self: CodeService, rewardCallbacks): ()
	self.rewardCallbacks = rewardCallbacks
	self.networker = Networker.server.new("CodeService", self, { self.redeem })
	self.playerData = ServicePlayerData.new(PLAYER_DATA_TEMPLATE)
end
```

- **Server side:** `Networker.server.new(id, module, clientAccess)` — `clientAccess` lists the server functions clients may call. The player is injected as the first argument.
- **Client side:** `Networker.client.new(id, module)`; call `networker:fetch(name, ...)` for a return value or `networker:fire(name, ...)` for fire-and-forget.
- **Server → client:** `networker:fire(player, name, ...)` or `fireAll(name, ...)` calls the client method with the same name. `networker:set(player, key, value)` writes a field on the client module (no method call) — used for e.g. `vipMultiplier` on `RunnerManager`.
- The id string must match exactly on both sides. It is **not** derived from the folder name: `soundService` uses `"SFXService"`, `generalNotificationsService` uses `"UtilitiesService"`, `offlineEarningsService` uses `"OfflineEarnings"`. See [`services/catalog.md`](../services/catalog.md).
- `Networker` remotes live under `ReplicatedStorage.Packages.Networker._remotes/<id>`.

Service-local rules:

- Ephemeral per-player state (locks, targets, sessions) goes in `ServicePlayerData`, not the profile.
- Connections/instances are tracked with `Janitor` and cleaned on player removal or destroy.
- Cross-service calls are direct `require` + method calls on the server. Avoid requirement cycles (see the Stock↔Monetization wiring above).
- Client services may expose `Signal` objects (e.g. `BlockServiceClient.autoRollStateChanged`) for UI to subscribe to.

### Special cases

| Case | Detail |
| --- | --- |
| `profileService` | Server-only, no Networker. Owns profile lifecycle + leaderstats. |
| `runnerService` | Server-only module; its client half is `src/classes/runner/RunnerManager.luau`, which registers the same `"RunnerService"` id. |
| `titleService` | No Networker. Uses the replicated `player:SetAttribute("TitleId", …)`. |
| `classes/plot` | Creates a per-player networker id `plot_{player.UserId}` with `addRecipient(player)`; server methods all `assert(player == self.player)`. |
| `analyticsService` | Client half forwards untrusted events; server half validates, throttles, dedupes, and fans out to two backends. |

## Packages (Wally)

Declared in `wally.toml`, generated into ignored `Packages/` (`npm run wally-install`, which also emits `sourcemap.json` + package types). Never edit `Packages/`.

| Package | Used for |
| --- | --- |
| `Networker` | Client↔server remotes (`fetch`/`fire`/`fireAll`/`set`) |
| `DataService` | Profile persistence, signals, global messages, array ops |
| `ServicePlayerData` | Ephemeral per-service, per-player state |
| `Janitor` | Connection/instance cleanup |
| `Signal` | Lightweight local events |
| `Promise` | Async retry loops (monetization Discord logging) |
| `Charm` | Reactive atoms bridged from `DataService` signals (`GetDataSource`) |
| `Ripple` | Spring/tween helpers in plot UI |
| `Sift` | Table/array helpers in UI |
| `Topbarplus` | Roblox topbar buttons (`src/ui/Hud/TopBarButtons.luau`) |
| `Vide` | Declarative UI runtime and state sources |
| `VideCharm` | `useAtom`/`useSignalState` bridge from Charm atoms into Vide |
| `GameBeast` | Gamebeast analytics SDK (server) |

`CharmSync` and `VideRipple` are declared in `wally.toml` but have no direct `require` under `src/` as of this writing; do not assume they are wired up.

## Code vs content

| Area | Location | Managed by |
| --- | --- | --- |
| Game code | `src/**/*.luau` | Rojo (`npm run build:rojo`) |
| Wally packages | `Packages/` | Wally (gitignored) |
| Game content | `ReplicatedStorage.Assets`, `workspace._PLOTS`, `ServerStorage` | The place file (`.rbxl`) — **not in Git** |
| Player saves | `DataService` profile store | Roblox DataStores |

Place-managed assets that code depends on by name:

| Instance | Consumers |
| --- | --- |
| `ReplicatedStorage.Assets.Entities.<id>` | Runner models (regular 1–40, exclusive ids ≥ 1000); `RunnerClient`, `MergeEffects` |
| `ReplicatedStorage.Assets.Runways.Runway<routeId>` | `Plot.buildRunway`; contains `waypoints/lane<N>/<n>` attachments and `gateAttachments/<gateId>` |
| `ReplicatedStorage.Assets.Gates.NormalGate` / `ExclusiveGate` | `GateServer.placeGate` |
| `ReplicatedStorage.Assets.Blocks.<crateId>` | `Plot.buildCrate` (crate models) |
| `ReplicatedStorage.Assets.Tutorial.Arrow` | `useArrowNavigator` |
| `ReplicatedStorage.Assets.leaderboardEntry`, `Sample`, `Circles`, `VfxInstance`, `Plot` | UI/effects templates |
| `workspace._PLOTS.<plotId>` | Plot roots claimed by `PlotService` — see [`plots-and-gates.md`](../systems/plots-and-gates.md) |

Renaming or moving any of these breaks code silently; grep before changing.

## Configuration & environment

- `.luaurc`: strict Luau default. The two `src/library` entrypoints opt out with `--!nonstrict`.
- `DataService` profile store: `__test__` in Studio, `__production__` live. `StockService` uses `__test__Stock_v1` / `__production__Stock_v1`.
- `ServerStorage.dotenv` provides environment secrets (not in the repo): `GAMEBEAST_API_KEY` (analytics), `DISCORD_PROXY_URL` + `DISCORD_PROXY_KEY` (purchase logging proxy).
- Studio differences: Roblox analytics funnel events are skipped outside live servers; `SafeTeleport` no-ops in Studio; advertised ad eligibility varies.
- Python economy tooling lives in `tools/` and outputs to `balance/` — see [`economy.md`](../systems/economy.md).

## Related docs

- [Data flow](data-flow.md)
- [Rojo mapping](../reference/rojo-mapping.md)
- [Services catalog](../services/catalog.md)
- [Gotchas](../reference/gotchas.md)
