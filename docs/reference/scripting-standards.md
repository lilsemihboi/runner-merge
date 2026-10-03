# Scripting Standards

Project rules for writing Luau here. They mirror `AGENTS.md`; this page adds the rationale and examples.

## Style tooling

- `.luaurc` sets `"languageMode": "strict"`. Only `src/library/Server.server.luau` and `src/library/Client.client.luau` opt out with `--!nonstrict`.
- `stylua.toml`: tabs, Windows line endings, 160-column width, double-preferred quotes, always-parenthesized calls, sorted requires.
  - Format with `stylua src`. Don't hand-fix formatting.
- `selene.toml`: Roblox standard library, mixed tables allowed.
  - Lint with `selene src`.
- Both tools are pinned in `rokit.toml` (stylua 2.5.2, selene 0.31.0) and both understand the 2026 `const` keyword.

## `const` vs `local`

`const` is a valid Luau keyword for immutable bindings. This codebase uses it for **module-scope** bindings — requires, constants, top-level functions:

```lua
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Networker = require(ReplicatedStorage.Packages.Networker)
const MAX_ROLLS = 10
```

`local` stays in place for reassignable bindings inside function bodies (and for anything that would be reassigned). Follow the file you are editing; do not "fix" an existing `const` to `local`, and do not mass-convert files.

## Naming

1. Use descriptive, obvious names.
   - No abbreviations: `player` beats `plr`.
   - Direct names: `wasCalled` beats `hasBeenCalled`; `notify` beats `doNotification`.
   - Booleans read as yes/no questions: `isFirstRun`, not `firstRun`.
   - Functions use verb forms: `increment`, `unzip`.
   - Event handlers express when they run: `onClick`, not `click`.
2. Positive form.
   - `isFlying` beats `isNotFlying`; `late` beats `notOnTime`.
   - Lead with positive conditionals; avoid `if not x then ... else ... end`.
   - Name the inverse when that's what you mean: `missingValue` instead of `not hasValue`.

## Function signatures

- Avoid boolean parameters that change behavior (code smell). Prefer two functions or an options table.
- Avoid `nil` arguments; use an optional options table as the last/only parameter.
- Server methods always take `player` first (Networker injects it), then validated arguments.

## Code structure

- **Write less code.** Fewer lines, fewer bugs. Omit single-use variables. Reuse well-supported packages instead of reinventing.
- **Colocate by feature, not type.** A feature owns its state and exposes methods to read/change it.
- **One job per function.** Loading and calculating should be separate; keep side effects explicit and obvious.
- **Prefer safe patterns.** If a feature is sometimes dangerous and a safer option exists, use the safer option.
- **Classes for things that can exist more than once.** Use stateful instances with explicit cleanup (Janitor for connections/instances). Prefer composition over inheritance. Provide getters/setters instead of exposing mutable state.
- **Generic over specific; parallel code for parallel concepts.** When repeating a pattern, keep the shape consistent so it reads quickly.
- **Optimize for reading.** Comments answer "why", not "what". Be idiomatic and unsurprising; avoid clever metaprogramming.
- **Exceptions should be exceptional.** Return success values (e.g. `"SUCCESS"` / `InfoEnums` keys) for expected failures; reserve `error`/`assert` for unrecoverable misuse. Serverside, the common return shape is `(boolean, string)` or a status string.

## Realm and file conventions

- Services live in `src/services/<name>/` with `Server.luau`, optionally `Client.luau`/`Utils.luau`; wiring happens in `src/library/*.luau` only.
- Shared helpers live in `src/modules/`; shared classes in `src/classes/`.
- After adding/renaming files: `npm run build:rojo`. Check require paths against [`rojo-mapping.md`](rojo-mapping.md).

## Before you finish

1. `stylua src`
2. `selene src`
3. `npm run build:rojo` if files were added/renamed (also required on a fresh checkout/pull).
4. Manual Studio verification for behavior changes; there is no test suite in this repo.

## Related

- [`../AGENTS.md`](../../AGENTS.md) — the short rules hub
- [`gotchas.md`](gotchas.md)
- [`rojo-mapping.md`](rojo-mapping.md)
