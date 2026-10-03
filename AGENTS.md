# AGENTS.md

Merge Cars (`lilsemihboi/runner-merge`): a Roblox/Luau merge-runner tycoon. Server-authoritative economy; clients simulate runner visuals deterministically; Vide reactive UI; services wired explicitly in two entrypoints.

Detailed developer documentation lives in [`docs/`](docs/README.md). This file is the short hub: hard rules, commands, architecture summary, and pointers. **Code is the source of truth — if a doc disagrees with code, trust the code and fix the doc.**

> If a nested `AGENTS.md` exists in a folder, it governs that folder (e.g. `AlgoTips/AGENTS.md` is a separate, untracked marketing knowledge base — not code guidance).

## Rules (Read First)

**CRITICAL (YOU MUST):**

- **Read the owning doc before changing a system.** System → doc map:
  - runners / paths / gates / income validation → [`docs/systems/runner-simulation.md`](docs/systems/runner-simulation.md)
  - plots / upgrades / world buttons → [`docs/systems/plots-and-gates.md`](docs/systems/plots-and-gates.md)
  - persistence / `DataService` / profiles → [`docs/systems/player-data.md`](docs/systems/player-data.md)
  - costs, income, trails, routes, rebirth → [`docs/systems/economy.md`](docs/systems/economy.md)
  - crates, lap rewards, stock → [`docs/systems/crates-and-stock.md`](docs/systems/crates-and-stock.md)
  - products, passes, receipts, gifts, ads, offline earnings → [`docs/systems/monetization.md`](docs/systems/monetization.md)
  - onboarding steps / HUD gating → [`docs/systems/tutorial.md`](docs/systems/tutorial.md)
  - markers / funnel → [`docs/systems/analytics.md`](docs/systems/analytics.md)
  - menus / Vide / Charm → [`docs/systems/ui.md`](docs/systems/ui.md)
  - service ids, endpoints, data keys → [`docs/services/catalog.md`](docs/services/catalog.md)
- **Regenerate the Rojo tree after adding/removing/renaming any file under `src/`**: `npm run build:rojo`. `default.project.json` is generated and gitignored; a stale tree means silent require failures. See [`docs/reference/rojo-mapping.md`](docs/reference/rojo-mapping.md).
- **Never edit generated files**: `default.project.json`, `sourcemap.json`, `src/modules/items/assets.luau` (Asphalt output), or anything under `Packages/`.
- **Wire services in the entrypoints.** Creating `src/services/<name>/Server.luau` does nothing until it is required and initialized in `src/library/Server.server.luau` (and the client half in `Client.client.luau`). Respect the documented init order.
- **Keep the runner determinism contract in sync.** Movement math must stay identical across `src/classes/runner/Utils.luau`, `Client.luau`, `RunnerManager.luau`, `src/services/runnerService/Server.luau`, and `PathData.luau`. Change one, change all — or income validation silently breaks.
- **Persisted data is a schema.** Add fields to `src/modules/game/DataTemplate.luau` with safe defaults. Never rename/remove fields; never rename `__gamepasses`, `__oneTimePurchases`, `__purchaseCooldowns`, `__processedPurchases`, `_codes`. See [`docs/systems/player-data.md`](docs/systems/player-data.md).
- **Keep the income formula in sync** across server payout (`RunnerService.reportGate`), client display (`RunnerManager`), offline earnings, and the Python simulator in `tools/`.
- **`const` is a valid 2026 Luau keyword.** Module-scope bindings use `const`; `local` is for reassignable function-local values. Do not "fix" `const` to `local`.
- **No repo test/typecheck scripts exist.** Run `stylua src` and `selene src` after edits; verify behavior manually in Studio.
- **The server is authoritative.** Validate every client argument; never grant items/cash from client signals. Purchase callbacks that grant must be idempotent (Roblox retries receipts). See [`docs/reference/gotchas.md`](docs/reference/gotchas.md).
- **Marker and funnel names are frozen dashboard schema** (`Markers.luau`, `OnboardingFunnel.luau`). Add new names; don't rename shipped ones.
- **Secrets don't live in Git.** `ServerStorage.dotenv` (`GAMEBEAST_API_KEY`, `DISCORD_PROXY_*`) is provisioned in the place.
- **A push is the final product.** Don't commit or push while a task is still in progress; finish and verify the work first, and only then push. A push is not a checkpoint — this applies to docs/AGENTS changes too.

## Common Commands

| Task | Command |
|------|---------|
| Install toolchain (Rojo/StyLua/Selene/Wally/Asphalt) | `rokit install` (fresh machine) |
| Install JS tooling | `npm install` |
| Install Wally packages + types + sourcemap | `npm run wally-install` (needed on fresh checkout) |
| Regenerate Rojo tree | `npm run build:rojo` |
| Continuous Rojo rebuild | `npm run watch:rojo` |
| Format | `stylua src` |
| Lint | `selene src` |
| Generate asset ids from `assets/**` | `asphalt` (rokit-managed) |
| Quick balance simulation | `python -m tools.run_balance --quick` |
| Full balance simulation | `python -m tools.run_balance` |

