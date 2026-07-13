# await-patt-task : promote `await T(...)` to a first-class pattern

## Goal

Let `await T(...)` (spawn-and-await a task prototype) compose with the
pattern combinators instead of being a parser-level special case:

```
await T(...) || :X          ;; either T terminates or :X fires
await T(...) until c
watching T(...)             ;; and inside spawn/loop-on filters
:any [T(a), U(b)]
```

Today `await T(...)` bypasses `parser_await` entirely and cannot combine
with `&&` / `||` / `!`, `until`/`while`, or `:any`/`:all`.

## Current state

### Parser : special case

`src/prim.lua:164-194`

- `await` + next token is an id  -> `check(nil,'id')` branch
    - parses full call via `parser_6_pip`
    - rewrites `T(...)`  ->  `await(T, ...)` (args spread, `call.f` first)
    - never touches `parser_await`
- otherwise (`(` or juxtaposed pattern) -> `parser_await`

### Pattern parser

`src/await.lua`

- `parser_await(stop, base0)` : pool prefix, `until`/`while`, base +
  `&&`/`||`/`!` combinators
- juxtaposition base is `parser_1_prim` (single primary) : will NOT
  consume a `(...)` call postfix -> reason the special case grabs the
  call with `parser_6_pip`
- `await_ast_logical` stops at `call` nodes, passing them verbatim
- `mk_tagged` / `:any`/`:all` build combinator tables from task
  **instances** and tags

### Runtime : already unified

`atmos/init.lua:72-82` (installed lua-atmos)

```lua
function await (awt, ...)
    if X.is(awt, 'task') then      -- prototype -> spawn + await instance
        return await(run.spawn(debug.getinfo(2), nil, false, awt, ...))
    elseif type(awt) == 'function' then
        assertn(2, false, "invalid spawn : expected task prototype")
    else                           -- combinator table
        return run.await(run.TIME, awt, ...)
    end
end
```

The runtime already accepts a task prototype as an await argument. The
gap is purely that a prototype cannot yet be embedded *inside* a
combinator table : `run.await` / `:any`/`:all` expect task instances.

## Blockers

| blocker                                   | where               |
|-------------------------------------------|---------------------|
| call not consumed in juxtaposition base   | `await.lua:81` `parser_1_prim` |
| `await_ast_logical` passes `call` verbatim| `await.lua:29-30`   |
| combinator items must be task instances   | `mk_tagged`, `:any`/`:all` |

Inside a `||`, a bare `T()` would be *called*, not spawned-then-awaited.

## BLOCKER : run.await has no lazy task-spawn (revises approach)

Earlier assumption "task drops into the run.await combinator table
unchanged" is FALSE :

- `run.watching(awt, f)` = `par_any(\() -> M.await(awt), f)`
  (`lua-atmos/run.lua:916`) : `awt` is evaluated BEFORE the call
- combinator subs recurse through `M.await` (`run.lua:508-509`), whose
  ONLY lazy-spawn hook is `S.is` (streams, `run.lua:553`)
- a task prototype passed as a combinator operand is **never spawned**
- lua-atmos (external dep) is not editable from this repo

Consequences :

- a table `{or, T, :X}` will not spawn `T`
- an eager task INSTANCE in `watching(inst, f)` leaks if `f` ends first
  (instance is a child of `me`, not the par branch)

## Approach (Option B — par-lowering, revised)

The spawn must land INSIDE a par branch, at the coder/prim level, using
the existing `await(T, ...)` sugar — no lua-atmos change.

| pattern            | lower to                                       |
|--------------------|------------------------------------------------|
| `await T()` solo   | keep existing sugar (works)                    |
| `loop on T() {b}`  | `loop { await(T,...) ; b }` (sugar per iter)   |
| `watching T() {b}` | `par_any(\()->await(T,...), \()->b)`           |
| `T() || :X`        | `par_any(\()->await(T,...), \()->await(:X))`   |
| `T() && :X`        | `par_all(...)`                                 |

Rule : lower a pattern to `par_any`/`par_all` ONLY when it contains a
task-call operand; pure-event patterns stay `run.await` tables (tests
depend on it).

## DECISION : solo + pools first (scope)

Chosen (iii) : support only

- `await T()` solo — existing sugar
- `watching T() {}` — `par_any(\()->await(T,...), \()->body)`
- `loop on T() {}` — `loop { await(T,...) ; body }`
- `:any` / `:all` pools — already await task INSTANCES (orthogonal, done)

DEFER mixed task+event combinators (`T() || :X`) and `!`/`until`/`while`
around a task-call : those need par-lowering + the event-semantics
caveat (`par_any(:X,:Y)` != `run.await{or,:X,:Y}`). Revisit later.

## Resolved

- Discrimination is **runtime-only**. The parser has no type info, but it
  **can detect call syntax** (`call.tag == 'call'`). So the parser routes
  any id-call in pattern position into a spawn-instance node; the
  runtime keeps deciding prototype-vs-call via `X.is` (as `await` does).

## Runtime confirmation

Read of installed `atmos/run.lua` :

- awaiting a task **instance** is already a first-class operand
  (`meta_xtask` branch, `run.lua:591-594` -> returns `awt.ret, awt`)
- `or`/`and` recurse `M.await` per sub-item (`run.lua:508-509`), so
  combinators **already accept instances** -> no runtime change for
  composition
- result value unwraps correctly via `par_any`/`par_all`

The ONE real issue is scope/pinning :

