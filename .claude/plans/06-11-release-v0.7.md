# Plan: Release v0.7 (atmos-lang)

## RESUME HERE (state @ 2026-06-11)

NOT STARTED. Adapted from the lua-atmos v0.7 plan
(`/x/lua-atmos/atmos/.claude/plans/06-08-release-v0.7.md`).

This is the COMPILER repo (atmos-lang). The runtime + environments ship
separately under the lua-atmos v0.7 plan, already DONE: `atmos 0.7`,
`env-sdl 0.2`, `env-pico 0.3`, `env-socket 0.2`, `env-iup 0.2` published;
`env-js` postponed. So atmos-lang v0.7 only releases the compiler + its docs
+ its rockspec (pinning `atmos ~> 0.7`).

Language work already DONE for v0.7 (plans archived in `done/`):

- sigil remap — index `t@(e)`/`t@i`, table `[…]`, tip `t@#`/`t@+`,
  pool/emit `@`-qualifier, block `{}` mono-purpose (`done/06-06-index-table.md`)
- clock unit literals `5s`/`300ms`/`2h30min` (`done/06-06-clock.md`)
- `thread` (`done/threads.md`), ppp markers (`done/06-09-ppp.md`), no-tco

Prerequisites — these language plans MUST land before cutting v0.7:

- [x] `done/06-11-await.md` — value-event await/emit + `||`/`&&`/`!`
      combinators (CLOSED 2026-06-18; bare-pool guard landed)
- [ ] `06-11-spawn-on.md` — `spawn on` (step 4) + await-docs review

Next actions, in order: finish the two prereq plans -> §1 tests -> §2 docs ->
§3 rockspec -> §4.1 migrate `.atm` apps (sdl-birds/sdl-rocks to `v0.4`) ->
§5 release branch -> §6 publish -> §7 remote verify (incl. apps) -> §8
announce.

App migration (requested 2026-06-20): the atmos-lang org `.atm` apps
sdl-birds + sdl-rocks migrated to v0.7 SYNTAX (Appendix A) and RUN OK
(2026-06-20). READMEs updated. REMAINING: cut the `v0.4` branch per repo
(commit + push + ff `main`/`master`) — user-run. Tracked in §4.1.

## Context

atmos-lang v0.6 is the current stable release (main feature: `thread`).
v0.7 is a large language/syntax refactor that tracks lua-atmos v0.7's
runtime changes and adds the sigil remap. Depends on lua-atmos `atmos ~> 0.7`
(already released). Versioning uses release BRANCHES (not tags).

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

(Confirm the final feature list against `done/06-11-await.md` /
`06-11-spawn-on.md`
once those land — combinators, `spawn on`, etc.)

## Steps

### 1. Run tests

- [x] Automatic: `cd tst && lua5.4 all.lua` (all pass, incl. task/xtask sweep)
- Manual:
    - [ ] README.md examples
    - [ ] doc/guide.md examples
    - [ ] doc/manual.md examples

### 2. Docs consistency

Check README.md / doc/guide.md / doc/manual.md / HISTORY.md all reflect
v0.7 syntax (sigil remap, clock units, single-arg events, combinators).

- [ ] README.md — add `v0.7` to version list; stable link `v0.6` -> `v0.7`;
      Install `install atmos-lang 0.7`; About in sync
- [x] HISTORY.md — v0.7 entry incl. task/xtask split (2026-06-19)
- [ ] doc/guide.md — sigil/clock/await examples current
- [~] doc/manual.md — sigil + `At` grammar migrated earlier; task/xtask
      content DONE (`260620-task.md` §1: Task/Spawn chapters, type lists,
      `xtask()`="me", all embedded examples). STILL TODO: spot-check the
      rest, then regen `doc/manual-out.md` (`cd doc && lua5.4 manual.lua
      manual.md > manual-out.md`) — never edit `manual-out.md` by hand
- [x] rockspec `detailed` synced (Streams/`thread` block, `loop on`)

### 3. Rockspec `atmos-lang-0.7-1.rockspec` -- DONE (2026-06-20)

- [x] `atmos-lang-0.7-1.rockspec` (branch `v0.7`, dep `atmos ~> 0.7`)
- [x] `atmos-lang-dev-4.rockspec` (branch `main`, dep `atmos` unpinned)
- [x] both: `await.lua` module added; desc `every` -> `loop on`;
      `lua >= 5.4`; Streams/`thread` block (mirrors runtime `atmos-0.7-2`)
