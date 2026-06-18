# Compiler: `task` keyword + `xtask` (atmos-lang side)

## Sidetrack: `every` -> `loop_on` emission (DONE)

Runtime renamed `M.every` -> `M.loop_on` (no `every` alias in
`init.lua`). The compiler emitted `every(...)`, undefined in the new
runtime. The surface keyword was already `loop on`; only the emitted
name was stale.

| file              | place                  | change                       |
|-------------------|------------------------|------------------------------|
| src/prim.lua      | `loop on` desugar :656 | emit `loop_on` not `every`   |
| tst/stmt.lua      | 5 tosource asserts     | `every(` -> `loop_on(`       |
| exs/hello.atm     | :5                     | `every` -> `loop on`         |
| exs/rx-behavior.atm | :9                   | `every` -> `loop on`         |
| exs/clicks.atm    | 5 sites                | `every [ids] [in]` -> `loop` |
| exs/click-drag-cancel.atm | 2 sites        | `every [ids] [in]` -> `loop` |

Note: `every` is no longer a keyword (`global.lua` KEYS has only
`loop`/`on`; lexer treats `every` as a plain id), so the stale `.atm`
forms no longer parsed -- now migrated. `doc/manual.md` code blocks
already use `loop on`; the `<!-- exs/exp-29-every.atm -->` marker is a
cosmetic stale label (left as-is).

## Decision: error traces label instances `task`, not `xtask`

The `trace()` frame label is a human-readable string only; identity is
the metatable (`getmetatable(x)==meta_xtask`). Users write `task`/
`spawn` in source and never type `xtask`, so traces echo their
vocabulary. Pool frames still read `tasks`; a trace shows `task`/
`tasks` but never `xtask`.

| repo                       | action                                       |
|----------------------------|----------------------------------------------|
| lua-atmos (runtime)        | `run.lua:184` emit `'task'` (was `'xtask'`)  |
| atmos-lang (this worktree) | NO change -- keep tst/exec.lua `(task)`      |

The `run.lua` edit is OUTSIDE this worktree; must be applied in the
lua-atmos worktree. Until then `tst/exec.lua` "defer 4" etc. fail
(runtime currently emits `xtask`).

## Status

IN PROGRESS. Companion to the lua-atmos runtime work, which
is DONE and GREEN (`/x/lua-atmos/atmos`, branch `260616-task-xtask`,
plan `.claude/plans/260616-task-xtask.md` §1-§2).

### Done so far

- Sidetrack `every` -> `loop_on` (src + tests + exs).
- Trace label decision: instances read `task` (runtime `run.lua:184`).
- Spawn emission migrated (src/prim.lua):
    - block `spawn {}` -> `do_spawn(fn)` (helper).
    - `spawn T()` -> `spawn(T, ...)` (dropped `false`).
    - `spawn @ts T()` -> `spawn_in(ts, T, ...)` (unchanged).
    - pin-wrap now triggers unless `spawn_in` (wraps `do_spawn` too,
      for its `<close>` handle).
    - transparent-reject detects `f.str=='do_spawn'` (boolean gone).
- src/run.lua:5 `atm_pin_chk_set`: `X.is(t,'task')` -> `'xtask'`.
- tst/stmt.lua tosource: dropped `false` from `spawn(false, T...)`.

- `task` keyword DONE + verified (compiled snippets):
    - global.lua: `'task'` moved into KEYS.
    - Surface model: `task` is decl-only; instance-from-proto is the
      plain call `xtask(T)` (xtask stays a non-keyword id). Old surface
      `task(fn)` call form is gone.
- AST refactor DONE + verified (behavior-preserving):
    - Renamed func node `tag='func'` -> `tag='proto'` with a single
      discriminator `sub` in {'lua','func','task'} (replaces both the
      old `lua=true` and the interim `task=true` flags). Rationale: a
      function literal IS a prototype (Lua compiles each to a Proto);
      the three are mutually exclusive, so one field suffices.
    - prim.lua: new `parser_proto(sub, dcl)` helper unifies func/task
      across all 3 locations (anon expr, named `set`, val/var/pin
      `dcl`); `::` method form gated to `sub=='func'`. 4 call sites
      collapse to one-liners.
    - coder.lua: sole reader -- `sub=='lua'`->raw fn; else
      `atm_func(...)`, +`task(...)` when `sub=='task'`.
    - tosource.lua / await.lua / parser.lua: `tag` checks ->'proto';
      tosource keyword via `sub=='task'`.
    - tst/stmt.lua (5 dumps) + tst/thread.lua tag check regenerated.

### Pending

- Test sweep (KEYWORD-FIRST style):
    - exec.lua "task N"/"emit 2": raw `func` protos -> `task T(){}`;
      `task(T)` instance -> `xtask(T)` / `spawn T()`.
    - expr.lua: `task(T)` call test -> `xtask(T)` (call form gone).
    - tst/tasks.lua bulk sweep + negative tests (raw-func spawn now
      rejected by runtime: "expected task prototype").
- aux.lua `atm_behavior`: bless behavior fn into proto once.
- run.lua:5 already done (xtask).
- doc/manual.md; rockspec bump.

This plan covers §3 "Compiler" of that runtime plan, adapted to the
CURRENT runtime API (the runtime was renamed after §3 was written).

## Context

The runtime now distinguishes prototype vs instance and splits spawn:

