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

- [ ] `06-and-or-not.md` — value-event await/emit + `||`/`&&`/`!` combinators
      (in progress; blocked on a lua-atmos `where` runtime branch)
- [ ] `06-11-spawn-on.md` — `spawn on` (step 4) + await-docs review

Next actions, in order: finish the two prereq plans -> §1 tests -> §2 docs ->
§3 rockspec -> §5 release branch -> §6 publish -> §7 remote verify -> §8
announce.

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

(Confirm the final feature list against `06-and-or-not.md` / `06-11-spawn-on.md`
once those land — combinators, `spawn on`, etc.)

## Steps

### 1. Run tests

- [ ] Automatic: `cd tst && lua5.4 all.lua` (all pass)
- Manual:
    - [ ] README.md examples
    - [ ] doc/guide.md examples
    - [ ] doc/manual.md examples

### 2. Docs consistency

Check README.md / doc/guide.md / doc/manual.md / HISTORY.md all reflect
v0.7 syntax (sigil remap, clock units, single-arg events, combinators).

- [ ] README.md — add `v0.7` to version list; stable link `v0.6` -> `v0.7`;
      Install `install atmos-lang 0.7`; About in sync
- [ ] HISTORY.md — v0.7 entry (confirm date)
- [ ] doc/guide.md — sigil/clock/await examples current
- [ ] doc/manual.md — migrated this cycle (sigil + `At` grammar); spot-check,
      then regen `doc/manual-out.md` (`cd doc && lua5.4 manual.lua manual.md
      > manual-out.md`) — never edit `manual-out.md` by hand
- [ ] rockspec `detailed` synced with README "About" (see §3)

### 3. Rockspec `atmos-lang-0.7-1.rockspec`

- [ ] Copy from `atmos-lang-0.6-1.rockspec`
- [ ] `version` -> `"0.7-1"`
- [ ] `branch` -> `"v0.7"`
- [ ] dependency `atmos ~> 0.6` -> `atmos ~> 0.7`
- [ ] `detailed` synced with README "About"
- [ ] Move old rockspec to `old/`
- [ ] Install locally (Phase 1):
      `sudo luarocks make atmos-lang-0.7-1.rockspec --lua-version=5.4`
- Convention (from the v0.7 cycle): keep BOTH a pinned `0.7-1` rockspec
  (branch `v0.7`) and a `-dev-1` rockspec (git `main`/HEAD).

### 4. Test examples (Phase 1 — local install)

NOTE: in v0.7 the environments/apps live in separate repos (env-sdl/-pico/
-socket/-iup + sdl-*/pico-* apps), released & verified under the lua-atmos
plan §7. Here, only the COMPILER's own `exs/` are in scope.

- [ ] Inventory `exs/*.atm`; identify env-independent ones
- [ ] Run the core (non-env) examples and confirm output

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
- Gotcha: `--force` remove wipes your local dev `make`; restore with
  `luarocks make` afterwards if you keep developing.

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