- [x] superseded `0.6-1` + `dev-3` moved to `old/`; committed + pushed
- [ ] Install locally (Phase 1):
      `sudo luarocks make atmos-lang-0.7-1.rockspec --lua-version=5.4`
- Convention (from the v0.7 cycle): keep BOTH a pinned `0.7-1` rockspec
  (branch `v0.7`) and a `-dev-N` rockspec (git `main`/HEAD).
- See `done/260618-task-xtask.md` for the task/xtask compiler details;
  `260620-task.md` for remaining task/xtask DEFERRALS (parser + runtime).

### 4. Test examples (Phase 1 — local install)

NOTE: the lua-atmos `.lua` apps (env-sdl/-pico/-socket/-iup + their apps)
were migrated under the lua-atmos v0.7 plan (RUNTIME API: `loop_on`,
`xtask`, `do_spawn`).
SEPARATE from that, the atmos-lang org ships its OWN `.atm` apps that must
be migrated to v0.7 SYNTAX (sigil remap, clock units, single-arg events).
These ARE in scope here (§4.1).

- [x] Inventory `exs/*.atm` (5 files) + migrated to v0.7 (2026-06-20):
    - core (env-clock): `hello.atm`, `rx.atm`, `rx-behavior.atm` — clock
      literals, `S.from(clock)`->`S.fr_await(1s)`, `@{}`->`[]`, `it[2]`->`it@2`
    - pico (env-pico): `click-drag-cancel.atm` — grounded on env-pico
      `click-drag-cancel.lua` twin (`await(:X until pred)`,
      `await(:key.dn [key='Escape'])`)
    - `clicks.atm` — UNFINISHED scratch (no twin); live code migrated
      best-effort, dead `;;;` block left as-is. Findings:
      `S.fr_await(fn, args...)` needs fn = a plain `func` (it wraps with
      `task()` internally via `fr_spawn`); a `task` proto falls to the
      pattern branch -> `await(proto, args)` -> "invalid event pattern".
      So `Debounce` stays `func`. Combinator `(:a || :b)`, `S.from [..]`
      call-sugar, value-event `emit :tag [..]` used.
      (`atmos/streams.lua` also ships `S.debounce`/`S.buffer` built-ins.)
      STATUS: v0.7 SYNTAX migration COMPLETE — compiles + runs (table form
      `['!', x=..]` verified -> `{[1]='!', x=..}`). Click-path C abort fixed:
      `pico.get.mouse()` now REQUIRES a mode arg in pico-sdl (`l_get_mouse`
      -> `C_mode_t(L,2)`); changed to `pico.get.mouse('!')`. (cf. user
      reworked click-drag-cancel coords to `pico.cv.rect('!', ['%', ..])`.)
- [ ] Run the core (non-env) examples and confirm output (`./atmos exs/<f>`)
- [ ] Pico exs need env-pico installed to run; `clicks.atm` likely needs
      author fixes beyond syntax (mixed sdl/pico refs, half-built logic)

#### 4.1 Migrate the `.atm` apps to v0.7 syntax

atmos-lang org repos, depend on compiler v0.7 + env-sdl (`.lua` runtime
already at v0.7):

| repo      | branch | new branch | files to migrate              |
| --------- | ------ | ---------- | ----------------------------- |
| sdl-birds | main   | v0.4       | birds-01..11.atm, README.md   |
| sdl-rocks | master | v0.4       | battle/main/ts.atm, README.md |

Highest existing branch is `v0.3`; +0.1 per repo -> `v0.4`.
Leave the untracked `x.atm` scratch files alone.
Apps have NO rock: run from the repo via `./atmos <f>.atm`.

Migration = the v0.6 -> v0.7 SYNTAX changes (see Appendix A).
Per file: compile `atmos <f>.atm` (must emit Lua, no error), then
smoke-run under a display.

Landmines (NOT mechanical sed):

- `:clock` dt is now MICROSECONDS, not ms: re-derive `v/1000` and
  `ms*0.5` arithmetic in birds-11 / battle.
