# Analytics

Two independent transports, one shared vocabulary:

| Transport | Where | When |
| --- | --- | --- |
| **Gamebeast SDK** (`@gamebeast-gg/gamebeast`) | `src/services/analyticsService/Server.luau` | Always (Studio included). Markers, purchase revenue |
| **Roblox `AnalyticsService`** | same file | Live servers only (`not RunService:IsStudio()`). Creator Dashboard onboarding funnel |

The client never talks to either backend directly. `AnalyticsServiceClient` forwards validated calls over the `"AnalyticsService"` networker; the server validates, throttles, dedupes, and sends.

## Initialization and ordering

- Server: Analytics is the **first optional feature** after `DataService:init`, because funnel step 1 is logged on `PlayerAdded` and the Gamebeast handle must exist before other services send markers. Initialize failures warn and disable analytics; server marker calls no-op when the handle is nil.
- Client: `AnalyticsServiceClient:init()` runs right after `DataService:init()` with its own `xpcall` wrapper. Client callers (`Menu`, monetization, `TutorialRoot`) invoke analytics unconditionally, so a failed client init would surface errors in those callers.
- Gamebeast setup: server `GameBeast:Setup({ key = ServerStorage.dotenv.GAMEBEAST_API_KEY })`; the client calls `GameBeast:Setup()` with no key.
- Studio warning at init: Roblox funnel events are skipped; Gamebeast markers still send.

## Markers (`src/services/analyticsService/Markers.luau`)

Marker names are **dashboard schema** — treat as frozen once shipped. Values must be a primitive or a flat dictionary of primitives (no arrays/nesting).

| Constant | String | Sent by | Value |
| --- | --- | --- | --- |
| `storeOpened` | `"storeOpened"` | server `logStoreOpened` | `{ source = "menu" \| "restore" }` |
| `productViewed` | `"productViewed"` | server `logProductViewed` | `{ offerId, productId }` |
| `purchaseStarted` | `"purchaseStarted"` | server `logPurchaseStarted` | `{ offerId, productId }` |
| `purchaseSuccess` | `"purchaseSuccess"` | monetization server (granted path) | `{ offerId, productId, robuxSpent, isGift }` |
| `purchaseFailed` | `"purchaseFailed"` | monetization server + client-reported | `{ offerId, productId, reason, isClientReported? }` |
| `tutorialStarted` | `"tutorialStarted"` | tutorial server | `true` |
| `tutorialStep` | `"tutorialStep"` | tutorial server | stage number |
| `tutorialFinished` | `"tutorialFinished"` | tutorial server | `true` |
| `runnerPurchased` | `"runnerPurchased"` | `Profile.giveRunner` | `{ runnerLevel, amount, totalPurchases, isFirstUnlock }` |
| `runnerMerged` | `"runnerMerged"` | `Plot.merge` | `{ mergeCount, highestResultLevel, runnerCountBefore, runnerCountAfter }` |
| `playerProgression` | `"playerProgression"` | server snapshot loop | 17 flat fields (runners, upgrades, rebirths, cash, route, session, tutorial) |

`Markers.failureReasons` enumerates valid `purchaseFailed` reasons: server `noPlayer`, `dataLoadFailed`, `unknownProduct`, `alreadyOwned`, `cooldown`, `disabled`, `noCallback`, `callbackError`, `grantRejected`; client `soldOut`, `policyBlocked`, `declined`. `Markers.storeSources` enumerates `menu` / `restore`. Use `Markers.getFailureReason` for validation instead of literals. `playerProgression` snapshots run every `PROGRESSION_SNAPSHOT_INTERVAL = 60` s plus once on leaving; `sendProgressionSnapshot` deliberately does not `waitForData`.

## Onboarding funnel (`src/services/analyticsService/OnboardingFunnel.luau`)

Roblox Creator Dashboard funnel steps; names are frozen once published.

| Step | Name | Emitted when |
| --- | --- | --- |
| 1 | Joined Game | Server `PlayerAdded`, skipped for players who already finished the tutorial |
| 2 | Tutorial Started | Client `TutorialRoot` after the plot loads |
| 3–15 | Step 01…Step 13 - Tutorial Finished | `logTutorialStage(stage)` maps `stage + 2` |

`fromTutorialStage` fails closed for unknown stages; `_logStep` dedupes per player per session before calling Roblox.

## Client forwarding and validation

Client API (`AnalyticsServiceClient`): `logOnboardingStep(step)`, `logTutorialStage(stage)`, `logStoreOpened(source)`, `logProductViewed(productKey?)`, `logPurchaseStarted(productKey?)`, `logPurchaseDeclined(productKey?, reason)`. It re-exports `failureReasons` and `storeSources`.

Server rules (`_acceptClientMarker` + validators):

- Client events are untrusted: product keys are resolved against the live `Products` table; reasons are checked against `failureReasons`; steps against `getStepName`.
- Client-triggered markers are throttled to `CLIENT_MARKER_MIN_INTERVAL = 0.2` s per player.
- Revenue is **never** derived from client signals. `purchaseSuccess` / `SendNewPurchaseGrantedMarker` run only on the `PurchaseGranted` path, and `adHeartCrate` is excluded (the rewarded-ad receipt is not reported as revenue). `declined` is marked `isClientReported = true`.

## Reliability

- Every transport call is `pcall`-wrapped with a warning; failures never block gameplay.
- Failed Gamebeast batches are captured via `OnMarkersFailed` into `bufferedFailedMarkers` (cap `MAX_BUFFERED_FAILED_MARKERS = 2_000`) and retried every `FAILED_MARKER_RETRY_DELAY = 30` s; on repeated failure they are dropped with a warning.

## Where markers are sent from

| Site | Markers |
| --- | --- |
| `src/classes/profile/Server.luau` (`giveRunner`) | `runnerPurchased` |
| `src/classes/plot/Server.luau` (`merge`) | `runnerMerged` |
| `src/services/monetizationService/Server.luau` | `purchaseSuccess`, server-side `purchaseFailed` |
| `src/services/monetizationService/Client.luau` | `productViewed`, `purchaseStarted`, client-side `purchaseFailed` |
| `src/ui/App/components/Menu.luau` (`setOpenedMenu`) | `storeOpened` (Shop only) |
| `src/ui/Tutorial/TutorialRoot.luau` | `tutorialStep`, `tutorialStarted` |
| `src/services/tutorialService/Server.luau` | `tutorialStarted`, `tutorialStep`, `tutorialFinished` |

## Gotchas

- Renaming a marker or funnel step splits dashboard history. Add new names instead.
- Keep `Markers.luau` / `OnboardingFunnel.luau` as the only place these strings exist; client and server both read them so schemas can't drift.
- Tutorial stages and funnel steps are different vocabularies (`stage + 2`); step 1 is server-emitted, step 2 client-emitted.
- `PurchaseGranted` and analytics must stay paired: report only after granting, and never for `adHeartCrate`.
- `ServerStorage.dotenv` is not versioned; a missing `GAMEBEAST_API_KEY` disables analytics with a warning (setup is wrapped by `initializeOptionalFeature`).
- Revenue must never be derived from client signals; the server reports it only on the `PurchaseGranted` path, and client-reported failures carry `isClientReported = true`.

## Related

- [Tutorial](tutorial.md)
- [Monetization](monetization.md)
- [Architecture overview](../architecture/overview.md)
