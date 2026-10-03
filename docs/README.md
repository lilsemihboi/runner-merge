# RunnerMerge Documentation

Developer and AI-agent documentation for **Merge Cars** (`lilsemihboi/runner-merge`).

These docs describe the `main` branch and the published place that matches it. They exist so an agent or new developer can make a change without rediscovering the architecture, and without breaking the invariants that keep the game deterministic and server-authoritative.

> [!IMPORTANT]
> The code is the source of truth. If a doc conflicts with `src/`, trust the code and then fix the doc. Numeric balance values (costs, multipliers, odds) change often — always re-check the file named in a doc instead of quoting a value from memory.

## Where to start

| Doc | Read it before… |
| --- | --- |
| [`architecture/overview.md`](architecture/overview.md) | Touching anything. Runtime topology, boot order, service pattern, packages, code/content boundary |
| [`architecture/data-flow.md`](architecture/data-flow.md) | Tracing an end-to-end flow (income, merges, crates, rebirth, purchases, offline earnings) |
| [`systems/runner-simulation.md`](systems/runner-simulation.md) | **Any** change to runners, paths, gates, income, or speed. Contains the determinism contract |
| [`systems/plots-and-gates.md`](systems/plots-and-gates.md) | Changing plot lifecycle, upgrades, gates, runway/crate placement, plot UI buttons |
| [`systems/player-data.md`](systems/player-data.md) | Adding/renaming persisted fields, touching `DataService`/`ProfileServer`, migrations |
| [`systems/economy.md`](systems/economy.md) | Changing costs, income, trails, routes, rebirth, runner pricing |
| [`systems/crates-and-stock.md`](systems/crates-and-stock.md) | Changing crates, trail drops, lap rewards, auto-roll, limited stock |
| [`systems/monetization.md`](systems/monetization.md) | Changing products, passes, receipts, gifting, rewarded ads, offline earnings, inventory |
| [`systems/tutorial.md`](systems/tutorial.md) | Changing onboarding, tutorial steps, HUD gating |
| [`systems/analytics.md`](systems/analytics.md) | Adding or renaming markers/funnel steps, touching Gamebeast or Roblox analytics |
| [`systems/ui.md`](systems/ui.md) | Adding/removing UI screens, menu lifecycle, Vide/Charm state |
| [`services/catalog.md`](services/catalog.md) | Looking up a service's Networker id, endpoints, events, or data keys |
| [`guides/`](guides/) | Step-by-step recipes: add a service, endpoint, UI screen, item/asset, product/reward, balance change |
| [`reference/rojo-mapping.md`](reference/rojo-mapping.md) | Adding/renaming files. Explains generated instance names and require paths |
| [`reference/scripting-standards.md`](reference/scripting-standards.md) | Writing Luau. Naming, structure, `const`, style tooling |
| [`reference/gotchas.md`](reference/gotchas.md) | Before finishing a change. Central list of traps |

[`../AGENTS.md`](../AGENTS.md) is the short hub with the hard rules and commands.

## Conventions used in these docs

- Paths are relative to the repo root. `src/services/...` is source; `ServerScriptService.Services...` / `ReplicatedStorage.Shared...` are **generated instance paths** (see [`reference/rojo-mapping.md`](reference/rojo-mapping.md)).
- "Place-managed" content (models, UI templates, `ReplicatedStorage.Assets`) lives in the `.rbxl` place file, not in `src/`. Rojo does not build it.
- Tables of endpoints/events use the names passed to Networker, not function names.
- `docs/` describes game code; `AlgoTips/` is a separate, untracked game-marketing knowledge base with its own `AGENTS.md` — do not mix it into code docs.

## Keeping docs current

When you make a change:

1. Update the system doc that owns the changed behavior.
2. Update [`services/catalog.md`](services/catalog.md) if a Networker id, endpoint, event, or data key changed.
3. Update [`architecture/data-flow.md`](architecture/data-flow.md) if the change alters an end-to-end flow.
4. Update [`../AGENTS.md`](../AGENTS.md) only for rules that all changes must follow.
