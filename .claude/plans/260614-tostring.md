# 260614-tostring : render values as atmos-lang tables `:X [...]`

## Goal

Change `M.tostring` (and thus `M.print`) in lua-atmos `atmos/x.lua` to
emit atmos-lang surface syntax instead of Lua-ish `@{...}`:

| value                         | old (`@{}`)        | new (atmos)        |
| ----------------------------- | ------------------ | ------------------ |
| empty                         | `@{}`              | `[]`               |
| vector                        | `@{1, 2, 3}`       | `[1, 2, 3]`        |
| record                        | `@{x=1, y=2}`      | `[x=1, y=2]`       |
| tagged                        | `@{10, tag=X}`     | `:X [10]`          |
| tagged (dotted)               | `@{10, tag=Y.X}`   | `:Y.X [10]`        |
| tagged empty                  | `@{tag=X}`         | `:X []`            |
| nested                        | `@{@{0}}`          | `[[0]]`            |
| AST node                      | `@{tag=num, ...}`  | `:num [...]`       |

The `tag` field stops being a printed key and becomes a `:tag ` prefix;
braces `{}` become brackets `[]`; the `@` marker is dropped.

## Constraint

`atmos/x.lua` is in lua-atmos, **outside this worktree** — you apply the
function edit there.
The test-expectation updates are in atmos-lang `tst/` (editable here).

## Function change (`atmos/x.lua:171`)

Three edits to the existing body:

1. Uncomment the tag guard so the tag is skipped from the entries:

       if k ~= 'tag' then
           t[#t+1] = { k, x }
       end

2. Replace the final two lines:

       --local tag = v.tag and (':'..v.tag..' ') or ''
       return --[[tag ..]] "{" .. vs .. "}"

   with:

       local tag = (type(v.tag)=='string') and (':'..v.tag..' ') or ''
       return tag .. "[" .. vs .. "]"

Everything else (sort, numeric-vs-named key logic, recursion) is kept.

## Impact on tests (`tst/`)

`grep -ro '@{' tst | wc -l` = **339** occurrences, across:
`lexer.lua`, `expr.lua`, `stmt.lua`, `tasks.lua`, `exec.lua`,
`streams.lua`, `x.lua`.

Most are AST dumps where every node has `tag=`, so a blind `@{`→`[`
replace is WRONG: the `tag=...` key must move to a `:tag ` prefix and
leave the entry list.
Example:

    @{blk=@{es=@{}, tag=block}, tag=loop}
    -> :loop [blk=:block [es=[]]]

### Strategy: regenerate, do not hand-edit

The mapping is deterministic from `M.tostring`, so the reliable path is
to regenerate expected strings from actual output:

1. apply the function change in lua-atmos
2. for each `assertx(out, EXPECTED)` that now fails, capture the new
   `out` and replace `EXPECTED`
3. re-run until green

(diff each change so a real regression is not masked by the rewrite)

## Risks / edge cases

- `type(v.tag)=='string'` guard: only string tags become a prefix; a
  non-string `tag` value (rare) stays a normal key.
- Ambiguity: vector `[1,2]`, record `[a=1]`, and empty `[]` all use the
  same brackets — same as old behavior, no regression.
- A string value that looks like a brace (`str={`) still prints
  literally (`str={`); acceptable, matches a current test.
- Tag-name with dots (`Y.X`) is emitted verbatim as `:Y.X`.

## Status

- [ ] apply `M.tostring` edit in lua-atmos `atmos/x.lua` (outside worktree)
- [ ] regenerate failing `assertx` expectations in `tst/` (~339 sites)
- [ ] full suite green: `cd tst && lua5.4 all.lua`
