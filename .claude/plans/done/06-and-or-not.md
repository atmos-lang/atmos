# and / or / not — value events (atmos language layer)

## Goal

Make the **language** compile to the new lua-atmos **value-event**
runtime: events as `{tag=K, ...}` values, single-arg `await`/`emit`, and
the combinator operators `||` / `&&` / `!` inside `await` / toggle-filter
positions lowering to `{tag='or'/'and'/'not', ...}` (NOT Lua
`or`/`and`/`not`).

Runtime is already done (see lua-atmos `06-and-or-not`). This plan is the
compiler half: `src/{lexer,parser,coder,tosource}.lua` + `doc/manual.lua`.

## Runtime contract (target output)

| source                  | must compile to                                  |
| ----------------------- | ------------------------------------------------ |
| `:X`                    | `"X"`  (already: `coder_tag`)                     |
| `await(:X)`             | `await("X")`                                      |
| `await(:X || :Y)`       | `await({tag='or', "X", "Y"})`                     |
| `await(:X && :Y)`       | `await({tag='and', "X", "Y"})`                    |
| `await(! :X)`           | `await({tag='not', "X"})`                         |
| `emit(:X)`              | `emit("X")`  (single event)                       |
| `emit(evt{...})`        | `emit({tag='evt', ...})`                          |
| `<clock>` literal       | `clock{...}` -> `{tag='clock', ms=N}` (already)   |
| `toggle(e, FLT, body)`  | `toggle("e", FLT, body)` (filter = one pattern)   |

`emit('X', v)` is invalid; use an event table `emit(X{v})` /
`emit({tag='X', v})`. No-arg `emit()` = nil wake signal (allowed).

## Current state (what exists)

- `await`/`every`/`watching` are **plain calls** (not in the parser
  `no` prefix list at `src/parser.lua:235`, only emit/spawn/toggle/thread).
- `||`/`&&` are bins, `!` a uno; `src/global.lua:64-65` maps
  `['||']='or'`, `['&&']='and'`; the coder default bin/uno branches
  (`src/coder.lua:78,96`) emit the Lua op via `OPS.lua`.
  => `await(:X || :Y)` currently mis-lowers to `await("X" or "Y")`.
- `:X` tag -> `"X"` string (`coder_tag`, `src/coder.lua:42`).
- `clk` node -> `clock {...}` already (`src/coder.lua:65`).

So: events, clock, single-arg already line up. **Only the combinator
lowering is missing.**

## The combinator problem

`||`/`&&`/`!` are overloaded: ordinary logical ops everywhere, but
**event combinators** when they are the await pattern / toggle filter.
The compiler must lower them differently **by context**, not globally
(global change would break real boolean logic).

Combinator context = the (single) pattern argument of:

- `await( <pat> )`           (not the `await(ts,'any'/'all')` pool form)
- `every( <pat>, body )`
- `watching( <pat>, body )`
- toggle filter slot `toggle(e, <pat>, body)` / `toggle(t,false,<pat>)`

## Approach (preferred: coder-only, context-flagged)

Lower combinators in the coder when emitting a pattern argument, leaving
the AST and ordinary boolean codegen untouched.

1. Add `coder_pat(e)` — like `coder(e)` but:
   - `bin ||`  -> `atm_table{ [1]=..,[2]=.., tag="or"  }` over
     `coder_pat` of each side (flatten nested `||` to one n-ary table).
   - `bin &&`  -> same with `tag="and"`.
   - `uno !`   -> `atm_table{ [1]=coder_pat(e), tag="not" }`.
   - `parens`  -> recurse into `coder_pat`.
   - anything else -> fall back to `coder(e)` (strings, tables, clocks,
     ids, calls all pass through unchanged).
2. In the `call` coder branch (`src/coder.lua:98`), detect callee name in
   `{await, every, watching}` and run the **pattern argument** through
   `coder_pat` instead of `coder` (await: arg 1 unless 2nd arg is a
   `'any'/'all'` string; every/watching: arg 1).
3. Toggle is a `no`-prefixed form: in its coder path, run the filter slot
   through `coder_pat`.
4. Emit `tag` as a string key inside the table:
   `atm_table{ tag = "or", [1]=.., [2]=.. }` (match runtime `M.is` per
   field; `tag` is a normal key).

### Alternative (parser-marked)