- `run.spawn(dbg, up=nil, ...)` parents the task to the enclosing task
  (`M.me(true)`), NOT the await block (`run.lua:462`)
- auto-pin fires only for a `meta_tasks` pool (`run.lua:463-464`); a
  plain `||` is not a pool
- so in `await T() || :X`, if `:X` wins, the spawned `T` leaks as a
  child of `me`
- the solo fast path is safe only because it has no competing branch
- => the spawn-instance node must **pin to the await/block scope**

`dbg` frame is cosmetic (error location only).

## Decision : spawn-and-await thunk (Option B)

`pin` = ownership + abort-on-close (`src/run.lua:16-38`) : a pinned task
dies when its owning **block** closes.

The leak exists because we pre-spawn the instance (parented to `me`) and
drop it verbatim in the combinator table. Instead, model the promoted
`await T(...)` as a **spawn-and-await thunk** :

```
\() -> await(spawn(T, ...))
```

so the spawn happens **inside** the combinator branch — mirroring the
stream case `run.lua:553-554` (`S.is` spawns a wrapper task inside
`M.await`). When another branch wins, `par_any` closes the losing branch
and its child `T` cascades closed via `__close` (`run.lua:58-59`).

- `T` is aborted the moment the await resolves (tight, structured)
- no explicit `pin`, no leak
- drops into `or`/`and` unchanged (they already wrap each sub in a thunk,
  `run.lua:508-509`)

Rejected Option A (pin pre-spawned instance to enclosing block) : looser
lifetime — a losing `T` lingers until the whole block ends, surprising in
`loop { await T() || :X }`.

## Ambiguity check (Option B) : no new ambiguity

Chosen : promote only bare `await T()` (existing sugar) plus
`watching` / `loop on` / `:any`,`:all` pools. `await(...)` stays
**value-await** — so hazard (b) `await(g())` is untouched.

- (a) `await :X || :Y` -> `(await :X) || :Y` is the FIRST row of the
  manual Ambiguities table (`doc/manual.md:2733`) : pre-existing,
  inherited unchanged by `T()`.
- (b) `await(g())` : NOT introduced — B leaves parenthesized await as
  value-await.

Promotion is a sugar **extension**, not a new ambiguity :

| form                     | today            | after B          |
|--------------------------|------------------|------------------|
| `await T(a)`             | spawn+await      | same             |
| `await(g())`             | await the value  | same (unchanged) |
| `watching T(a)`          | await the value  | spawn+await (new)|
| `loop on T(a)`           | await the value  | spawn+await (new)|

Safe because :

- single parse, no two-reading (`watching`/`loop on` patterns are not
  expressions, so no result-level `||`)
- runtime-guarded : a non-task callee errors at `spawn`'s `X.is` check,
  never silently mis-spawns

Cost (not an ambiguity) : behavior CHANGE for `watching g()` /
`loop on g()` that relied on value-await -> now task-only. Add a manual
note (NOT an Ambiguities-table row).

## Files

| file            | place                        | change                    |
|-----------------|------------------------------|---------------------------|
| `src/await.lua` | `parser_await`, `await_ast_logical` | recognize a `call` base -> spawn-and-await thunk node; keep verbatim in combinators |
| `src/prim.lua`  | `await` dispatch (`164-194`) | route id-call through pattern path; keep fast path |
| `src/coder.lua` | thunk node                   | lower to `\() -> await(spawn(T, ...))` |

No `src/run.lua` change : composition already works (instances await-able,
combinators thunk each sub); discrimination stays runtime `X.is`.

## Status

- [x] confirm scope + runtime : composition free, only lifetime matters
- [x] decide mechanism : Option B spawn-and-await thunk
- [x] spec tests : `tst/await.lua` (Option B, 6 cases)
- [x] `prim.lua` : `await_call_sugar` helper (factored)
- [x] `prim.lua` : `loop on T()` -> await sugar per iter
- [x] `prim.lua` : `watching T()` -> `par_any { await(T) } with { body }`
- [x] `await T()` solo fast path : unchanged (already worked)
- [x] `is_task_call` guard — exclude synthetic `atm_*` calls (fixed
      regression `loop v on :X [10]` -> `atm_tag_do`)
- [x] refactor : `is_task_call` moved to `await.lua`; `parser_await`
      tags the bare-call node `is_task=true`; consumers branch on the
      flag (detection centralized, lowering stays per-consumer)
- [ ] RUN tests : `cd tst && lua5.4 all.lua`
- [ ] deferred : mixed task+event combinators (`T() || :X`)
- [ ] deferred : `!` / `until` / `while` around a task-call
- [ ] manual note : `watching`/`loop on` call = task spawn (behavior change)

No coder change : reused existing `await(T,...)` sugar + `par_any`.

## Tests

`tst/await.lua` : section "AWAIT-PATTERN TASK PROMOTION (Option B)"

| test                         | kind        | expects                        |
|------------------------------|-------------|--------------------------------|
| `task_promote solo 1`        | regression  | `await T(10)` -> `20`          |
| `task_promote watching_task` | spec        | solo, `T` ends -> `T\nok`      |
| `task_promote watching_body` | spec        | solo, body ends -> `T` aborts (no leak) |
| `task_promote loop_on 1`     | spec        | respawn per `:step` -> 2 ticks |
| `task_promote paren_value 1` | non-regress | `await(g())` value-await -> ok |
| `task_promote nontask_err 1` | guard       | non-task -> spawn error        |
