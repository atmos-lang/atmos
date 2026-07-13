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

## Approach (Option C — runtime-first : prototype as await pattern)

Make the task prototype a first-class awaitable in lua-atmos `M.await`
itself (alongside the stream case `run.lua:553`), plus a
`{tag='spawn', T, args...}` carrier pattern for calls with args.
Then the compiler needs no thunk node at all.

See sibling plan : `/x/lua-atmos/atmos/.claude/plans/260713-await-patt-task.md`

1. lua-atmos (`run.lua` / `init.lua`)
    - `M.await` : new `meta_task` branch -> spawn inside the awaiting
      task/branch + recurse; relax varargs assert for this case
    - `M.await` : new `tag=='spawn'` branch -> spawn `awt[1]` with
      `awt[2..]` args (carrier for calls inside combinators)
    - `init.lua` `await` sugar collapses to `run.await(run.TIME, ...)`

2. Compiler : centralize `parser_await`
    - move the `check(nil,'id')` branch from `prim.lua` `accept('await')`
      into `parser_await`; all pattern consumers (`await`, `watching`,
      `loop on`, `toggle with`, `:any`) share it
    - base0 (bare form) widens `parser_1_prim` to also consume a
      same-line call suffix; still no binops, so bare
      `await T() || :X` stays `(await T()) || :X` (2606 rule)
    - lower a pattern-position call : bare `T` stays verbatim
      (prototype is directly awaitable); `T(a,b)` lowers to the
      `{tag='spawn', T, a, b}` carrier table

3. Keep the fast path
    - degenerate `await T(a,b)` with no combinators stays the direct
      `await(T, a, b)` spread (varargs reach spawn directly)
    - decide fate of `parser_7_out` (`await T() -> f` pipe-out) : the
      old id branch applied it, the pattern path never does

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

## Decision : runtime-first (Option C)

Move the prototype case into `M.await` itself : `or`/`and` subs recurse
through `M.await` inside **transparent branch tasks**
(`run.lua:508-509`, `889`), so a prototype sub is spawned in-branch
automatically — `M.me(true)` is the branch task, the spawn parents
there, and when the branch loses `meta_par.__close` cascades and aborts
`T` (`run.lua:57-59`).

- lifetime identical to the thunk plan, with **zero compiler thunks**
- `watching T()` / `loop on T()` get it free (both funnel into
  `M.await` : `run.lua:921`, `854`)
- args inside combinators use the `{tag='spawn', T, a, b}` carrier
  (prototypes are non-callable); bare `T` drops in verbatim

Rejected Option A (pin pre-spawned instance to enclosing block) : looser
lifetime — a losing `T` lingers until the whole block ends, surprising in
`loop { await T() || :X }`.

Rejected Option B (compiler emits `\() -> await(T, ...)` thunks) : works
but pushes lifetime plumbing into codegen and leaves `watching` /
`loop on` needing their own wraps; runtime-first covers all consumers at
one spot.

## Open questions

- Interaction with `2606-await-parens` rules (bare vs parenthesized
  patterns) : `await T(...) || :X` bare form must obey the same
  ambiguity rule as `await :X || :Y`.

## Files

| file            | place                        | change                    |
|-----------------|------------------------------|---------------------------|
| `src/await.lua` | `parser_await`               | absorb id-call branch; widen base0 with same-line call suffix |
| `src/await.lua` | `await_ast_logical`          | `call` leaf -> `{tag='spawn', f, es...}` carrier (bare id stays verbatim) |
| `src/prim.lua`  | `await` dispatch (`164-194`) | delete id branch; detect solo call -> spread `await(T, ...)`; `parser_7_out` fate |

lua-atmos changes tracked in the sibling plan :
`/x/lua-atmos/atmos/.claude/plans/260713-await-patt-task.md`

## Status

- [x] confirm scope + runtime : composition free, only lifetime matters
- [x] decide mechanism : Option C runtime-first (prototype in `M.await`)
- [ ] lua-atmos : `meta_task` + `{tag='spawn'}` branches (sibling plan)
- [ ] parser : centralize id-call into `parser_await`
- [ ] lower pattern-position call -> `{tag='spawn', ...}` carrier
- [ ] preserve `await T(...)` fast path (no combinators)
- [ ] compose with `||` / `until` / `:any` / `watching` / `loop on`
- [ ] `2606-await-parens` ambiguity rule for bare `await T() || :X`
- [ ] decide `parser_7_out` on `await T(...)`
