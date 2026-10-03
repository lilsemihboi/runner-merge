# Monetization

Robux products, game passes, gifting, rewarded ads, offline earnings, and trail inventory. The server is authoritative; clients only prompt and display.

## Products (`src/services/monetizationService/modules/Products.luau`)

Prices are **never** defined in code — they come from the Roblox place configuration (`GetProductInfoAsync` / receipts). Product ids must match the place exactly or prompts/receipts silently fail.

| Key | id | Type | Flags / notes |
| --- | --- | --- | --- |
| `doubleOfflineEarnings` | 3609107348 | Product | |
| `starterPack` | 3609866032 | Product | `oneTimePurchase` |
| `carBundle1` | 3609863241 | Product | `giftId` 3610794683 |
| `x5Spin` / `x3Spin` / `x1Spin` | 3609863143 / 3609863090 / 3609862993 | Product | `random`; x5/x3 giftable. No current prompt site |
| `extraGate1` / `extraGate2` | 3609858039 / 3609858087 | Product | No current prompt site |
| `skipRebirth` | 3612182563 | Product | No cash requirement, no wipe |
| `cashPack1`–`cashPack4` | 3609857753 / 3609857642 / 3609857532 / 3609857146 | Product | 20% / 50% / 125% of `max(cash, 10k)`; pack 4 is flat 1B |
| `crate1`–`crate3` | 3703612993 / 3703613988 / 3703614930 | Product | `random` |
| `x3crate1`–`x3crate3` | 3703758478 / 3703773886 / 3703775270 | Product | `random` |
| `adHeartCrate` | 3710757101 | Product | `random`; only granted via rewarded ads |
| `exclusiveCar` | 3637359531 | Product | `stock = 1_000`, `giftId` 3675691634 |
| `vip` | 1908932677 | Game pass | ×1.5 cash, extra gates, chat title |
| `x2Speed` | 1907576707 | Game pass | Runner speed ×2 |
| `x2Cash` | 1906304732 | Game pass | Gate income ×2 |
| `autoRollCrate` | 1952750474 | Game pass | Enables crate auto-roll |

`MonetizationProduct` shape (`Utils.luau`): `id`, `key` (backfilled at init), `giftId?`, `isPass?`, `oneTimePurchase?`, `purchaseCooldown?` (seconds), `random?`, `disabled?`, `stock?`, `callback?` (server only). `random = true` products display `Locked` (and refuse prompts) when `ArePaidRandomItemsRestricted` blocks paid random items.

## Game pass flow

`PromptGamePassPurchaseFinished` → guard (purchased, awarding enabled, not already owned) → notification → `awardGamepass`: writes `__gamepasses[tostring(id)] = true`, runs the pass callback if any, fires `gamePassAwarded`. Discord is logged once.

- Ownership reads use profile data (`ownsGamepass` = `__gamepasses`), not the Roblox API. `ownsGamepassAsync` is used for join recovery and gift delivery.
- Reactive ownership: `MonetizationServiceServer:getPassOwnshipChanged(player, product)` — note the misspelling — returns a `DataService` change signal. Used by `runnerService` (x2Speed/x2Cash/VIP) and `titleService` (VIP title). `plot/Server` checks `ownsGamepass` at upgrade time; `blockService` reacts via `gamePassAwarded` plus live `ownsGamepass` checks.

## Developer product receipts

`ProcessReceipt` → `_processDeveloperProduct` validates in order: player online → data loaded → replay (`__processedPurchases`, capped at `MAX_PROCESSED_PURCHASE_RECORDS = 50`) → known product → gift handling → one-time/cooldown/disabled → callback (`pcall`). Outcomes:

| Result | Meaning |
| --- | --- |
| `PurchaseGranted` | Success **or** deliberate soft-fail (`callback == false` → `grantRejected` marker; receipt acked, nothing granted) |
| `NotProcessedYet` | Invalid/unknown/error; Roblox retries (callback that granted then errored will double-grant — make callbacks idempotent) |
| Replayed `PurchaseId` | Acked without granting |

On success: one-time/cooldown keys are written, `productProcessed` fires (entrypoint consumes it for stock), `purchaseSuccess` marker + notification + `purchaseSucceded` sound run. `adHeartCrate` is excluded from Gamebeast purchase-revenue and Discord logging.

Callbacks live in `modules/ProductServerCallbacks.luau` (required for side effects by the server entrypoint). Effects: starter pack (`runner(6)`, `$50k`, `+0.2` customMultiplier), `carBundle1` (levels 14–16), cash/spin packs, `skipRebirth`, `extraGate1/2`, `exclusiveCar`, and crate grants. Passes have no callbacks.

## Gifting

