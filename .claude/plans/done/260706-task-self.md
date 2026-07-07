# task-self -- the running task ("me")

## Goal

Give atmos-lang a surface expression for the currently running
(non-transparent) task instance -- lua-atmos calls this `xtask()`.
Today atmos has no user-facing spelling: `pub` is the only construct
that reaches it (`coder.lua:54` emits `xtask().pub`).

This reverses the deferral in `done/260620-task.md` §1, which marked
`xtask()`="me" as WONT DO ("spawn-only surface"). We now want it.

## Decision (final)

Primary: **`task` (no parens)** as an expression yields the running
instance.
Desugar: bare `task` lowers to the plain runtime call `xtask()`,
reusing the call AST -- tosource prints `xtask()` (desugar leaks,
accepted; no dedicated `me` AST tag).

Alternative kept on the shelf: **`xtask()`** direct (zero compiler
change; verbose, exposes internal name).
If a user-facing instance *constructor* is ever wanted, revisit via
`xtask(T)` -- `task`=me forecloses `task(...)` construction.

## Why `task`-as-expression parses cleanly

`task` is today an unconditional proto-header keyword
(`src/prim.lua:246-292`): after it the parser demands `(` (anon
proto) or an id (named proto).
Two apparent ambiguities, both resolved by the separator the lexer
already tracks.

`SEP` (`src/lexer.lua:16-20`) is a counter bumped on every `\n` and
every lone `;`.
So `TK0.sep == TK1.sep` is true iff the two tokens sit on the same
logical line.

Precedents that already lean on this:
- `src/parser.lua:278` -- postfix `(`/`[` binds as call/index only
  same-line.
- `src/parser.lua:131` -- `parser_stmts` requires `\n`/`;` between
  statements.

Rule after consuming `task` (pure LL(1)):

```
task (        same line   -> anonymous proto
task ID       same line   -> named proto
task <sep> …              -> "me"  (ID/`(` after newline or `;`)
task ) , } ?? ++ :tag …   -> "me"  (operator / closer follows)
```

Only loss: a proto header may not split across a newline before its
name/params (`task\nFoo(){}`) -- nobody writes that.

## Desugar

```
val me = task
```
becomes
```
local me = xtask()
```

AST: `{ tag='call', f={tag='acc',tk={tag='id',str='xtask'}}, es={} }`
-- codegen is free.

## Build approach

Surgical change in `src/prim.lua`, `task`/`func` branch (247-252).
Only `sub=='task'` can be "me"; `func` always stays a proto.

```lua
if accept('task') or accept('func') then
    local sub = TK0.str
    -- bare `task` = running instance ("me"): not a proto header when
    -- no same-line `(` or name follows.
    if sub=='task' and not ((check'(' or check(nil,'id')) and TK0.sep==TK1.sep) then
        return { tag='call', f={tag='acc',tk={tag='id',str='xtask'}}, es={} }
    end
    ...                             ;; existing proto parse unchanged
```

No lexer change (`task` stays a keyword, `xtask` a plain id).
No runtime change: lua-atmos `xtask()` with no arg already returns
the running task.

## Files

(paths relative to `atmos/` subdir of the repo)

| file             | place                      | description                                   |
| ---------------- | -------------------------- | --------------------------------------------- |
| `src/prim.lua`   | `task`/`func` branch (247) | emit `xtask()` call when `task` is not a proto header (sep-gated) |
| `tst/expr.lua`   | near `xtask(T)` (~1236)    | tosource of bare `task` -> `xtask()`          |
| `tst/tasks.lua`  | task tests                 | behavior: `task ?? :xtask`, "me" identity     |
| `doc/manual.md`  | Tasks chapter              | document `task` (bare) = running instance     |

## Checks to add

Parse/round-trip (`expr.lua`):
- `task` alone -> tosource `xtask()`.
- `task T(){}` still a named proto; `task(){}` still anon proto.

Behavior (`tasks.lua`):
```
val me = task
print(me ?? :xtask)          ;; --> true
```
- inside a spawned body, `task` is that instance.
- separator lock: `val t = task` then a new `foo()` line must NOT be
  read as `task foo(...)`.

## Docs

- `doc/manual.md` Tasks chapter: add the bare-`task` expression to
  the grammar (lift the `XTask` production deferred in
  `done/260620-task.md` §1, adapted to `task` spelling), with a "me"
  example.
- NEVER edit or regen `doc/manual-out.md` (user handles regen).
- Note in `done/260620-task.md` §1 that this plan supersedes the
  "`xtask()`=me WONT DO" decision.

## Progress

- [x] `src/prim.lua` bare-`task` branch (2026-07-06)
- [x] `tst/expr.lua` tosource checks: bare `task`, sep lock
      (`\n` before `(`, `;` before `(`, `\n` before id),
      named proto unchanged (2026-07-06)
- [x] `tst/tasks.lua` behavior checks: tests 5 (me identity) and
      6 (separator lock) (2026-07-06)
- [x] `doc/manual.md` grammar + "me" example + Ambiguities row;
      regenerated `manual-out.md` (2026-07-06)
- [x] SUPERSEDED note in `done/260620-task.md` §1 (2026-07-06)
- [x] `HISTORY.md`: new unreleased `v0.8 (???/??)` Additions entry
      (2026-07-06)
- [x] `src/run.lua` `atm_pin_chk_set`: allow val/var/set alias when
      the value is the running task (`t==xtask()`) -- `val me = task`
      failed the "expected pinned value" check. CORRECTED rationale:
      EVERY spawn ends up pinned (pin var, pool, or the forced
      `pin _ =` wrapper for unassigned spawns, whose chk=false skips
      asserts but still sets `t.pin=true`); the flag is only false
      DURING the body's synchronous startup (before spawn returns) --
      exactly where bare `task` runs. Mutating the flag from inside
      was rejected: would break the call-site wrapper's "expected
      unpinned value" assert (2026-07-06)
- [x] `src/run.lua` generalized to `atm_is_up` up-chain walk:
      val/var/set may alias "me" OR any ancestor (structured
      concurrency: ancestors outlive the scope); `pin` additionally
      REJECTS me/ancestors (pin = ownership + abort-on-close ->
      upward abort cycle). Tests 7 (ancestor alias ok), 8
      (non-ancestor alias rejected: emit during startup wakes a
      sibling while T is still unpinned), 9 (pin me rejected)
      (2026-07-06)
- [x] test 8b: "me" as emit payload `emit @(:global) (:X [task])` --
      table constructors are unchecked borrows (2026-07-07)
- [x] user refactor of `atm_pin_chk_set`: `chk` guards hoisted;
      messages renamed to "unexpected pinned value" / "unexpected
      parent task"; tests 9 and pin-3 synced (2026-07-07)
- [x] test suite GREEN (user, 2026-07-07)
- [x] `doc/exs/val-06-tasks.atm`: synced with manual example
      (`print(task ?? :xtask)`); regen `manual-out.md` after user's
      manual restructuring (XTask production, moved paragraph)
      (2026-07-07)

## Moved out

- Dotted task declarations `task T.Task` (no `::`) -- split to
  `260707-task-dot.md`.

## Won't do

- `xtask()` / `xtask(T)` as the user-facing surface (documented
  alternative only).
- `self` (Lua collision), `this`/`me` (new keyword, no gain).
- A dedicated `me` AST tag for tosource fidelity (bare `task`
  round-trips as `xtask()` -- accepted).
- A `task(T)` instance *constructor* -- out of scope.
