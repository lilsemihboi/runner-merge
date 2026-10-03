# UI

The UI is built with **Vide** (declarative, reactive UI runtime) and **Charm** (reactive atoms bridged from `DataService`). Every screen is a Lua module under `src/ui/`; there are no `.rbxmx` ScreenGuis for menus.

## Mounting

`MountUI()` (`src/ui/App/MountUI.luau`) runs late in the client entrypoint:

1. `TopBarButtons()` — TopbarPlus buttons.
2. `Vide.mount(RootUI, playerGui)`.

`RootUI` (`src/ui/App/RootUI.luau`) mounts itself plus every "root" module it discovers:

```lua
for _, module in ReplicatedStorage.Shared.UI:GetDescendants() do
	if module:IsA("ModuleScript") and module.Name:lower():find("root") and module ~= script and not module.Name:find(".story") then
		table.insert(capturedRoots, require(module))
	end
end
```

Current roots: `src/ui/Hud/Root.luau`, `src/ui/Menus/MenuRoot.luau`, `src/ui/Tutorial/TutorialRoot.luau`. `CratesScreen`, `ErrorMessage`, `NotificationMessage`, and `Notifications.Screen()` are mounted explicitly in `RootUI`.

**Rule:** a new always-on screen is mounted by naming its module with `root` (case-insensitive). Menus are different — they render through `Menu.Component` and appear when `Menu.setOpenedMenu(id)` selects them.

## Menu lifecycle (`src/ui/App/components/Menu.luau`)

- `Menu.openedMenu()` is a Vide source holding the open menu id (or `nil`); items return `{ menuId, alwaysMounted?, Component, ... }`.
- `Menu.setOpenedMenu(id, options?)` toggles: setting the current id closes it. Opening `"Shop"` logs `storeOpened` (`restore` when `options.isRestoringPreviousMenu`). Opening `"GroupRewards"` prompts the Roblox favorite once.
- `Menu.closeCurrentMenu()` closes through the menu's `OnClose` if provided (OfflineRewards claims its reward when closed).
- **Overlays must hide, not close**: `Menu.hideOpenMenu(reason)` / `Menu.restoreOpenMenu(reason)` suppress rendering while keeping `openedMenu` unchanged (reasons are ref-counted). Closing would fire menu intents twice — e.g. the offline claim.
- Menus animate open/close (spring scale, `CLOSE_RENDER_DURATION = 0.5`) and unmount unless `alwaysMounted`.

Menu ids in use: `Shop`, `Index`, `Inventory`, `Rebirth`, `Routes`, `Settings`, `OfflineRewards`, `GroupRewards`, `GiftingMenu`, `GiftReceivedMenu`. The crate reel (`CratesScreen`) is a full-screen overlay mounted directly by `RootUI`, not a `Menu` menu — it hides the HUD via `HudSlice`/`Menu.hideOpenMenu` instead.

## State: Vide sources and Charm atoms

Two reactive styles, deliberately:

| Style | Where | Bridge |
| --- | --- | --- |
| **Vide sources** (`Vide.source`, `derive`, `effect`) | UI-local state (slices) | Used directly in components |
| **Charm atoms** (`GetDataSource`) | Player data signals (`cash`, `runners`, settings) and cross-service state | `VideCharm.useAtom` / `useSignalState`, or `VideCharm` directly |

`src/modules/ui/Sources/GetDataSource.luau` returns a Charm atom bound to a `DataService` path — the canonical way for UI to read player data reactively. `src/modules/ui/Sources/PreferredInputSource.luau` tracks input device.

Slices (Vide sources / Charm atoms in `*.luau` Slice modules): `HudSlice`, `ShopSlice`, `CratesSlice`, `OfflineEarningsSlice`, `LeaderboardSlice`, `StockSlice`, `TutorialSlice`, `RewardedAdSlice`, plus per-menu local state. Slices hold **client-only** state; persisted state always lives in the profile.

## Where UI lives

```
src/ui/
├── App/                 # RootUI, MountUI, shared components (Menu, buttons, Stud frames), hooks
├── Crates/              # Crate reel screen + slice
├── Gifts/               # GiftingMenu, GiftReceivedMenu
├── GroupRewards/        # GroupRewardsMenu
├── Hud/                 # Root, CashBar, SideButtons, TopBarButtons, Notice, Purchasing, income UI
├── Index/               # IndexMenu (owned cars)
├── Inventory/           # InventoryMenu (trails)
├── Menus/               # MenuRoot
├── OfflineRewards/      # OfflineMenu
├── Rebirth/             # RebirthMenu
├── Routes/              # RoutesMenu
├── Settings/            # SettingsMenu
├── Shop/                # ShopMenu, ShopSlice, Frames/*, Components/*
└── Tutorial/            # TutorialRoot + overlay components
```

Reusable helpers live in `src/modules/ui/` (formatting, primitives, sources); shared components in `src/ui/App/components/`.

| Module (src/modules/ui) | Purpose |
| --- | --- |
| `Primitives/Frame.luau`, `TextLabel.luau`, `ImageLabel.luau`, `Button.luau` | Vide wrappers injecting common defaults (strokes, fonts, scale) |
| `Components/ErrorMessage.luau`, `NotificationMessage.luau`, `PlayerPortrait.luau` | Reusable UI pieces |
| `Abbreviate`, `Comma`, `AddSuffix`, `Suffixes` | Number formatting |
| `FormatCurrency`, `FormatPercent`, `FormatTime`, `FormatNameWithIcons` | Formatting |
| `AutoGradient`, `ButtonColors`, `CoolTransistions`, `GetPlayerPortaitImage` | Visual helpers |
| `Sources/GetDataSource`, `PreferredInputSource` | Reactive sources |

Hooks in `src/ui/App/hooks/`: `usePx` (design-resolution scaling, initialized once in `RootUI`), `useOrder`, `getVideDataSource`.

## Conventions and gotchas

- Use `usePx` for sizes so UI scales across devices — don't hardcode pixels.
- Read player data through `GetDataSource`; never poll `DataService` in render.
- New menu: create `src/ui/<Name>/<Name>Menu.luau` returning `{ menuId, alwaysMounted?, Component = Menu.Component({...}) }`, plus a shop/HUD entry point. See [`guides/adding-a-ui-screen.md`](../guides/adding-a-ui-screen.md).
- Renaming a `*root*` module changes mounting behavior; `*.story.luau` files are excluded on purpose (`root.story.luau` is a Vide story, not a mount).
- Overlays (Purchasing, crate screen, Roblox menu) hide menus via `hideOpenMenu`; closing instead can double-fire `OnClose` intents.
- `Menu.openedMenu` is a Vide source; read it with tracking in effects or `Vide.untrack` in writers.
- `CratesSlice` uses Charm atoms, not Vide sources — consume with `VideCharm.useAtom`.
- Some UI strings come from `src/modules/utils/InfoEnums.luau`; add new user-facing errors there.
- After adding/renaming UI files run `npm run build:rojo` (folder `ui` → `UI`, `hooks` → `Hooks`, `components` → `Components`).

## Related

- [Tutorial](tutorial.md) — overlay system and HUD gating
- [Crates and stock](crates-and-stock.md) — crate screen
- [Rojo mapping](../reference/rojo-mapping.md)
