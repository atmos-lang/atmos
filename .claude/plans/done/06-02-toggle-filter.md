# Toggle Filter — atmos language (`with` syntax)

## Status

Done:

- [x] `src/prim.lua` block form: optional `with` list before block, appended.
- [x] `src/prim.lua` task form: optional trailing `with` list, appended.
- [x] `src/coder.lua`: no change (toggle is a generic `call`).
- [x] `doc/manual.md`: grammar + `with` semantics + example.
- [x] `tst/expr.lua`: codegen cases (task single/multi, block, regression).
      Block form renders `toggle(:X, { }, :Draw)` (func has `lua=true`).
- [x] `tst/exec.lua`: end-to-end `toggle filter` (task) + `toggle filter
      block` (block, via `par`).
- [x] `doc/exs/exp-28-toggle.atm`: added the `with :Draw` example.

Pending (must do):

- [x] Reinstall runtime so the CLI gets the filter
      (`luarocks make --local`); CLI was loading the OLD rock without the
      filter, gating everything.
- [x] Run `cd tst && lua5.4 all.lua` — passing.
- [x] Re-gen `doc/manual-out.md` from `manual.md`.

Pending (optional):

- [ ] Re-add the multi-pattern caveat in the manual (`with :a, :b` is
      positional; "A or B" = predicate). Dropped for brevity.
- [ ] Extra assert: task-form `with` immediately followed by another statement
      (terminator edge — relies on `parser_list` stopping at first non-comma).

Note (separate lua-atmos repo, not this plan):

- [ ] `06-and-or-not`: `not`/`and`/`or`/`clock` as filters currently fail
      QUIETLY (the runtime `filter 4` stub). Make them work or error.

## Scope

Language/compiler only.
Add `with <pattern>` to both `toggle` forms, lowering to extra trailing args of
the runtime `toggle(...)` call.

The runtime (lua-atmos) already accepts the filter args and is DONE in its own
repo (`/x/lua-atmos/atmos`, plan `done/06-02-toggle-filter.md`).
This plan does NOT touch runtime behavior.

## Grammar

    Toggle : `toggle´ Expr `(´ Expr `)´ [ `with´ Expr* ]    ;; task
           | `toggle´ TAG [ `with´ Expr* ] Block             ;; block

`with Expr*` is the filter pattern.
It follows the exact `await` / `every` / `watching` convention (comma list,
positional per-emit-argument match).
To match "A or B" use a predicate, not multiple args.
Omitting `with` reproduces today's `toggle`.

## Lowering (target runtime calls)

The runtime (done) expects the filter as trailing args:

    toggle(task, bool, pat...)     -- task form
    toggle(tag,  body, pat...)     -- block form

So in both parser forms the `with` pattern expressions are appended to the end
of the generated `call.es`.

## Target file

`src/prim.lua` only.
- `with` is already a keyword: `global.lua:27` KEYS. No lexer/global change.
- `toggle` compiles as a generic `call` node (`coder.lua` has no toggle case),
  and filter patterns are ordinary expressions appended to `es`. They compile
  like any `await` arg (tags -> strings via `coder_tag`). No `coder.lua` change.

## Current parser (prim.lua:204-230)

- block form @204-220: `accept(nil,'tag')` then `parser_block()`; builds
  `es = { {tag='tag'}, {tag='func', blk} }`.
- task form @221-229: `parser_6_pip()` parses `t(false)`; inserts `call.f` as
  arg 1 (`es = { t, false }`); wraps as `toggle(...)`.

`parser_list(',', clo, parser)` @parser.lua:37 reads comma-separated items and
returns at the first non-`,` token (the no-sep path), so it terminates a
trailing pattern even without a closing `{`.

## Parser changes

### Block form (@204-220) — `toggle :X with :Draw { }`

Parse optional `with` (terminated by the block `{`) before `parser_block`,
then append to `es` AFTER the body func.

    elseif accept('toggle') then
        local tag = accept(nil, 'tag')
        if tag then
            local fil = {}
            if accept('with') then
                fil = parser_list(',', '{', parser)
            end
            local blk = parser_block()
            return {
                tag = 'call',
                f = { tag='acc', tk={tag='id',str='toggle'} },
                es = concat({
                    { tag='tag', tk=tag },
                    { tag='func', lua=true, pars={}, blk=blk },
                }, fil),
            }

### Task form (@221-229) — `toggle t(false) with :Draw`

After building `es = { t, false }`, parse an optional trailing `with` pattern
(no closing token; rely on the parser_list no-sep stop) and append.

    else
        local tk = TK0
        local cmd = { tag='acc', tk={tag='id', str='toggle', lin=TK0.lin} }
        local call = parser_6_pip()
        if call.tag ~= 'call' then
            err(tk, "expected call syntax")
        end
        table.insert(call.es, 1, call.f)
        local es = call.es
        if accept('with') then
            es = concat(es, parser_list(',', function () return false end, parser))
        end
        return parser_7_out({ tag='call', f=cmd, es=es })
    end

`concat` and `parser_list` are already in scope (used by the block form @178 and
by `every`/`watching` @645/@685).
`parser_6_pip` / the binary parser stop before `with` (a keyword, not an
operator), so the explicit `accept('with')` is reached.

## Manual (doc/manual.md, Toggle §~2179)

- Add `with Expr*` to the grammar (both forms).
- Note the filter follows the `await` pattern convention; "A or B" = predicate.
- One example, e.g. the freeze-but-keep-drawing case:

        spawn {
            toggle :Pause with :Draw {
                par {
                    every :Draw { draw() }
                } with {
                    every :Tick { step() }
                }
            }
        }
        emit(:Pause, false)   ;; step() frozen, draw() still runs

## Edge cases / verification points

- No `with` -> `es` unchanged -> today's output byte-for-byte.
- Task form: confirm `parser_list` stops at end of statement and does not
  swallow the following statement (sep-based; verify with a 2-line program).
- Block form: `with` pattern terminated by `{`; multiple tags become a
  positional await pattern (same as `every :a, :b`).
- `tosource.lua` (AST pretty-printer): toggle is a plain `call`, so it already
  round-trips; the appended args print as normal call args. Spot-check only.

## Tests (where)

Two existing files already cover `toggle`; extend both (both wired via
`tst/all.lua` — no `all.lua` change):

- `tst/expr.lua` (toggle block @~1342-1387) — parser/codegen via `tosource`.
  Add cases asserting the filter is appended as trailing call args:
    - `toggle t(false) with :Draw`        -> `toggle(t, false, 'Draw')`
    - `toggle t(false) with :a, :b`       -> `toggle(t, false, 'a', 'b')`
    - `toggle :X with :Draw { ... }`      -> `toggle('X', function ... end, 'Draw')`
    - `toggle t(true)` (no `with`)        -> unchanged (regression)
  (confirm exact tag rendering — strings vs `:X` — against current `tosource`.)
- `tst/exec.lua` (toggle block @~2398-2555) — execution via `atm_test(src)`.
  Add the freeze-but-draw program from §Manual: while toggled `with :Draw`,
  emit `:Tick`/`:Draw` and assert only `:Draw` runs; then toggle on and assert
  `:Tick` resumes.

Tests are run by the user (per workflow), not executed here.

## Out of scope

- Runtime semantics, filter matching, `t._.filter` — DONE in lua-atmos.
- `not`/`and`/`or`/clock as filters — runtime follow-up (`06-and-or-not`),
  not a language concern.
