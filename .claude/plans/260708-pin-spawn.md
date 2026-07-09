# Plan: pin-spawn — spawn as tail expression

## Problem

`pin t = if x => spawn T()` compiles silently but `t` is always
`nil`, and the spawned task is aborted immediately:

- `spawn` is only preserved as a value when it is the *direct*
  RHS of `val/var/pin =` (`src/prim.lua:339-344`).
- Anywhere else, `parser_1_prim` rewrites it into an implicit
  `pin _ = spawn T()` declaration (`src/prim.lua:196-208`).
- `coder_stmts` never emits `return` for a `dcl`
  (`src/coder.lua:21-33`), so the branch value is `nil`, and the
  `_ <close>` aborts the task when the branch IIFE ends.

There is no workaround today:

- `set t = spawn T()` is a parse error (`tst/tasks.lua:61-70`).
- It could never work anyway: `pin` compiles to
  `local t <close>`, and Lua forbids assigning to `<close>`
  variables.

## Design

`spawn T()` as the **last statement of a value-position block**
remains a plain expression:

- The task flows out of the block unpinned.
- The consumer takes ownership: `pin t = ...` already emits
  `atm_pin_chk_set(true, true, <value>)`, which pins the task
  and scopes it to the declaration's block via `<close>`.
- If no branch spawns (e.g. `if` is false), the value is `nil`
  and the pin holds `nil` — no runtime error.

Scope of the rule:

- Applies only where `coder_stmts` runs with `noret == nil`
  (tag `block`): if/match branches, `do`/`catch`/function/task
  bodies.
- Does NOT apply to loop bodies and top-level `stmts`
  (`noret == true`): the implicit `pin _ =` wrap is kept there,
  preserving abort-at-end-of-block semantics.
- Applies only to `spawn T()` / `spawn @ts T()`; `spawn {}`
  (transparent `do_spawn`) keeps the implicit pin, mirroring the
  direct-RHS rejection at `src/prim.lua:342-344`.

## Changes

| file          | place                            | description                                                                        |
| ------------- | -------------------------------- | ---------------------------------------------------------------------------------- |
| src/prim.lua  | parser_1_prim, spawn branch      | mark implicit dcl with `spw = spw` when `spw.f.tk.str == 'spawn'`                   |
| src/coder.lua | is_stmt / coder_stmts            | tail stmt with `e.spw`: emit `return <e.set>` (with no-TCO guard) instead of `dcl`  |
| doc/manual.md | spawn / pin ownership section    | document tail-spawn-as-value rule and consumer ownership                            |

### src/prim.lua

In the `check('spawn')` branch of `parser_1_prim`
(`src/prim.lua:196-208`), when wrapping into the implicit
`pin _ =` dcl, attach the raw spawn call for the coder:

- `out = { tag='dcl', ..., set=out, spw=spw }`
- only when `spw.f.tk.str == 'spawn'`
  (not `do_spawn`; `spawn_in` is never wrapped).

### src/coder.lua

In `coder_stmts` (`src/coder.lua:25-36`):

- `is_stmt(e)` returns `false` for `e.tag=='dcl' and e.spw`,
  so the tail case reaches the `return` branch.
- Non-tail (`i < #es`) and `noret` positions still emit the dcl
  normally (guarded by the existing `noret or i<#es` check).
- In the `return` branch, code `e.set` instead of `e` when
  `e.spw` is present.

## Semantics / edge cases

Safety argument: the path from a tail `spawn` to the consuming
`pin` is fully synchronous — no `await`/`yield` can occur in
between, so the scheduler never observes the unpinned task.
This is the same window that already exists today in
`pin t = spawn T()` (guarded by test "task 8").

| case                                   | before                     | after                                  |
| -------------------------------------- | -------------------------- | -------------------------------------- |
| `pin t = if x => spawn T()`            | t=nil, task aborted        | t=task (or nil), owned by outer block  |
| `pin t = match ... => spawn T()`       | same bug                   | works (same `ifs` machinery)           |
| `pin t = do { ... spawn T() }`         | same bug                   | works                                  |
| `pin t = if x => if y => spawn A() => spawn B()` | same bug         | works (rule applies at every tail)     |
| `if x { spawn T() }` (statement)       | task aborted at branch end | task unpinned, lives with parent task  |
| `loop { ... spawn T() }` (tail)        | aborted at iteration end   | unchanged (noret path)                 |
| `spawn T()` at top level (tail)        | implicit pin               | unchanged (noret path)                 |
| `spawn {}` at tail                     | implicit pin               | unchanged (transparent task)           |
| `var t = if x => spawn T()`            | t=nil                      | runtime error "expected pinned value"  |

The `var` case errors at runtime because non-pin dcls emit
`atm_pin_chk_set(true, false, ...)`, which rejects unpinned
fresh tasks — consistent with direct `var t = spawn T()`.

### Derived patterns (work for free, worth manual examples)

| pattern                                          | note                                        |
| ------------------------------------------------ | ------------------------------------------- |
| `val f = func () { spawn T() }` + `pin t = f()`  | task factory: function returns unpinned task, caller pins |
| `f(do { spawn T() })`                            | ownership transfer: `pin` inside callee accepts fresh task |
| `pin t = catch :X { spawn T() }`                 | consistent: catch body is a value block     |

Factory caveat to document: the returned task must land in a
`pin` before the next await; the runtime already enforces this
dynamically ("expected pinned value").

Task body tail is a trap, worth a manual note:
`val T = task () { spawn U() }` — U attaches to T's dying
block, so the returned reference is an already-aborted task.

## Notes

- `tst/tasks.lua:511-520` ("spawn 5") asserts the old
  nil-behavior (`var co = if true => spawn t() => nil`); it will
  now hit the "expected pinned value" error instead — needs
  expectation update when tests are run.

## Won't do

- `set t = spawn T()`: impossible with `<close>` encoding of
  pins; keep as parse error.
- Operand position: `x and spawn T()`, `f(spawn T())`,
  `[spawn A(), spawn B()]` — not at a block tail; separate
  design; workaround is always a block (`if x => spawn T()`,
  `f(do { spawn T() })`).
- Loop-tail spawn flowing as value: loop bodies are `noret`;
  out of scope.

## Progress

- [ ] src/prim.lua : mark implicit spawn dcl
- [ ] src/coder.lua : tail unwrap in coder_stmts
- [ ] doc/manual.md : document tail-spawn rule
