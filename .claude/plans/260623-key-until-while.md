# Plan: make `until` / `while` reserved keywords

## Status

PENDING.

## Goal

Promote `until` and `while` from soft (contextual) words to reserved
keywords, so they lex as `key` tokens instead of `id` tokens.

## Motivation

- The manual already lists `until` and `while` as keywords
  (`doc/manual.md`, Keywords section), but the implementation keeps
  them commented out in `KEYS`.
  This aligns the implementation with the documentation.
- It removes a special-case workaround in the `await` dispatch.
  Because `until`/`while` currently lex as `id`, `await until f`
  matched `check(nil,'id')` and was wrongly routed into the
  `await T(...)` spawn sugar.
  The guard `not (check('until') or check('while'))` only exists to
  undo that misroute.

## Current state

| file              | place                | detail                          |
|-------------------|----------------------|---------------------------------|
| `src/global.lua`  | `KEYS`               | `until`/`while` commented out   |
| `src/lexer.lua`   | id branch (~158)     | `contains(KEYS,id)` -> key/id   |
| `src/prim.lua`    | await dispatch (166) | guards against `until`/`while`  |

How matching works:

- `check(nil,'id')` matches by `tag` (fails for a `key` token).
- `check('until')` / `accept('until')` match by `str` only
  (tag-agnostic), so they keep working for a `key` token.

## Change

1. `src/global.lua`: move `'until'` and `'while'` out of the commented
   line and into the active `KEYS` list.
2. `src/prim.lua` (await dispatch, ~166): revert the guard back to a
   plain `if check(nil,'id') then`.
   With `until`/`while` as keys, `check(nil,'id')` is already false for
   them, so the extra condition is dead.

## Consequences

- `until` and `while` can no longer be used as identifiers or field
  names (`t.until`, `.while` would now require an `id` token).
  Verified: no such use exists in the sources or examples; all current
  occurrences are loop-break clauses or await predicates.
- All `accept('until')` / `accept('while')` sites keep working
  (string match, not tag match): `parser_await` (synchronous and base
  forms) and the loop-break clauses in `prim.lua`.
- The soft-word group (`abort`, `break`, `escape`, `it`, `pub`,
  `return`, `skip`, `throw`, `xtask`) stays as-is; only `until` and
  `while` graduate to hard keywords.

## Verify (inspection)

- `KEYS` contains `until` and `while`; the lexer yields `key` tokens
  for them.
- `await until f`, `await(:X until f)`, `loop ... until f`, and the
  break clauses `until(...)` / `while(...)` still parse.
- the reverted `await` dispatch no longer mentions `until`/`while`.

## Follow-up (separate)

- The broader doc/impl mismatch remains: the manual also lists
  `break`, `escape`, `it`, `pub`, `return`, `throw` as keywords while
  `KEYS` keeps them soft.
  Reconciling the rest (either direction) is out of scope here.