Tool versions are pinned in `rokit.toml` (Rojo 7.7, StyLua 2.5.2, Selene 0.31.0, Wally 0.3.2, wally-package-types 1.6.2, Asphalt 2.0.1).

## Architecture

Full detail: [`docs/architecture/overview.md`](docs/architecture/overview.md).

- **Source → instance**: `src/services/**` etc. are mapped by `scripts/genRojoTree.js`. Filenames containing `server` go to `ServerScriptService`; everything else to `ReplicatedStorage.Shared`. Folders are PascalCased (`ui` → `UI`, `hooks` → `Hooks`); basenames `Server`/`Client`/`Utils`/`Types` are parent-prefixed (`StockServiceServer`, `RunnerServiceTypes`).
- **Entrypoints**: `src/library/Server.server.luau` → `ServerScriptService.Server`; `src/library/Client.client.luau` → `StarterPlayer.StarterPlayerScripts.Client`. `src/library/` is excluded from the generator.
- **Services**: module table with `init`; `Networker.server.new(id, self, { methods })` + `Networker.client.new(id, self)`. Verbs: client `fetch`/`fire`; server `fire(player, …)`, `fireAll(…)`, `set(player, key, value)`. Ids are exact strings and sometimes differ from folder names (`SFXService`, `UtilitiesService`, `OfflineEarnings`).
- **State**: player state via `DataService` + `ProfileServer`; client UI via Vide sources and Charm atoms (`GetDataSource`); ephemeral per-player state via `ServicePlayerData`.
- **Runner flow**: server broadcasts a plot snapshot (`setRunners`) → each client simulates every active plot in one `Heartbeat` → client reports `reportGate`/`reportLap` → server recomputes deterministic positions and pays.
- **Content boundary**: 3D/UI assets live in the place (`ReplicatedStorage.Assets`, `workspace._PLOTS`), not in `src/`. Code depends on their names.
- **UI**: Vide; menus render via `Menu.Component` and open with `Menu.setOpenedMenu(id)`; always-on screens mount when their module name contains `root`. Overlays hide menus (`hideOpenMenu`), they don't close them.

### Request flow

```text
client intent (fetch/fire)
  → Networker remote → server method (validate, mutate profile)
  → profile data change → DataService signals
  → client atoms/UI update; server broadcast events where needed
```

## Key Files

| File | Role |
|------|------|
| `src/library/Server.server.luau` | Server entrypoint: DataService, service init order, optional-feature wrapper |
| `src/library/Client.client.luau` | Client entrypoint: service init, `RunnerManager.new()`, `MountUI()` |
| `src/classes/runner/RunnerManager.luau` | Client authority for all runner simulation; client half of `RunnerService` |
| `src/classes/runner/Client.luau` | One simulated car: movement, gates, laps, model, trail |
| `src/classes/runner/Utils.luau` | Deterministic income/speed/lane/sanitize formulas |
| `src/services/runnerService/Server.luau` | Snapshot broadcasts, gate/lap validation, income payout |
| `src/classes/plot/Server.luau` | Plot authority: upgrades, merge, runner purchases, runway/crate/gates |
| `src/classes/plot/Client.luau` | Plot world UI (upgrade board, buttons, crate, stands) |
| `src/classes/profile/Server.luau` | `ProfileServer`: all sanctioned player-data reads/writes |
| `src/modules/game/DataTemplate.luau` | Persisted player schema and defaults |
| `src/modules/game/Configuration.luau` | `PLOT_COUNT`, bounds padding, friends-per-tick |
| `src/modules/items/UpgradeUtils.luau` / `Runners.luau` / `Trails.luau` / `Blocks.luau` | Costs, pricing, trail/crate data |
| `src/services/routeService/Utils.luau` | Route caps/multipliers/requirements |
| `src/services/monetizationService/modules/Products.luau` | Product/pass ids and flags |
| `src/services/monetizationService/modules/ProductServerCallbacks.luau` | Purchase grant effects |
| `src/services/stockService/Server.luau` | Global sold-count store + prompt gating |
| `src/services/analyticsService/Markers.luau` / `OnboardingFunnel.luau` | Frozen analytics vocabulary |
| `src/ui/App/RootUI.luau` / `MountUI.luau` | UI mounting (root discovery) |
| `src/ui/App/components/Menu.luau` | Menu lifecycle, hide/restore for overlays |
| `scripts/genRojoTree.js` | Generates `default.project.json` |
| `tools/run_balance.py` | Python economy simulator/report |

