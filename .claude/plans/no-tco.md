# Plan: no-tco

## Description
Understand `coder_stmts` in `coder.lua` — how the statement
code generation works, with focus on understanding the current
implementation. Fix test infrastructure to work with current
lua-atmos runtime.

## Done
- [x] Full walkthrough of `coder_stmts`, `is_stmt`, and all
      6 call sites
- [x] Explained `noret` parameter: `true` = imperative context
      (no implicit return), `false` = expression context (last
      expression is the block's value)
- [x] Critical case: `noret=true` in `loop` prevents `return`
      from breaking the `for` loop on first iteration
- [x] Fixed `atmos.call` → `atmos.loop` in `src/exec.lua:24`
      (`atmos.call` was removed from lua-atmos runtime)
- [x] Investigated `par_or 6` failure — resolved upstream
- [x] Confirmed escape TCO bug: without `escape` in `is_stmt`,
      `return escape(...)` tail-call erases frame →
      `debug.getinfo(2)` returns `[C]:-1` instead of source line
- [x] Added `escape` to `is_stmt` in `src/coder.lua:25`
- [x] Added "catch 8b : err : escape" test in `tst/exec.lua`
      (after "catch 8") — verifies escape error shows correct
      source location
- [x] Fixed broken symlink `lua/atmos` → `.atmos/main/`
- [x] Removed debug `print('xxx', cur)` from installed aux.lua
- [x] All tests passing

## Edits
- `src/exec.lua:24` — `atmos.call` → `atmos.loop`
- `src/coder.lua:25` — added `escape` to `is_stmt`
- `tst/exec.lua:1554` — added "catch 8b : err : escape" test

## Pending
- [ ] Remove old escape TCO test at end of `tst/exec.lua`
      (superseded by "catch 8b")
- [ ] Discuss `_no_tco_ <close>` as alternative to `is_stmt`
- [ ] Commit and push when ready
