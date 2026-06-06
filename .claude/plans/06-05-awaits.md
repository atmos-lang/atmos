# Unified await-pattern parsing — Option B (chosen)

## Goal

One recognizer for the **single** pattern of `await` / `every` / `watching`.
Everything is exactly one pattern (no lists / no comma / no 2-arg), covering:

- combinators `||` / `&&` / `!`  -> `{tag='or'/'and'/'not', ...}`;
- pool prefix `:any` / `:all`     -> `{tag='any'/'all', ts}`;
- empty pattern                   -> parse error;
- (later) `where` predicates      -> hooks into the same recognizer.

## Recognizer

```lua
local function parser_await_pat ()
    if accept(:any) or accept(:all) then        -- pool prefix
        local mode = TK0.str                    -- 'any' / 'all'
        return { tag = mode, parser() }         -- needs lua-atmos branch
    end
    return await_ast_logical(parser())          -- combinators; parser() errors on empty
end
```

Empty falls out for free everywhere: an empty slot makes `parser()` hit the
terminator (`)` / `{`) and error `expected expression` — one uniform message.

## Sites

| site | change |
| ---- | ------ |
| await | rewrite: parse `await ( parser_await_pat() )` or juxtaposition `await PAT` via the recognizer (NOT the generic call-chain); then re-apply the suffix chain for `::m()` / `-->` / `<--` / `where`-out. Drops the 2-arg comma/pool form. `await()` -> error. |
| every | loop-vars list before `in` stays (`a, b in`); the pattern (after `in`, or no-`in`) = `parser_await_pat()` (single). |
| watching | pattern = `parser_await_pat()` (single). |

## Resolved by B

- **pool**: `:any/:all ts` is a single-pattern prefix -> no 2-arg `await(ts,mode)`.
- **empty error**: uniform `expected expression` (all go through `parser()`).
- **multi-pattern**: gone -- `await(:X,:Y)` / `every v in :X,:Y` no longer parse.

## Cost / risk

- The **await rewrite** is the real work: today the call-chain
  (`parser_2_suf..parser_6_pip`) gives `await(...)::m()`, pipes, binops on the
  result for free. Parsing `( pat )` manually means re-applying that chain to the
  built await-call node, and re-testing those forms.

## Runtime dependency (lua-atmos -- user)

- `tag=='any'/'all'` branch in `M.await` (task-pool, parallel to or/and/not),
  replacing the `await(ts, 'any'/'all')` 2-arg shape.

## Done (≥1 lists -- separate from B)

- [x] toggle filter `with` x2, `set` targets, `parser_ids` -> `parser_list_1`.

## Predicate form: `until` / `while` (NOT `where`)

lua-atmos renamed `where`->`until` and added `while` (`run.lua:538`):
`{tag='until'|'while', [1]=pat, [2..]=pred-funcs}`, `#awt>=2` (>=1 pred).
- `until`: return when ALL preds hold; result = last pred's non-true return
  (else the event) -> preds can transform the result.
- `while`: return the event when ANY pred fails.
Source: `await PAT until c1, c2` / `await PAT while c`.
Compiler wraps each non-func pred as `\{ e }` (implicit `it`); func passes
through; >=1 pred via `parser_list_1`.

## Pending (ordered)

- [x] `parser_await` v1 (combinators + single pattern; `parser()` errors on empty)
- [x] route every / watching through it (single pattern; multi-var `every`
  dropped — one optional var)
- [ ] 1. rewrite await onto `parser_await`; bare `call` node (outer chain keeps
  `::m()`/pipes/binops); `await()` -> parse error; re-test
- [ ] 2. `:any/:all` prefix in `parser_await` -> `{tag='any'/'all', ts}`
  (runtime already has 'any'/'all' mode)
- [ ] 3. `until`/`while` in `parser_await` -> `{tag='until'/'while', pat, \{p}..}`
  (>=1 pred; stop token per caller: `)` await, `{` every/watching)
- [ ] 4. fix tests to new syntax: `await(:X,10)` -> `await :X until it.v==10`
  (+ `emit :X @{v=..}`); update/drop multi-`every` test (stmt.lua:888)
