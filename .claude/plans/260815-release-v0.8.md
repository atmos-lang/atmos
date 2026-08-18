# Plan: Release v0.8 (atmos-lang)

Instantiated from `release.md` @ 2026-08-15. IN PROGRESS.

# RESUME HERE (state @ 2026-08-17)

- ALL local work DONE: tests, docs, rockspecs, exs, app migration
- repo is on branch `v0.8`; all release edits UNCOMMITTED
- app repos have UNCOMMITTED migration (14/14 compile+run)
- Claude authorized to run tests/atmos this cycle

- next steps, in order:
    - 1. [DONE @ 2026-08-17] atmos commit `+ v0.8` = `d2884b3`
         (only this plan file left uncommitted)
    - 2. push `v0.8` DONE (`origin/v0.8` == `d2884b3`);
         check CI green (PENDING)
    - 3. [DONE @ 2026-08-17] sdl-birds -> `v0.5`
    - 4. [DONE @ 2026-08-17] sdl-rocks -> `v0.5`
    - 4b. [DONE @ 2026-08-17] pico-birds / pico-rocks -> `v0.9`
    - 5. [DONE @ 2026-08-17] local install (`make` 0.8-1 OK)
    - 6. ff atmos `main` -> `v0.8` + push; verify vs origin
    - 7. publish: `luarocks upload atmos-lang-0.8-1.rockspec`
         + `atmos-lang-dev-5.rockspec`; verify search
    - 8. §7 remote verify (clean install; re-run exs + apps)
    - 9. §8 announce; move this plan to `done/`

## Context

- COMPILER repo only; pins `atmos ~> 0.8`
- PREREQUISITE: lua-atmos v0.8 released TOGETHER (user-confirmed
  @ 2026-08-15; assume runtime+envs done under the lua-atmos plan)
- v0.8 changes (HISTORY.md, dated aug/26)
    - additions: `task` as expression; `task M.T` dot decls;
      `pin t = spawn {}` inline task
    - modifications: `await :any/all` non-buffered + non-empty pool;
      `@:x` without parens; `await` patterns `<...>` + bare `await T()`
      everywhere
    - fixes: `return` crosses transparent spawn; `spawn T()` where /
      last-expr; `await T(nil,...)`
- this rev ships NEW code (not metadata-only)

## Pre-flight (repo hygiene)

- [x] HISTORY.md: date `aug/26`; cross-checked runtime HISTORY
      (consistent; X.gte + emit-target fixes are runtime-only)
- [ ] commit pending `doc/manual.md` working-tree edits (dev)
- ignored (user): stray `.src.rock`; open-plans decision
    - `260804-spawn-exts.md` (`spawn on P` / `spawn @ts {}`) — additive
    - `260714-at-tag.md`, `2606-await-parens.md`, `async.md`,
      `no-tco.md`, `260628-context.md`, `260709-status.md`
    - move stale/done ones to `done/`

## §0. Conventions

- branch-tracking (not tags): rock pins `source.branch = v0.8`
- two rockspecs: `atmos-lang-0.8-1.rockspec` (branch `v0.8`,
  dep `atmos ~> 0.8`) + `atmos-lang-dev-5.rockspec` (branch `main`,
  unpinned; supersede `dev-4` -> `old/`)
- apps bump to their OWN next `vN` (sdl apps: `v0.4` -> `v0.5`)
- ff `main` after pushing `v0.8`; verify `main == v0.8 == origin`

## §1. Run tests

- Claude authorized to run (user @ 2026-08-16)
- [x] automatic: `cd tst && lua5.4 all.lua` PASS (exit 0;
      3 known TODO warnings only)
