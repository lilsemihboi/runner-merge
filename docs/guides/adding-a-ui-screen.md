# Adding a UI Screen

Screens are Lua modules under `src/ui/`. Menus render through the shared `Menu.Component`; always-on screens are mounted by `RootUI` when their module name contains `root`.

## 1. Create the menu module

Follow an existing menu, e.g. `src/ui/Settings/SettingsMenu.luau`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Menu = require(ReplicatedStorage.Shared.UI.App.Components.Menu)
local usePx = require(ReplicatedStorage.Shared.UI.App.Hooks.usePx)

return {
	menuId = "Rocket",
	alwaysMounted = false, -- true keeps it alive while closed

	Component = Menu.Component({
		menuId = "Rocket",
		Title = "Rocket",
		Scale = 1,
		ShowTitle = true,
		ShowCloseButton = true,
		Size = usePx.offset(1008, 802),
		-- children...
	}),
}
```

`Menu.Component` handles the frame, title bar, close button, and open/close springs. `OnClose` runs instead of the default close when provided.

## 2. Open it from an entry point

```lua
local Menu = require(ReplicatedStorage.Shared.UI.App.Components.Menu)
Menu.setOpenedMenu("Rocket")
```

- `setOpenedMenu(id)` toggles: passing the currently open id closes it.
- Add a button/icon where players expect it (`src/ui/Hud/SideButtons.luau`, `CashBar`, `RightSide`, or a plot button) and check the tutorial gating table in [`../systems/tutorial.md`](../systems/tutorial.md) so the button isn't visible before it should be.
- Opening `"Shop"` automatically logs `storeOpened`; other menus don't.
- Overlays must use `Menu.hideOpenMenu(reason)` / `Menu.restoreOpenMenu(reason)` instead of closing/reopening the open menu — closing fires `OnClose` intents (e.g. the offline claim) twice.

## 3. State

| State kind | Where |
| --- | --- |
| Persisted player data | Read with `GetDataSource(path)` (`src/modules/ui/Sources/GetDataSource.luau`) |
| Cross-screen client state | A slice module (`ShopSlice`, `CratesSlice`, …) using `Vide.source` or `Charm.atom` |
| Screen-local state | `Vide.source` inside the component |

Minimal slice:

```lua
local Vide = require(ReplicatedStorage.Packages.Vide)

return {
	state = {
		selectedRocket = Vide.source(nil),
	},
}
```

If the slice uses Charm atoms, consume them with `VideCharm.useAtom`.

## 4. Always-on screens

Name the module with `root` (e.g. `src/ui/Rocket/RocketRoot.luau`) and it is mounted by `RootUI.captureRoots`. `*.story.luau` files are skipped. `RootUI` mounts roots plus `CratesScreen`, error/notification overlays, and `Notifications.Screen()`.

## 5. Verify

```powershell
npm run build:rojo   # new/renamed files must become instances
stylua src
```

Then test in Studio:
- the menu opens/closes and doesn't leak connections after closing (use `Vide.cleanup`/`Janitor` for listeners);
- with an overlay open (`Purchasing`, crate screen), the underlying menu hides and restores;
- mobile scaling via `usePx` (no hardcoded pixels);
- tutorial gating hides the entry point until the right stage.

## Checklist

- [ ] `menuId` matches the `setOpenedMenu` id.
- [ ] Entry point added and tutorial-gated where relevant.
- [ ] Persisted reads go through `GetDataSource`; local state lives in a slice/source.
- [ ] `usePx` for sizing.
- [ ] `npm run build:rojo`, `stylua src`, `selene src`.
- [ ] [`../systems/ui.md`](../systems/ui.md) menu list updated if the screen is persistent.
