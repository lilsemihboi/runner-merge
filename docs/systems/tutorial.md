# Tutorial

A linear, client-driven onboarding of **13 steps**. `TutorialRoot` detects progress and drives the overlay; the server only persists progress and emits analytics. Tutorial state also gates parts of the HUD and plot UI.

## Files

| File | Role |
| --- | --- |
| `src/ui/Tutorial/TutorialRoot.luau` | Step table, detection, advancement, mount entry point |
| `src/services/tutorialService/Server.luau` | `saveStage` / `finishTutorial` endpoints, `tutorialStarted`/`tutorialStep` markers |
| `src/services/tutorialService/Client.luau` | Networker wrappers (fires, no fetch; hardcoded `255` cap) |
| `src/ui/Tutorial/TutorialSlice.luau` | Charm atoms mirrored from data; reads must happen in `task.spawn` |
| `src/ui/Tutorial/components/UINavigator.luau` | Spotlight/dimming around a target + optional cursor |
| `src/ui/Tutorial/components/useArrowNavigator.luau` | 3D guide beam (`ReplicatedStorage.Assets.Tutorial.Arrow`) |
| `src/ui/Tutorial/components/useInstructor.luau` | Instructor banner ScreenGui |
| `src/ui/Tutorial/hooks/useTargetRect.luau` | GUI/world target → screen rect projection |

`TutorialRoot` is mounted by name: `RootUI.captureRoots` requires every `ModuleScript` under `ReplicatedStorage.Shared.UI` whose lowercased name contains `"root"` (excluding `*.story`). Renaming the file silently disables the tutorial.

## Steps

`tutorialSteps` (`TutorialRoot` lines ~88–555) is keyed 1–13. Detection uses `GetDataSource`, menu state, or `CratesSlice`; a step can self-complete if its condition is already true.

| Stage | Objective | Detected by | Target |
| --- | --- | --- | --- |
| 1 | Buy a gate upgrade | `upgrades.gates >= 1` | 3D arrow → `UpgradeTable.UpgradeTable.UpgradePart`; UI spotlight `SurfaceGui.Frame.gates` |
| 2 | Buy first runner | `#runners >= 1` | Arrow → `Buttons.Runner["1"].ButtonTrigger` |
| 3 | Wait for earnings | `cash` change | — |
| 4 | Buy 2 more runners | `#runners >= 3` | Runner buttons |
| 5 | Merge two runners | any runner level > 1 | Arrow → `Buttons.Merge.Merge.ButtonTrigger` |
| 6 | Complete 5 laps | `lapsLeftToAcquire <= 0` | — (rich-text `x/5 Laps`) |
| 7 | Open lucky block | `CratesSlice.cratesScreenOpen` | Arrow → `LuckyBlock.CrateSpawn` |
| 8 | Open inventory | `Menu.openedMenu() == "Inventory"` (after crate screen closes) | UI spotlight `SideButtons.tutorialButtonRefs.inventory` |
| 9 | Equip a trail | `selectedTrail ~= nil` | — |
| 10 | Save $1,000 | `cash >= 1000` (closes open menu) | — |
| 11 | Open rebirth menu | `Menu.openedMenu() == "Rebirth"` | UI spotlight `SideButtons.tutorialButtonRefs.rebirth` |
| 12 | Rebirth | `rebirths` increases | — |
| 13 | Finish | 3 s delay → `finishTutorial` | — |

## Advancement & persistence

- `advanceTo(nextStage)` sends `AnalyticsServiceClient:logTutorialStage(nextStage - 1)` (reports the stage just completed), `TutorialServiceClient:saveStage(nextStage)`, then runs the next step.
- `advanceWithoutSaving(nextStage)` is used at 8→9 and 11→12 so stages 9 and 12 are intentionally never persisted; a rejoin during those resumes from 8 / 11.
- `finishTutorial()` reports stage 13 and fires `TutorialServiceClient:finishTutorial()`.
- Server writes go through `Profile.stepTutorial` / `Profile.finishTutorial` → `tutorial.step`, `tutorial.finished`. `saveStage` only validates number and `<= MAX_TUTORIAL_STAGE = 255`; `finishTutorial` has no dedupe guard.
- `TutorialRoot` re-reads `tutorial.finished` from `DataService` (not the mirrored atom) so finished players can't replay.

## HUD gating

Tutorial state hides UI until steps are reached (see `src/ui/Hud/SideButtons.luau`, `RightSide.luau`, `CashBar.luau`, and `PlotClient`):

| UI | Visible from |
| --- | --- |
| Shop button | finished or stage ≥ 10 |
| Inventory button | stage ≥ 8 |
| Rebirth button | stage ≥ 11 |
| Right sidebar + cash "+" | finished or stage ≥ 10 |
| Runner buttons (1×) | stage ≥ 2 (5×/25×/50× from stage ≥ 4) |
| Merge button | stage ≥ 5 |
| Crate prompt | stage ≥ 7 (auto-roll prompt stage ≥ 10) |

If you add UI behind gating, use `TutorialSlice.states` (`localTutorialStage` / `isTutorialFinished`) and mirror this table in the docs.

## Overlay mechanics

- `UINavigator` renders a dimming `UIStroke` spotlight (`DisplayOrder = 1_000_000`) sized to the target rect; `useTargetRect` supports GUI objects, parts, models, and `SurfaceGui` descendants; world targets project 8 bounding corners each `RenderStepped`.
- `useInstructor` renders a rich-text banner at `DisplayOrder = 1_000_001` (one above the navigator; ZIndex cannot cross ScreenGuis).
- `useArrowNavigator` clones the arrow asset, creates an `Attachment` on the local `HumanoidRootPart`, and points it at cached world attachments (`upgradeTable`, `runnerButton`, `mergeButton`, `luckyBlock`).

## Gotchas

- Never rename `TutorialRoot.luau` away from `*root*`.
- Plot child names and the arrow asset are hard dependencies; renaming them breaks specific steps at runtime.
- `TutorialSlice` must read data inside `task.spawn`; a module-scope `DataService:get` deadlocks before `DataService:init()`.
- Marker names/funnel step numbers are shared schema (`Markers.luau`, `OnboardingFunnel.luau`) — see [`analytics.md`](analytics.md). Tutorial stages 1–13 map to funnel steps 3–15 (`stage + 2`).
- The tutorial has **no completion reward**; finishing only sets `tutorial.finished`.
- Client-side validation is UX only; server endpoints are intentionally lenient (backward-only stages are not rejected).

## Related

- [UI](ui.md) — mount discovery and menu state
- [Analytics](analytics.md) — funnel steps and markers
- [Data flow · tutorial](../architecture/data-flow.md#tutorial)
