# Adding a Network Endpoint

Networker channels are created once per service. Adding an endpoint means touching the server method table, the server function, and (optionally) the client caller or the client event handler.

## Client → server

1. Implement the server method. It receives `self` and `player` first, then client arguments. Validate and return a value for `fetch` callers:

```lua
function Plot.upgrade(self: Plot, player: Player, upgradeId: string): string
	assert(player == self.player, "You dont own the base!")
	if upgradeId ~= "cashBonus" and upgradeId ~= "gates" and upgradeId ~= "runnerSpeed" then
		return "WRONG_UPGRADE_ID"
	end
	-- ...
	return "SUCCESS"
end
```

2. Register it in the channel's method list (server module `init`):

```lua
self.networker = Networker.server.new("PlotService", self, {
	self.merge,
	self.upgrade,     -- added
})
```

3. Call it from the client half:

```lua
local success, reason = self.networker:fetch("upgrade", upgradeId)   -- yields, returns values
self.networker:fire("teleportToBase")                                -- no return value
```

### Rules

- Endpoint names are the method names as strings; a typo fails silently at runtime (client waits or errors).
- `fetch` for anything needing a result, `fire` for pure actions. Both call the **same** server method.
- Validate types, ranges, and ownership before touching data. Return codes should map to `src/modules/utils/InfoEnums.luau` messages where the UI displays them.
- Never trust client-provided amounts, ids, or positions. Compare against server state; see `RunnerService.reportGate` for the reference implementation.
- For per-owner channels, create the networker with `addRecipient(player)` (see `PlotServer`) and assert `player == self.player` in every endpoint.
- Endpoints that grant purchased goods must stay idempotent or record receipt ids — see [`../systems/monetization.md`](../systems/monetization.md).

## Server → client

Add a method on the client module with the exact event name, then call it:

```lua
-- client
function BlockServiceClient.updateAutoRollState(self: BlockServiceClient, enabled: boolean): ()
	-- update state / fire a Signal
end

-- server
self.networker:fire(player, "updateAutoRollState", true)     -- one player
self.networker:fireAll("announceDrop", drop)                 -- everyone
self.networker:set(player, "vipMultiplier", 1.5)             -- write a field (no method call)
```

- `fire` targets one player or a player list; `fireAll` broadcasts.
- `set` does not call a method — it writes `clientModule[key] = value`. It is used for multiplier pushes onto `RunnerManager`. Prefer events for anything with logic.
- Client handlers receive their own `self` first, then the payload; there is no `player` argument.

## Checklist

- [ ] Server method validates player identity and all argument types.
- [ ] Registered in `Networker.server.new(..., { ... })` (for client-callable methods).
- [ ] Client caller uses the exact name; server event handler exists with the exact name.
- [ ] Failures return a result the UI can display (or are silently dropped for anti-exploit paths — say so in a comment).
- [ ] [`../services/catalog.md`](../services/catalog.md) row updated (endpoint/event list).
- [ ] `stylua src` and `selene src` clean.
