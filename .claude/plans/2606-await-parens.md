# await-parens : parenthesize await patterns + tidy parser_await

## Goals

1. Let every await-pattern statement accept ONE optional pair of parens
   wrapping the whole pattern, so pool (`:any`/`:all`), `until`/`while`
   work parenthesized (matching what `await(...)` already does):

   ```
   watching (:any ts)    { ... }
   watching (:I until c) { ... }
   watching (until c)    { ... }
   loop on  (:any ts)    { ... }   ;; etc.
   ```

2. Make bare `await :X || :Y` an ERROR (ambiguous), while
   `watching :X || :Y` stays fine.

3. Simplify `parser_await`: drop the dead `stop` param, fold paren
   handling into it, rename `base0` -> `bare`.

## Rules

### Opening `(` ends the pattern (like `await`)

If a pattern opens with `(`, the matching `)` ends it; nothing
pattern-related may follow.

- no parens -> trailing `until`/`while` allowed: `watching :X until c`
- parens    -> must be inside: `watching (:X until c)`
- `watching (:X) until c` -> NOT ok
- `watching (:X) || :Y`   -> NOT ok

### Bare `await` rejects trailing combinators

`await` is an expression (can be an operand), so bare
`await :X || :Y` is ambiguous (pattern combinator vs logical-or on the
result). Require parens:

- `await(:X || :Y)`  -> combinator pattern
- `await(:X) || :Y`  -> logical-or on the await result
- `await :X || :Y`   -> ERROR "ambiguous await : use parens"

`watching`/`loop on` are statements (never operands), so
`watching :X || :Y` is unambiguous and stays valid.

## Why not already so / constraints

| statement   | who strips `(`               | base parser           |
|-------------|------------------------------|-----------------------|
| `await(P)`  | `prim` strips, runs full     | full pattern          |
| `watching`  | none; `(` -> `parser()`      | expression base only  |
| `loop on`   | none; `(` -> `parser()`      | expression base only  |

- Lexer is single-pass (coroutine): 1-token lookahead, no backtrack.
- `stop` param of `parser_await` is DEAD: never read in the body;
  expression end is `parser()`'s job, list end is `parser_list_1`'s.
- Paren strip must be ONCE then delegate the base to `parser()`, so
  nested grouping like `((:A||:B)&&:C)` stays intact. Use a `par` FLAG
  (not recursion): consume at most one leading `(`, parse the base with
  `parser()`, then one closing `accept_err(')')`. A recursive
  `parser_await` would eat the inner grouping paren and drop `&& :C`;
  the flag does not. `par` also forces `bare=false` (parens => full
  expression base, combinators ok).

## Design

`src/await.lua` — one function, `par` flag, single-exit `pat`:

```lua
function parser_await (bare)
    local par = accept('(')
    if par then bare = false end

    local pat
    local m = accept(':any','tag') or accept(':all','tag')
    if m then
        pat = { tag='table', es={ ...tasks-table (unchanged)... } }
    else
        local k0 = accept('until') or accept('while')
        if k0 then
            pat = mk_tagged(k0.str, parse_pred())
        else
            local base = bare and parser_1_prim() or parser()
            pat = await_ast_logical(base)
            local k = accept('until') or accept('while')
            if k then pat = mk_tagged(k.str, pat, parse_pred()) end
            -- bare await: trailing &&/|| is ambiguous -> require parens
            if bare and (check('&&') or check('||')) then
                err(TK1, "ambiguous await : use parens")
            end
        end
    end

    if par then accept_err(')') end
    return pat
end
```

(`accept_err(')')` so `watching (:X {` is a real error.)

`src/prim.lua` — call sites:

| place        | from                                    | to                  |
|--------------|-----------------------------------------|---------------------|
| await else   | `if accept('(') ... else ... end` (12L) | `parser_await(true)`|
| watching     | `parser_await('{')`                     | `parser_await(false)`|
| loop on      | `parser_await('{')`                     | `parser_await(false)`|
| toggle x2    | `parser_await('{')` / `(func)`          | `parser_await()`    |

## Behavior table (must hold)

| input                       | result | note                |
|-----------------------------|--------|---------------------|
| `await :X`                  | ok     | single primary      |
| `await(:X)`                 | ok     |                     |
| `await(:X \|\| :Y)`         | ok     | combinator pattern  |
| `await(:X) \|\| :Y`         | ok     | logical-or on result|
| `await :X \|\| :Y`          | ERR    | ambiguous           |
| `await((:X\|\|:Y)&&:Z)`     | ok     | inner via parser()  |
| `watching :X \|\| :Y`       | ok     | statement           |
| `watching (:X)`             | ok     |                     |
| `watching ((:A\|\|:B)&&:C)` | ok     | inner via parser()  |
| `watching (:any ts)`        | ok NEW | pool in parens      |
| `watching (:I until c)`     | ok NEW | until in parens     |
| `watching (until c)`        | ok NEW | base-less in parens |
| `watching (:X) until c`     | ERR    | `)` ends pattern    |
| `watching (:X) \|\| :Y`     | ERR    | `)` ends pattern    |

Same as `watching` for `loop on`. `toggle` comes along via the unified
`parser_await` (single parenthesized filter items now accepted; the
unused `(:X)||:Y` filter-item form errors).

## Files

| file          | place                       | change                       |
|---------------|-----------------------------|------------------------------|
| src/await.lua | `parser_await`              | `par` flag + paren + bare guard; drop `stop`; `base0`->`bare` |
| src/prim.lua  | await / watching / loop / toggle | update 5 call sites    |
| doc/manual.md | Ambiguities (~2722), ~2168  | bare `await \|\|` is an error|
| doc/manual.md | Watching / Loop-on / Await  | note optional parens         |
| tst/stmt.lua  | new `--- AWAIT PARENS ---` after `--- LOOP ON ---` (~980) | watching/loop-on parens parse = bare AST; strict-rule errors (`assertfx`) |
| tst/toggle.lua| after filter tests (~90)    | toggle `with (...)` parens forms (`tosource`) |
| tst/await.lua | top + header comment (4-9)  | bare `await \|\|` errors; `await(:X)\|\|:Y` / `await(:X\|\|:Y)` ok; fix stale comment |

Test style: parser-level (`parse` -> `tosource` equality, or `assertfx`
for the error cases). User runs the suite; do not execute.

## Status

- [ ] rewrite `parser_await`: `par` flag + paren + bare-combinator guard
- [ ] drop `stop`, rename `base0` -> `bare`
- [ ] update 5 call sites in `prim.lua`
- [ ] manual: Ambiguities + optional-parens notes
- [ ] tests: stmt.lua (watching/loop-on), toggle.lua, await.lua
- [ ] verify with `scratchpad/baseline.sh` (7 ERR -> PASS)