Tag the pattern subtree in the parser (set `e.is_pat=true` when parsing
the await/every/watching/toggle-filter argument) and let one `coder`
switch read the flag. More invasive; only if context detection in the
coder proves fragile (e.g. aliased `await`).

## Edge cases / rules

- Bare `await :X || :Y` (no parens) parses as `(await :X) || :Y` — a
  user logic error, **documented not enforced** (see `tst/await.lua`
  header).
- Mixed precedence `await(:X && :Y || :Z)` — define and document:
  follow existing `&&`/`||` precedence, flatten per-operator into nested
  `{tag='and'}` / `{tag='or'}`.
- `await(true)` / `await(false)` / numbers / clocks / function patterns
  pass straight through `coder` (fallback) — no special-casing.
- Pool form `await(ts, 'any'/'all')` must NOT be treated as combinator;
  detect the 2-arg string-mode shape and skip `coder_pat`.

## Files

| file               | change                                              |
| ------------------ | --------------------------------------------------- |
| src/coder.lua      | add `coder_pat`; route await/every/watching/toggle filter arg through it; n-ary `{tag='or'/'and'/'not'}` |
| src/parser.lua     | (only if alternative chosen) mark pattern subtree   |
| src/tosource.lua   | round-trip combinator forms if needed               |
| doc/manual.lua     | document `||`/`&&`/`!` await combinators, parens rule, event `{tag=}` model, single-arg emit |

## Test migration (value-event emit) — side discovery

Installed runtime now enforces single-arg `emit` (`init.lua:54`,
`assert select('#',...)==0`). Deprecated two-arg `emit(:X, v)` must
become `emit(:X @{v})`; `await(:X)` returns the whole event table, so
payload binding changes.

No-paren statement form (manual `:2303`): `emit :X @{v=10}`;
`every it in :X { print(it.v) }`. Toggle `:Show` uses positional `[1]`
bool, so `emit :Show @{false}`.

Parser caveat (verified w/ `./atmos`): juxtaposition `emit ARG` only
accepts a call-arg primary (tag / `@{}` / clock-lit / str). `emit
clock@{..}` FAILS (`clock` is a plain id) -> use clock literal
`emit @10` / `emit @0.100` instead. `emit(clock@{..})` needs parens.

- [x] `tst/exec.lua`: await 2 clock, toggle 8, toggle filter block
    - `emit(:clock,10*1000)` -> `emit @10`; `emit(:clock,100)`
      -> `emit @0.100`
    - `every _,evt in :Draw { print(evt) }`
      -> `every it in :Draw { print(it.v) }`
    - `emit(:Draw,1)` -> `emit :Draw @{v=1}`
    - `emit(:Show,false)` -> `emit :Show @{false}` (positional bool)
    - `await 1` two-arg emit left as-is (unreachable: errors first)
### tasks.lua — value-event migration (user-approved conventions)

await now returns ONE value (the whole event); no tag/payload split.
1. `emit(:t,@{1})` -> `emit :t @{1}` (payload contents merge: `{tag='t',1}`)
2. table-var payload `emit(:t, e)` -> **DELAY** (need tag-merge form)
3. multi-value reads (`_,v=await`, `print(await)`) -> **index** event
   (`e.tag` / `e[1]`); empty `@{}` payload has nothing to index -> `e.tag`
4. fn pattern `await(func(_,e){..})` -> `await(func(e){..})`
5. multi-positional await `await(p1,p2)` REMOVED by runtime (only one
   pattern; tasks form allows pool mode `'any'/'all'`) -> drop extra arg

- [x] spawn 8a/8b/9/10, emit 8: `emit :x/:t @{}`, read `.tag`
    - verified outputs (`x`, `t`) via worktree-src loader
- [x] emit 7: `await(true, type(evt)!='table')` -> `await(true)`
    - verified `10/10/20`
