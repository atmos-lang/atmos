# Plan: Add Exponentiation Operator `**`

Implements [issue #6](https://github.com/atmos-lang/atmos/issues/6).

## Summary

Add the `**` binary operator for exponentiation to the Atmos language.
The operator maps directly to Lua's `^` operator.

Examples from the issue:
- `2 ** 3` evaluates to `8`
- `9 ** (1/2)` evaluates to `3.0`

## Design Decisions

- **Lexer**: `*` is already in `OPS.cs`, so `**` will be tokenized
  correctly once added to `OPS.vs`.
- **Parser**: Adding `**` to `OPS.bins` makes it work automatically
  with `parser_5_bin()`. Like all binary operators, it is
  left-associative and requires parentheses when mixed with other
  operators (e.g., `2 ** 3 + 1` is an error;
  use `(2 ** 3) + 1` instead).
- **Coder**: Lua uses `^` for exponentiation, so the mapping
  `['**'] = '^'` in `OPS.lua` enables direct pass-through
  (no runtime helper needed).
- **Documentation**: The manual and operator listings are updated to
  include `**`.

## Changes

### 1. `src/global.lua` — Register the operator
- [x] Add `'**'` to `OPS.vs` (valid operator strings)
- [x] Add `'**'` to `OPS.bins` (binary operators)
- [x] Add `['**'] = '^'` to `OPS.lua` (Lua mapping)

### 2. `tst/expr.lua` — Parser tests
- [x] Add test: `2 ** 3` parses to `(2 ** 3)`
- [x] Add test: `2 ** 3 + 1` produces disambiguation error
- [x] Add test: `2 ** 3 ** 2` parses to `((2 ** 3) ** 2)`
  (left-associative)

### 3. `tst/exec.lua` — End-to-end execution tests
- [x] Add test: `2 ** 3` outputs `8`
- [x] Add test: `9 ** (1/2)` outputs `3.0`
- [x] Add test: `(2 ** 3) ** 2` outputs `64`

### 4. `doc/manual-out.md` — Documentation
- [x] Add `**` to the operator table of contents (line 17)
- [x] Add `**` to the operator listing in section 3.3 (line 522)
- [x] Add `**` to the operations section 5.3 (line 1381)
- [x] Add `**` to the Lua vs Atmos subtleties (line 372)

## Status

- [x] Plan created
- [x] Implementation
- [x] Tests
- [x] Documentation
- [ ] PR created
