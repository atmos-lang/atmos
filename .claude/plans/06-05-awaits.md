# Unified await-pattern parsing (await / every / watching / toggle)

## Goal

One shared parser for the "await pattern" slot used by `await`, `every`,
`watching`, and the `toggle` filter.
It must handle, in one place:

- base pattern (tag, `true`/`false`, clock, task, function, ...);
- combinators `||` / `&&` / `!`  -> `{tag='or'/'and'/'not', ...}`;
- `where` predicates  -> `{tag='where', [1]=pat, [2]=\{p}, ...}`;
- (await only) the pool mode `, :any` / `, :all`.

Today each construct rolls its own parsing; combinators are duplicated and
`where` exists only on `await`.

## Current state (`src/prim.lua`)

| site               | parse                       | combinators   | where | pool |
| ------------------ | --------------------------- | ------------- | ----- | ---- |
| `await(..)` :256   | call-chain -> `es`          | `es[1]` only  | yes   | yes  |
| `every .. in P` :741 | `parser_list(',','{')`    | `awt[1]` only | no    | no   |
| `watching P` :775  | `parser_list(',','{')`      | `awt[1]` only | no    | no   |
| toggle `with` :288 | `parser_list(',','{')`      | no            | no    | no   |

Helpers already present:

- `await_ast_logical(e)` :19  -- lowers `||`/`&&`/`!` in one expression.
- `await_where(es)` :56       -- builds `{tag='where', ..}` (await-only).
- `await_is_pool_mode(e)` :49 -- detects `:any`/`:all`.

The per-construct comma-list also enables a broken multi-pattern await
(`every v in :X, :Y` -> `await(:X, :Y)` -> "invalid event pattern").

## Proposed unified helper

```
-- parses:  <pat-expr>  [ where <pred> , <pred> .. ]
-- stop = token ending the predicate list: ')' await, '{' every/watching/toggle
local function parser_await_pat (stop)
    local pat = await_ast_logical(parser())
    if accept('where') then
        local preds = parser_list(',', stop, parser)
        return await_where(pat, preds)   -- rework await_where to (pat, preds)
    end
    return pat
end
```

`await_where` reworked to take `(pat, preds)` instead of the `es` list;
predicate wrapping unchanged (non-func expr -> `\{ e }` with implicit `it`,
a func arg passes through -- user rule #3).

### Call sites collapse to

| site         | becomes                                                  |
| ------------ | -------------------------------------------------------- |
| `await(..)`  | `await( parser_await_pat(')') [, :any/:all] )`           |
| `every .. in P` | `awt = { parser_await_pat('{') }` (single pattern)    |
| `watching P` | `awt = { parser_await_pat('{') }`                        |
| toggle `with`| `filter = { parser_await_pat('{') }` (+combinators+where)|

Net: combinators / `where` / future tweaks live in one place; every /
watching / toggle gain `where`; the broken multi-pattern comma is removed
(use `||`/`&&` for multiple events).

## Wrinkles / decisions

1. `await` call-syntax.
   Today `await(x)::m()` works because await is parsed via the call-chain.
   The predicate `where` must be intercepted *inside* arg parsing anyway
   (else `parser_7_out`'s binding-`where` grabs it and demands `{`), so
   await needs custom `( pattern )` parsing regardless -- main cost.

2. `where` is overloaded.
   Existing `expr where { x=.. }` (binding form, `parser.lua:382`) vs the new
   predicate form. `parser_await_pat` checks `where` right after the base
   pattern, so the predicate form wins in pattern slots; nested binding-where
   inside a predicate still works.

3. toggle filter = "one pattern" per runtime contract -- the single-pattern
   shape fits; confirm `where` on a toggle filter is wanted.

4. pool form stays await-only (`, :any/:all` after the pattern) -- lives in
   the await call site, not the shared helper.

## Depends on (runtime, lua-atmos -- user)

- `tag=='where'` branch in `M.await`:
  `while true do it=M.await(awt[1]); if all awt[2..](it) then return it end end`.
  Predicate gets `it` (first await return) only.

## Pending

- [ ] rework `await_where(pat, preds)` signature
- [ ] add `parser_await_pat(stop)`
- [ ] route await / every / watching / toggle filter through it
- [ ] decide: `where` on toggle filter?  predicate gets `it`-only?
- [ ] manual: `where` predicates, parens rule, combinators

## Done (current branch, value-event migration)

- [x] tasks.lua fully migrated to value events (emit / await / patterns)
- [x] combinator lowering `||`/`&&`/`!` -> `{tag=..}` (`await_ast_logical`)
- [x] `await_where` desugar (comma form) -- to be switched to `where`
- [x] runtime: termination-as-event (defined), `await.time` regression fixed
