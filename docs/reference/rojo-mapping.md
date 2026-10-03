# Rojo Mapping and Require Paths

`default.project.json` is **generated** by `scripts/genRojoTree.js` (`npm run build:rojo`) and ignored by Git. It maps `src/**/*.luau` to instances with rules that are easy to get wrong. Never hand-edit it; rerun the generator after adding, removing, or renaming files.

## Rules

1. `src/library/` is excluded from the walk and mapped explicitly:
   - `src/library/Server.server.luau` → `ServerScriptService.Server`
   - `src/library/Client.client.luau` → `StarterPlayer.StarterPlayerScripts.Client`
2. **Realm:** if the file's basename (lowercased) **contains** `server`, the file goes under `ServerScriptService`; everything else goes under `ReplicatedStorage.Shared`.
   - `Server.luau`, `ServerCallbacks.luau`, `ProductServerCallbacks.luau`, `RunnerServiceServer` → server.
   - `Client.luau`, `Utils.luau`, `Types.luau`, `SettingsInitializer.luau` → shared (even if used only by the server).
3. **Folders** are PascalCased by segment. A leading `src/ui/` segment becomes the special `UI`; a nested `modules/ui/` becomes `Ui`.
   - `src/ui/App/hooks/` → `ReplicatedStorage.Shared.UI.App.Hooks`
   - `src/modules/ui/Primitives/` → `ReplicatedStorage.Shared.Modules.Ui.Primitives`
4. **Filenames:** basenames `server`, `client`, `utils`, `types` (case-insensitive, exact) are prefixed with the parent folder name:
   - `src/services/codeService/Server.luau` → `CodeServiceServer`
   - `src/classes/runner/Utils.luau` → `RunnerUtils`
   - `src/services/runnerService/Types.luau` → `RunnerServiceTypes`
   All other files keep their literal name (`Products.luau` → `Products`, `Markers.luau` → `Markers`).
5. `init.luau` claims its parent folder (the folder becomes the module script, children are skipped). No `init.luau` files exist today; prefer the standard file layout.
6. Runtime roots:
   - `ReplicatedStorage.Shared.{Services,Classes,Modules,UI}` (the generated tree also declares these folders).
   - `ServerScriptService.{Services,Classes,Modules}`.
   - `ReplicatedStorage.Packages` → the Wally output folder.

## Cheat sheet

| Source | Generated instance |
| --- | --- |
| `src/services/codeService/Server.luau` | `ServerScriptService.Services.CodeService.CodeServiceServer` |
| `src/services/codeService/Client.luau` | `ReplicatedStorage.Shared.Services.CodeService.CodeServiceClient` |
| `src/services/generalNotificationsService/Client.luau` | `ReplicatedStorage.Shared.Services.GeneralNotificationsService.GeneralNotificationsServiceClient` |
| `src/services/monetizationService/modules/ProductServerCallbacks.luau` | `ServerScriptService.Services.MonetizationService.Modules.ProductServerCallbacks` |
| `src/services/settingsService/SettingsInitializer.luau` | `ReplicatedStorage.Shared.Services.SettingsService.SettingsInitializer` |
| `src/classes/plot/Server.luau` | `ServerScriptService.Classes.Plot.PlotServer` |
| `src/classes/runner/Client.luau` | `ReplicatedStorage.Shared.Classes.Runner.RunnerClient` |
| `src/modules/items/Blocks.luau` | `ReplicatedStorage.Shared.Modules.Items.Blocks` |
| `src/ui/App/MountUI.luau` | `ReplicatedStorage.Shared.UI.App.MountUI` |
| `src/ui/App/hooks/usePx.luau` | `ReplicatedStorage.Shared.UI.App.Hooks.usePx` |
| `src/ui/Tutorial/hooks/useTargetRect.luau` | `ReplicatedStorage.Shared.UI.Tutorial.Hooks.useTargetRect` |
| `src/library/Server.server.luau` | `ServerScriptService.Server` |
| `src/library/Client.client.luau` | `StarterPlayer.StarterPlayerScripts.Client` |

## Typical requires

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- server
local ProfileServiceServer = require(ServerScriptService.Services.ProfileService.ProfileServiceServer)
local Runners = require(ReplicatedStorage.Shared.Modules.Items.Runners)

-- client / shared
local Menu = require(ReplicatedStorage.Shared.UI.App.Components.Menu)
local RunnerUtils = require(ReplicatedStorage.Shared.Classes.Runner.RunnerUtils)
```

## Common mistakes

- Assuming `src/modules/ui/...` maps to `...UI...` — it is `...Modules.Ui...` (only the top-level `src/ui/` becomes `UI`).
- Forgetting that a filename containing "server" lands in `ServerScriptService` — e.g. a shared helper named `LoggerServer.luau` would not be reachable from the client.
- Forgetting that `Utils`/`Types` get prefixed: `MonetizationServiceUtils`, `PlotServiceTypes`, `RunnerServiceTypes`.
- Using a stale `default.project.json` after checkout. It is generated and gitignored: run `npm run build:rojo` on a fresh checkout or after pulling new files. (`npm run wally-install` also regenerates it.)
- Expecting `Packages/` in Git — it is generated; run `npm run wally-install`.
