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

## Blockers

| blocker                                   | where               |
|-------------------------------------------|---------------------|
| call not consumed in juxtaposition base   | `await.lua:81` `parser_1_prim` |
| `await_ast_logical` passes `call` verbatim| `await.lua:29-30`   |
| combinator items must be task instances   | `mk_tagged`, `:any`/`:all` |

Inside a `||`, a bare `T()` would be *called*, not spawned-then-awaited.

## Why a runtime change (was BLOCKER)

`run.await` has no lazy task-spawn :

- `run.watching(awt, f)` = `par_any(\() -> M.await(awt), f)`
  (`lua-atmos/run.lua:916`) : `awt` is evaluated BEFORE the call
- combinator subs recurse through `M.await` (`run.lua:508-509`), whose
  ONLY lazy-spawn hook is `S.is` (streams, `run.lua:553`)
- a task prototype passed as a combinator operand is **never spawned**
- an eager task INSTANCE in `watching(inst, f)` leaks if `f` ends first
  (instance is a child of `me`, not the par branch)

This refuted the thunk plan ("drops into or/and unchanged" was FALSE)
and, under the old constraint "lua-atmos not editable", forced Option B
par-lowering in the compiler.
That constraint is now DROPPED : lua-atmos is ours, changed via the
sibling plan.
The missing lazy-spawn hook is added at the one right place, `M.await`.

## Approach (Option C — runtime-first : prototype as await pattern)

Make the task prototype a first-class awaitable in lua-atmos `M.await`
itself (alongside the stream case `run.lua:553`), plus a
`{tag='spawn', T, args...}` carrier pattern for calls with args.
Then the compiler needs no thunk node and no par-lowering.

Sibling plan : `/x/lua-atmos/atmos/.claude/plans/done/260713-await-patt-task.md`

1. lua-atmos (`run.lua` / `init.lua`) — DONE (carrier-only)
    - `M.await` : single `tag=='spawn'` branch -> spawn `awt[1]` with
      `awt[2..]` args, then await it (mirrors the `S.is` stream case)
    - DECISION : CARRIER-ONLY — no `meta_task` branch. A bare prototype
      is NOT an await pattern; the compiler always emits the carrier.
      Varargs assert unchanged (the carrier packs args in the table).
    - `init.lua` `await` sugar : bare `await(T, ...)` now wraps into the
      carrier and funnels through `M.await` (single path). The
      `function` guard is kept, so the reject-fn error is unchanged.

2. Compiler : centralize `parser_await`
    - move the `check(nil,'id')` branch from `prim.lua` `accept('await')`
      into `parser_await`; all pattern consumers (`await`, `watching`,
      `loop on`, `toggle with`, `:any`) share the PARSE half
    - base0 (bare form) : `parser_1_prim` -> `parser_2_suf` so it eats
      the call postfix (`parser.lua:318-325`); still no binops, so bare
      `await T() || :X` stays `(await T()) || :X` (2606 rule)
    - CAVEAT : preserve the `sep`-based ambiguities (`:X []`, `f (x)`)
    - lower a task-call in PROMOTION sites : ALWAYS the carrier (bare
      prototype is not an await pattern under carrier-only) : `T()` ->
      `{tag='spawn', T}`, `T(a,b)` -> `{tag='spawn', T, a, b}`
    - detection : `is_task_call(e)` = `e.tag=='call'` and callee a plain
      id NOT matching `^atm_` — excludes `:X [payload]` -> `atm_tag_do`
      (REGRESSION WATCH : tasks.lua "every 2", `loop v on :X [10]`)

3. Keep the fast path
    - degenerate `await T(a,b)` with no combinators stays the direct
      `await(T, a, b)` spread (varargs reach spawn directly)
    - decide fate of `parser_7_out` (`await T() -> f` pipe-out) : the
      old id branch applied it, the pattern path never does

## SCOPE : full mixed combinators

The earlier "solo + pools first" narrowing was REVERTED : the spec tests
are back to the mixed form `watching T() || :X`, so mixed task+event
combinators ARE in scope.