- `every` keyword removed -> `loop on` / `loop _,e on` / `loop _,i in`.
- `spawn` needs a task PROTOTYPE: a `func F(){}` that is later spawned
  must be declared `task F(){}` (runtime error otherwise: "invalid spawn
  : expected task prototype"). Verified on birds-01.
- NOTE: `&&` `||` `!` are UNCHANGED in `.atm` source (codegen maps them
  to Lua `and`/`or`/`not`); do NOT rewrite them. (Verified on the
  birds-01 pilot: `assert((a==c) and (b==d))` is rejected.)

Per-repo checklist:

- [x] sdl-birds: all 11 (birds-01..11) migrated + RUN OK (2026-06-20).
      tables `@{}`->`[]`, `func`->`task`, `loop us on :clock`+µs-merge,
      `loop on :sdl.draw`, `spawn @birds`, `emit @b :collided`,
      `:sdl [type=…,name=…]` events, `escape(:Track,b)`. `&&`/`||` KEPT.
- [x] sdl-rocks: main/battle/ts.atm migrated + RUN OK (2026-06-20).
      + `watching :any ships` (returns ship's RETURN value -> Ship ends
      `return(pub.tag)`, Battle `match s`); `await (dt*1ms)`;
      `await Move_T(...)` (spawn+await sugar); `par_or`/`match`/`ifs`/`++`
      kept; `points[winner]`->`points@winner`.
- [x] Updated both README.md (atmos-lang `0.7` + env-sdl `0.2`;
      `git checkout v0.4`; birds `birds-11.atm`, rocks `main.atm`).
- [~] Branch `v0.4` per repo (commit + push + ff + verify):
    - [x] sdl-rocks: master==v0.4==origin @ bee3893 (DONE 2026-06-20).
    - [~] sdl-birds: v0.4==origin/v0.4 @ 11c00f6 (pushed); `main` @ 3beeb63
          NOT yet ff'd. PENDING: `git checkout main && git merge --ff-only
          v0.4 && git push` (then `git checkout v0.4`).

### 5. Commit, push main, create release branch

- [ ] Single commit: `release: v0.7`
- [ ] Push main; check GitHub Actions for green CI
- [ ] Create branch `v0.7`
- [ ] Update README links: `main` -> `v0.7`; commit + push `v0.7`
- [ ] Return to main

### 6. Publish rockspec to LuaRocks

```bash
luarocks upload atmos-lang-0.7-1.rockspec
```

### 7. Verify LuaRocks install + examples again (Phase 2 — remote)

Smoke-test the PUBLISHED rock (not local `make`).

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
- Gotcha: `--force` remove wipes your local dev `make`; restore with
  `luarocks make` afterwards if you keep developing.
- Gotcha: env-sdl needs its font in cwd (`tiny.ttf` for sdl-rocks).

### 8. Announce (manual)

- Twitter / BlueSky
- Mailing list
- Students

## Conventions carried from the v0.7 cycle (lua-atmos learnings)

- Release BRANCHES, not tags; every repo's README shows a version list +
  stable link.
- Two rockspecs: pinned `X.Y-1` (branch) + `-dev-1` (HEAD).
- Per-repo release plans; `main` fast-forwarded to the version branch.
- Phase-2 (local `luarocks make`) != remote (published rock) — always do a
  clean install verify (§7).

## Appendix A — v0.6 -> v0.7 `.atm` syntax cheat-sheet

Used by §4.1 to migrate the apps.
Grounded in `tst/*.lua`, `done/06-06-*.md`, `done/06-11-*.md`, lexer/parser.
Forms marked CONFIRM-ON-COMPILE must be checked by compiling each file.

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
UNCHANGED in source (do NOT rewrite to `and`/`or`/`not`).
Rows 14/17/18/21/22 to be pinned exactly while compiling the first file.

## Appendix B — release conventions (folded from old plans)

From lua-atmos `06-08-release-v0.7.md` + `release.md` "Release Learnings".
Still relevant to atmos-lang v0.7:

- MIGRATION step BEFORE README: when core has breaking changes, each
  downstream repo needs an explicit "migrate to vX" pass, not just a
  version bump.
- Version branches are PER-REPO and INDEPENDENT: next unused `vN` for
  that repo (apps here: `v0.3` -> `v0.4`), NOT lockstep with the compiler.
- Apps have NO rockspec: run from the repo on the version branch.
- `main` fast-forward is easy to forget: develop+commit on `vN`, push,
  THEN `git checkout main && git merge --ff-only vN && git push`; verify
  `main == vN == origin` before calling a repo done.
- Phase-1 (`luarocks make`, local) != Phase-2 (`luarocks install`, remote
  published rock): always do the clean remote verify (§7).
- Mechanical-sed pitfall: spaced `every (` / `spawn (` are missed by a
  `\bevery\(` pattern; match `\s*` before `(` and re-verify by compiling.
- After running an app, `git checkout main`/`master`.