| concept             | runtime name | notes                          |
|---------------------|--------------|--------------------------------|
| prototype (abstract)| `task`       | non-callable tagged value      |
| instance (executing)| `xtask`      | `xtask()` = me, `xtask(T)` = new|
| pool                | `tasks`      | unchanged                      |
| spawn proto/instance| `spawn`      | opaque (was `spawn(false,…)`)  |
| spawn anon block    | `do_spawn`   | transparent (was `spawn(true,…)`)|
| spawn into pool     | `spawn_in`   | unchanged                      |
| event loop (`every`)| `loop_on`    | already migrated in atmos-lang |

`_is_`: prototype is `'task'`, instance is `'xtask'`.

IMPORTANT: the runtime is prepared natively, so the compiler needs NO
shadowing of `spawn`/`task` and NO tag remapping in `atm_is`
(`src/aux.lua`); `match`'s `_is_` agrees with `??` for free.

## Reconciliation (READ FIRST)

The runtime API changed vs the original §3 draft. Emission targets are
now the NEW names, NOT the old boolean form:

| surface              | OLD draft emit     | NEW emit (current runtime) |
|----------------------|--------------------|----------------------------|
| `spawn T()`          | `spawn(false,T,…)` | `spawn(T, …)`              |
| `spawn { }` (block)  | `spawn(true, fn)`  | `do_spawn(function() … end)`|
| `spawn @ts T()`      | `spawn_in(ts,T,…)` | `spawn_in(ts, T, …)` (same)|
| `await T()`          | `spawn(T,…)` await | unchanged (spawn then await)|

atmos-lang already has the `on` family settled (`loop on` / `toggle on`
/ `spawn on`, `every` removed -- see `06-11-spawn-on.md` /
`done/06-06-in-on.md`). `spawn on P {}` (one-shot concurrent handler)
desugars to a transparent block -> should emit `do_spawn`. Verify how
`spawn {}` and `spawn on` currently emit before changing.

## Scope (grounded in current src -- VERIFY line numbers)

| file              | change                                              |
|-------------------|-----------------------------------------------------|
| src/global.lua:37 | move `'task'` out of the reserved-comment list into |
|                   | KEYS (:35)                                           |
| src/prim.lua      | `task` declaration forms mirroring `func`:           |
|                   | `task T(){}`, `task M.f(){}`, `task (){}` (anon),    |
|                   | `val task T(){}`. No `::` method form.               |
| src/prim.lua      | spawn emission (`parser_spawn` :15, sites :201/:337/ |
|                   | :409): `spawn T()` -> `spawn(T,…)`; `spawn {}` ->    |
|                   | `do_spawn(fn)`; confirm `spawn @ts T()` stays        |
|                   | `spawn_in(ts,T,…)`.                                  |
| src/coder.lua     | reuse `tag='func'` node + new `task=true` flag: when |
|                   | set, wrap emitted `atm_func(...)` in `task(...)`.    |
|                   | `pub` access -> `assert(xtask(),'…').pub`.           |
| src/run.lua:5     | pin check `X.is(t,'task')` -> `'xtask'` (instances   |
|                   | are now `'xtask'`).                                  |
| src/aux.lua:63    | `atm_behavior`: bless the behavior fn into a proto   |
|                   | ONCE at module level (`local Tp = task(fn)`), then   |
|                   | `spawn_in(tsks, Tp, …)`.                             |
| src/aux.lua       | `atm_is`: NO change (native vocabulary).             |
| src/tosource.lua  | round-trip the `task` keyword / `task=true` flag.    |
| tst/              | sweep `tst/tasks.lua` (bulk): `func T` protos that   |
|                   | get spawned -> `task T`; `task(T)` instances ->      |
|                   | `xtask(T)`; `?? :task` instance checks -> `:xtask`.  |
|                   | NEW negative tests: `T()` direct-call fails;         |
|                   | `spawn F()`/`await F()` of a func fails;             |
|                   | `task(T)` of a prototype fails. Also `exs/*.atm`.    |
| doc/manual.md     | keyword lists (add `task`, drop from reserved);      |
|                   | value/ref type lists (add `xtask`); Task chapter     |
|                   | split prototype (`task`) vs instance (`xtask`);      |
|                   | `pin t = xtask(T)`; `t ?? :xtask`. (never            |
|                   | manual-out.md)                                       |

## Desugaring

```
task T (...) { ... }   -->   local T = task(atm_func(function (...)
                                 ...
                             end))
```

`xtask` is NOT a keyword -- it is a plain runtime identifier and a plain
tag, both already lexable.

## Dependency / CI

- Bump the lua-atmos dependency in the rockspec to the new major.
- CI uses a sibling checkout (`LUA_PATH=../lua-atmos/...`); pin/point at
  the runtime branch `260616-task-xtask` until both land.

## Open questions (from runtime plan §5)

1. `::` method form for `task` -- rejected for now.
2. Anonymous `task (...) { ... }` expression -- include, or rely on
   `task(\…)`?
3. `pin task T()` -- reject in parser (protos are not pinnable)?
4. `toggle T()` on a prototype vs instances only -- lean instances.

## Notes

- Drafted from the lua-atmos worktree; line numbers come from a quick
  grep and MUST be re-verified against the current atmos-lang `src/`.
- Rollout: runtime first (DONE), then this compiler work, then f-streams
  audit of `spawn_in` call sites reached from streams.
