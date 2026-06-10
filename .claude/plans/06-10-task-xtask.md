# Task Prototypes vs Instances — `task` / `xtask`

## 1. Context

Today a "task prototype" is just a `func` — a plain Lua function by the
time the runtime sees it (`src/coder.lua:121` wraps it in `atm_func`).
The distinction between a function and a task prototype is pure intent,
invisible at runtime, so nothing can be enforced:

- `spawn F()` of an ordinary function silently runs it as a task.
- `await F()` sugar (`src/prim.lua:197-214`) silently *spawns* an
  ordinary function — almost certainly a bug, never an intent.
- `T()` of a task prototype silently runs it as a function, with
  `await` hijacking the caller's coroutine.

The fix is a `task` keyword for prototypes, plus a vocabulary split
between the prototype and the executing instance:

| Concept              | Name    | Why                                  |
| -------------------- | ------- | ------------------------------------ |
| prototype (abstract) | `task`  | written constantly — gets plain name |
| instance (executing) | `xtask` | "x" = executing; checked rarely      |
| pool                 | `tasks` | kept — "task pool" names the concept |

No tag hierarchy (`:task:x` rejected) — two flat tags `:task` and
`:xtask`. Spelled `xtask` (no hyphen/underscore): valid identifier and
valid tag today, zero lexer changes.

The governing rule, which keeps `tra` (transparency) coherent:

> **Functions are inline bodies; prototypes are spawnable
> abstractions.** A transparent task is an inline body, so `tra=true`
> only ever accompanies a raw function. A transparent *prototype* is a
> contradiction (transparency = no identity; prototypes exist to have
> one) — the parser already encodes this instinct (`src/prim.lua:372`).

