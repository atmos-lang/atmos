# Plan: Release vX.Y (atmos-lang TEMPLATE)

Reusable checklist for an atmos-lang (COMPILER) release: docs, core
rockspec, core `exs/`, downstream `.atm` apps, remote verify, announce.
Copy this file to `.claude/plans/YYMMDD-release-vX.Y.md` and fill it in
per release.
Replace `vX.Y` (atmos-lang), `<rev>` (rockspec rev), `<n>` (dev rev),
`vN` (per-app branch) throughout.

## Context

Fill in per release:

- What changed since the last cut (sigil/syntax remaps, new keywords,
  removals, bug fixes); mirror this into `HISTORY.md`.
- Which lua-atmos runtime this compiler pins (`atmos ~> X.Y`); confirm
  that runtime + its envs are ALREADY released under the lua-atmos plan.
- Whether this rev ships NEW code or only corrected METADATA (see
  branch-tracking note below).

## §0. Conventions (read first)

These drive every decision below.

### This is the COMPILER repo only

atmos-lang ships the `.atm` -> Lua compiler + its docs + its rockspec.
The RUNTIME (`atmos`) and the ENVIRONMENTS (env-sdl/-pico/-socket/-iup)
ship SEPARATELY under the lua-atmos release plan and must be DONE first.
This plan depends on a published `atmos ~> X.Y`.

### Branch-tracking (not tags)

The rock pins `source.branch = vX.Y`, NOT a tag.
Pushing migrated code to the version branch ALREADY serves it under the
EXISTING rock rev.
A new rev (`0.7-2`, ...) only re-publishes corrected METADATA -- it ships
no new code.
luarocks.org rejects overwriting a published version, so any description
fix can ONLY ship via a fresh rev.

### Two rockspecs

- `atmos-lang-X.Y-<rev>.rockspec`: `source.branch = vX.Y`, pinned dep
  `atmos ~> X.Y`.
- `atmos-lang-dev-<n>.rockspec`: `source.branch = main`, unversioned
  `atmos` (single dev spec convention -- supersede the stale one, move it
  to `old/`).

### Downstream `.atm` apps are INDEPENDENT

Each app (sdl-birds, sdl-rocks, ...) bumps to ITS OWN next unused `vN`,
NOT lockstep with the compiler (e.g. apps `v0.3` -> `v0.4`).
Apps have NO rockspec: run from the repo via `./atmos <f>.atm` on the
version branch.

### `main` fast-forward (easy to forget)

Develop + commit on the release branch `vX.Y`, push it, THEN ff `main`:
`git checkout main && git merge --ff-only vX.Y && git push`.
Always verify `main == vX.Y == origin/main` before calling the repo done.
Same rule per app: develop on `vN`, push, ff `main`/`master` to `vN`.

## §1. Run tests

- [ ] Automatic tests:

```bash
cd tst && lua5.4 all.lua
```

With dependencies (CI environment):

```bash
cd tst && LUA_PATH="../f-streams/?/init.lua;../lua-atmos/?.lua;../lua-atmos/?/init.lua;;" lua5.4 all.lua
```

- [ ] Manual snippet checks -- COMPILE each fenced/embedded example
      against the new API (run-check optional):
    - [ ] README.md examples (Hello World, About)
    - [ ] doc/guide.md fenced blocks (note `<...>` placeholders + error
          -output blocks that are expected NOT to compile)
    - [ ] doc/manual.md embedded `doc/exs/*.atm`

## §2. Docs consistency

Check ALL docs reflect the new syntax before cutting:

- [ ] README.md
- [ ] doc/guide.md
- [ ] doc/manual.md  (regenerate `doc/manual-out.md`, never edit it)
- [ ] HISTORY.md
- [ ] rockspec `detailed`

### 2.1 README.md

- [ ] Add `vX.Y` to version list
- [ ] Update stable link to `vX.Y`
- [ ] Update `Install & Run`: `install atmos-lang X.Y`
- [ ] Re-check every example against the new syntax

### 2.2 HISTORY.md

- [ ] Add the `vX.Y` entry (additions / modifications / removals /
      fixes) -- the source of truth for "what changed".

### 2.3 doc/manual.md (+ auto-gen)

- [ ] Walk prose + every embedded `doc/exs/*.atm` against the new syntax.
- [ ] Regenerate the output (NEVER edit `manual-out.md` by hand):

```bash
cd doc && lua5.4 manual.lua manual.md > manual-out.md
```

- [ ] Confirm stale old-syntax forms are gone from the regenerated file.

### 2.4 doc/guide.md

- [ ] Walk every snippet against the new syntax.
- [ ] Terminology aligned with the manual.

### 2.5 Rockspec `detailed`

- [ ] Keep `detailed` in sync with the README "About" section. A stale
      word here is a metadata-only reason to bump a rev.

## §3. Rockspec (compiler)

- [ ] Create `atmos-lang-X.Y-<rev>.rockspec` (copy prior rev,
      `source.branch = vX.Y`, dep `atmos ~> X.Y`). Leave the prior rev
      untouched.
- [ ] Create/refresh `atmos-lang-dev-<n>.rockspec` (branch `main`, dep
      `atmos` unpinned; single dev spec convention).
- [ ] Add any NEW modules to BOTH rockspecs' `build.modules`.
- [ ] Move superseded rockspecs to `old/`.
- [ ] Install locally (Phase 1 -- LOCAL install, NOT the remote verify):

