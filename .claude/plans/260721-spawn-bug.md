# Plan: `await T(...)` drops arguments after a `nil`

## Problem

A `nil` argument in an implicit-spawn await truncates every argument
after it.

```
task T (a, b, c) {
    print(a)
    print(b)
    print(c)
}

spawn T(nil, 10, 20)    ;; OK  -> nil / 10 / 20
await T(nil, 10, 20)    ;; BUG -> nil / nil / nil
```

The same applies to any pattern position that promotes a lone call to
an implicit spawn (`await`, `watching`, `loop on`, `<T() || :X>`).

## Cause

`mk_tagged` (`src/await.lua:29`) builds the lua-atmos combinator table
with explicit numeric keys:

```lua
{ ['tag'] = 'spawn', [1] = T, [2] = nil, [3] = 10, [4] = 20 }
```

The runtime then unpacks it with the length operator
(`lua-atmos:atmos/run.lua:562`):

```lua
return M.await(time, M.spawn(..., awt[1], table.unpack(awt, 2, #awt)))
```

`#awt` on a table with a `nil` hole at `[2]` is a valid border of `1`,
so `table.unpack(awt, 2, 1)` yields nothing.

`spawn T(...)` is unaffected because it compiles to a direct call and
never round-trips through a table.

## Failing test

Add to `tst/await.lua`, in the `task_promote` block (after the
`task_promote solo 1` anchor):

```lua
    -- SPEC: a nil argument must not truncate the remaining arguments
    local src = [[
        task T (a, b, c) {
            print(a)
            print(b)
            print(c)
        }
        spawn {
            await T(nil, 10, 20)
        }
    ]]
    print("Testing...", "task_promote nil_arg 1")
    local out = atm_test(src)
    assertx(out, "nil\n10\n20\n")
```

Current output is `nil\nnil\nnil\n`.

## Solution

Carry the argument count explicitly instead of inferring it from `#`.

### 1. compiler: emit `n`

`src/await.lua`, `mk_tagged`: add an `n` entry holding
`select('#',...)`, so the generated table is

```lua
{ ['tag'] = 'spawn', ['n'] = 3, [1] = T, [2] = nil, [3] = 10, [4] = 20 }
```

`n` counts the items after the tag name, i.e. prototype plus
arguments, matching the existing `[1..n]` numeric keys.

Only the `spawn` shape needs it; emitting it for every tagged table is
harmless, since `or`/`and`/`not`/`until`/`while` are built from
non-nil sub-patterns and are consumed by `ipairs` or a fixed arity.

### 2. runtime: use `n`

`lua-atmos:atmos/run.lua:562`, branch `tag == 'spawn'`:

```lua
return M.await(time, M.spawn(debug.getinfo(2), nil, false, awt[1],
    table.unpack(awt, 2, awt.n or #awt)))
```

The `or #awt` fallback keeps hand-written lua-atmos combinator tables
working.

### Alternative (runtime only)

If a compiler change is undesirable, replace `#awt` with a scan for
the largest integer key. This is exact for interior nils; trailing
nils are absent from the table but arrive as `nil` parameters anyway,
so behaviour is still correct.

## Files

| file                    | place            | change                        |
| ----------------------- | ---------------- | ----------------------------- |
| `src/await.lua`         | `mk_tagged`      | emit `n = select('#',...)`    |
| `lua-atmos:atmos/run.lua` | `M.await` spawn  | `table.unpack(awt,2,awt.n)`   |
| `tst/await.lua`         | `task_promote`   | add `nil_arg 1` test          |

## Status

- [ ] failing test added
- [ ] compiler emits `n`
- [ ] runtime uses `n`
