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

(Re-checked 2026-06-17 against live files — most prior items were already
done; see strike-through/DONE marks below.)

### atmos-lang — docs
- [MOSTLY DONE] Manual combinators are documented in the `### Await` pattern
  table (Logical group `!p`/`&&`/`||`, `until`/`while` preds, value-event
  matching `e =<= pat` / `e ?? x`) plus examples (`manual.md:~2130-2175`).
  - [ ] SUPERSEDED: the parens/first-arg rule is now one row of a new
    `## Ambiguities` table — see the dedicated task below.

### atmos-lang — docs : `## Ambiguities` section (PENDING — resume here)

Context: a syntax sweep (lexer+parser) found the real "silent surprise"
parses. We document only those in a new `## Ambiguities` table.

Decisions (settled 2026-06-18):
- Place a `## Ambiguities` subsection at the END of `# SYNTAX`, after the BNF
  block (~`doc/manual.md:2734`). 4-col table: case | what it is | what it
  could be | why.
- INCLUDE (silent surprises): await-parens, newline-ends-call, `f :X []`
  greedy, `<-` pipe-lexing, toggle-filter swallow, `\-` binary.
- EXCLUDE: self-announcing errors (same-level bin, same-line stmts); design
  choices already in *Subtleties* (`::`, `[]`, list-parens, return-parens);
  general max-munch; `5s` clock; `.`/`...`.
- `@` index DROPPED from ambiguities (see compiler change below — it now
  chains across newlines like `.`/`::`, so no longer surprising). NO
  `### Indexing` back-link.
- Stale commented note at `manual.md:1304` (binary same-line): LEAVE as-is
  (HTML comment, user decided not to touch).

DONE (compiler):
- [DONE] `src/parser.lua` `parser_2_suf`: added `@` to the cross-newline
  suffix exemption (`TK1.str=='@'`), so `t` ⏎ `@1` chains as `t@1` (was a
  parse error). Only converts former errors -> valid; no valid program
  changes meaning.
  - [ ] optional: add a parse test pinning `t` ⏎ `@1` -> `t@1`.

NEXT STEPS (docs — execute in order on resume):

1. [DONE] Appended `## Ambiguities` table at end of `# SYNTAX`
   (`doc/manual.md` after the BNF block).

```
## Ambiguities

Every program has a single parse, but a few constructs resolve in a way that
may surprise a naive reading:

| case | what it is | what it could be | why |
|------|------------|------------------|-----|
| `await :X \|\| :Y` | `(await :X) \|\| :Y` | `await(:X \|\| :Y)` | bare [await](#await) takes one pattern; parens for combinators |
| `f` ⏎ `(x)` | `f ; (x)` | `f(x)` | a [call](#calls) continues only on the same line (`.`/`::` access chains) |
| `f :X []` | `f(:X [])` | `(f(:X)) []` | single constructor-arg [call](#calls) is greedy |
| `x<-y` | `y(x)` | `x < (-y)` | `<- -> <-- -->` lex as [pipes](#pipes); space to compare |
| `… with :a until c, :b` | `:a until (c, :b)` | `(:a until c), :b` | a [toggle](#toggle) filter's `until`/`while` eats the comma-list |
| `\-` | `\(a,b){ a - b }` | `\(a){ -a }` | for `-` (both un/binary) the [lambda](#lambda) section picks binary |
```

2. [DONE] Added ONE back-link note per section, prefixed
   "See [Ambiguities](#ambiguities): " (the table only lists cases — no
   prose — so "listed/See", not "detailed"). Wording matches the edited
   table (`f(:X) []`, `with :a (until c, :b)`). Sections: Lambda, Calls,
   Pipes, Await, Toggle.
   - `### Await`  : note that `await :X || :Y` reads as `(await :X) || :Y`,
     not as `await(:X || :Y)`.
   - `### Calls`  : note that `f` ⏎ `(x)` reads as two statements `f ; (x)`,
     not as `f(x)`, and that `f :X []` reads as `f(:X [])`, not as
     `(f(:X)) []`.
   - `### Pipes`  : note that `x<-y` reads as the pipe `x <- y`, not as
     `x < (-y)`.
   - `### Toggle` : note that `with :a until c, :b` reads as `:a until
     (c, :b)`, not as `(:a until c), :b`.
   - `### Lambda` : note that `\-` reads as `\(a,b){ a - b }`, not as
     `\(a){ -a }`.

3. Add a general pointer in the `# SYNTAX` intro (no template):
   "See [Ambiguities](#ambiguities) for productions that resolve in ways a
   naive reading may not expect."

4. Anchors already verified present: `#await` `#calls` `#indexing`
   `#precedence-and-associativity` `#pipes` `#lambda` `#toggle`. New anchor
   `#ambiguities` from the section title.

5. Do NOT regenerate `doc/manual-out.md` (auto-gen; defer).
- [DONE] Manual: reviewed `every`(->`loop on`) / `watching` / `par_*` examples
  — all v0.7 value-event already; renamed capture var `loop it on :X` ->
  `loop e on :X` (manual:1862) to avoid clashing with the `it` keyword.
- [DONE] Reserved-Names: no change. `tasks` (real `tasks()` constructor) and
  `where` (live `v where {...}`, parser:416) stay; `clock` already absent (now
  numeric literals `1s`/`100ms`). The raw-tag leak concern was already fixed by
  the `### Await` table atmos-ification (`:clock`, `:any ts`, `p until c`).
- NOTE: the `### Await` match-slot review lives in `06-11-spawn-on.md`.

### atmos-lang — stale example/source files
(not run by `all.lua` so the suite stays green)
- [DONE] `doc/exs/exp-26-await.atm` — already value-event (`await :Key
  [:escape]`, `&&`, `!`, `until`, single-arg `emit`).
- [DONE] `doc/exs/exp-28-toggle.atm` — already value-event (`emit :E [1]`,
  reads `e@1`).
- [DONE] `tst/guide.atm` (6.4 toggle) — lines 266 + 269 converted to
  `emit :X [false]` / `emit :X [true]`.

### atmos-lang — leftover test migrations
- [DONE] `tst/await.lua:114` — now `emit :X [10]`.
- [DONE] `tst/expr.lua` two-arg cases — now NEGATIVE tests asserting the
  single-arg rule (`emit(:X,10)` -> "expected single argument"; `await(10s,x)`
  -> error); `await(:X until e1,e2)` is valid `until`-preds.
- [DONE] toggle-filter combinator (2026-06-17). Was NOT wired (both filter
  slots used generic `parser`). FIXED: both slots now route through
  `parser_await` (`prim.lua:220` block-form, `prim.lua:243` call-form), so
  `&&`/`||`/`!` lower to `{tag='and'/'or'/'not'}` and `:any`/`:all` pools work
  — matching `await` / `loop on` / `watching`.
  - DECISION: NO parens disambiguation. `until`/`while` inside a filter list
    greedily SWALLOWS trailing commas as predicates (accepted; documented in
    the `tst/toggle.lua` swallow test).

### lua-atmos — user's domain
- [DONE] `until`/`while` runtime — CONFIRMED present at `run.lua:495`
  (`tag=='until' or tag=='while'`, results at 514/516). The old BLOCKING
  reconcile is resolved; compiler wiring is green.
- [ ] bare-pool guard: `await(ts)` HANGS (pool has no `.tag`; `run.lua:471`
  falls through). Add error + test. NOT done.
- [ ] clock/non-table emit guard: `emit(5)`/`emit(true)` nil-deref. Line ref
  was stale (`627` is now emit-target code); needs runtime re-locate. UNVERIFIED.
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
