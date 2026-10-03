# Adding a Code or Product

## Codes

Codes are managed by `CodeService` (`src/services/codeService/`), stored in their own DataStore (`CODES` key in datastore `Codes`), and redeemed once per player (`_codes` profile key).

### Add a code

```lua
-- src/library/Server.server.luau (or a server console one-off)
CodeServiceServer:add("mantle2026", {
	active = true,
	expiration = 1798675200,          -- optional unix seconds
	reward = "currency",               -- callback key in ServerCallbacks.luau
	params = { 15_000 },               -- arguments passed to the callback
	-- uses = 100,                     -- optional global uses
	-- userIds = { 123 },              -- optional allowlist
})
```

There is a commented example in the server entrypoint. `CodeService:add` errors if the code already exists; use `remove`/`deactivate`/`listActiveCodes` for maintenance. Codes are lowercase-normalized.

`reward` must be a key in `src/services/codeService/ServerCallbacks.luau`. Currently:

| Reward | Params | Effect |
| --- | --- | --- |
| `currency` | `amount` | `Profile:giveCash(amount)` + notification |
| `runner` | `level` | `Profile:giveRunner(level)` + notification (~counts as a purchase) |

To add a reward type, add a function to `ServerCallbacks` and pass the table as `CodeServiceServer:init(ServerCallbacks)` (already wired in the entrypoint).

Reward callbacks run through `pcall`; a raising callback returns `err` to the client. Multi-reward codes use `reward = { "currency", "runner" }` with `params = { {…}, {…} }` (see `CodeService.redeem`).

## Products and passes

### 1. Create the item in the Roblox place

Create the developer product (or game pass) in the Creator Dashboard / Studio and note its numeric id, plus a **gift product id** per giftable product (gifts are separate product ids). Prices are configured on Roblox, not in code.

### 2. Register it in `Products.luau`

`src/services/monetizationService/modules/Products.luau`:

```lua
rocketPack = {
	id = 1234567890,
	giftId = 1234567891,      -- optional; separate gift product id
	random = true,             -- paid random item (policy-gated)
	oneTimePurchase = true,    -- optional
	purchaseCooldown = 60,     -- optional seconds
	stock = 1_000,             -- optional lifetime stock (StockService)
} :: MonetizationProduct,
```

`isPass = true` for game passes. `disabled = true` hides a product without removing it.

### 3. Wire the effect

Developer products: add a callback in `src/services/monetizationService/modules/ProductServerCallbacks.luau` and assign it to `products.<key>.callback` (or inside the module's setup, matching the crate pattern). Return `false` for a soft-fail (`grantRejected`, receipt still granted); return `nil`/`true` for success. Callbacks that grant must be **idempotent** — a callback that grants then errors is retried by Roblox and will double-grant.

Game passes: no callback; consumers check ownership via `MonetizationServiceServer:ownsGamepass(player, Products.<key>)` and can subscribe to `getPassOwnshipChanged(player, product)`.

Crates additionally need a `CRATE_PRODUCTS` row mapping the product to `{ crateId, rolls }` (see [`../systems/crates-and-stock.md`](../systems/crates-and-stock.md)).

### 4. Surface it in the UI

Add a `RobuxButton`/card to a shop frame (`src/ui/Shop/frames/*`), `RebirthMenu`, `OfflineMenu`, or plot UI as appropriate. The button reads `getProductCostString` (Owned / Sold Out / Cooldown / Disabled / Locked / price) automatically. Giftable products get the gift icon when `giftId` is set and `HideGift` is not passed.

### 5. Test

- Studio uses the `__test__` profile/stock stores; purchases can be simulated through Studio's developer-product testing.
- Verify: prompt opens, receipt grants exactly once, `__oneTimePurchases`/cooldowns/`__gamepasses` update, notification + sound fire, gift flow delivers to an online receiver, stock counts down (if stocked), analytics `purchaseSuccess` fires only on the granted path.
- Check the `adHeartCrate` exclusions if you touch the receipt wrapper.

## Checklist

- [ ] Ids (product, pass, gift) match the Roblox place.
- [ ] `random = true` for loot-box products (policy gating).
- [ ] Callback is idempotent; return semantics chosen deliberately.
- [ ] UI entry point added; tutorial gating respected.
- [ ] Docs updated: [`../systems/monetization.md`](../systems/monetization.md), [`../services/catalog.md`](../services/catalog.md).
- [ ] `stylua src`, `selene src`.
