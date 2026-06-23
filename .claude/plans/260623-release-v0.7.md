# Plan: Release v0.7 (atmos-lang)

## RESUME HERE (state @ 2026-06-23)

RESTART. Prior plan (`done/06-11-release-v0.7.md`) went stale; redoing
v0.7 in sequence from the new `release.md` template. ALL steps below are
RESET to not-done -- re-verify each, do not trust prior state.

This is the COMPILER repo (atmos-lang). The RUNTIME + ENVIRONMENTS ship
separately under the lua-atmos v0.7 plan (`atmos 0.7`, `env-sdl`,
`env-pico`, `env-socket`, `env-iup`). This plan releases ONLY the
compiler + its docs + its rockspec, pinning `atmos ~> 0.7`.

## Context

atmos-lang v0.6 is the current stable release (main feature: `thread`).
v0.7 is a large language/syntax refactor that tracks lua-atmos v0.7's
runtime changes and adds the sigil remap. Depends on lua-atmos
`atmos ~> 0.7`. Versioning uses release BRANCHES (not tags).

New since v0.6 (draft `HISTORY.md` entry):

```
v0.7 (jun/26)
-------------

- Sigil remap (every delimiter mono-purpose):
    - index `t[…]` -> `t@(…)`  (bare `t@i` / `t@1`); field `t.x` unchanged
    - table `@{…}` -> `[…]`;  computed keys `[@(k)=v]` (bare `[@i=v]`)
    - tip indexing `t@#` (last) / `t@+` (append)
    - pool / emit-target `[ts]`/`emit[t]` -> `@`-qualifier
      (`spawn @ts`, `emit @(:t)`)
    - block `{…}` now mono-purpose
- Clock: `@5` -> unit literals `5s` `300ms` `2h30min` (us..day);
  `clock` value-type -> microsecond number
- Events: single-arg `await`/`emit`; value-events `{tag=…}`; combinators
  `||`/`&&`/`!` -> `{tag='or'/'and'/'not'}`
