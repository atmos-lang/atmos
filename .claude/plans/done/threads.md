# threads

Port the `thread` primitive from lua-atmos into the atmos compiler.

## Status: planning

## Source reference

- lua-atmos plan: `/x/lua-atmos/atmos/.claude/plans/thread.md`
- lua-atmos impl: `/x/lua-atmos/atmos/atmos/run.lua:824-861`
- lua-atmos export: `/x/lua-atmos/atmos/atmos/init.lua:60`
- lua-atmos tests: `/x/lua-atmos/atmos/tst/thread.lua`

## Context

The lua-atmos runtime already has `thread(f)` implemented. It:
- Takes a function `f` (captures upvalues, no explicit args)
- Launches it in a real OS thread via LuaLanes
- Polls for result via `linda:receive(0,"ok")` + `await(true)`
- Returns the lane result inline
- Caches `lanes.gen` by function identity (weak-key table)

The atmos **compiler** needs to:
1. Register `thread` as a keyword
2. Parse `thread { ... }` syntax
3. Generate Lua code that calls the runtime `thread(f)`

## Decisions

| Decision | Choice | Why |
|----------|--------|-----|
| Syntax | `thread { ... }` | Block form only, like `spawn { ... }` |
| Args | No explicit args | Upvalue capture only; matches lua-atmos runtime |
| Func wrap | `lua=true` (plain) | Thread runs in isolated Lua state; atmos exceptions can't cross |
| Pin wrapper | None | Runtime handles cleanup internally (defer + lane:cancel) |
| Suffix exclusion | Yes | `thread` added to `parser_2_suf` exclusion check |
| Tests | New `tst/thread.lua` | Dedicated file for thread parser/codegen tests |
| Manual | Update now | Add thread docs to `doc/manual.md` |

## Plan

### Step 1: Register keyword — `src/global.lua`

Add `'thread'` to the `KEYS` table (alphabetical order,
between `'test'` and `'toggle'`).

### Step 2: Parse `thread { ... }` — `src/prim.lua`

In `parser_1_prim()`, add `check('thread')` to the
emit/await/spawn/toggle branch (line 140), then handle it:

```lua
elseif accept('thread') then
    local blk = parser_block()
    return {
        tag = 'call',
        f = { tag='acc', tk={tag='id', str='thread', lin=TK0.lin} },
        es = {
            { tag='func', lua=true, pars={}, blk=blk },
        },
    }
```

This generates an AST node: `thread( (function() ... end) )`

Key points:
- `lua=true` → plain `function()`, no `atm_func` wrapping
- No pin wrapper (unlike `spawn { ... }`)
- No args — body captures upvalues from enclosing scope
- Returns the call AST directly (usable as expression)

### Step 3: Exclude from suffix ops — `src/parser.lua:235`

Add `check('thread')` to the suffix exclusion line:

```lua
local no = check('emit') or check('spawn') or check('toggle')
                         or check('thread')
```

### Step 4: Tests — `tst/thread.lua`

Parser/codegen tests only (runtime tests are in lua-atmos).
Test categories:
1. Basic: `thread { ... }` parses and generates
   `thread((function() ... end))`
2. Expression: `val x = thread { ... }` works as expression
3. Upvalue capture: body referencing outer variables compiles
4. Error: `thread` without block raises parse error

### Step 5: Register tests — `tst/all.lua`

Add `dofile "thread.lua"` entry.

### Step 6: Manual — `doc/manual.md`

Add `thread` documentation section covering:
- Syntax: `thread { ... }`
- Semantics: runs body in real OS thread, blocks calling task
- Upvalue capture behavior
- Serialization constraints (only serializable upvalues)

## Files to modify

| File | Change |
|------|--------|
| `src/global.lua:23-27` | Add `'thread'` to `KEYS` |
| `src/prim.lua:140` | Add `check('thread')` + handler |
| `src/parser.lua:235` | Add `thread` to suffix exclusion |
| `tst/thread.lua` | New file — parser/codegen tests |
| `tst/all.lua` | Add `dofile "thread.lua"` |
| `doc/manual.md` | Add thread documentation |
