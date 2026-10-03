# Adding Items and Assets

Two pipelines feed game content:

| Kind | Source | Tool | Output |
| --- | --- | --- | --- |
| Image asset ids referenced by code | `assets/**` (e.g. `assets/images/settings.png`) | Asphalt (`asphalt` CLI from `rokit.toml`) | Generated `src/modules/items/assets.luau` |
| 3D models and world content | The place file | Studio | `ReplicatedStorage.Assets.*`, `workspace._PLOTS.*` |

## Asphalt asset ids

`asphalt.toml`:

```toml
[creator]
type = "group"
id = 113923204

[codegen]
typescript = false
style = "nested"
strip_extensions = true

[inputs.assets]
path = "assets/**"
output_path = "src/modules/items/"
```

Workflow:

1. Add the file under `assets/` (currently `assets/images/*.png`).
2. Run `asphalt` (installed by `rokit`; use `rokit install` first on a fresh machine).
3. Commit the updated `src/modules/items/assets.luau` **and** the input file.
4. Use it as `require(ReplicatedStorage.Shared.Modules.Items.Assets).images.settings`.

`src/modules/items/assets.luau` is generated — never edit it by hand. As it has no `Server` in the filename it lives under `ReplicatedStorage.Shared.Modules.Items`.

## Place-managed content

These are authored in Studio; code references them **by name**. Renaming any of them breaks code silently, so grep first.

### Runner (car) model

1. Add a `Model` under `ReplicatedStorage.Assets.Entities` named with its numeric id.
2. Regular cars use ids 1–40 and derive income/speed from `RunnerUtils` (`10 * level^3`, `8 + floor((level-1)^1.35 * 0.8)`); display name/image live in `src/modules/items/CarIds.luau` (cosmetic).
3. Exclusive cars use ids ≥ 1000 (`ExclusiveCars.ID_BASE`) and must be registered in `src/modules/items/ExclusiveCars.luau` with explicit `name`, `imageId`, `incomePerLap`, `speed`, `rarity`. They never merge and bypass `runnerPurchases`.
4. Grant path for exclusives: `Profile:giveExclusiveRunner(id)` via the `exclusiveCar` product / stock flow — see [`../systems/monetization.md`](../systems/monetization.md).

### Trail

1. Add an entry to `src/modules/items/Trails.luau` (`trailMultiplier`, `trailName`, `trailColorSequence`, `trailRarity`).
2. Add loot weights for it to the relevant crates in `src/modules/items/Blocks.luau` (keep each crate's weights summing to 100 so `getOdds` reads as percentages).
3. Optionally add a `Rarities` color (already present for all six rarities).
4. No model needed — trails color a `Trail` instance inside runner models.

### Crate / lucky block

1. Add the definition to `src/modules/items/Blocks.luau` (`lapsRequirement`, `blockWeight`, `blockName`, `loot`).
2. Add its model under `ReplicatedStorage.Assets.Blocks` named `tostring(id)` (code clones it; missing model = no crate).
3. If it is purchasable, add the product entry + `CRATE_PRODUCTS` mapping — see [`adding-a-code-or-product.md`](adding-a-code-or-product.md).

### Route / runway

1. Add the route row to `src/services/routeService/Utils.luau` (`gateCap`, `cashGateCap`, `rebirthRequirement`, `cashMultiplier`, `imageId`).
2. Add `ReplicatedStorage.Assets.Runways.Runway<routeId>` containing:
   - `waypoints/lane<N>/` folders with numerically named `Attachment`s (sorted by `tonumber`), at least 2 per lane;
   - `gateAttachments/<gateId>` attachments for every gate id up to `gateCap`.
3. `Plot.buildRunway` clones it to `Runway`; `PathData` caches and invalidates on route change. No code change needed for a new route beyond the table row.
4. Test: select the route, verify runners follow the path and `gateAttachments` align with the visible gates (`GateServer` places gates at the same attachments).

### Image / thumbnail ids in code

UI images (route cards, car images, notification icons) reference raw `rbxassetid://…` strings in the owning modules (`CarIds`, `ExclusiveCars`, `RouteServiceUtils`, `Trails`, UI modules). Uploading new images is an external step; treat ids as content, not code.

## Checklist

- [ ] Do **not** hand-edit `src/modules/items/assets.luau`; rerun Asphalt.
- [ ] New `src/` files/renames → `npm run build:rojo`.
- [ ] Model/attachment names match what code looks up (`Entities.<id>`, `Blocks.<crateId>`, `Runways.Runway<routeId>`, `gateAttachments.<gateId>`).
- [ ] Crate weights sum to 100; trail ids unique.
- [ ] Exclusive car ids ≥ 1000 and registered with explicit stats.
- [ ] Balance docs/tools updated if the new content changes progression — see [`changing-game-balance.md`](changing-game-balance.md).
