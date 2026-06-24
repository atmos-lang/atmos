# await-parens : optional parens around the whole await pattern

## Goal

Let `watching` and `loop on` accept a single optional pair of parens
wrapping the *entire* await pattern, so the pattern-only syntax
(pool prefix `:any`/`:all`, `until`/`while`) works parenthesized,
matching what `await(...)` already supports.

Make these forms valid:

```
watching (:any ts)   { ... }
watching (:all ts)   { ... }
watching (:I until c) { ... }
watching (until done) { ... }
watching (while c)    { ... }
loop on  (:any ts)   { ... }   ;; etc.
```

## Why it is not already so

| statement   | who strips the `(`            | mode of parser_await |
|-------------|-------------------------------|----------------------|
| `await(P)`  | `prim` strips, calls `(')')`  | full pattern         |
| `watching`  | none; `(` goes to `parser()`  | expression base only |
| `loop on`   | none; `(` goes to `parser()`  | expression base only |

So `await(...)` already parses pool/until/while inside parens;
`watching`/`loop on` hand the `(` to the expression parser, which
rejects pool/until/while.

## Constraints found

- Lexer is a single-pass coroutine: no backtracking, 1-token
  lookahead (`TK1`).
    - Cannot "parse, peek past `)`, then backtrack".
- The wrapper must NOT live inside `parser_await`:
    - that would mis-eat the inner grouping paren of the tested
      `await((:X || :Y) && :Z)` (`tst/await.lua:42`).
    - so the wrapper lives at the statement level only.
- Only regression: `watching (:X) || :Y` (paren on the FIRST operand
  of a top-level combinator).
    - used nowhere in `src/ tst/ exs/ doc/`.
    - becomes a loud parse error, not a silent miscompile.
    - rewrite as `:X || :Y` or `(:X || :Y)`.

## Design

Add a helper in `await.lua` (where `mk_tagged`/`parse_pred` are in
scope) that consumes one optional wrapping paren, parses the full
pattern inside via `parser_await(')')`, then still allows a trailing
`until`/`while` after the close paren (back-compat with
`watching (:X) until c`):

```lua
function parser_await_blk ()
    if accept('(') then
        local p = parser_await(')')
        accept_err(')')
        local k = accept('until') or accept('while')
        return k and mk_tagged(k.str, p, parse_pred()) or p
    end
    return parser_await('{')
end
```

`watching` and `loop on` call `parser_await_blk()` in place of
`parser_await('{')`.

## Traces (must hold)

| input                       | result   | note                |
|-----------------------------|----------|---------------------|
| `watching :X`               | ok       | no paren, unchanged |
| `watching (:X)`             | ok       | unchanged           |
| `watching (:X \|\| :Y)`     | ok       | unchanged           |
| `watching ((:A\|\|:B)&&:C)` | ok       | inner via parser()  |
| `watching (:X) until c`     | ok       | trailing until      |
| `watching (:any ts)`        | ok NEW   | pool inside parens  |
| `watching (:all ts)`        | ok NEW   | pool inside parens  |
| `watching (:I until c)`     | ok NEW   | until inside parens |
| `watching (until done)`     | ok NEW   | base-less inside    |
| `watching (while c)`        | ok NEW   | base-less inside    |
| `watching (:X) \|\| :Y`     | ERR      | regress; rewrite    |

Same table for `loop on`.

## Files

| file          | place                          | change                  |
|---------------|--------------------------------|-------------------------|
| src/await.lua | after `parser_await`           | add `parser_await_blk`  |
| src/prim.lua  | `watching` branch (~702)       | call `parser_await_blk` |
| src/prim.lua  | `loop on` branch (~647)        | call `parser_await_blk` |
| doc/manual.md | Watching / Loop-on / Await     | note optional parens    |

## Out of scope

- `toggle` filter lists (comma-separated): leave as is for now.
- `await(...)` itself: already works; untouched.

## Status

- [ ] add `parser_await_blk` in `await.lua`
- [ ] wire `watching` branch in `prim.lua`
- [ ] wire `loop on` branch in `prim.lua`
- [ ] manual note
- [ ] verify with sample `.atm` files
