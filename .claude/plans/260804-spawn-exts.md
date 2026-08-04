# Plan: spawn-exts

- renamed from `260621-spawn-on-at.md`
- extends spawn with explicit escape/guard forms
- motivation: `if ok { spawn {...} }` pins spawn to the
  branch block, aborting it at branch end (footgun)

# Features

- `spawn on P {}`
    - one-shot concurrent handler
    - desugar: `spawn { await P ; ... }`
    - `spawn` is the only concurrency signal
    - no bare `on P {}` (use `await P ; ...`)
- B: `spawn @ts {}`
    - anon real task into pool
    - desugar: `spawn_in(ts, task(){ ... })`
- B': `spawn @t {}` with `t` a task (incl. `@(task)`)
    - anon real task attached to owner task
    - same code path as B: runtime `M.spawn` accepts any `up`
    - escapes branch blocks (spawn_in skips implicit pin)
- D: `spawn if E {}`
    - guard sugar
    - desugar: `spawn { if E { ... } }`
    - note: task exists even if `E` false (dies at once)
    - block form only (no `spawn if E T()` for now)
- docs: `spawn @(task) T()`
    - already works, undocumented/untested

# Settled: C (block attachment wins)

- decision (26-08-04): impl is right, manual is wrong
- evidence: corpus relies on iteration-end abort
    - `pico-birds/birds-02.atm:32`
        - loop respawns birds each click
    - `pico-rocks/main.atm:84`
        - pause overlay dies at iteration end
- task attachment would leak both cases
- fix: `doc/manual.md:852`
    - "enclosing task" -> "enclosing block"
- footgun answered by explicit escapes: B' / D / tail
- E (warn non-tail branch spawn): won't do for now

# Implementation

- `src/prim.lua` `parser_spawn`
    - after `accept_err('spawn')`:
        - `accept('if')`: parse cond + block
            - wrap block in `ifs` node, then `spawn(lin, blk)`
        - `accept('on')`: `pat = parser_await('{')`
            - prepend `await(pat)` call to block stmts
            - wrap with `spawn(lin, blk)` helper
        - both return `spw, spw` (caller forces `pin _ =`)
    - else-branch, after `parser_at` sets `ts`:
        - if `ts and check('{')`:
            - `blk = parser_block()`
            - proto: `{tag='proto', sub='task', pars={}, blk}`
            - emit `spawn_in(ts, proto)` (`f='spawn_in'`)
            - `f=='spawn_in'` skips the `pin _ =` wrap
- decide while implementing
    - binding form `spawn e on :Y {}`?
    - default: binding-less

# Docs (after green)

- `doc/manual.md` Spawn section + SYNTAX appendix
    - `spawn on P {}` beside `loop on` / `toggle on`
    - `spawn @ts {}` beside `spawn @ts T()`
    - `spawn @t {}` / `spawn @(task) T()` owner targets
    - `spawn if E {}` guard sugar
- fix manual `:852` (see Settled: C)
- await-patterns doc review (`### Await`)
    - match-slot list vs `src/await.lua` (shared w/
      `done/06-11-await.md`)

# Cross-refs

- parent (archived): `done/06-06-in-on.md`
- siblings: `done/06-11-await.md`, `done/260708-pin-spawn.md`