```bash
sudo luarocks make atmos-lang-X.Y-<rev>.rockspec --lua-version=5.4
```

Per-rev DECISION: if branch-tracking already serves the code AND the
published `detailed` text is still correct, SKIP the rev bump. Bump ONLY
when the published description is wrong.

## §4. Core examples (Phase 1 -- local install)

The atmos-lang org ships its OWN `.atm` examples + apps that must be
migrated to the new SYNTAX (separate from the lua-atmos `.lua` runtime
migration, which is done under that plan).

- [ ] Inventory `exs/*.atm` and migrate to vX.Y syntax (see Appendix A).
- [ ] Compile each: `./atmos <f>.atm` (must emit Lua, no error).
- [ ] Run each + confirm output (some need an env installed, e.g.
      env-clock / env-pico).

### 4.1 Migrate the `.atm` apps to vX.Y syntax

atmos-lang org repos; depend on compiler vX.Y + the relevant env (`.lua`
runtime already migrated under the lua-atmos plan):

| repo      | branch | new branch | files to migrate              |
| --------- | ------ | ---------- | ----------------------------- |
| sdl-birds | main   | vN         | birds-*.atm, README.md        |
| sdl-rocks | master | vN         | battle/main/ts.atm, README.md |

Bump each app to ITS next unused `vN` (NOT lockstep with the compiler).
Leave untracked scratch files (`x.atm`, ...) alone.

Per file: compile `./atmos <f>.atm`, then smoke-run under a display.

Per-repo checklist:

- [ ] Migrate all `.atm` files (Appendix A) + RUN OK
- [ ] Update README.md (atmos-lang `X.Y` + env version; `git checkout
      vN`; entry-point file)
- [ ] Branch `vN`: commit + push + ff `main`/`master` + verify
      `main == vN == origin`

## §5. Commit, push main, create release branch

- [ ] Create/update branch `vX.Y` (pushed)
- [ ] Update README links: `main` -> `vX.Y`
- [ ] Push `vX.Y`; check GitHub Actions CI green
- [ ] ff `main` -> `vX.Y` + push, then back to `vX.Y`; verify
      `main == vX.Y == origin/main`
- [ ] Commit the working `.claude/plans/YYMMDD-release-vX.Y.md` edits

## §6. Publish rockspec to LuaRocks

```bash
luarocks upload atmos-lang-X.Y-<rev>.rockspec
luarocks upload atmos-lang-dev-<n>.rockspec
```

Verify: `luarocks --lua-version=5.4 search atmos-lang`.

## §7. Verify LuaRocks install + examples (REMOTE)

Smoke-test the PUBLISHED rock (NOT local `make`).

```bash
sudo luarocks --lua-version=5.4 remove atmos-lang --force
sudo luarocks --lua-version=5.4 install atmos X.Y        # runtime first
sudo luarocks --lua-version=5.4 install atmos-lang X.Y   # pins atmos ~> X.Y
```

- [ ] Re-run the core `exs/` examples against the installed rock
- [ ] Apps (NO rock): checkout the version branch, run, then
      `git checkout main`/`master`:
    - [ ] sdl-birds (`vN`): entry-point `.atm`
    - [ ] sdl-rocks (`vN`): entry-point `.atm`

Gotchas:

- `--force` remove wipes your local dev `make`; restore with
  `luarocks make` afterwards if you keep developing.
- env-sdl needs its font in cwd (e.g. `tiny.ttf` for sdl-rocks).
- After running an app, `git checkout main`/`master`.

## §8. Announce (manual)

- [ ] Twitter / BlueSky
- [ ] Mailing list
- [ ] Students

## Appendix A -- syntax migration cheat-sheet (PER RELEASE)

Fill in the vPREV -> vX.Y syntax changes used by §4 / §4.1 to migrate the
`.atm` examples + apps. Ground each row in `tst/*.lua`, the `done/` plans,
and the lexer/parser. Mark rows CONFIRM-ON-COMPILE when unsure; pin them
exactly while compiling the first file.

| # | construct | vPREV | vX.Y |
| - | --------- | ----- | ---- |
|   |           |       |      |

Record per-repo breaking counts so nothing is missed:

```
repo         breaking-A   breaking-B   notes
sdl-birds    <n>          <n>
sdl-rocks    <n>          <n>
```

## Appendix B -- release learnings (folded from prior cuts)

- Release BRANCHES, not tags; every repo's README shows a version list +
  stable link.
- MIGRATION step BEFORE README: when the syntax breaks, each downstream
  app needs an explicit migrate pass, not just a version bump.
- App version branches are PER-REPO and INDEPENDENT: next unused `vN`,
  NOT lockstep with the compiler.
- Apps have NO rockspec: run from the repo on the version branch.
- `main` fast-forward is easy to forget: develop+commit on `vX.Y`/`vN`,
  push, THEN ff `main`/`master`; verify `== origin` before done.
- Phase-1 (`luarocks make`, local) != Phase-2 (`luarocks install`,
  remote published rock): always do the clean remote verify (§7).
- Mechanical-sed pitfall: spaced calls (`every (`, `spawn (`) are missed
  by a `\bword\(` pattern; match `\s*` before `(` and re-verify by
  compiling.
- NEVER edit `doc/manual-out.md` by hand: regenerate via `manual.lua`.
- Migration is NOT pure sed: re-derive clock arithmetic, watch keyword
  removals, and `func` -> `task` for spawned prototypes.