- [x] emit 9 (2a table-var): `set e.tag=:t; emit(e)`, read `.tag` -> `t`
- [x] emit 10/11 (2a), emit 12 (#1 `@{1}`, read `e.tag`,`e[1]` -> `t  1`)
- [x] emit scope 1/2/3 (`@{}` -> `.tag` -> `t`)
- [x] emit scope 5 (`@{20}` -> `e[1]` -> `20`)
- [x] emit scope 7/8/9 (`func(_,v)`->`func(v)`; `v[1]` unchanged -> `@{N}`)
- [~] emit scope 6: migrated syntax; expected PREDICTED+UNVERIFIED
    - BLOCKED by lua-atmos runtime overflow (see below)

### Task-termination IS an event (NOT a bug) — confirmed by user

A terminating task emits itself (`run.lua:179 M.emit(false,up,t)`);
`await(true)` legitimately receives the terminated task. lua-atmos test
`tst/task.lua` "await 7" documents this (`t/t/u/?`). No runtime change.

Consequence for migration: a function pattern used as a FILTER must
filter on `.tag`, not just truthiness, else it matches termination
(a bare task) and printing it overflows.
- scope 6: `await(func(e){(e,e)})` -> `await(func(e){(e.tag,e)})`
  (matches tagged user events only); verified -> predicted output OK.

- [x] scope 6 fixed (tag-filtered pattern); BLOCKED comment removed
- [x] scope 10/11 (`@{}`->`.tag`->`t`), scope 12 (2a), scope 13 (`emit :t @{}`,`ok`)
- [x] alien 0 (2a, printed-after-tag -> `@{tag=t}`), alien 1/2 (2a -> `t`)
- [x] alien 3 (`@{@{10, tag=t}}`), alien 4 (`@{10, tag=t}`), alien 5/6 (`@{10}`/`@{1}`)
- [x] alien 7, payload 1: already value-event form (no change)
- [x] payload 4 (2a), payload 8/9 (`emit :X @{...}` + index)
- [x] payload 2/3/5/6/7, payload 9b, order 1-4, emit-in: pass as-is
  (order 1/3/4 rely on termination-as-event -> confirms runtime is OK)
- [x] task-term 1/3 (2b `emit(:T @{t})`), task-term 2 (`emit(t)`, as-is)
- [x] pub 7, every 2: two-param/multi-pattern -> FUNCTION pattern
  `func(e){ (e.tag==:X) && (e[1]==N) }` + index

Observation (not a bug per user model): tagged-table AWAIT patterns
`await(:X @{10})` / `await(@{tag=:X,10})` do NOT match; only tag string,
function patterns, or or/and/not combinators do. Used function patterns.

**tasks.lua migration COMPLETE** — no two-arg emit / multi-value await /
two-param pattern remains.

### Function-pattern nil-safety (suite runtime semantics)

CRITICAL: the SUITE uses `/x/lua-atmos/atmos/.work/06-and-or-not` runtime
(my earlier probes hit a different checkout `/x/atmos-lang/atmos/lua-atmos`
-> false greens). Per its `M.await` source (`run.lua:546,574`):
- function patterns are evaluated ONLY at loop-top, called `awt(emt)`
  with **emt=nil on the first iteration**;
- await returns the func's **2nd return value** (`ret`), not the event.

So a pattern that indexes/matches nil unconditionally either CRASHES
(`e.tag` on nil) or spuriously matches (`type(nil)!='table'`,
`nil !? :task`). Fix = guard with `e &&` (short-circuits) and return the
event when used: `func(e){ (e && <cond>, e) }`.
- [x] scope 6 `(e && e.tag, e)`
- [x] payload 2 `(e && (type(e)!='table'), e)` -- parens REQUIRED:
  Atmos binops are single-level, mixing `&&`/`!=` w/o parens = parse error
- [x] pub 7 `e && (e.tag==:X) && (e[1]==pub)`
- [x] every 2 / payload 9 `(e && (e.tag==:X) && (e[1]==N), e)`
- [x] tasks 11/12 `e && (e !? :task)`
- payload 9b `(e??:X) && (e.v==10)` already nil-safe (?? + short-circuit)

NOTE: unverified (no test runs per user) — fixes derived from runtime
source. Expected outputs unchanged (await returns `ret`=event).

### await.time regression (lua-atmos) — FIXED by user

order 2 fired a 2nd await from the same emit: value-event `M.await`
dropped `t._.await.time = TIME` (main sets it via `await_to_table`), so
the emit guard `await.time < time` was always true -> re-fire.
Fix applied in lua-atmos: `me._.await.time = TIME` in `M.await`.
Regression test added: `lua-atmos tst/task.lua` "await 8: one wake per
emit". order 2 expected (`1\n2\n3\n4`) stays as-is.

### Remaining (other files)
- [ ] `tst/await.lua:114` `emit(:X, 10)`
- [ ] `tst/expr.lua:1196` `emit(:X,10)` (tosource test)
- [ ] remaining literal-payload emits: 626,663,677,692,721,744,746,778,
  792,809,828,852,903,966,984,1015,1194-96,1593,3369
- [ ] DELAYED table-var emits (need #2 form): 576,595,611,874,918,933,
  949,999,1110,1433,1464  -> suite halts at 576 next
- [ ] `tst/await.lua:114`, `tst/expr.lua:1196` two-arg emit (separate)

## Compiler fix — toggle filter block arg order

Runtime `M.toggle` string form wants body **last**: `toggle(e, <filter>,
body)` (`f = filter or on`). Compiler emitted `toggle(e, body, filter)`
-> "expected task prototype". Fixed `src/prim.lua:248` (tag/block form):
`es = concat(concat({tag}, filter), {body})`. No-filter path unchanged.

- [x] `src/prim.lua` toggle block-form arg order (body last)
    - verified via worktree-src loader: block-filter test ->
      `draw/tick/draw/tick`
    - NOTE: test suite uses the **installed** compiler; needs reinstall
      (`luarocks make`) before `tst/` picks this up
- [x] `tst/expr.lua:1414` tosource expectation -> `toggle(:X, :Draw, {})`
  (body last, matches new arg order)

## Combinator lowering — implemented (parser-marked, the "Alternative")

Done via `await_ast_logical` (`src/prim.lua:19`), already wired into
await (`:222`), every (`:703`), watching (`:736`). It rewrites bin
`&&`/`||` and uno `!` -> `{tag='or'/'and'/'not', [1]=.., [2]=..}`,
recursing through parens and nested trees, flattening per-operator.

- [x] BUG FIX: it built `{[1]='or', [2]=X, [3]=Y}` (op name at `[1]`,
  subs shifted) -> runtime reads `awt.tag` + `ipairs` so never matched.
  Now: name -> `:tag` key, subs -> `[1..n]`. (`prim.lua` `f`)
  - NEEDS compiler reinstall (suite uses installed compiler)

## Comma-predicate await -> `where` combinator (NEW design w/ user)

`await(pat, e1, .., eN)` = match `pat`, then require function predicates
`e1..eN` over the matched event `it`. Lowers to a runtime combinator:
```
await(pat, e1, e2)  ->  await({tag='where', [1]=pat, [2]=\{e1}, [3]=\{e2}})
```
Runtime (USER adds in lua-atmos): new `tag=='where'` branch in M.await --
`while true do it=M.await(awt[1]); if all awt[2..](it) then return it end end`.
Relies on full await matching for `pat` (any pattern type), predicates are
functions of `it`. Naturally nil-safe (preds only see real matches).

- [x] compiler: `await_where` + wiring (`src/prim.lua`)
    - each non-func arg wrapped `\{ e }` (implicit `it`); a func arg passes
      through unchanged (user rule #3)
    - skips pool form `await(ts, :any|:all)`
    - NEEDS reinstall
- [x] `tst/await.lua` op_payload_or: emit -> `emit :X @{10}` (await keeps
  the comma form `await(:X, a||20)`)
- [ ] BLOCKED on user adding the `where` branch to lua-atmos runtime

NOTE: predicate gets only `it` (first M.await return); task patterns' 2nd
return (the task) not passed -- agreed simplest.

## Pending

- [ ] toggle-filter combinator (plan said route filter slot too — check)
- [ ] leftovers: `tst/await.lua:114`(now `op_payload_or`, done), `tst/expr.lua:1196` two-arg emit
- [ ] manual: combinators, parens rule, value-event model, single-arg emit, where
- [ ] skip pool form `await(ts,'any'/'all')`
- [ ] precedence + mixed-operator decision, documented
- [ ] manual: combinators, parens rule, value-event model, single-arg emit
- [ ] verify `tst/await.lua` combinator cases lower correctly

## Done (runtime side, lua-atmos — reference only)

- [x] events as `{tag=K, ...}`; single-arg await/emit; inlined matcher
- [x] `or`/`and`/`not` via `par_*`; clock `{tag='clock', ms}`
- [x] toggle filter via off-tree hidden gate; block form = sugar