- `abort` task/tasks; `await(ts, 'any'/'all')`; `toggle(…, [filter], …)`
- `loop` folds `every` (`loop ids on :Y {}`); `toggle on`
```

Open decision: `260621-spawn-on-at.md` (`spawn on P {}` + `spawn @ts {}`)
is additive -> v0.7 CAN ship without it; confirm defer vs blocker.

## §0. Conventions (read first)

- COMPILER repo only; runtime + envs ship under the lua-atmos plan
  (must be published first). This pins `atmos ~> 0.7`.
- Branch-tracking (not tags): rock pins `source.branch = v0.7`. A new rev
  only re-publishes METADATA.
- Two rockspecs: `atmos-lang-0.7-<rev>.rockspec` (branch `v0.7`, dep
  `atmos ~> 0.7`) + `atmos-lang-dev-<n>.rockspec` (branch `main`,
  unpinned `atmos`).
- Downstream `.atm` apps bump to their OWN next unused `vN` (apps here:
  `v0.3` -> `v0.4`), NOT lockstep with the compiler. Apps have NO rock.
- `main` ff: develop+commit on `v0.7`, push, THEN
  `git checkout main && git merge --ff-only v0.7 && git push`; verify
  `main == v0.7 == origin/main`.

## §1. Run tests

> Claude does NOT execute ANYTHING -- no tests, no `atmos`/`lua`, no
> compile/run shims. The developer runs every check. Claude reviews
> statically and reasons from language rules. (Some items below were
> verified by dev-authorized runs earlier this session; from now on:
> static only.)

- [x] Automatic: `cd tst && lua5.4 all.lua` (PASS @ 2026-06-23, dev-run)
- [x] Manual snippet COMPILE checks (dev runs; Claude reviews statically):
    - [x] README.md examples -- Hello World runs (dev) OK
    - [x] doc/guide.md fenced blocks -- all v0.7; fixed 8 `func`->`task`
          spawned protos + `spawn(\{})()`->named task + "function"->
          "task prototype" prose
    - [x] tst/guide.atm (runnable guide mirror) -- MIGRATED to v0.7
          (`spawn [ts]`->`spawn @ts`, `func`->`task`, `xprint`->`X.print`)
          + RE-SYNCED section labels to guide.md (Streams->§7.1,
          More-about-Tasks->§5, Errors->§6) + ADDED §7.2 thread example
          (md->atm, iters 10^7). Dev-run: full file OK end-to-end.
    - [!] LAUNCHER BUG fixed: `./atmos` set `atmos.thread` (wrong field)
          instead of appending `atmos.thread_modules` -> thread lane had
          no `catch` ("attempt to call nil 'catch'"). Now matches
          exec.lua:24-25. NOTE: append (not `= {...}`) is REQUIRED --
          `atmos.thread_modules` aliases `run.thread_modules` (init.lua:14
          / run.lua:814); reassigning breaks the alias. -> HISTORY.md fix.
          INSTALLED bin/atmos picks it up only after §3 `luarocks make`.
    - [x] doc/manual.md embedded `doc/exs/*.atm` -- ran ALL 47 with
          installed rock 0.7-1. FIXED -> 44 clean + 3 run-forever loops,
          0 unexpected. Fixes applied:
        - A. `exp-09-equivalence:2` `task(\{})` -> `task () {}` DONE
        - B. `xprint`/`x.*` -> `X.print`/`X.*` (legit lib at lua-atmos
          `atmos/x.lua`, required in run.lua; API is capital `X`:
          `X.tostring`/`X.print`/`X.copy`). Files: `exp-08-set`,
          `exp-13-ppp`, `exp-11-concatenation`, `val-02-vector`. Also
          documented `X` in manual.md STANDARD LIBRARIES. DONE
        - C. `spawn/await func` -> `task` proto (Appx A #28): `exp-02-
          blocks`, `exp-05-locals`, `exp-11-concatenation`, `exp-11-
          length`, `exp-24-abort`, `exp-26-await`, `exp-28-toggle` DONE
        - D. `await(\{pred})` -> `await until \{ pred }` (predicate form,
          per tst/tasks.lua:782) in `exp-26-await`. DONE
        - WONT-DO: `lex-01-literals` native lit `` `x:f{"lua"}` ``
          references undefined Lua `x` -- syntax demo only (manual
          inlines source, never runs it).
        - EXPECTED throws: `exp-03-escape` (Z), `exp-23-exceptions` (X).
        - NOTE: NEVER regenerate `manual-out.md` (per user).


## §2. Docs consistency

Check README.md / doc/guide.md / doc/manual.md / HISTORY.md + rockspec
`detailed` all reflect v0.7 syntax (sigil remap, clock units, single-arg
events, combinators).

- [ ] README.md — `v0.7` in version list + stable link; Install `0.7`;
      About `every`->`loop`; re-check examples
- [ ] HISTORY.md — v0.7 entry (incl. task/xtask split)
- [ ] doc/guide.md — walk every snippet; value-event forms
      `emit(:X [v])` / `await(:X [id])`
- [ ] doc/manual.md — prose + embedded `doc/exs/*.atm` v0.7; regenerate
      `doc/manual-out.md` (NEVER edit by hand):
      `cd doc && lua5.4 manual.lua manual.md > manual-out.md`
- [ ] rockspec `detailed` synced (Streams/`thread` block, `loop on`)

## §3. Rockspec (compiler)

- [ ] `atmos-lang-0.7-1.rockspec` (branch `v0.7`, dep `atmos ~> 0.7`)
- [ ] `atmos-lang-dev-<n>.rockspec` (branch `main`, dep `atmos` unpinned)
- [ ] both: ensure `await.lua` module present; desc `every` -> `loop on`;
      `lua >= 5.4`; Streams/`thread` block
- [ ] move superseded rockspecs to `old/`
- [ ] Install locally (Phase 1, LOCAL not remote):
      `sudo luarocks make atmos-lang-0.7-1.rockspec --lua-version=5.4`

See `done/260618-task-xtask.md` (task/xtask compiler details);
`done/260620-task.md` (task/xtask DEFERRALS).

## §4. Core examples (Phase 1 — local install)

The atmos-lang org ships its OWN `.atm` examples + apps that must be
migrated to v0.7 SYNTAX (separate from the lua-atmos `.lua` runtime
migration done under that plan).

- [ ] Inventory `exs/*.atm` + migrate to v0.7 (Appendix A):
    - core (env-clock): `hello.atm`, `rx.atm`, `rx-behavior.atm`
    - pico (env-pico): `click-drag-cancel.atm`, `clicks.atm` (scratch)
- [ ] Compile each: `./atmos <f>.atm`
- [ ] Run each + confirm output (env-clock / env-pico installed)

### 4.1 Migrate the `.atm` apps to v0.7 syntax

| repo      | branch | new branch | files to migrate              |
| --------- | ------ | ---------- | ----------------------------- |
| sdl-birds | main   | v0.4       | birds-01..11.atm, README.md   |
| sdl-rocks | master | v0.4       | battle/main/ts.atm, README.md |

Highest existing branch is `v0.3`; +0.1 per repo -> `v0.4`.
Leave untracked `x.atm` scratch files alone. Apps have NO rock:
`./atmos <f>.atm`.

Landmines (NOT mechanical sed):

- `:clock` dt is now MICROSECONDS, not ms: re-derive `v/1000` and
  `ms*0.5` arithmetic in birds-11 / battle.
- `every` keyword removed -> `loop on` / `loop _,e on` / `loop _,i in`.
- `spawn` needs a task PROTOTYPE: `func F(){}` later spawned must be
  `task F(){}` (else "invalid spawn : expected task prototype").
- `&&` `||` `!` are UNCHANGED in `.atm` source (codegen -> Lua
  `and`/`or`/`not`); do NOT rewrite them.

Per-repo checklist:

- [ ] sdl-birds: migrate all (birds-01..11) + README + RUN OK
- [ ] sdl-rocks: migrate main/battle/ts.atm + README + RUN OK
- [ ] Branch `v0.4` per repo: commit + push + ff `main`/`master` + verify
      `== origin`

## §5. Commit, push main, create release branch

- [ ] Create/update branch `v0.7` (pushed)
- [ ] Update README links: `main` -> `v0.7`
- [ ] Push `v0.7`; check GitHub Actions CI green
- [ ] ff `main` -> `v0.7` + push, then back to `v0.7`; verify
      `main == v0.7 == origin/main`
- [ ] Commit the working `.claude/plans/260623-release-v0.7.md` edits

## §6. Publish rockspec to LuaRocks

```bash
luarocks upload atmos-lang-0.7-1.rockspec
luarocks upload atmos-lang-dev-<n>.rockspec
```

Verify: `luarocks --lua-version=5.4 search atmos-lang`.

## §7. Verify LuaRocks install + examples (REMOTE)

Smoke-test the PUBLISHED rock (NOT local `make`).

```bash
sudo luarocks --lua-version=5.4 remove atmos-lang --force
sudo luarocks --lua-version=5.4 install atmos 0.7        # runtime first
sudo luarocks --lua-version=5.4 install atmos-lang 0.7   # pins atmos ~> 0.7
```

- [ ] Re-run the core `exs/` examples against the installed rock
- [ ] Apps (NO rock): checkout the version branch, run, then
      `git checkout main`/`master`:
    - [ ] sdl-birds (`v0.4`): `birds-11.atm`
    - [ ] sdl-rocks (`v0.4`): `main.atm`

Gotchas: `--force` remove wipes local dev `make` (restore with
`luarocks make`); env-sdl needs its font in cwd (`tiny.ttf` for
sdl-rocks); after running an app, `git checkout main`/`master`.

## §8. Announce (manual)

- [ ] Twitter / BlueSky
- [ ] Mailing list
- [ ] Students

## Appendix A — v0.6 -> v0.7 `.atm` syntax cheat-sheet

Used by §4 / §4.1 to migrate the examples + apps.
Grounded in `tst/*.lua`, `done/06-06-*.md`, `done/06-11-*.md`,
lexer/parser. Forms marked CONFIRM-ON-COMPILE must be checked by
compiling each file.

| # | construct | v0.6 | v0.7 |
| - | ------------- | ------------------------ | -------------------------- |
| 1 | table literal | `@{ x=1 }` / `@{ a }`     | `[ x=1 ]` / `[ a ]`        |
| 2 | computed key  | `@{ [k]=v }`             | `[ @(k)=v ]` (bare `@i`)   |
| 3 | index expr    | `t[i+1]`                 | `t@(i+1)`                  |
| 4 | index id/lit  | `t[k]` / `t[5]`          | `t@k` / `t@5`              |
| 5 | field         | `t.x`                    | `t.x` (unchanged)          |
| 6 | tip           | (n/a)                    | `t@#` last / `t@+` append  |
| 7 | clock lit     | `@5` / `@.500` / `@.100` | `5s` / `500ms` / `100ms`   |
| 8 | clock compound| `@1:30.500`              | `1min30s500ms`             |
| 9 | clock var     | `@(x)`                   | `x * 1s` (or `* 1ms`)      |
|10 | clock dt val  | ms (per `:clock`)        | MICROSECONDS — re-derive   |
|11 | every (evt)   | `every :X { }`           | `loop on :X { }`           |
|12 | every (bind)  | `every _,e in :X { }`    | `loop _,e on :X { }`       |
|13 | every (data)  | `every _,i in xs { }`    | `loop _,i in xs { }`       |
|14 | await evt 2-arg | `await(E, 'P')`        | single-arg pattern (verify)|
|15 | await clock   | `await @1` / `await @.5` | `await 1s` / `await 500ms` |
|16 | await task    | `await(t)`               | `await(t)` (unchanged)     |
|17 | emit payload  | `emit('Show', false)`    | value-event `{tag=…}` form |
|18 | emit bare tag | `emit :collided`         | `emit :collided` (verify)  |
|19 | watching evt  | `watching E, 'P' { }`    | `watching E { }` (1-arg)   |
|20 | spawn pool    | `spawn [birds] B(...)`   | `spawn @birds B(...)`      |
|21 | emit target   | `emit [b1] :collided`    | `emit @b1 :collided` (parens optional for bare tag; `emit @t (e)` for exprs) |
|22 | pool ctor     | `tasks(5)`               | `tasks(5)` UNCHANGED (arity kept) |
|23 | bool logic    | `a && b` / `a \|\| b` / `!a` | UNCHANGED (codegen -> Lua and/or/not) |
|24 | evt combinator| `:X && :Y` (in pattern)  | `:X && :Y` UNCHANGED (lowers to {tag}) |
|25 | toggle block  | `toggle :Show { }`       | `toggle on :Show { }`      |
|26 | toggle task   | `toggle t(false)`        | `toggle t(false)` (same)   |
|27 | spawn block   | `spawn { }`              | `spawn { }` (unchanged)    |
|28 | spawned proto | `func Bird(){}` + `spawn Bird()` | `task Bird(){}` (spawn needs a task proto, NOT a bare func) |
|29 | where/do/par  | `where{}` `do{}` `par{}with{}` | unchanged             |
|30 | escape        | `do :T { escape(:T,v) }` | unchanged                  |
|31 | pipes/set     | `--> f` / `set x.y=`     | unchanged (`set t@k=` #4)  |

CRITICAL rows: 10 (µs), 11-13 (`every` removed -> `loop on`), 28
(`func`->`task` for spawned protos). NOTE row 23/24: `&&`/`||`/`!` are
UNCHANGED in source. Rows 14/17/18/21/22 to be pinned exactly while
compiling the first file.

## Appendix B — release learnings

- Release BRANCHES, not tags; README shows a version list + stable link.
- MIGRATION step BEFORE README: syntax break -> each app needs an
  explicit migrate pass, not just a version bump.
- App version branches are PER-REPO and INDEPENDENT (`v0.3` -> `v0.4`).
- Apps have NO rockspec: run from the repo on the version branch.
- `main` fast-forward is easy to forget: develop+commit on `v0.7`/`vN`,
  push, THEN ff `main`/`master`; verify `== origin`.
- Phase-1 (`luarocks make`, local) != Phase-2 (`luarocks install`,
  remote published rock): always do the clean remote verify (§7).
- Mechanical-sed pitfall: spaced `every (` / `spawn (` missed by
  `\bword\(`; match `\s*` before `(`; DEV re-verifies by compiling.
- NEVER edit `doc/manual-out.md` by hand: regenerate via `manual.lua`.
- After running an app, `git checkout main`/`master`.
- Claude NEVER runs tests/`atmos`/`lua`/compile shims -- static review
  only; the DEV runs every check. `func`->`task` spawn errors are caught
  by the rule (Appx A #28), not by running.
- `manual.lua` only builds the TOC; it does NOT inline `doc/exs/*.atm`.
  So manual.md fenced blocks are hand-authored and DRIFT from the `.atm`
  files -- review both. guide.md blocks likewise hand-authored.
