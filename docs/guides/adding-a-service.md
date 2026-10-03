# Adding a Service

When to add a service (not a plain module): the feature needs its own Networker channel, per-player lifecycle, or server authority. Shared pure logic belongs in `src/modules/`.

## 1. Create the files

```
src/services/<name>/
├── Server.luau      # server module (required as <Name>Server)
├── Client.luau      # optional client half (required as <Name>Client)
└── Utils.luau       # optional shared tables/helpers (required as <Name>Utils)
```

Instance names are generated (folder PascalCased, `Server`/`Client`/`Utils` prefixed). `src/services/rocketService/Server.luau` becomes `ServerScriptService.Services.RocketService.RocketServiceServer`.

## 2. Server module shape

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Networker = require(ReplicatedStorage.Packages.Networker)

local RocketService = {}

function RocketService.init(self: RocketService): ()
	self.networker = Networker.server.new("RocketService", self, {
		self.launch,
	})
end

-- client: fetch("launch", target) / fire("launch", target)
function RocketService.launch(self: RocketService, player: Player, target: number): (boolean, string)
	-- validate everything; the client is untrusted
	if typeof(target) ~= "number" then
		return false, "ERROR"
	end
	-- ... server-authoritative work ...
	return true, "SUCCESS"
end

type RocketService = typeof(RocketService) & {
	networker: Networker.Server,
}

return RocketService :: RocketService
```

Use `ServicePlayerData` for ephemeral per-player state and `Janitor` for connections/instances. Match the patterns in `src/services/codeService` (compact) or `src/services/stockService` (global state).

## 3. Client half (only if needed)

```lua
local RocketServiceClient = {}

function RocketServiceClient.init(self: RocketServiceClient): ()
	self.networker = Networker.client.new("RocketService", self)
end

function RocketServiceClient.launch(self: RocketServiceClient, target: number): (boolean, string)
	return self.networker:fetch("launch", target)
end

-- server → client: networker:fire(player, "showLaunch", ...) calls this
function RocketServiceClient.showLaunch(self: RocketServiceClient, position: Vector3): ()
	-- update UI / fire a local Signal for menu code
end

return RocketServiceClient
```

Networker ids must match exactly on both sides.

## 4. Wire it into the entrypoints

Adding files does **not** register anything. Edit `src/library/Server.server.luau`:

```lua
local RocketServiceServer = require(ServerScriptService.Services.RocketService.RocketServiceServer)

-- direct: part of core gameplay, must be running immediately
RocketServiceServer:init()

-- OR optional: a failure should warn and disable the feature, not kill startup
initializeOptionalFeature("RocketService", function()
	require(ServerScriptService.Services.RocketService.RocketServiceServer):init()
end)
```

And `src/library/Client.client.luau` for the client half (same choice). Respect ordering constraints — e.g. services that read stock must init after `StockServiceClient`, and analytics must start before anything that sends markers. See [`../architecture/overview.md`](../architecture/overview.md#boot-sequence).

## 5. Regenerate the Rojo tree

New/renamed files require:

```powershell
npm run build:rojo
```

Without it, `default.project.json` (generated, gitignored) has no instance for the new files and requires fail at runtime. If you added a Wally dependency, run `npm run wally-install` instead (it also rebuilds the sourcemap).

## 6. Update the docs

- Add a row to [`../services/catalog.md`](../services/catalog.md).
- If the service introduces a system, add a doc under `docs/systems/` and link it from [`../README.md`](../README.md).

## Checklist

- [ ] Id string identical in `Networker.server.new` and `Networker.client.new`.
- [ ] Every client argument validated server-side.
- [ ] State cleaned on `PlayerRemoving` (or via `ServicePlayerData`).
- [ ] `Janitor` used for connections/instances.
- [ ] Initialized in both entrypoints if it has both halves, with the right direct/optional choice.
- [ ] `npm run build:rojo` run.
- [ ] `stylua src` and `selene src` clean.
- [ ] Catalog updated.
