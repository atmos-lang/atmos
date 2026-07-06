# task-self -- the running task ("me")

## Goal

Give atmos-lang a surface expression for the currently running
(non-transparent) task instance -- lua-atmos calls this `xtask()`.
Today atmos has no user-facing spelling: `pub` is the only construct
that reaches it (`coder.lua:54` emits `xtask().pub`).

This reverses the deferral in `done/260620-task.md` §1, which marked
`xtask()`="me" as WONT DO ("spawn-only surface"). We now want it.

## Candidate spellings (considered)

| spelling   | verdict  | note                                          |
| ---------- | -------- | --------------------------------------------- |
| `task`     | CHOSEN   | bare keyword as expression = "me"             |
| `xtask()`  | alt      | plain call; zero parser change; see below     |
| `self`     | rejected | collides with Lua `self` in native `` ` ` `` blocks |
| `this`/`me`| rejected | new keyword; OOP/informal connotation, no gain |

## Decision (pending final sign-off)

Primary: **`task` (no parens)** as an expression yields the running
instance. Rationale: terse, reads as "the task I am," and keeps a
single vocabulary word (`task`) for the concept. The parse is clean
(next section).

Alternative kept on the shelf: **`xtask()`**. It needs *no* compiler
change at all -- `xtask` is already a plain runtime global and
`xtask()` already round-trips through the coder (`coder.lua:54`), so
`val me = xtask()` compiles and runs today. It also unifies "me"
(`xtask()`) with a future constructor (`xtask(T)`) under one name.
The cost is verbosity and exposing the `x`-prefixed internal name.
If we ever want a user-facing instance *constructor*, revisit this --
`task(T)` cannot be that constructor (it is grammatically an
anonymous proto), so `task`=me forecloses `task(...)` construction.

## Why `task`-as-expression parses cleanly

`task` is today an unconditional proto-header keyword
(`prim.lua:246-292`): after it the parser demands `(` (anon proto) or
an id (named proto). Two apparent ambiguities, both resolved by the
separator the lexer already tracks.

`SEP` (`lexer.lua:16-19`) is a counter bumped on every `\n` and every
lone `;`. So `TK0.sep == TK1.sep` is true iff the two tokens sit on
the same logical line (no `\n`/`;` between them).

Precedents that already lean on this:
- `parser.lua:278` -- a postfix `(`/`[` binds as call/index only when
  it hugs on the same line.
- `prim.lua:90` -- tag application `:X(...)`/`:X[...]` only same-line.
- `parser.lua:131` -- `parser_stmts` *requires* `\n`/`;` between
  statements ("sequence error : expected ';' or new line").

Given that, the rule after consuming `task` is pure LL(1):

```
task (        same line   -> anonymous proto  (never a call: no "call me")
task ID       same line   -> named proto
task <sep> …             -> "me"  (ID/`(` after a newline or `;`)
task ) , } ?? ++ :tag …  -> "me"  (operator / closer / tag follows)
```

The named-proto name is *always* same-line as `task`; a following
statement's identifier is *always* separated (enforced by
`parser_stmts`). So the natural usage disambiguates:

```
val me = task     ;; me  (task ends the statement)
foo()             ;; foo is a new statement -> sep differs
```

Only loss: you may not split a proto header across a newline before
its name/params (`task\nFoo(){}`) -- nobody writes that.

## Desugar

Bare `task` (me) lowers to the existing runtime call `xtask()`:

```
val me = task
```
becomes
```
local me = xtask()
```

Reuse the call AST so codegen is free:
`{ tag='call', f={tag='acc',tk={tag='id',str='xtask'}}, es={} }`.

## Build approach

Surgical change in `prim.lua`, in the `task`/`func` branch
(`prim.lua:247-252`). Only `sub=='task'` can be "me"; `func` always
stays a proto.

```lua
if accept('task') or accept('func') then
    local sub = TK0.str
    -- bare `task` = running instance ("me"): not a proto header when
    -- no same-line `(` or name follows.
    if sub=='task' and not (
        (check'(' or check(nil,'id')) and TK0.sep==TK1.sep
    ) then
        return { tag='call',
                 f={tag='acc', tk={tag='id',str='xtask'}}, es={} }
    end
    ...                             ;; existing proto parse unchanged
```

No lexer change (`task` stays a keyword, `xtask` a plain id). No
runtime change: lua-atmos `xtask()` with no arg already returns the
running task.

## Files

| file             | place                     | description                                  |
| ---------------- | ------------------------- | -------------------------------------------- |
| `src/prim.lua`   | `task`/`func` branch (247)| emit `xtask()` call when `task` is not a proto header (sep-gated) |
| `tst/expr.lua`   | near `xtask(T)` (~1236)   | tosource of bare `task` -> `xtask()`         |
| `tst/exec.lua` / `tst/tasks.lua` | task tests | behavior: `task ?? :xtask`, "me" identity    |
| `doc/manual.md`  | Tasks chapter (~774)      | document `task` (bare) = running instance     |

## Tests to add

Parse/round-trip (`expr.lua`):
- `task` alone -> tosource `xtask()`.
- `task T(){}` still a named proto; `task(){}` still anon proto.

Behavior (`tasks.lua`/`exec.lua`):
```
val me = task
print(me ?? :xtask)          ;; --> true
```
- inside a spawned body, `task` is that instance.
- separator lock: `val t = task` then a new `foo()` line must NOT be
  read as `task foo(...)`.

## Docs

- `doc/manual.md` Tasks chapter: add the bare-`task` expression to the
  grammar (lift the `XTask` production deferred in `260620-task.md`
  §1, adapted to `task` spelling), with a "me" example.
- Regen `doc/manual-out.md` via
  `cd doc && lua5.4 manual.lua manual.md > manual-out.md`
  (never edit by hand).
- Note in `done/260620-task.md` §1 that this plan supersedes the
  "`xtask()`=me WONT DO" decision.

## Open decisions

- tosource fidelity: bare `task` currently round-trips as `xtask()`
  (desugar leaks). Acceptable, or add a dedicated `me` AST tag whose
  tosource prints `task`? Leaning acceptable (keep it simple).
- `pub` unchanged (`xtask().pub`); `task.pub` would also work as a
  same-line index but `pub` stays the blessed accessor.

## Won't do

- `xtask()` / `xtask(T)` as the user-facing surface (kept as the
  documented alternative above, not the chosen spelling).
- `self` (Lua collision), `this`/`me` (new keyword, no gain).
- A `task(T)` instance *constructor* -- out of scope; `task`=me
  forecloses that spelling, revisit via `xtask(T)` if ever needed.
