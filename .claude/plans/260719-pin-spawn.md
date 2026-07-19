# Plan: pin t = spawn { ... } as non-transparent task

## Goal

Make `pin t = spawn { ... }` valid, spawning an anonymous
non-transparent task, equivalent to the current workaround:

```
pin t = spawn (task () { ... }) ()
```

Currently rejected at `src/prim.lua:338` with
"invalid assignment : unexpected transparent task".

## Feasibility

- Runtime already supports it:
    - `spawn(task(atm_func(function () ... end)))`
    - `run.spawn` accepts any `meta_task` prototype
      (`lua-atmos/atmos/run.lua:447`)
- Change is compiler-only (parser AST rewrite), no coder or
  runtime changes needed.

## Desugaring

```
pin t = spawn { BLK }
--
pin t = spawn(task(atm_func(function () BLK end)))
```

AST rewrite of the `do_spawn` call built by `parser_spawn`:

| field           | before      | after   |
|-----------------|-------------|---------|
| `spw.f.tk.str`  | `do_spawn`  | `spawn` |
| `spw.es[1].sub` | `lua`       | `task`  |

The coder then emits `spawn(task(atm_func(function () ... end)))`
via the existing `proto` case (`src/coder.lua:118-142`).

## Steps

- [ ] `src/prim.lua` (dcl branch, ~line 333-339):
    - if `tk.str == 'pin'` and `spw.f.tk.str == 'do_spawn'`:
        - rewrite `spw` as above (promote to real task)
    - else (`val`/`var`): keep current error
- [ ] `doc/manual.md`: document `pin t = spawn { ... }`

## Semantics (after change)

- Inside the block, `pub`/`xtask()` refer to the new task
  itself (not the enclosing task, unlike transparent spawn)
- `t` is a real task handle: `await(t)`, `t.pub`,
  `emit_in(t, ...)`, `abort(t)` all work
- Plain statement `spawn { ... }` remains transparent
  (unchanged)

## Out of scope / won't do

- `val`/`var` `= spawn { ... }`: still an error (a real task
  would fail the pin check at runtime anyway)
- `set x = spawn { ... }`: unchanged
- `spawn @ts { ... }` (pool + block): unchanged

## Affected tests (for user to run)

- `tst/tasks.lua` "pin 4": updated to expect an xtask handle
- `tst/tasks.lua` "pin 5": new — `pub` refers to the new task
- `tst/tasks.lua` "pin 6": new — `await(t)` on termination
- `tst/stmt.lua:877`: `val` case — unchanged, still errors

## Progress

- [x] Feasibility analysis
- [x] Tests written first (pin 4/5/6)
- [x] Implementation (`src/prim.lua` dcl branch)
- [ ] Tests pass (user runs `cd tst && lua5.4 tasks.lua`)
- [ ] Manual update
