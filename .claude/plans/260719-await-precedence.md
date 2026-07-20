# Plan: await-pattern parser (precedence + explicit spawn)

## Phase 1 -- precedence levels (DONE)

Replaced the post-parse rewrite with a leveled recursive-descent
pattern parser in `src/await.lua`, mirroring the expression cascade.

| level | function              | forms                          |
|-------|-----------------------|--------------------------------|
| 1     | `parser_await_1_prim` | leaves, `:any`/`:all`, `until c`, `(p)` |
| 2     | `parser_await_2_pre`  | `!p`                           |
| 3     | `parser_await_3_bin`  | `&&` `||` `until` `while` (one level, same-op only) |

Outcome (shipped, `214a36e`):

- both reported bugs fixed:
  `X() || (true until c)` and `Hold(:X) || until c` parse
- mixing combinators without parens errs, as `parser_5_bin`
- bare `await` accepts a single primary/spawn (+ optional
  `until`/`while`); combinators and value ops require `await(...)`
- grammar block in `doc/manual.md`

## Phase 2 -- explicit spawn for operands (ACTIVE)

### Problem

A call in a pattern is overloaded: `T()` spawns-and-awaits, while a
value-await needs the `((f()))` escape.
This overload is the sole reason for the `parens`/deferred-spawn
machinery in `parser_await` (the `parens` flag, the operand
`await_ast_spawn`, the double-paren escape).

### Rule

A bare call implicitly spawns ONLY when it is the entire pattern
(the statement-head positions).
As an operand of any combinator, a bare call is a value; a task
requires an explicit `spawn` prefix.

| form                         | meaning            | today       |
|------------------------------|--------------------|-------------|
| `await T()`                  | spawn + await task | same        |
| `watching T()`               | spawn + await      | same        |
| `loop on T()`                | spawn + await      | same        |
| `toggle .. T()`              | spawn + await      | same        |
| `await(f())`                 | value-await        | was spawn   |
| `await(spawn T())`           | spawn + await      | was `await(T())` |
| `await(spawn T() || :X)`     | task races `:X`    | new         |
| `:any [spawn T(), spawn U()]`| pool of tasks      | needs spawn |

### Why it simplifies

Operands become unambiguous (bare call = value, `spawn` = task),
which removes:

- the `parens` flag threaded through levels 1-3
- the operand `await_ast_spawn` promotion in the bin loop
- the `((f()))` value escape (inside `(...)` a call is already a
  value; `await(f())` IS the value-await)

`spawn` becomes an explicit prim (like `:any` / `until`).
The only implicit spawn is a single post-parse check at each entry
point: "if the whole pattern is a lone call -> spawn it".

### Parens

Parens are grouping and do not change task-vs-value meaning, EXCEPT
an extra paren layer around a call is the value-escape:

- outer delimiter (`await(...)`): stripped by `prim.lua`, so
  `await(T())` == `await T()`
- nested `(p)` where `p` is a pattern: grouping, returns `p`
- nested `(call)` / `(value)`: value-escape, stays a `parens` node
  (never spawns) -- keeps the `((f()))` escape

Implicit spawn is decided once, at the top of `parser_await`:
if the whole pattern is a BARE, unwrapped lone call -> spawn it.
A `parens`-wrapped call fails this check, so `((T()))` is a value.
Operands never implicit-spawn.

```
await T()          ;; bare lone call -> spawn
await(T())         ;; outer stripped -> lone call -> spawn
await((T()))       ;; nested (T()) -> parens node -> VALUE
await(T() || :X)   ;; operand call -> value; spawn for a task
await(spawn T())   ;; explicit task
```

### Steps

- [x] `parser_await_1_prim`: add `spawn` prim -> `{tag='spawn', ...}`
      (keep the `(` branch: pattern -> grouping, else parens-wrap)
- [x] remove the `parens` flag from levels 1-3 and the bin-loop
      `await_ast_spawn` (operands stay as parsed: bare call = value)
- [x] `parser_await` top: single implicit-spawn for a bare lone
      call (verified against local `src/`)
- [x] update tests that used implicit operand spawn: `tst/await.lua`
      `watching T() || :X` -> `watching spawn T() || :X` (2 tests,
      runtime-verified); `tst/expr.lua` operand-value assertions.
      Full scan: no other implicit-operand-spawn in tests/examples
- [ ] `doc/manual.md`: grammar + the implicit/explicit spawn rule

### Costs (breaking)

- composed task patterns gain `spawn`
  (`T() || ..`, `!T()`, `:any [T()]`)
- `T()` is context-dependent: task when it is the whole pattern,
  value as an operand
- unchanged: bare `await T()`, `((f()))` value-escape

## Won't do

- make `spawn` obligatory everywhere (taxes the common
  `await T()`; reverts the phase-1 compose intent)
- implicit precedence between `until` and `||`/`&&`
- runtime changes (nested tables already supported)

