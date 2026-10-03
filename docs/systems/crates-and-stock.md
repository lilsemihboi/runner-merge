# Crates and Stock

Two related systems:

- **Crates** (internally "blocks" or "lucky blocks") are weighted loot boxes that grant **trails**. They come in two flavors: a lap-gated crate queued on the player's plot, and Robux / rewarded-ad crates.
- **StockService** is a global lifetime stock counter for limited products (currently only `exclusiveCar`). It is separate from crate logic but shares shop UI.

## Crate definitions (`src/modules/items/Blocks.luau`)

`Blocks.blocks[id]` = `{ lapsRequirement, blockWeight, blockName, loot }`. Ids:

- `1–9`: rollable track crates (`blockWeight > 0`), queued automatically. Lap requirements: 5, 10, 25, 50, 75, 100, 200, 450, 500.
- `10–12`: Robux crates (Spike/Magma/Robux Crate; ids map to products below); `blockWeight = 0` so they never queue naturally.
- `13`: rewarded-ad Heart Crate; also `blockWeight = 0`.

Timing constants: `rollTime = 4.5`, `revealHold = 1.6`. Helpers: `Blocks.rollTrail(crateId, rng)` (weighted trail pick), `Blocks.rollBlock(rng)` (next queued crate by `blockWeight`; authored weights sum to 100), `Blocks.getOdds(crateId, trailId)` (percent, formatted by `FormatPercent`), `Blocks.getBlock(id)`.

Rarity bands come from `src/modules/items/Rarities.luau`; trail data from `Trails.luau` (see [`economy.md`](economy.md)).

## Track crate flow (lap-gated)

1. `DataTemplate` starts players with `luckyBlockInQueue = 1` (Wood Crate) and `lapsLeftToAcquire = 5`.
2. `Plot._watchCrate` builds the crate model from `ReplicatedStorage.Assets.Blocks.<crateId>` on the plot's `LuckyBlock.CrateSpawn`.
3. `RunnerManager` reports laps → `RunnerService.reportLap` validates → `_spendLaps` decrements `lapsLeftToAcquire` (whole laps, clamped at 0).
4. At 0, `BlockServiceClient:openCrate()` checks queue/laps for UX, then `fetch("openCrate")`.
5. `BlockService._openCrate` (server): rejects if a roll is already in flight for that player (`playersOpeningCrates`), no profile, no queued crate, or laps remain. Rolls the trail, grants it immediately (`profile:giveTrail`), clears the queued crate, rolls the **next** crate and resets laps, schedules rarity announcements, and returns `"SUCCESS", { crateId, trailId }`.
6. Client: `CratesSlice.actions.beginRolling` opens `CratesScreen`; the reel is cosmetic (winner forced at index 46).

Auto-roll (gamepass `autoRollCrate` + `autoCrateOpen` flag): `PlotClient` triggers `openAutoCrate` when the crate becomes rollable; the server re-checks the stored flag and live gamepass ownership. Manual rolls release the in-flight lock immediately; auto-rolls hold it for `rollTime + revealHold` to prevent spam. Toggling state fires `updateAutoRollState`; `BlockServiceClient.autoRollStateChanged` / `crateRollStatusChanged` are local signals used by the plot UI.

Announcements: `Epic`, `Legendary`, `Mythic`, `Secret` drops (and auto-rolls beating the selected trail) fire `fireAll("announceDrop")`; clients post a `TextChannels.RBXGeneral` system message. The channel must exist — there is no guard.

## Purchased crates

Products map to crates in `src/services/monetizationService/modules/ProductServerCallbacks.luau` (`CRATE_PRODUCTS`):

| Product | Product id | Crate | Rolls |
| --- | --- | --- | --- |
| `crate1` / `x3crate1` | 3703612993 / 3703758478 | 10 | 1 / 3 |
| `crate2` / `x3crate2` | 3703613988 / 3703773886 | 11 | 1 / 3 |
| `crate3` / `x3crate3` | 3703614930 / 3703775270 | 12 | 1 / 3 |
| `adHeartCrate` | 3710757101 | 13 | 1 (rewarded ad only) |

