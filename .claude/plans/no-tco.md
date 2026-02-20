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
- [x] Investigated `par_or 6` failure (`dbg` nil in
      `run.lua:211`) — initially theorized escape TCO bug,
      but theory was **disproved** by tests (`escape` always
      throws, so `return` before it is innocuous). Issue was
      resolved upstream in lua-atmos.
- [x] Added escape test to `tst/exec.lua` (passes — confirms
      escape works correctly with current runtime)
- [x] All tests passing

## Edits
- `src/exec.lua:24` — `atmos.call` → `atmos.loop`
- `tst/exec.lua` — added escape test at end of file

## Pending
- [ ] Decide: keep or remove the escape test in `tst/exec.lua`
      (it passes but was created to investigate a wrong theory)
- [ ] Fix broken symlink `lua/atmos` → `.atmos/fixes/`
      (only `.atmos/main/` exists)
- [ ] Remove debug `print('xxx', cur)` from
      `lua/atmos/atmos/lang/aux.lua:16` (installed version)
- [ ] Commit and push when ready
