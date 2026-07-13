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

## SCOPE : full mixed combinators (reverted "solo + pools first")

The earlier "solo + pools first" narrowing was REVERTED : the spec tests
are back to the mixed form `watching T() || :X`, so mixed task+event
combinators ARE in scope.

Consequence : the event-semantics question is RE-OPENED and must be
solved, not deferred :

- `par_any(await(:X), await(:Y))` is NOT identical to
  `run.await{or, :X, :Y}` (multi-task vs single-task, emit-reentrancy)
- so a mixed `T() || :X` puts `:X` under `par` — decide whether the
  behavior difference is acceptable, or lower more carefully

Still open : `!` / `until` / `while` around a task-call.

## Reuse parser_await everywhere : parse vs lower

Insight : the split is PARSE (unifiable in `parser_await`) vs LOWER
(irreducibly per-consumer). Every await-pattern site can share
`parser_await` for parsing + task-call detection; only the lowering
differs.

| site                     | parse via parser_await   | lowering (stays per-site)          |
|--------------------------|--------------------------|------------------------------------|
| bare `await T()`         | yes, needs adaptation #1 | emit `await(T,...)` sugar          |
| `await(PAT)`             | yes (already)            | value-await : IGNORE task flag     |
| `loop on PAT`            | yes (already)            | `await(T,...)` sugar per iter      |
| `watching PAT`           | yes (already)            | `par_any(await(T,...), BODY)`      |
| `spawn`/`toggle` filters | yes (already)            | IGNORE task flag (no promotion)    |

Two adaptations unify the PARSE half :

1. base0 juxtaposition base : `parser_1_prim` -> `parser_2_suf` so it
   eats the call postfix `(...)` (`parser.lua:318-325`). Then bare
   `await T()` flows through `parser_await` and the `parser_6_pip`
   special case (`prim.lua` await id-branch) is removed. `await :X || :Y`
   still leaves `||` outside (parser_2_suf stops before level-5 `||`).
   CAVEAT : preserve the `sep`-based ambiguities (`:X []`, `f (x)`).
2. `parser_await` flags task-call operands `is_task=true` (as the earlier
   refactor did). Each consumer honors or ignores per its semantics.

CANNOT move into `parser_await` :

- lowering shape, esp. `watching` (folds in the BODY, parsed AFTER
  `parser_await` returns)
- mixed `T() || :X` -> `par` is an OPERAND-level rewrite inside the
  combinator, deeper than the top-level flag

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

## Decision : spawn-and-await thunk (Option B) — SUPERSEDED

NOTE : the "drops into or/and unchanged" claim below is WRONG, refuted by
the BLOCKER section (`run.await` has no lazy task-spawn). Kept for the
reasoning trail; the working lowering is `par_any`/`par_all` (Approach
table), not a thunk in the combinator table.

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

## Files (target, pending mixed-lowering decision)

| file            | place                        | change                    |
|-----------------|------------------------------|---------------------------|
| `src/await.lua` | `parser_await`               | detect/flag a bare task-call operand |
| `src/prim.lua`  | `await` / `loop on` / `watching` | promote task-call -> `await(T,...)` sugar / `par_any`/`par_all` |

No `src/run.lua` (compiler) or lua-atmos change : lowering reuses the
existing `await(T,...)` sugar + `par_any`/`par_all`.

## State to resume from

- working tree == HEAD : implementation REVERTED, nothing to undo
- spec tests PRESENT (`tst/await.lua`, section "AWAIT-PATTERN TASK
  PROMOTION", mixed `||`) : 2 anchors pass today, 3 promotion specs FAIL
  until implemented, 1 guard
- all analysis above stands (blockers, runtime, ambiguity, reuse)

Sanity check on the new machine :

```
git status                 # clean except .rock artifact
cd tst && lua5.4 all.lua   # baseline green (promotion specs fail)
```

## Next steps (explicit, ordered)

### STEP 0 — GATE : decide mixed-combinator lowering (blocks all code)

`T() || :X` must lower to `par_any(\()->await(T), \()->await(:X))`
(BLOCKER section : `run.await` cannot lazily spawn a task operand). But
`par_any(await(:X), await(:Y))` != `run.await{or,:X,:Y}` (multi-task vs
single-task, emit-reentrancy). Pick one :

- (A) lower the WHOLE combinator to `par` whenever any operand is a
  task-call ; accept the event-semantics difference (document it)
- (B) reject mixed task+event in one combinator (parse error) ; allow
  task-only (`T()||U()` -> par) and event-only (`run.await`)
- (C) narrow back to solo + pools (the reverted decision)

Write the choice here before coding. Everything below assumes (A).

### STEP 1 — parser detection (shared)

- file `src/await.lua`, `parser_await`
- add local `is_task_call(e)` : `e.tag=='call'` and callee is a plain
  id NOT matching `^atm_` (excludes `:X [payload]` -> `atm_tag_do`)
- set `pat.is_task=true` on a bare task-call operand
- for STEP 4, also detect task-calls INSIDE the combinator operands
  (in `await_ast_logical`, `await.lua:21-32`)

### STEP 2 — solo lowerings (get the easy specs green first)

- `loop on T()` : `src/prim.lua` loop-on block — if `awt.is_task`, emit
  `await(T,...)` sugar (spread `call.f` + `call.es`) as the loop await
- `watching T()` : `src/prim.lua` watching block — if `awt.is_task`,
  emit `par_any(\{ await(T,...) }, \{ BODY })` instead of
  `watching(awt, body)`
- factor helper `await_call_sugar(call, lin)` (shared with bare await)
- REGRESSION WATCH : exclude `atm_*` callees or `loop v on :X [10]`
  breaks (tasks.lua "every 2")

### STEP 3 — unify bare await (adaptation #1, optional but desired)

- `src/await.lua` : change base0 base `parser_1_prim` -> `parser_2_suf`
- `src/prim.lua` : remove the `await` id-branch special case, route
  through `parser_await` + `await_call_sugar`
- verify `sep` ambiguities intact (`await :X || :Y`, `:X []`)

### STEP 4 — mixed combinator (the hard part, assumes GATE=A)

- operand-level : lower `T() || :X` / `T() && :X` to `par_any`/`par_all`
  with each operand a branch (`await(T,...)` for task, `await(:X)` for
  event)
- only when an operand is a task-call ; pure-event stays `run.await`

### STEP 5 — deferred

- `!` / `until` / `while` around a task-call
- manual note in `doc/manual.md` : `watching`/`loop on` with a call now
  = task spawn (behavior change); NOT an Ambiguities-table row

### Verify (ask the user to run — never run tests here)

```
cd tst && lua5.4 await.lua   # 6 promotion cases
cd tst && lua5.4 all.lua     # full suite, watch tasks.lua "every"
```

## Tests

`tst/await.lua` : section "AWAIT-PATTERN TASK PROMOTION" (mixed `||`)

| test                          | kind        | expects                       |
|-------------------------------|-------------|-------------------------------|
| `task_promote solo 1`         | regression  | `await T(10)` -> `20`         |
| `task_promote watching_event` | spec        | `T() || :X`, `:X` wins -> `ok`|
| `task_promote watching_task`  | spec        | `T() || :X`, `T` ends -> `T\nok` |
| `task_promote loop_on 1`      | spec        | respawn per `:step` -> 2 ticks|
| `task_promote paren_value 1`  | non-regress | `await(g())` value-await -> ok|
| `task_promote nontask_err 1`  | guard       | non-task -> spawn error       |
