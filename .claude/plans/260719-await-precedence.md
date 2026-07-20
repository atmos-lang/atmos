# Plan: await-pattern parser (three delimited tiers) -- COMPLETE

All phases done. Full test suite passes (verified against local
`src/`, confirmed by user). Final design: three tiers
(`await P` / `await(E)` / `await<PAT>`), calls spawn in pattern
mode, `(f())` for value, mandatory predicate parens.


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

## Phase 2 -- explicit spawn for operands (DONE, may be superseded by Phase 3)

### Problem

A call in a pattern is overloaded: `T()` spawns-and-awaits, while a
value-await needs the `((f()))` escape.
This overload is the sole reason for the `parens`/deferred-spawn
machinery in `parser_await` (the `parens` flag, the operand
`await_ast_spawn`, the double-paren escape).

### Rule (refined)

Inside a pattern (bare or `<>`), a bare call SPAWNS -- operand or
not; there is NO `spawn` keyword. To await a call's value, drop to a
`(f())` value leaf. The value tier `await(E)` treats calls as values.
So: `await T()` / `await<T() || :X>` spawn; `await(f())` /
`await<(f()) || :X>` are values.

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

## Phase 3 -- three delimited tiers (PROPOSED)

Split await into three orthogonal grammars, one per delimiter, so
value and pattern never share syntax:

| tier   | form        | grammar                | notes                     |
|--------|-------------|------------------------|---------------------------|
| bare   | `await P`   | one primary            | lone call -> spawn (sugar)|
| value  | `await(E)`  | value expr (`parser()`)| value-await               |
| patt   | `await<PAT>`| pattern cascade        | combinators live here     |

Applies equally to `watching< >`, `loop on< >`, `toggle .. with< >`.

### Pattern grammar (inside `<>`)

- leaves: `:X [v]`, clock, `:any`/`:all`, `spawn T(...)`,
  `until c` / `while c`, `(E)` (value fallback = tier 2)
- combinators: `!p`, `p && p`, `p || p`, `p until c`, `p while c`
  (one level, same-op only, mixing errs)
- grouping: NESTED `<...>` -- `()` is always a value leaf, so a
  sub-pattern is regrouped with `<>`

```
await< :X || :Y >
await< spawn T() || until c >
await< (a < b) >                ;; value leaf via tier 2
await< <:X || :Y> until c >     ;; grouping via nested <>
await(f())                      ;; value-await, no ((..)) escape
await T()                       ;; bare lone-call spawn
```

### What it deletes

- the value-op leaf loop and its mixing check (line 109): value
  ops live in tier 2, never at pattern level
- the `((f()))` escape: value is plain `await(E)`
- the `&&`/`||` overload: pattern-or in `<>`, value-or in `()`

`parser_await` becomes a dispatch on the opener:
bare -> one primary; `(` -> `parser()`; `<` -> the cascade.

### Costs

- new `<>` syntax; lexer special-cases `<`/`>` as delimiters right
  after `await`/`watching`/`loop on`/`toggle .. with`
- `<` reads as less-than at a glance
- broad (mechanical) migration: `await(:X||:Y)` -> `await<:X||:Y>`,
  `watching T()||:X` -> `watching< spawn T()||:X >`
- `await(T())` becomes a value-await (bare `await T()` still spawns)

### Predicate parens (resolved blocker)

`>` is both the pattern closer and the comparison operator, so a bare
predicate `until c` lets `parser()` eat the closing `>`
(`<:X until c>` -> "expected expression").
Fix: `until`/`while` predicates are ALWAYS parenthesized -- `until (c)`,
`while (c)` -- and `parse_pred` consumes the `()` itself, bounding the
inner parser so it never sees `>`. Uniform (bare too): `await :X
until (c)`.

### Status

- [x] parser DONE + verified: three-tier dispatch, `<>` cascade,
      nested `<>` grouping, `spawn` prim, value-op loop removed,
      `parse_pred` mandatory parens, `:any`/`:all` bounded arg
- [x] `src/prim.lua`: await/watching/loop-on/toggle call `parser_await()`
- [x] MIGRATION of all 8 test files -- full suite green against
      local `src/` (expr, await, toggle, stmt, exec, tasks, +others).
      Bounding rule inside `<>`: predicates `until (c)`, pool args
      `:any (E)`, value leaves `(E)`, grouping nested `<>`.
      Also: `bool` added to bare allow-list (`await true`); bare
      ident (`watching f`) now errs at parse, not runtime
- [x] examples: `exs/click-drag-cancel.atm` (only breaking one) migrated
- [x] `doc/manual.md`: three-tier grammar, escape prose, Await
      examples, Ambiguities rows (await/toggle). `manual-out.md`
      regenerates from `manual.md`
    - `await(:X || :Y)` -> `await<:X || :Y>`
    - `await(:X until c)` -> `await<:X until (c)>`
    - `await :X until c` -> `await :X until (c)`
    - `watching :X||:Y {` -> `watching <:X||:Y> {`
    - `await((f()))` -> `await(f())`
    - operand `T()` -> `spawn T()`

## Won't do

- make `spawn` obligatory everywhere (taxes the common
  `await T()`; reverts the phase-1 compose intent)
- implicit precedence between `until` and `||`/`&&`
- braces `{ }` for patterns (clash with block bodies)
- runtime changes (nested tables already supported)