Receipt → `BlockServiceServer:grantPurchasedCrate(player, crateId, rolls)`: clamps rolls to `MAX_PURCHASED_ROLLS = 10`, rolls and grants every trail, then fires `beginPurchasedRolls` with the whole array and staggers announcements. Rewards are granted **before** the animation; purchased crates bypass the lap gate and the `luckyBlockInQueue` slot. It returns `false` when nothing could be granted (receipt soft-fail: `grantRejected`, still `PurchaseGranted`).

## Crate UI

| File | Role |
| --- | --- |
| `src/ui/Crates/CratesScreen.luau` | Full-screen reel animation; mounted by `RootUI`; hides the menu HUD while open |
| `src/ui/Crates/CratesSlice.luau` | Charm atoms: `rollData`, `cratesScreenOpen`, `isRolling`, `pendingRolls`, `rollNumber`, `rollCount`; actions `beginRolling`, `beginRollQueue`, `advanceRoll`, `finishRolling`, `closeScreen` |
| `src/ui/Shop/frames/Crates.luau` | Shop section with crate 10/11/12 cards and odds previews |
| `src/ui/Shop/frames/SpecialOffers.luau` | Heart Crate rewarded-ad card (`adHeartCrate`) |

`CratesScreen` constants: `STRIP_LENGTH = 50`, `WINNER_INDEX = 46`, `MIN_TICK_INTERVAL = 0.045`; sounds `caseTick`/`caseReveal`. The screen must never decide rewards.

## StockService

Lifetime "units sold" counters for products with a `stock` field, persisted **outside** `DataService`:

- DataStore: `("__test__" or "__production__") .. "Stock_v1"`, key `GlobalStock`, value `{ [productKey]: soldCount }`. Prefix uses `RunService:IsStudio()`.
- Only `exclusiveCar` is stocked today: `Products.exclusiveCar.stock = 1_000`.
- Stock is stored as **sold**, never remaining: absent key = zero sold, stale cached reads can't resurrect stock, and the merge is monotonic (`math.max`) on refresh (`REFRESH_INTERVAL = 15` s).
- Endpoint: `fetch("getStocks")` (served from memory); broadcast `fireAll("stockChanged", soldCounts)`.
- `consumeByProductId(productId)` resolves the numeric id **or** gift id to a product key and increments via `UpdateAsync` after a granted receipt. It intentionally never refuses (may oversell). Prompt-time guards (server `promptGift`, client `promptProduct`) are what keep the window small.
- `StockSlice` (Charm atoms `soldCounts`, `isSynced`) + `useStock(key)` hook power UI. Gate content on `isSynced` — an empty table is ambiguous on the first frames.

Client cost text order: `Owned` → `Sold Out` → `Cooldown: …` → `Disabled` → `Locked` → price.

## Gotchas

- "Block", "crate", "lucky block" are the same id space; `luckyBlockInQueue` is a crate id, not a stock key.
- Never make `consumeByProductId` refuse or replace the `math.max` merge with assignment.
- `setCrateInQueue` writes laps before crate id deliberately — preserve the order.
- The client reel is cosmetic; never let the winner come from the client strip.
- Purchased crate rewards are not replayed after a disconnect (they're already in `inventory`).
- Crate models must be named `tostring(crateId)` under `ReplicatedStorage.Assets.Blocks` or `buildCrate` silently does nothing.
- `announceDrop` assumes `TextChannels.RBXGeneral` exists.
- `inventory` allows duplicates; crates and inventory UI must tolerate them.
- After changing `Blocks.luau` loot, keep per-crate weights summing to 100 so odds read as percentages (normalization still works either way).

## Related

- [Economy](economy.md) — trails and multipliers
- [Monetization](monetization.md) — receipts, products, rewarded ads
- [Services catalog](../services/catalog.md)
