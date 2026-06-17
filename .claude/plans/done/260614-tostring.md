# 260614-tostring : render values as atmos-lang tables `:X [...]`

## Goal

Make `X.tostring` / `X.print` emit atmos-lang surface syntax instead of
Lua-ish `@{...}`, by OVERRIDING `X.tostring` in our own runtime
(`src/run.lua`) — lua-atmos `atmos/x.lua` stays generic.

| value             | old (`@{}`)        | new (atmos)        |
| ----------------- | ------------------ | ------------------ |
| empty             | `@{}`              | `[]`               |
| vector            | `@{1, 2, 3}`       | `[1, 2, 3]`        |
| record            | `@{x=1, y=2}`      | `[x=1, y=2]`       |
| tagged            | `@{10, tag=X}`     | `:X [10]`          |
| tagged (dotted)   | `@{10, tag=Y.X}`   | `:Y.X [10]`        |
| tagged empty      | `@{tag=X}`         | `:X []`            |
| nested            | `@{@{0}}`          | `[[0]]`            |
| AST node          | `@{tag=num, ...}`  | `:num [...]`       |

## Place & mechanism

- `src/run.lua` — required by every compiled program
  (`require "atmos.lang.run"`, `src/exec.lua:24`), loaded right after
  `X = require "atmos.x"` (`src/exec.lua:23`).
- Override the `X.tostring` FIELD there.
  `X` is the same table lua-atmos's `M.print` closes over, so
  `M.print` (= `X.print`) calls `M.tostring` by field lookup and picks
  up our override automatically.
  One override covers `X.tostring`, `X.print`, and user code.
- lua-atmos untouched.

## Reuse (approach A)

Decision: self-contained in `src/run.lua`.
Reuses self-recursion for nesting and `tostring` for scalars; the
sort+walk is re-expressed (lua-atmos exposes no format seam, and
`X.iter` cannot be reused because it orders named keys via `next()` —
non-deterministic, while the AST-dump tests need stable sorted order).

## Code (`src/run.lua`, new section)

    -- TOSTRING : render values as atmos-lang tables (:X [...])

    local X = require "atmos.x"

    function X.tostring (v)
        if type(v) ~= 'table' then
            return tostring(v)
        else
            local fst = true
            local vs = ""
            local t = {}
            for k,x in pairs(v) do
                assert(type(k)=='number' or type(k)=='string')
                if k ~= 'tag' then
                    t[#t+1] = { k, x }
                end
            end
            table.sort(t, function (x, y)
                local n1, n2 = tonumber(x[1]), tonumber(y[1])
                if n1 and n2 then
                    return (n1 < n2)
                else
                    return (tostring(x[1]) < tostring(y[1]))
                end
            end)
            local i = 1
            for _,kx in ipairs(t) do
                local k,x = table.unpack(kx)
                if not fst then
                    vs = vs .. ', '
                end
                if tonumber(k) == i then
                    i = i + 1
                    vs = vs .. X.tostring(x)
                else
                    vs = vs .. k .. '=' .. X.tostring(x)
                end
                fst = false
            end
            local tag = v.tag and (':'..v.tag..' ') or ''
            return tag .. "[" .. vs .. "]"
        end
    end

## Impact on tests (`tst/`)

`grep -ro '@{' tst | wc -l` = **339** occurrences across `lexer.lua`,
`expr.lua`, `stmt.lua`, `tasks.lua`, `exec.lua`, `streams.lua`,
`x.lua`.
Most are AST dumps where every node has `tag=`, so a blind `@{`→`[`
replace is WRONG: each `tag=...` moves to a `:tag ` prefix and leaves
the entry list, e.g.

    @{blk=@{es=@{}, tag=block}, tag=loop}
    -> :loop [blk=:block [es=[]]]

### Strategy: regenerate, do not hand-edit

The mapping is deterministic, so regenerate expected strings from
actual output:

1. add the override to `src/run.lua`
2. for each failing `assertx(out, EXPECTED)`, capture the new `out` and
   replace `EXPECTED`
3. re-run until green; diff each so a real regression is not masked

## Risks / edge cases

- `type(v.tag)=='string'` guard: only string tags become a prefix.
- Vector / record / empty all share `[...]` brackets — no regression
  vs the old shared `{}` behavior.
- A string value containing a brace (`str={`) still prints literally;
  this is why a string-rewrite approach was rejected.
- Tag with dots (`Y.X`) emitted verbatim as `:Y.X`.

## Status

- [x] add `X.tostring` override to `src/run.lua`
- [x] regenerate `assertx` expectations in `tst/` — `@{...}` -> `[...]` /
  `:tag [...]` across `x.lua`, `exec.lua`, `streams.lua`, `tasks.lua`
  (`lexer.lua:42` kept: it is lexer INPUT, not output)
- [x] full suite green: `cd tst && lua5.4 all.lua` (user runs)
