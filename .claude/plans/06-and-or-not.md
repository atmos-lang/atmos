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

- [x] spawn 8a/8b/9/10, emit 8: `emit :x/:t @{}`, read `.tag`
    - verified outputs (`x`, `t`) via worktree-src loader
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

## Pending

- [ ] `coder_pat` + n-ary flatten (`||`/`&&`/`!`)
- [ ] route await / every / watching / toggle-filter args (combinators)
- [ ] skip pool form `await(ts,'any'/'all')`
- [ ] precedence + mixed-operator decision, documented
- [ ] manual: combinators, parens rule, value-event model, single-arg emit
- [ ] verify `tst/await.lua` combinator cases lower correctly

## Done (runtime side, lua-atmos — reference only)

- [x] events as `{tag=K, ...}`; single-arg await/emit; inlined matcher
- [x] `or`/`and`/`not` via `par_*`; clock `{tag='clock', ms}`
- [x] toggle filter via off-tree hidden gate; block form = sugar
