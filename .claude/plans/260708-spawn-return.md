# spawn-return -- escapes crossing transparent `spawn {}`

## Goal

`return()` inside a transparent `spawn {}` should IGNORE the
transparent task and terminate the enclosing non-transparent
prototype (same invisibility as `pub`/`emit`).

Follow-up of `done/260706-task-self.md` discussion.

## Current behavior (characterized by tests below)

The spawn block compiles to its own `atm_func` wrapper
(`prim.lua` spawn() -> proto sub='func'; `do_spawn` in lua-atmos).
Escapes crossing the transparent boundary:

| escape     | mechanism                                   | result                     |
| ---------- | ------------------------------------------- | -------------------------- |
| `return()` | caught by spawn's OWN `atm_func`            | silently ends only the transparent block; owner survives |
| `break()`  | no catch inside; error crosses the coroutine | owner's loop catches -- works |
| `throw()`  | same crossing; dynamic by design            | owner's `catch` matches -- works |

The crossing is STRUCTURED in both timings:
- sync startup: `task_result` `error(err,0)` re-raises in the
  resumer frame = the owner mid-`spawn`.
- post-await: the emit traversal converts a child error into an
  `'atm_error'` resume of the parent (`run.lua:711` lua-atmos),
  and `await` rethrows it inside the parent at its await point
  (`run.lua:609-613`) -- errors climb the task tree, never the
  emitter's stack (bidimensional stack traces).

So `return` is the odd one out ONLY because of its own wrapper.

## Desired semantics

`return`/`break`/`throw` all ignore the transparent block and
propagate to the owner. break/throw already do; return must join.

## Implementation sketch

Remove the `atm_func` wrapper from the `spawn {}` desugar so
`return` escapes exactly like break/throw:

- `prim.lua` spawn() helper (line 4-12): proto `sub='func'` is
  what makes the coder emit `atm_func(...)`.
- Precedent: toggle's body proto uses `sub='lua'` (`prim.lua:223`)
  -- check how the coder treats `sub='lua'` (likely no wrapper);
  reuse for spawn blocks.
- Owner-side landing: `return` throw `'atm-func'` is then caught
  by the owner task body's own `atm_func` -> terminates the owner
  with the value. No lua-atmos change needed.

## Files (this repo)

| file             | place              | description                          |
| ---------------- | ------------------ | ------------------------------------ |
| `tst/tasks.lua`  | escapes section    | 3 await-before tests (DONE)          |
| `src/prim.lua`   | spawn() helper (4) | drop atm_func wrapper (sub='lua'?)   |
| `doc/manual.md`  | Tasks/Return       | document escapes-through-transparent |
| `HISTORY.md`     | v0.8               | bullet                               |

## Progress

- [x] characterization tests moved to NEW `tst/throw.lua` (added to
      `all.lua` after toggle): 4x2 matrix return/break/throw/escape
      x pre/pos-await, ALL capturing the escaping value (loop value
      for break, catch values for throw, do-block value for escape,
      await(t) for return). return pre+pos show the PROBLEM: value
      lost (nil), T survives; others deliver 10 in both timings
      (2026-07-08)
- [x] outputs confirmed: suite GREEN with all 8 characterization
      asserts (user, 2026-07-08)
- [x] `src/prim.lua` spawn() helper: `sub='lua'` -- coder emits a
      plain function, no `atm_func` wrapper (coder.lua:131)
      (2026-07-08)
- [x] `tst/throw.lua`: return pre/pos flipped to "10\nend\n"
      (2026-07-08)
- [x] `doc/manual.md` transparent-task paragraph: escapes ignore
      the transparent task; `HISTORY.md` v0.8 Modifications bullet
      (2026-07-08)
- [x] fallout: tasks.lua "return 2" relied on return-ends-the-block
      as a feature (block result via return) -- rewritten to use the
      last-expression result instead (2026-07-08)
- [ ] run test suite (user)
