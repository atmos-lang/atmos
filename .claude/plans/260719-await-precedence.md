# Plan: dedicated await-pattern parser with precedence levels

## Motivation (reported bugs)

```
watching X() || true until c        ;; parses as (X()||true) until c:
                                    ;; X aborted+respawned per event
watching Hold(:X) || until c        ;; `until` becomes loop-break
                                    ;; atm_until: parse/runtime error
```

Today `parser_await` (`src/await.lua`) parses patterns with the
generic expression parser and rewrites the AST after the fact
(`await_ast_logical`):

- `until`/`while` are only whole-pattern prefix/suffix, silently
  binding outside `||`/`&&`
- bare `until c` is invalid as a `||` operand: `until` parses as
  an identifier (`src/prim.lua:680-681`) and gets miscoded as the
  loop-break `atm_until` (`src/coder.lua:49,58-59`)
- the intended grouping `(true until c)` is a parse error

The runtime already supports nested combinator tables
(`lua-atmos/atmos/run.lua:506-512`), so this is compiler-only.

## Design

Replace the rewrite approach with a dedicated recursive-descent
pattern parser, `parser_await_N_*`, mirroring the expression
cascade `parser_1_prim`..`parser_7_out`.

### Levels

| level | function              | forms                          |
|-------|-----------------------|--------------------------------|
| 1     | `parser_await_1_prim` | leaf patterns (below)          |
| 2     | `parser_await_2_pre`  | `!p`                           |
| 3     | `parser_await_3_bin`  | `p && q` , `p || q` ,          |
|       |                       | `p until c` , `p while c`      |

- Level 3 mirrors `parser_5_bin` (`src/parser.lua:376-388`):
  same-op chaining only; mixing `&&`/`||`/`until`/`while`
  without parens errs "use parentheses to disambiguate"
- `&&`/`||` rhs recurses level 2; `until`/`while` rhs is an
  expression via `parser()` (wrapped `\it -> e`, as `parse_pred`)

### Prims (level 1)

| prim                  | result                                 |
|-----------------------|----------------------------------------|
| `:X [v]`              | tag (+ payload), as today              |
| `@1` / `@(e)`         | clock                                  |
| `:any e` / `:all e`   | pool shortcut (today's PRE shortcut)   |
| `until c` / `while c` | bare predicate, = `true until c`;      |
|                       | now valid as a `||`/`&&` operand       |
| `T(...)` / `f :X`     | call -> `{tag='spawn', ...}`           |
| `(PAT)`               | grouping: recurse level 3              |
| `(expr)`              | value escape: lone call or plain expr  |
|                       | stays verbatim (generalizes `(f())`)   |

Bare ids/literals remain parens-only (`await(x)`), as today.

### Resulting behavior

```
watching X() || true until c    ;; ERROR: use parentheses
watching X() || (true until c)  ;; ok, explicit
watching (X() || true) until c  ;; ok, explicit (respawn opt-in)
watching Hold(:X) || until c    ;; ok: until-prim as operand
```

### Settled design points

- Parens ambiguity: a lone call in parens = value escape
  (today's rule); grouping only matters for combinators
- Predicate extent: `until c1 && c2` swallows `&&` into the
  predicate (matches `parse_pred` doc); resume pattern
  combinators by closing the group: `(p until c) || q`
- acc-`until` hack (`src/prim.lua:680-681`) stays for loop-break
  statements; patterns no longer route through it

## Steps

- [ ] `src/await.lua`: implement `parser_await_1_prim`,
      `parser_await_2_pre`, `parser_await_3_bin`
    - entry `parser_await(stop)` dispatches to level 3
    - keep `:any`/`:all` and bare `until`/`while` as prims
    - build combinator tables directly via `mk_tagged`
      (replaces `await_ast_logical` rewrite)
    - keep bare-await gating (`stop==nil`): base must start as
      call-arg token or parse into a call
- [ ] error message for mixed ops:
      "operation error : use parentheses to disambiguate"
      (same as `parser_5_bin`)
- [ ] verify call sites: `await`, `watching`, `toggle with`
      (stop=','), `loop on`, `every` -- all via `parser_await`
- [ ] `doc/manual.md` (await patterns section):
    - pattern grammar with the 3 levels
    - no-mixing rule and parens grouping
    - `until c` operand form; value-escape rule

## Compatibility

- unchanged: `p until c` (single base), prefix `until c`,
  `:any`/`:all`, `(f())` escape, `((x))` unwrapping, tag
  payloads, clocks, bare-await form, mixed `||`/`&&` error
  (same message, same near-token)
- breaking (intended): unparenthesized `p || q until c` and
  `p && q until c` now err instead of silently meaning
  `(p || q) until c` (no test used these forms)
- relaxed (intended): value ops now bind tighter than pattern
  combinators, so `await(a + b || c)` is valid (was: mixing
  error) -- levels imply value-vs-pattern precedence
- new: `p until a until b` chains (same-op rule)
- corner: `(a, b)` es-lists no longer parse in pattern leaf
  base position (no test/example uses them in patterns)

## Final leaf rule (Option B)

`await_ast_logical` removed: the grammar carries the semantics.
The whole leaf rule is `await_ast_spawn`: a bare task call
spawns; anything else is a value leaf. Parens escape by
construction (`(f())` is a parens node, not a bare call) -- no
unwrap pass. AST difference: escaped leaves keep their `parens`
node (identical Lua semantics; no tosource test asserts them).

## Won't do

- implicit precedence between `until` and `||`/`&&` (violates
  the no-precedence rule)
- runtime changes (nested tables already supported)

## Progress

- [x] Bug analysis and design
- [x] Implementation (`src/await.lua` rewritten with levels)
- [x] Refactors: no rewrite pass (`await_ast_spawn`), leaf
      inlined into prim, levels as globals (as `parser.lua`),
      single parse path with bare-form post-check ("error back")
- [x] Bare check simplified to AST-only allow-list (no token
      pre-gate): pat tables except and/or/not; leaves
      tag/clk/str/nat/table/proto/call
- [x] Breaking (accepted): bare `await` + trailing value op errs
      (`await 20min + 1s` -> use `await(20min) + 1s`); bare
      `await :X || :Y` errs (was footgun `(await :X) || :Y`);
      updated `tst/expr.lua` accordingly
- [x] Manual: grammar block updated (staged); extra prose +
      Ambiguities row removal -> WON'T DO (user's call)
- [ ] New tests for the fixed forms (not yet added)
- [ ] Tests pass (user runs `cd tst && lua5.4 all.lua`)
