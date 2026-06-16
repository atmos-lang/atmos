# Plan: await / emit value-event redesign (consolidated)

Consolidates three earlier await plans, now archived in `done/` (kept for full
rationale, recipes, and per-test detail):

- `done/2026-05-22-await.md` — original `&&`/`||`/`!` combinator sugar. Used a
  POSITIONAL `{[1]='or', a, b}` format, **SUPERSEDED** by the tag-keyed format
  below.
- `done/06-05-awaits.md` — unified single-pattern `parser_await` (Option B):
  combinators + `:any`/`:all` pool + `until`/`while` preds + single-arg emit.
- `done/06-and-or-not.md` — value-event runtime alignment + combinator lowering
  to `{tag='or'/'and'/'not'}`; the live value-event test migration.

This plan is the ACTIVE tracker: the shared goal + the REMAINING work.

## Goal

Compile to the lua-atmos value-event runtime:

- events are `{tag=K, ...}` values; `await`/`emit` take a SINGLE argument.
- combinators `||`/`&&`/`!` (only in await / every / watching / toggle-filter
  position) lower to `{tag='or'/'and'/'not', [1..n]=…}` — NOT Lua or/and/not.
- pool prefix `:any`/`:all` -> `{tag='tasks', mode=…, tasks=ts}`.
- predicates: `await PAT until c1,c2` / `await PAT while c` ->
  `{tag='until'|'while', [1]=pat, [2..]=pred-funcs}` (each non-func pred wrapped
  `\{ it }`).
- ONE recognizer `parser_await` (in `src/await.lua`) for the single pattern of
  await / every / watching.

## DONE (compiler + most tests + runtime)

- [DONE] unified `parser_await` (`src/await.lua`): combinators, `:any`/`:all`
  pool, `until`/`while` preds; single-primary (juxtaposition `await :X`) vs
  full-expr (`await(...)`); empty -> `expected expression`. 5 call sites
  collapsed to one export. (06-05-awaits)
- [DONE] combinator lowering to `{tag='or'/'and'/'not'}` — tag KEY, subs at
  `[1..n]`; FIXED the original positional `{[1]='or',…}` bug from the May-22
  plan (runtime reads `awt.tag` + `ipairs`). (06-and-or-not, 06-05-awaits)
- [DONE] single-arg `emit` parser check (`prim.lua`); `emit()` / `emit(a,b)` ->
  parse error. (commit 1b0a198)
- [DONE] toggle filter block-form arg order (body last); `toggle … with` filter.
- [DONE] most test migrations -> value-event: `tst/await.lua`, `tst/expr.lua`,
  `tst/stmt.lua`, `tst/exec.lua`, `tst/tasks.lua`, `tst/streams.lua`; suite
  GREEN. (06-and-or-not, 06-05-awaits)
- [DONE] runtime (lua-atmos, user): `{tag=K}` events, single-arg await/emit,
  or/and/not, clock `{tag='clock'}`/µs, toggle gate, streams value-event.

## REMAINING

### atmos-lang — docs
- [ ] Manual combinator subsection (`doc/manual.md`, after `### Await`):
  `||`/`&&`/`!` combinators, parens + first-arg rule, value-event `{tag=}`
  model, single-arg emit, `until`/`while` preds. (all three originals)
- [DONE] Manual: reviewed `every`(->`loop on`) / `watching` / `par_*` examples
  — all v0.7 value-event already; renamed capture var `loop it on :X` ->
  `loop e on :X` (manual:1862) to avoid clashing with the `it` keyword.
- [DONE] Reserved-Names: no change. `tasks` (real `tasks()` constructor) and
  `where` (live `v where {...}`, parser:416) stay; `clock` already absent (now
  numeric literals `1s`/`100ms`). The raw-tag leak concern was already fixed by
  the `### Await` table atmos-ification (`:clock`, `:any ts`, `p until c`).
- NOTE: the `### Await` match-slot review lives in `06-11-spawn-on.md`.

### atmos-lang — stale example/source files
(not run by `all.lua` so the suite stays green, but now-invalid value-event
syntax; EXACT before->after edits are in `done/06-05-awaits.md`)
- [ ] `doc/exs/exp-26-await.atm` — `await(:key,:escape)` -> `await :escape`,
  `emit(10,20)` -> `emit(:P @{x=10,y=20})`, multi-value read -> `e.x`/`e.y`.
- [ ] `doc/exs/exp-28-toggle.atm` — `emit(:E,1)` -> `emit :E @{1}`, read `e[1]`.
- [ ] `tst/guide.atm` (6.4 toggle) — `emit(:X,false)` -> `emit :X @{false}`.

### atmos-lang — leftover test migrations (line lists in `done/06-and-or-not.md`)
- [ ] `tst/await.lua:114`, `tst/expr.lua:1196` two-arg emit (tosource).
- [ ] remaining literal-payload emits + DELAYED table-var emits.
- [ ] toggle-filter combinator: route the filter slot through the combinator
  lowering too (plan said to — verify it's wired).

### lua-atmos — user's domain (some BLOCKING)
- [ ] `until`/`while` runtime — RECONCILE: `06-and-or-not` marked `await_where`
  BLOCKED on a runtime `where` branch, but `06-05-awaits` notes the runtime
  RENAMED `where`->`until` + added `while` (`run.lua:538`). Confirm the runtime
  has `until`/`while`; if so the blocker is RESOLVED and the compiler's wiring
  just needs a green run.
- [ ] bare-pool guard: `await(ts)` HANGS (pool has no `.tag`); add error + test.
- [ ] clock non-table emit regression: pin the `emit(5)`/`emit(true)` nil-deref
  guard (`run.lua:627`).
- [ ] streams sanity check; optional `S.emitter` value-event pin test.

## Format note (evolution — do not regress)

The May-22 plan emitted positional `{[1]='or', [2]=a, …}`; the runtime moved to
tag-keyed `{tag='or', [1..n]=…}`. Only the tag-keyed format is current.
Likewise the predicate combinator was `where` then renamed to `until`/`while`.

## Cross-refs

- Detailed history: `done/2026-05-22-await.md`, `done/06-05-awaits.md`,
  `done/06-and-or-not.md`.
- Related active: `06-11-spawn-on.md` (the `on` family + `### Await` review),
  `06-11-release-v0.7.md` (lists this as a v0.7 prerequisite).