## Design Patterns

| Pattern | Key points |
|---------|------------|
| **Service module** | Table + `init(self)`; required/initialized in entrypoints; `Janitor` for cleanup; `ServicePlayerData` for session state |
| **Networker endpoint** | Add method to `Networker.server.new(..., { … })`; client `fetch`/`fire`; server → client `fire`/`fireAll`/`set` |
| **DataService access** | `get`/`set`/`update`/array ops + change signals; prefer `ProfileServer` for player mutations |
| **ProfileServer** | Getter/mutator for every persisted field; keeps derived values (multipliers, index) consistent |
| **Reactive UI** | Vide sources for client state; `GetDataSource` (Charm) for player data; `VideCharm` bridges |
| **Class instances** | `PlotServer`/`PlotClient`, `GateServer`, `RunnerClient`, `ProfileServer`; explicit `destroy` |
| **Determinism** | Shared formulas + roster sanitization + `GetServerTimeNow()`; server re-validates, never trusts |
| **Optional features** | `initializeOptionalFeature(name, fn)` for non-critical services; failures warn and disable |
| **Content by name** | Code looks up place instances by exact names; docs list the contracts |

## Anti-Patterns / Gotchas

- Don't add a server `Heartbeat`, physics, or per-frame work — simulation is client-side by design.
- Don't trust client input anywhere; anti-exploit paths intentionally drop silently (`RunnerService.reportGate`, `Plot.addRunner` bans).
- Don't edit `default.project.json`, `sourcemap.json`, `Packages/`, or `assets.luau`.
- Don't assume a Networker id equals the folder name — check [`docs/services/catalog.md`](docs/services/catalog.md).
- Don't forget `npm run build:rojo` after file changes; requires will fail on a stale tree.
- Don't rename place assets/plot children; many are lookup contracts.
- Don't rename persisted keys or marker/funnel names.
- Don't change income/upgrade formulas in one place only (server, client, offline, simulator).
- Don't close the open menu from an overlay — hide it (`Menu.hideOpenMenu`).
- Don't expect a test suite or CI: neither exists; `stylua`, `selene`, and Studio verification are the process.
- Check your branch: this docs set and the live place describe `main`; feature branches can lag behind.

More: [`docs/reference/gotchas.md`](docs/reference/gotchas.md).

## Development Workflow

1. Confirm branch (`main`); on a fresh machine run `rokit install`, then `npm install` and `npm run wally-install`.
2. Read the owning system doc; find the service contract in [`docs/services/catalog.md`](docs/services/catalog.md).
3. Implement, respecting entrypoint ordering, determinism, and server authority.
4. New/renamed files → `npm run build:rojo`. New `assets/**` → `asphalt`.
5. `stylua src`, `selene src`.
6. Verify in Studio (data uses the `__test__` store; some features are disabled in Studio — e.g. Roblox funnel analytics, teleports).
7. Update the system doc + catalog. Update this file only when a global rule changes.
8. Commit and push only when the task is finished and verified — a push is the final product, not a checkpoint.

## Key Documentation

| Topic | Path |
|-------|------|
| Docs index | [`docs/README.md`](docs/README.md) |
| Architecture overview | [`docs/architecture/overview.md`](docs/architecture/overview.md) |
| End-to-end data flows | [`docs/architecture/data-flow.md`](docs/architecture/data-flow.md) |
| Runner simulation (determinism) | [`docs/systems/runner-simulation.md`](docs/systems/runner-simulation.md) |
| Plots and gates | [`docs/systems/plots-and-gates.md`](docs/systems/plots-and-gates.md) |
| Player data and persistence | [`docs/systems/player-data.md`](docs/systems/player-data.md) |
| Economy and progression | [`docs/systems/economy.md`](docs/systems/economy.md) |
| Crates and stock | [`docs/systems/crates-and-stock.md`](docs/systems/crates-and-stock.md) |
| Monetization | [`docs/systems/monetization.md`](docs/systems/monetization.md) |
| Tutorial | [`docs/systems/tutorial.md`](docs/systems/tutorial.md) |
| Analytics | [`docs/systems/analytics.md`](docs/systems/analytics.md) |
| UI framework | [`docs/systems/ui.md`](docs/systems/ui.md) |
| Service catalog | [`docs/services/catalog.md`](docs/services/catalog.md) |
| Guides (services, endpoints, UI, items, balance, products) | [`docs/guides/`](docs/guides/) |
| Rojo mapping / require paths | [`docs/reference/rojo-mapping.md`](docs/reference/rojo-mapping.md) |
| Scripting standards | [`docs/reference/scripting-standards.md`](docs/reference/scripting-standards.md) |
| Gotchas | [`docs/reference/gotchas.md`](docs/reference/gotchas.md) |