The old STEP-0 GATE (par-lowering changes event semantics) DISSOLVES
under Option C :

- pure-event patterns keep lowering to `run.await` tables — untouched
- mixed `{or, spawn-carrier, :X}` runs through `run.await`'s existing
  or-branch (internally `par_any` of `M.await` subs, `run.lua:506-512`),
  i.e. the exact machinery `{or, :X, :Y}` uses today
- consistent by construction; nothing moves to compiler-level `par`

Still open : `!` / `until` / `while` around a task-call (see Deferred).

## Promotion sites : parse vs lower

PARSE unifies in `parser_await`; the PROMOTE decision stays per-site :

| site                     | parse via parser_await | task-call promotion       |
|--------------------------|------------------------|---------------------------|
| bare `await T()`         | yes (juxtaposed)       | carrier                   |
| `await(PAT)`             | yes (delimited)        | carrier (STEP 6 : outer parens only delimit) |
| `loop on PAT`            | yes (already)          | carrier (respawn per iter)|
| `watching PAT`           | yes (already)          | carrier                   |
| `:any`/`:all` pools      | yes (already)          | carrier in list items     |
| toggle filters           | yes (already)          | carrier (STEP 5 : uniform rule; respawn per gate pass) |

=> RULE (STEP 6, supersedes STEP 5's) : pattern position ALWAYS
promotes, no exceptions; the single value escape is grouping parens
directly around the call — `await((f()))` calls f and awaits its
result, `(a || b)` stays combinator grouping.

## Resolved

- Discrimination is **runtime-only**. The parser has no type info, but it
  **can detect call syntax** (`call.tag == 'call'`). So the parser routes
  a task-call in promotion position into the carrier; the runtime keeps
  deciding prototype-vs-call via metatable checks.

## Runtime confirmation

Read of installed `atmos/run.lua` :

- awaiting a task **instance** is already a first-class operand
  (`meta_xtask` branch, `run.lua:591-594` -> returns `awt.ret, awt`)
- `or`/`and` recurse `M.await` per sub-item (`run.lua:508-509`) inside
  **transparent branch tasks** (`par_any` spawns subs with `tra=true`,
  `run.lua:889`)
- result value unwraps correctly via `par_any`/`par_all`

Lifetime under Option C : inside a branch, `M.me(true)` is the branch
task itself, so `M.spawn(dbg, nil, ...)` parents the new `T` there; when
another branch wins, `meta_par.__close` cascades and aborts `T`
(`run.lua:57-71`, `859-865`) — same tight lifetime the thunk plan
wanted, with zero compiler thunks.

`dbg` frame is cosmetic (error location only).

## Decision : runtime-first (Option C)

- prototype + `{tag='spawn'}` carrier handled in `M.await` itself
- `watching T()` / `loop on T()` get it free (both funnel into
  `M.await` : `run.lua:921`, `854`)
- args inside combinators use the carrier (prototypes are non-callable);
  carrier-only : bare `T` is ALSO wrapped (`{tag='spawn', T}`)

Rejected Option A (pin pre-spawned instance to enclosing block) : looser
lifetime — a losing `T` lingers until the whole block ends, surprising in
`loop { await T() || :X }`.

Rejected Option B-thunk (`\() -> await(T, ...)` in the combinator
table) : REFUTED — `run.await` rejects/ignores function operands; no
lazy-spawn hook besides `S.is`.

Superseded Option B-par (compiler lowers task-bearing combinators to
`par_any`/`par_all`) : worked around the frozen-runtime constraint, but
forked event semantics (the GATE) and spread lowering over every
consumer; runtime-first covers all consumers at one spot.

## Ambiguity check : no new ambiguity

Chosen : promote only bare `await T()` (existing sugar) plus
`watching` / `loop on` / `:any`,`:all` pools. `await(...)` keeps calls
as **value-await** — so hazard (b) `await(g())` is untouched.

- (a) `await :X || :Y` -> `(await :X) || :Y` is the FIRST row of the
  manual Ambiguities table (`doc/manual.md:2733`) : pre-existing,
  inherited unchanged by `T()`.
- (b) `await(g())` : NOT introduced — parenthesized await keeps calls
  evaluated.

Promotion is a sugar **extension**, not a new ambiguity :

| form                     | today            | after promotion       |
|--------------------------|------------------|-----------------------|
| `await T(a)`             | spawn+await      | same (via carrier)    |
| `await(g())`             | await the value  | same (unchanged)      |
| `watching T(a)`          | await the value  | spawn+await (new)     |
| `loop on T(a)`           | await the value  | spawn+await (new)     |

Safe because :

- single parse, no two-reading (`watching`/`loop on` patterns are not
  expressions, so no result-level `||`)
- runtime-guarded : a non-task callee errors at `spawn`'s prototype
  check, never silently mis-spawns

Cost (not an ambiguity) : behavior CHANGE for `watching g()` /
`loop on g()` that relied on value-await -> now task-only. Add a manual
note (NOT an Ambiguities-table row).

## Files

| file            | place                        | change                    |
|-----------------|------------------------------|---------------------------|
| `src/await.lua` | `parser_await`               | absorb id-call branch; base0 `parser_1_prim` -> `parser_2_suf` |
| `src/await.lua` | `await_ast_logical`          | task-call leaf -> `{tag='spawn', f, es...}` carrier, gated by site mode; exclude `atm_*` callees |
| `src/prim.lua`  | `await` dispatch (`164-194`) | delete id branch; solo call -> spread `await(T, ...)`; `parser_7_out` fate |

lua-atmos changes tracked in the sibling plan :
`/x/lua-atmos/atmos/.claude/plans/done/260713-await-patt-task.md`

## State to resume from

- branch `260713-await-patt-task`; plan conflict (main vs branch)
  RESOLVED here : Option C adopted, Option B-par superseded
- implementation REVERTED earlier : nothing to undo
- spec tests PRESENT (`tst/await.lua`, section "AWAIT-PATTERN TASK
  PROMOTION", mixed `||`) : 2 anchors pass today, 3 promotion specs FAIL
  until implemented, 1 guard
- all analysis above stands (blockers, runtime, ambiguity, sites table)

Sanity check :

```
git status                 # clean except .rock artifact
cd tst && lua5.4 all.lua   # baseline green (promotion specs fail)
```

## Next steps (explicit, ordered)

### STEP 0 — lua-atmos runtime (sibling plan; blocks all compiler work) — DONE

- carrier-only : single `{tag='spawn'}` branch in `M.await` (no
  `meta_task` branch, varargs assert unchanged); `init.lua` bare
  `await(T, ...)` wraps into the carrier -> single `M.await` path
- in-branch lifetime confirmed : `await T() || :X` aborts the loser
  (proto 4 test : loser's `defer` runs on abort)
- all proto 1-7 tests pass, no regressions

### STEP 1 — parser detection (shared) — DONE (tests green)

- `src/await.lua` : `is_task_call(e)` (plain-id callee, `^atm_`
  excluded); `await_ast_logical(e, promote)` wraps task-call leaves as
  `mk_tagged('spawn', e.f, es...)`; `parser_await` gained 3rd param
  `promote` threaded through
- pools `:any [T(a),U(b)]` NOT done (no test; runtime `tasks` branch
  expects a pool object) — moved to STEP 4

### STEP 2 — promotion sites — DONE (tests green : full suite passes,
tasks.lua "every 2" unaffected)

- `src/prim.lua` : `watching` / `loop on` sites now
  `parser_await('{', nil, true)`; `await(PAT)` and `toggle with`
  filters left unpromoted (value-await preserved)
- REGRESSION WATCH : `atm_*` exclusion or `loop v on :X [10]` breaks
  (tasks.lua "every 2")

### STEP 3 — unify bare await — DONE (tests green : full suite passes;
expectations updated : `tst/expr.lua` carrier output + new args case,
`tst/tasks.lua` `await x` relaxation; error-attribution guard added in
lua-atmos `tag=='spawn'` branch)

- `src/await.lua` : base0 base `parser_1_prim` -> `parser_2_suf`
  (sep/is_prefix guards live inside `parser_2_suf`, `parser.lua:274-282`)
- `src/prim.lua` : `await` id-branch REMOVED; bare form is
  `parser_await(nil, true, true)` (promotion site), paren form
  unchanged (no promote)
- solo spread fast path DROPPED : under carrier-only,
  `await({tag='spawn', T, a})` IS the single runtime path — the spread
  was redundant
- `parser_7_out` on `await T() -> f` : WON'T DO — no usage in tests or
  manual; pattern path never supported it
- dotted callees `await M.T()` : NOT promoted (`is_task_call` = plain
  id only); now value-await — no usage found, note kept in STEP 4
- behavior relaxations : REVERTED post STEP 6 — bare values are
  invalid again, consistent with "values need parens" : the gate is
  `check_call_arg()` before the parse OR `is_task_call(base)` after,
  so `await x` / `await m.x` / `await T` (no call) err
  "invalid await : unexpected expression"; use `await(x)`.
  Paren dispatch lives back in `prim.lua` (the `(` after `await` is
  its argument parens), parser_await keeps only the two stop modes

### STEP 4 — deferred

- `!` / `until` / `while` around a task-call : `run.await`'s
  until-loop re-awaits `awt[1]` per failed predicate -> would RESPAWN
  `T` each time; consistent with `loop on` respawn but must be an
  explicit semantics decision
- whether `await(T() || :X)` (paren form) should also promote — today
  chosen NO (value-await)
- [x] dotted callees (`M.T()`) : RESOLVED — `is_task_call` is now a
  BLACKLIST (any call promotes except exact `atm_tag_do`); dotted and
  computed callees promote, callee value eager, runtime discriminates.
  Methods (`o::f()`) generate invalid Lua (`o:m` bare) — pre-existing
  latent hole, identical under the old id-branch spread; not a
  regression
- pools `:any [T(a), U(b)]` : carrier in list items (runtime `tasks`
  branch expects a pool object — needs its own design)
- manual note in `doc/manual.md` : `watching`/`loop on` with a call now
  = task spawn (behavior change); NOT an Ambiguities-table row
- manual note : evaluation discipline — the PATTERN side is EAGER
  (evaluated once at await entry : payloads, combinator operands,
  promoted-call ARGS), the `until`/`while` predicate is LAZY
  (re-evaluated per event); nuance : a promoted call's args are eager
  but its SPAWN is lazy (deferred into the branch, re-spawned per
  re-await in `until` / `loop on` / toggle gates)

### STEP 5 — refactor : parser_await(stop, no_promote)

Collapse the three parameters into two orthogonal axes :

- `stop` : nil -> juxtaposed (bare await; single suffixed primary);
  non-nil -> delimited (full expression, combinators licensed because
  the pattern region is closed by the stop token). Replaces `base0`,
  which was derived; the old `stop` was DEAD (never read).
- `no_promote` : set ONLY by the internal value-paren branch. RULE :
  pattern position always promotes; the single value escape is await's
  argument parens.

Juxtaposed dispatch (stop==nil) :

```
:any/:all/until/while -> specials (as today)
(                     -> parser_await(')', true) ; accept_err(')')
check_patt_arg        -> parser_2_suf base, promoted
else                  -> err "expected expression"
```

- juxtaposed gate = `check_call_arg() or id` (inlined at the single
  call site; `check_call_arg` globalized) — gates what may start a
  juxtaposed pattern; bare `await true/nil/5` become parse errors
  (no usage; paren form remains)
- `(` after bare await is consumed INSIDE parser_await; the `)` too
- toggle filters now PROMOTE (uniformity) : the filter is a real await
  pattern (gate task `M.await`s it); a task-call filter = "pass per
  fresh termination of T" (respawn per gate loop). Predicates keep
  `until`/`while`. COST : `with g()` value-call breaks — bind first
  (`val p = g()` ; `with p`), same as `watching`/`loop on`.

Call sites become :

| site               | call                |
|--------------------|---------------------|
| prim await         | `parser_await()`    |
| toggle on filter   | `parser_await('{')` |
| toggle inst filter | `parser_await(',')` |
| loop on            | `parser_await('{')` |
| watching           | `parser_await('{')` |

### STEP 6 — value escape via extra parens (uniform promotion)

`T()` vs `f()` in pattern position looked identical but meant spawn vs
runtime error — pattern position effectively banned value-calls.
Resolution : unify — promotion applies EVERYWHERE, including inside
`await(PAT)`; the value escape is grouping parens around the call.

| form              | meaning                              |
|-------------------|--------------------------------------|
| `await f()`       | promote : spawn (task) / spawn-error |
| `await(f())`      | promote — outer parens just delimit  |
| `await((f()))`    | value : call `f`, await its result   |
| `watching (g())`  | value — works in every pattern site  |
| `await((a || b))` | grouping, still combinators          |

- `await_ast_logical` : parens directly wrapping a task-call -> return
  the call verbatim (value escape); other parens stay transparent
- `no_promote` param DELETED — `parser_await(stop)` single param,
  `await_ast_logical(e)` single arg
- BEHAVIOR CHANGE : `await(g())` single-parens flips from value-await
  to promote; manual note must cover it (hazard-b now needs `((..))`)
- dotted/method callees (`M.f()`, `o::f()`) remain unpromoted — single
  parens suffice there
- tests flipped : `paren_value` -> `await((g()))`;
  tasks.lua "tasks 21" -> `await((tostring(n)))`

Rejected alternative (lazy call-or-spawn in the carrier) : runtime
dispatch on callee type would never error on a wrong callee — silent
misreads; the parens rule keeps intent visible in the source.

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

## Status

- [x] confirm runtime : no lazy task-spawn hook -> runtime change needed
- [x] decide mechanism : Option C runtime-first (prototype in `M.await`)
- [x] ambiguity check : sugar extension, no new ambiguity
- [x] spec tests written (`tst/await.lua`)
- [x] STEP 0 : lua-atmos runtime DONE (carrier-only, sibling plan) —
      `tag=='spawn'` branch + sugar collapse, all proto 1-7 tests pass
- [x] STEP 1 : parser detection + carrier + site mode (pools deferred)
- [x] STEP 2 : `watching` / `loop on` promotion (full suite green)
- [x] STEP 3 : unify bare await (id-branch removed; `parser_7_out`
      won't-do; full suite green)
- [x] STEP 4 : all items closed —
      `!`/`until`/`while` respawn per re-await : documented as the
      semantics (manual "On re-await ... fresh instance");
      paren-form promotion : resolved by STEP 6 (promotes);
      dotted callees : resolved (blacklist);
      pools `:any [T(a), U(b)]` : WON'T DO (separate design);
      manual notes : DONE (`doc/manual.md` Await section + lua-atmos
      `api.md` carrier row + sugar scope)
- [x] docs : pattern tables aligned (manual.md `T(...)` row; api.md
      `{tag='spawn',...}` row; guide.md untouched — no table there)
- [x] STEP 5 : `parser_await(stop, no_promote)` refactor —
      `check_patt_arg` gate, parens-inside, dead `stop` repurposed as
      mode axis, uniform promotion incl. toggle filters (full suite
      green)
- [x] STEP 6 : value escape via extra parens — promotion truly
      uniform, `no_promote` deleted, `await((f()))` escape (full
      suite green)

## Done (2026-07-16)

Docs reviewed and accepted as-is; won't-fix nits :
SYNTAX `[...]` optionality in the await production, base-less
`until`/`while` prose, respawn-per-re-await note, api.md
top-level-only sugar caveat.
