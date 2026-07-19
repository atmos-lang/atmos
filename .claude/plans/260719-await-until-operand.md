# Plan: until(c) / while(c) as await-pattern operands

## Motivation (reported bugs)

```
watching X() || true until c        ;; parses as (X()||true) until c:
                                    ;; X aborted+respawned per event
watching Hold(:X) || until c        ;; `until` becomes loop-break
                                    ;; atm_until: parse/runtime error
```

`until`/`while` are only whole-pattern prefix/suffix in
`parser_await` (`src/await.lua`), not composable under `||`/`&&`,
even though the runtime already supports nested combinator tables
(`lua-atmos/atmos/run.lua:506-512` recurses into subs).

## Design

Reuse the statement call syntax `until(c)` / `while(c)` as pattern
operands:

```
watching X() || until(c)        { ... }
watching Hold(:X) || until(c)   { ... }
```

| form                  | meaning                                 |
|-----------------------|-----------------------------------------|
| `p until c` (suffix)  | unchanged: whole-pattern predicate      |
| `until c` (prefix)    | unchanged: any event until `c`          |
| `until(c)` (operand)  | new: same as `true until c`, composable |

- `X || until(c)` already parses today as a call to the acc
  `until` (`src/prim.lua:680-681`), later miscoded as loop-break
  `atm_until` (`src/coder.lua:49,58-59`) and misread as a task
  spawn by `is_task_call`.
- Fix is compiler-only: rewrite that call inside patterns.

## Desugaring

```
until(c)    -->  {tag='until', \it -> c}
while(c)    -->  {tag='while', \it -> c}
p || until(c)  -->  {tag='or', p, {tag='until', \it -> c}}
```

Single-predicate `{until, f}` form is already handled by the
runtime (`run.lua:529-534`).

## Steps

- [ ] `src/await.lua` `await_ast_logical`:
    - new case: `e.tag=='call'` and `e.f.tag=='acc'` and
      `e.f.tk.str=='until'|'while'`
    - require exactly 1 argument
    - wrap arg as predicate (reuse/extract the `\it -> e` wrap
      from `parse_pred`; keep `proto` args as-is)
    - return `mk_tagged(str, pred)`
- [ ] check `is_task_call` ordering: new case must run before the
  spawn rewrite
- [ ] `doc/manual.md` (await patterns section):
    - document `until(c)` / `while(c)` operand form
    - discourage `p || true until c` (until binds the whole
      pattern; rejected events abort+respawn task branches)

## Won't do

- precedence for `until` suffix (violates no-precedence rule,
  silently changes existing programs)
- `(p until c)` parenthesized sub-patterns (needs dedicated
  pattern parser; conflicts with `(f())` value escape)

## Progress

- [x] Bug analysis and design
- [ ] Implementation
- [ ] Manual update
