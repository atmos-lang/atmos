# Plan: `spawn on` (one-shot concurrent event handler)

## Context

Extracted from `done/06-06-in-on.md` (the `loop in`/`on` + `every`-fold
migration). That plan's lexer / `loop on` / `toggle on` / `every`-removal /
tests / docs are all DONE; its ONLY remaining code item was `spawn on`, split
out here so the parent can be archived.

The `on` family — all "upon event pattern", blocking unless `spawn`:

| form              | role                          | status     |
| ----------------- | ----------------------------- | ---------- |
| `loop on P {}`    | repeating handler (was `every`)| DONE       |
| `toggle on P {}`  | gated subscription            | DONE       |
| `spawn on P {}`   | one-shot concurrent handler   | THIS PLAN  |

Rule (settled): **`spawn` is the only concurrency signal.** `on` / `loop on`
are blocking in the current task; `spawn on` is the explicit one-shot
concurrent handler. Bare `on P {}` is NOT added — use `await P; ...`.

## Feature

```
spawn on P { body }   ==   spawn { await P ; body }
```

## Implementation

1. [ ] Parser — `src/prim.lua`, `parser_spawn()` (~line 15): add a branch at
   the top, right after `accept_err('spawn')`:
   - `if accept('on') then`
   - `pat = parser_await('{')`  (the same call `loop on` / `toggle on` block
     forms use)
   - `blk = parser_block()`
   - prepend an `await(pat)` call statement to `blk`'s statement list (mirror
     the await-call node built in the `accept('await')` branch, ~prim.lua:197)
   - wrap with the `spawn(lin, blk)` helper; `return spw, spw` (same shape as
     the `spawn { ... }` branch). The outer `check('spawn')` caller already
     forces the `pin _ =` wrap when there is no pool target — reuse it, no
     change needed.
2. [ ] DECIDE (while implementing): binding form? `spawn e on :Y {}` like
   `loop e on :Y`, lowering to `spawn { val e = await P ; body }`.
   Plan default = BINDING-LESS; pick one and record it here.
3. [ ] Tests (ask the user to run; do not run):
   - `tst/stmt.lua`: a `spawn on` parse / tosource case
   - `tst/exec.lua`: a `spawn on` exec case
   - then sync `src/` to the installed tree, `cd tst && lua5.4 all.lua`
4. [ ] Docs (after green): `doc/manual.md` Spawn section + the SYNTAX appendix
   (the `on` family is already documented for `loop` / `toggle`).

## Related (shared follow-up)

- [ ] Await-patterns doc review (`doc/manual.md` `### Await`): confirm the
  match-slot list (`true` / `false` / `n: number` / `f: function` / `t: task`
  / pool / combinators / `{tag=…}` / `x: any`), `until` / `while`, and the
  `await PAT` vs `await(PAT)` juxtaposition rule match `src/await.lua` /
  `parser_await` after the `on` / clock changes. Shared with
  `done/06-11-await.md`.

## Cross-refs

- Parent (archived): `done/06-06-in-on.md` — full `in`/`on`/`loop`/`every`
  rationale, desugarings, and the `parser_spawn` recipe in its step 4.
- Sibling await plan (archived): `done/06-11-await.md`.
