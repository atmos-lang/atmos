# await-patt-task : promote `await T(...)` to a first-class pattern

## Goal

Let `await T(...)` (spawn-and-await a task prototype) compose with the
pattern combinators instead of being a parser-level special case:

```
await T(...) || :X          ;; either T terminates or :X fires
await T(...) until c
watching T(...)             ;; and inside spawn/loop-on filters
:any [T(a), U(b)]
```

Today `await T(...)` bypasses `parser_await` entirely and cannot combine
with `&&` / `||` / `!`, `until`/`while`, or `:any`/`:all`.

## Current state

### Parser : special case

`src/prim.lua:164-194`

- `await` + next token is an id  -> `check(nil,'id')` branch
    - parses full call via `parser_6_pip`
    - rewrites `T(...)`  ->  `await(T, ...)` (args spread, `call.f` first)
    - never touches `parser_await`
- otherwise (`(` or juxtaposed pattern) -> `parser_await`

### Pattern parser

`src/await.lua`

- `parser_await(stop, base0)` : pool prefix, `until`/`while`, base +
  `&&`/`||`/`!` combinators
- juxtaposition base is `parser_1_prim` (single primary) : will NOT
  consume a `(...)` call postfix -> reason the special case grabs the
  call with `parser_6_pip`
- `await_ast_logical` stops at `call` nodes, passing them verbatim
- `mk_tagged` / `:any`/`:all` build combinator tables from task
  **instances** and tags

### Runtime : already unified

`atmos/init.lua:72-82` (installed lua-atmos)

```lua
function await (awt, ...)
    if X.is(awt, 'task') then      -- prototype -> spawn + await instance
        return await(run.spawn(debug.getinfo(2), nil, false, awt, ...))
    elseif type(awt) == 'function' then
        assertn(2, false, "invalid spawn : expected task prototype")
    else                           -- combinator table
        return run.await(run.TIME, awt, ...)
    end
end
```

The runtime already accepts a task prototype as an await argument. The
gap is purely that a prototype cannot yet be embedded *inside* a
combinator table : `run.await` / `:any`/`:all` expect task instances.

## Blockers

| blocker                                   | where               |
|-------------------------------------------|---------------------|
| call not consumed in juxtaposition base   | `await.lua:81` `parser_1_prim` |
| `await_ast_logical` passes `call` verbatim| `await.lua:29-30`   |
| combinator items must be task instances   | `mk_tagged`, `:any`/`:all` |

Inside a `||`, a bare `T()` would be *called*, not spawned-then-awaited.

## Approach (Option B — spawn-and-await thunk)

Model a promoted `await T(...)` as a thunk that spawns-then-awaits, so it
drops into the existing combinator machinery as an ordinary sub-item.

1. Recognize a task-prototype call in pattern position
    - in `parser_await`, when the base parses to a `call`, wrap it as a
      spawn-and-await thunk node (runtime still decides prototype-vs-call
      via `X.is`)
    - juxtaposition base must also see the call : widen the base parse so
      `await T(...)` in bare form consumes the `(...)`

2. Lower to a thunk, not a verbatim call
    - coder emits `\() -> await(spawn(T, ...))`
    - `await_ast_logical` keeps it verbatim inside `&&`/`||`/`!`; the
      thunk lands as a combinator sub, so the spawn happens inside the
      branch and cascades closed when the branch loses

3. Keep the fast path
    - degenerate `await T(...)` with no combinators stays the direct
      `await(T, ...)` sugar (no separate spawn) so nothing regresses

## Resolved

- Discrimination is **runtime-only**. The parser has no type info, but it
  **can detect call syntax** (`call.tag == 'call'`). So the parser routes
  any id-call in pattern position into a spawn-instance node; the
  runtime keeps deciding prototype-vs-call via `X.is` (as `await` does).

## Runtime confirmation

Read of installed `atmos/run.lua` :

- awaiting a task **instance** is already a first-class operand
  (`meta_xtask` branch, `run.lua:591-594` -> returns `awt.ret, awt`)
- `or`/`and` recurse `M.await` per sub-item (`run.lua:508-509`), so
  combinators **already accept instances** -> no runtime change for
  composition
- result value unwraps correctly via `par_any`/`par_all`

The ONE real issue is scope/pinning :

- `run.spawn(dbg, up=nil, ...)` parents the task to the enclosing task
  (`M.me(true)`), NOT the await block (`run.lua:462`)
- auto-pin fires only for a `meta_tasks` pool (`run.lua:463-464`); a
  plain `||` is not a pool
- so in `await T() || :X`, if `:X` wins, the spawned `T` leaks as a
  child of `me`
- the solo fast path is safe only because it has no competing branch
- => the spawn-instance node must **pin to the await/block scope**

`dbg` frame is cosmetic (error location only).

## Decision : spawn-and-await thunk (Option B)

`pin` = ownership + abort-on-close (`src/run.lua:16-38`) : a pinned task
dies when its owning **block** closes.

The leak exists because we pre-spawn the instance (parented to `me`) and
drop it verbatim in the combinator table. Instead, model the promoted
`await T(...)` as a **spawn-and-await thunk** :

```
\() -> await(spawn(T, ...))
```

so the spawn happens **inside** the combinator branch — mirroring the
stream case `run.lua:553-554` (`S.is` spawns a wrapper task inside
`M.await`). When another branch wins, `par_any` closes the losing branch
and its child `T` cascades closed via `__close` (`run.lua:58-59`).

- `T` is aborted the moment the await resolves (tight, structured)
- no explicit `pin`, no leak
- drops into `or`/`and` unchanged (they already wrap each sub in a thunk,
  `run.lua:508-509`)

Rejected Option A (pin pre-spawned instance to enclosing block) : looser
lifetime — a losing `T` lingers until the whole block ends, surprising in
`loop { await T() || :X }`.

## Open questions

- Interaction with `2606-await-parens` rules (bare vs parenthesized
  patterns) : `await T(...) || :X` bare form must obey the same
  ambiguity rule as `await :X || :Y`.

## Files

| file            | place                        | change                    |
|-----------------|------------------------------|---------------------------|
| `src/await.lua` | `parser_await`, `await_ast_logical` | recognize a `call` base -> spawn-and-await thunk node; keep verbatim in combinators |
| `src/prim.lua`  | `await` dispatch (`164-194`) | route id-call through pattern path; keep fast path |
| `src/coder.lua` | thunk node                   | lower to `\() -> await(spawn(T, ...))` |

No `src/run.lua` change : composition already works (instances await-able,
combinators thunk each sub); discrimination stays runtime `X.is`.

## Status

- [x] confirm scope + runtime : composition free, only lifetime matters
- [x] decide mechanism : Option B spawn-and-await thunk
- [ ] parser : `call` base -> thunk node (`await.lua`, `prim.lua`)
- [ ] coder : lower thunk to `\() -> await(spawn(T, ...))`
- [ ] preserve `await T(...)` fast path (no combinators)
- [ ] compose with `||` / `until` / `:any`
- [ ] `2606-await-parens` ambiguity rule for bare `await T() || :X`