- `promptGift(receiverUserId, product.giftId)` (server): rejects if already gifting, receiver offline/self, receiver owns it, cooldown, or sold out; marks `giftingTo` and prompts the **gift product id**.
- Gift receipts use a wrapper callback: local `receiveGift` if the receiver is in this server, otherwise `DataService:sendGlobalMessage("gift", receiverUserId, …)`; a failed cross-server send soft-fails (`grantRejected`).
- `receiveGift` fires `_receivedGift`; the client fires the `giftReceived` signal (`Client.client.luau` wires it to `ShopSlice` + `GiftReceivedMenu`).
- Granted gifted one-time products do **not** write `__oneTimePurchases` for the receiver — don't add a `giftId` to a one-time product without fixing that path.

## Rewarded ads

- Server `RewardedAdService`: `playAd` creates an `AdService:CreateAdRewardFromDevProductId(Products.adHeartCrate.id)` and shows the video (ad unit id `636257121902409`). One claim per server session (`playersClaimedRewardThisSession`).
- The reward arrives as a normal receipt for `adHeartCrate` → crate 13.
- Client `playAd`, `canShowAd` (ad availability check; internally uses `canClaimAdReward`). `RewardedAdSlice` refreshes every 30 s; the HUD "CRATE / FREE" button and `SpecialOffers` Hearts card consume it.

## Offline earnings

- Caps: minimum 900 s, maximum 43,200 s (12 h); multiplier `OFFLINE_EARNINGS_MULTIPLIER = 0.7`.
- `calculateOfflineEarnings` (`Server.luau`) walks path/gate distances per runner using the same speed math and the `cashBonus`/rebirth/custom/VIP/trail/route multipliers (not friends/x2). Stores `offlineEarnings` + `offlineEarningsPaid = false` + `offlineEarningsDoubled = false`.
- `requestBegin` **pays** the reward and marks it paid (menu open). `requestClaim` pays only if unpaid, then clears the three keys.
- `doubleOfflineEarnings` doubles pending or pays the difference when the base was already paid.
- `profileService`'s player-removing callback clears the keys; the next join recomputes from `lastLogoutTime`.

## Inventory (trails)

- `inventory` (array) + `selectedTrail`. `fetch("selectTrail", trailId | nil)` → `Profile.selectTrail` validates existence and ownership.
- `InventoryMenu` derives owned counts, rarity colors, and multipliers; selecting the equipped trail unequips it.
- Trails multiply gate income and offline earnings; see [`economy.md`](economy.md).

## Shop UI

`Menu.setOpenedMenu("Shop", options?)` toggles the shop; opening it logs `logStoreOpened` (`menu` vs `restore`). Sections (`src/ui/Shop/ShopMenu.luau`, `LayoutOrder`):

| Section | Contents |
| --- | --- |
| `SpecialOffers` (0) | Heart Crate ad, starter pack (hidden once owned), exclusive car (stock via `useStock`), car bundle |
| `Crates` (2) | Crate cards 10/11/12 with odds |
| `Passes` (3) | VIP, auto-roll, x2 speed, x2 cash |
| `Currency` (4) | cash packs (text mirrors the server formula) |
| `Codes` (5) | `CodeServiceClient:redeem` |

Other prompts: `RebirthMenu` (`skipRebirth`), `OfflineMenu` (`doubleOfflineEarnings`), plot UI (`vip`, `autoRollCrate`, `starterPack`, `exclusiveCar`), `RightSide` (`starterPack`). `RobuxButton` is the shared buy button.

## Environment / logging

- `ServerStorage.dotenv` must provide `DISCORD_PROXY_URL` + `DISCORD_PROXY_KEY` (external proxy; no worker source in this repo) and `GAMEBEAST_API_KEY` (analytics).
- Discord logging queues with `DISCORD_MAX_ATTEMPTS = 6`, spacing `0.6` s, retry-after handling, jitter; `logDiscord` waits for place info first.

## Gotchas

- Product ids, pass ids, and gift ids must match the Roblox place. Studio product info may be `UNKNOWN_PRODUCT_INFO`.
- Choose receipt outcomes deliberately: `NotProcessedYet` retries forever; `false` from a callback is a soft-fail.
- The server is authoritative; never grant from client signals. Client `purchaseFailed` reasons are best-effort and marked `isClientReported`.
- `ProductServerCallbacks` must be required before receipts arrive (it mutates the shared `Products` table).
- Stock gates are prompt-time only (`promptGift` server-side; `promptProduct` client-side); consumption never refuses.
- Entrypoint ordering: Stock before Monetization on both realms; `productProcessed` → stock consumption is wired in the server entrypoint.
- Menu overlays hide rather than close (`Menu.hideOpenMenu`) so opening `Purchasing` doesn't fire the OfflineRewards claim early.
- `__gamepasses`, `__oneTimePurchases`, `__purchaseCooldowns`, `__processedPurchases`, `__giftReceiver` are persisted contract even though they are absent from `DataTemplate`.

## Related

- [Crates and stock](crates-and-stock.md)
- [Player data](player-data.md)
- [Data flow · purchase](../architecture/data-flow.md#robux-purchase)
- [Adding a code or product guide](../guides/adding-a-code-or-product.md)