- [x] manual snippet compile checks (@ 2026-08-16):
    - [x] README.md: 2 code blocks OK (2 shell blocks n/a)
    - [x] doc/guide.md: 21/23 OK (2 known: placeholder + err-output)
    - [x] doc/exs/*.atm: 47/47 compile; exp-26-await FIXED to
          v0.8 patterns (`<:X && :Y>`, `until (it..)`) + runs OK
    - [x] tst/guide.atm end-to-end OK (thru §7.2 thread)

## §2. Docs consistency

- [x] README.md: `v0.8` in list; stable link; Install `0.8`;
      examples compile-verified
- [x] HISTORY.md: v0.8 entry finalized (date aug/26)
- [x] doc/manual.md: exs compile+run; prose scan clean (no stale
      predicate/combinator forms, no v0.7 refs)
    - manual-out.md: NEVER hand-edit; regen only if user approves
- [x] doc/guide.md: 21/23 compile + prose scan clean
- [x] rockspec `detailed` mirrors README About (verified in sync)
- [x] `atmos` CLI: already `VERSION = "v0.8"` (line 3)

## §3. Rockspec (compiler)

- [x] `atmos-lang-0.8-1.rockspec` (branch `v0.8`; `atmos ~> 0.8`)
- [x] `atmos-lang-dev-5.rockspec` (branch `main`; dep unpinned)
- [x] modules: 11 in both == all `src/*.lua` (no new modules)
- [x] moved `0.7-2` + `dev-4` to `old/` (git mv)
- [x] dev: local install `sudo luarocks make ... --lua-version=5.4`
      (@ 2026-08-17: `atmos-lang 0.8-1` listed; `atmos --version`
      = `atmos v0.8`; `exs/hello.atm` + `exs/rx.atm` run OK)

## §4. Core examples (Phase 1 -- local)

- [x] all 5 `exs/*.atm` compile; fixes applied:
    - clicks.atm: bare patt ids -> `(x)` value leaves
      (`watching (ctl)`, `loop v on (src)`, `watching (src)`)
    - click-drag-cancel + clicks: pico API `draw.text` ->
      `draw.text.fix` (installed pico-sdl split dyn/fix)
- [x] runs OK: hello (0/9x/now-µs), rx (1,2,3/33),
      rx-behavior (stream ticks); pico x2 loop w/o error

# §4.1 Migrate `.atm` apps

- | repo       | branch | new branch | files                        |
- | sdl-birds  | main   | v0.5       | birds-01..11.atm, README.md  |
- | sdl-rocks  | master | v0.5       | battle/main/ts.atm, README.md|
- | pico-birds | main   | v0.9       | birds-01..11.atm, README.md  |
- | pico-rocks | master | v0.9       | main/ts.atm, README.md       |
- pico apps FOUND @ 2026-08-17 (were MISSING from this plan):
    - own vN line, last released `v0.8` (pinned atmos v0.7)
      -> next is `v0.9`; NOT the same numbering as sdl apps
    - `.atm` migration ALREADY applied (uncommitted), runs OK
      (`pico-birds/birds-11.atm`, `pico-rocks/main.atm`)
    - extra churn vs sdl: env-pico 0.3 -> 0.4 API
      (`pico.layer.image(s) (nil,k,p,..)` -> `[key=,path=,sheet=]`;
      `draw.text` -> `.dyn("/id",..)` / `.fix`)
- [x] pico README.md x2 bumped (@ 2026-08-17, user go-ahead):
      `atmos-lang 0.8`; `atmos-env-pico 0.4`; `git checkout v0.9`
- v0.8 is mostly ADDITIVE; expect light migration, but CHECK:
    - `await :any/all` semantics (non-buffered, non-empty pool):
      sdl-rocks `watching :any ships` behavior may change
    - combinator patterns may need `<...>` (pin on first compile)
- [x] fetched + refs checked (@ 2026-08-16):
    - both: origin/v0.4 == origin default == local default (current)
    - both: LOCAL v0.4 branch stale (v0.7-era; origin moved on)
- [x] compile-check @ HEAD: 7/14 files FAIL, single pattern:
    - `watching until E {` -> `watching until (E) {` (11 sites)
    - birds-05/06:35; birds-08..11:38+57; rocks ts.atm:26
    - no other breaks (combinators, draw.text, :any/all clean)
- [x] fixes APPLIED (user go-ahead @ 2026-08-16); 14/14 compile:
    - 11x `watching until E {` -> `until (E) {`
    - birds-10/11: `watching bird` -> `watching (bird)`
    - birds-07: `watching \e{..}` lambda -> runtime-rejected in
      v0.8 -> `watching until ((rect.x>640) || (it==:collided))`
- [x] smoke-runs OK (timeout=running): birds-01..11 all,
      rocks main; battle/ts = modules (standalone n/a)
- [x] README.md x2: atmos-lang `0.8`; env-sdl `0.3` (repo @ v0.3);
      `git checkout v0.5`
- [x] sdl x2: DONE @ 2026-08-17; 4 refs verified, trees clean
    - sdl-birds  `main`==`v0.5`==origin x2 @ `75f7bbe`
    - sdl-rocks `master`==`v0.5`==origin x2 @ `0996ce5`
- [x] pico x2: DONE @ 2026-08-17; 4 refs verified, trees clean
    - pico-birds  `main`==`v0.9`==origin x2 @ `d72bca5`
    - pico-rocks `master`==`v0.9`==origin x2 @ `83ce521`

## §5. Commit, push main, release branch

- [x] branch `v0.8` created (matches v0.6/v0.7 convention:
      release commits on branch, ff `main` after)
    - [x] push `v0.8` (@ 2026-08-17: `origin/v0.8` == `d2884b3`)
- [x] README links `main` -> `v0.8` (stable link + list)
- [ ] CI green on GitHub Actions
- [ ] ff `main` -> `v0.8` + push; verify `main == v0.8 == origin`
- [ ] commit this plan's edits

## §6. Publish to LuaRocks

- [ ] `luarocks upload atmos-lang-0.8-1.rockspec`
- [ ] `luarocks upload atmos-lang-dev-5.rockspec`
- [ ] verify: `luarocks --lua-version=5.4 search atmos-lang`

## §7. Verify remote install (Phase 2)

- [ ] dev: clean remove + `install atmos 0.8` + `install atmos-lang 0.8`
- [ ] re-run core `exs/` on installed rock
- [ ] apps on `v0.5` branch; then back to default branch
- gotchas: `--force` remove wipes local make; sdl-rocks needs
  `tiny.ttf` in cwd

## §8. Announce (manual)

- [ ] Twitter / BlueSky
- [ ] Mailing list
- [ ] Students

# Appendix A -- v0.7 -> v0.8 cheat-sheet

- | # | construct       | v0.7                  | v0.8                  |
- | 1 | tag index       | `t@(:x)`              | `t@:x` (parens opt)   |
- | 2 | await combinator| `await (:X \|\| :Y)`  | `await <:X \|\| :Y>`  |
- | 3 | await predicate | `await :X until c`    | `<...>` for exprs     |
- | 4 | await task bare | `await T()` (limited) | also in `loop on` etc |
- | 5 | current task    | (n/a)                 | `task` as expression  |
- | 6 | task dot decl   | (n/a)                 | `task M.T (...)`      |
- | 7 | inline task     | (n/a)                 | `pin t = spawn {}`    |
- | 8 | await :any/all  | buffered              | needs prior await +
                                                  non-empty pool       |
- | 9 | bare id pattern | `watching s` / `on s` | `(s)` value leaf      |
- rows 2/3/9 PINNED @ 2026-08-16 (doc/exs + clicks fixes):
    - `await <:X && :Y>`; `await until (it && ..)`;
      `await <:X until (it.n==3)>`; `watching (ctl)`
- semantic (not syntax) row 8: re-check app logic, not just grep
- runtime env note: pico-sdl split `draw.text` -> `.fix`/`.dyn`;
  check apps for `draw.text(` calls too

# Appendix B -- learnings (carry-over)

- release BRANCHES, not tags; README version list + stable link
- runtime + envs FIRST (lua-atmos plan); compiler pins `~> 0.8`
- `git fetch` before app migration; 4-refs check; origin may be ahead
- ff `main` is easy to forget; verify vs origin before done
- Phase-1 local make != Phase-2 remote install; always both
- this cycle: user authorized Claude to run tests/atmos;
  commits/pushes remain user-only
- manual.md fenced blocks are hand-authored; drift vs `doc/exs/*.atm`