Enforcement is structural, not instrumented: a prototype is a
*non-callable* tagged value, so `T()` fails via Lua itself ("attempt to
call a table value") with zero call-site overhead, and `spawn`/`await`
of a raw function fails with an explicit runtime error.

The runtime is prepared natively (not shimmed in the compiler layer),
so `_is_`, `??`, `match`, native-Lua blocks, error messages, and pure
lua-atmos users all share one vocabulary.

## 2. Runtime — lua-atmos (separate repo, lands FIRST)

### 2.1 New public API

| Call            | Before                  | After                          |
| --------------- | ----------------------- | ------------------------------ |
| `task(f)`       | unstarted instance      | **prototype** from function    |
| `task()`        | current task (me)       | removed — use `xtask()`        |
| `xtask()`       | —                       | current executing task (me)    |
| `xtask(T)`      | —                       | unstarted instance from proto  |
| `spawn(...)`    | any function            | see dispatch table 2.2         |
| `spawn_in(...)` | any function            | prototypes only                |
| `_is_(v,?)`     | instance is `'task'`    | proto `'task'`, inst `'xtask'` |

- `task(f)` accepts **any** Lua function and returns a non-callable
  value (table, marker metatable, meta-tag `'task'`). It is both the
  desugaring target of the Atmos keyword and the interop blessing path
  for foreign functions. Passing a prototype to `task` is an error
  (no silent re-wrap).
- `xtask()` / `xtask(T)` absorb the two old overloads of `task()`,
  resolving the constructor/query pun.

### 2.2 `spawn` dispatch

`tra` is still required — `par*`/`watching`/`every` create transparent
tasks underneath via `run.spawn(true, f, ...)`, which is unchanged.
Only the public dispatch sharpens:

| Call                | Meaning                                       |
| ------------------- | --------------------------------------------- |
| `spawn(true, f, …)` | transparent inline body — raw function        |
| `spawn(T, …)`       | prototype → fresh `:xtask`                    |
| `spawn(t, …)`       | pre-instantiated `:xtask` → start it          |
| `spawn(f, …)`       | ERR: "invalid spawn : expected task prototype"|
| `spawn(true, T, …)` | ERR: transparent prototype is a contradiction |

The `spawn(false, f, ...)` form emitted by the compiler today
(`src/prim.lua:72`) is dropped from the public surface (may remain as
an internal `run.spawn` detail).

### 2.3 Internal changes

| Concern           | Change                                          |
| ----------------- | ----------------------------------------------- |
| instance meta-tag | `'task'` → `'xtask'` everywhere internally      |
| `tostring`        | `task: 0x…` (proto) / `xtask: 0x…` (instance)   |
| combinators       | unchanged — keep raw functions, `tra=true`      |
| `tasks(n)` pool   | unchanged name; members are `:xtask`            |
| `toggle`, `abort`,| vocab-only: internal `_is_(t,'task')` checks    |
| `emit_in`         | become `'xtask'`                                |
| `await(spw)`      | unchanged — receives the `:xtask` from spawn    |
| errors            | messages distinguish "task prototype" vs        |
|                   | "executing task (xtask)"                        |

### 2.4 Migration for pure-Lua users (major version bump)

| Before                  | After                          |
| ----------------------- | ------------------------------ |
| `spawn(f, ...)`         | `spawn(task(f), ...)`          |
| `spawn(true, f, ...)`   | unchanged (transparent body)   |
| `task(f)` (instance)    | `xtask(task(f))`               |
| `task()` (me)           | `xtask()`                      |
| `_is_(t, 'task')`       | `_is_(t, 'xtask')`             |

## 3. Compiler — atmos (this repo, lands SECOND)

Because the runtime is prepared natively, the compiler layer needs **no
shadowing of `spawn`/`task` and no tag remapping in `atm_is`**
(`src/aux.lua:88`); `match`'s direct use of `_is_` (`src/prim.lua:638`)
agrees with `??` for free.

### 3.1 Keyword and grammar

`task` moves from the reserved comment (`src/global.lua:28`) into
`KEYS`. Declaration forms mirror `func` (`src/prim.lua:283-326,346`):

```
task T (...) { ... }        ;; named prototype
task M.f (...) { ... }      ;; dotted (module) prototype
task (...) { ... }          ;; anonymous prototype (expression)
val task T (...) { ... }    ;; explicit-dcl form, like `val func`
```

- No `::` method form — a task is not a method (open question 5.1).
- `xtask` is NOT a keyword — it is a plain runtime identifier and a
  plain tag, both already lexable.
- Desugaring is exactly parallel to `func` → Lua function:

```
task T (...) { ... }   -->   local T = task(atm_func(function (...)
                                 ...
                             end))
```

### 3.2 AST and coder

- Reuse `tag='func'` nodes with a new `task=true` flag (less churn in
  `coder.lua` / `tosource.lua` than a new node tag).
- `src/coder.lua:102-123`: when `e.task`, wrap the emitted
  `atm_func(...)` in `task(...)`.
- `src/coder.lua:54`: `pub` access becomes
  `assert(xtask(), 'invalid pub : expected enclosing task').pub`.

### 3.3 Emission changes (prim.lua)

| Site                      | Before                     | After          |
| ------------------------- | -------------------------- | -------------- |
| `spawn T()` `:72`         | `spawn(false, T, …)`       | `spawn(T, …)`  |
| `spawn {}` `:8`           | `spawn(true, fn)`          | unchanged      |
| `await T()` `:210`        | `spawn(T, …)` (no bool)    | unchanged      |
| `spawn [ts] T()` `:70`    | `spawn_in(ts, T, …)`       | unchanged      |
| transparent-assign `:372` | parse error                | unchanged      |

### 3.4 Support layer

| File              | Change                                          |
| ----------------- | ----------------------------------------------- |
| `src/run.lua:3`   | pin check `'task'` → `'xtask'`                  |
| `src/aux.lua:136` | `atm_behavior`: bless once at module level —    |
|                   | `local Tp = task(T)` and `spawn_in(tsks, Tp,…)` |
| `src/aux.lua:88`  | `atm_is` — NO change (native vocabulary)        |

### 3.5 Tests

`tst/tasks.lua` is the bulk (300+ spawns). Mechanical sweeps:

- `func T` prototypes that get spawned/awaited → `task T`.
- `task(T)` instance constructions (`:120,198,640,2650`) → `xtask(T)`.
- `task(func() {…})` (`:393,406`) → `xtask(task(\…))` or `task` exprs.
- `` abort(`task()`) `` (`:1745`) → `` abort(`xtask()`) ``.
- `?? :task` instance checks → `?? :xtask`.
- NEW negative tests: `T()` direct call fails; `spawn F()` /
  `await F()` of a func fails; `spawn(true, T)` fails; `task(T)` of a
  prototype fails.

Also sweep `exs/*.atm` and `tst/streams.lua` for spawned prototypes.

### 3.6 Manual (`doc/manual.md` only — never `manual-out.md`)

| Place        | Change                                              |
| ------------ | --------------------------------------------------- |
| `:35,340`    | keyword lists: add `task`; drop from reserved list  |
| `:448-455`   | prototype listing: `task` prototype / `xtask`       |
| `:622,631`   | value/reference type lists: add `xtask`             |
| `:787-835`   | Task chapter: split prototype (`task`) vs instance  |
|              | (`xtask`); `pin t = xtask(T)`; `t ?? :xtask`        |
| `:813-818`   | example: `T ?? :function` → `T ?? :task`            |
| `:862-887`   | transparent tasks: tie to the inline-body rule      |
| `:889+`      | tasks chapter: pool of xtasks, name kept            |

### 3.7 Dependency / CI

- Bump the lua-atmos dependency in the rockspec to the new major.
- CI uses a sibling checkout (`LUA_PATH=../lua-atmos/...`) — the
  compiler branch must pin/point at the prepared runtime branch until
  both land.

## 4. Rollout Order

1. lua-atmos: prototype type, `xtask`, spawn dispatch, rename, docs,
   major version bump.
2. atmos: this plan's section 3, against the new runtime.
3. f-streams: audit `spawn_in` call sites reached from streams
   (`src/aux.lua:125-138` is the entry from this repo).

The repos can move independently — the compiler pins its runtime
version, so no flag day.

## 5. Open Questions

1. `::` method form for `task` — rejected for now; revisit if a use
   case appears.
2. Anonymous `task (...) { ... }` expression — included above; drop if
   `task(\…)` is deemed sufficient.
3. Should `pin task T()` be rejected (prototypes are not pinnable
   resources) or silently behave as `val`? Lean: reject in parser.
4. `tostring` spellings (`task:` / `xtask:` prefixes) — cosmetic,
   decide in lua-atmos.
5. Does `toggle T()` ever make sense on a prototype (spawn-toggled),
   or instances only? Lean: instances only, vocab-only change.
