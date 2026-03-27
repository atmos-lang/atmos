# Plan: Release v0.6

## Context

Atmos-lang v0.5 is the current stable release.
For v0.6, the main new feature is `thread` support
(thread block, thread cancel, thread no-args).
This plan uses release branches (not tags) for versioning.
Depends on lua-atmos v0.6 (already released).
Note: env-iup has pending tests (`iup-net.lua`) in lua-atmos.

## Steps

### 1. Run tests

- [x] Automatic tests:

```bash
cd tst && lua5.4 all.lua
```

### 2. Create rockspec `atmos-lang-0.6-1.rockspec`

- [x] Copy from `atmos-lang-0.5-1.rockspec`
- [x] Change `version` to `"0.6-1"`
- [x] Change `branch` to `"v0.6"`
- [x] Change dependency from `atmos ~> 0.5` to `atmos ~> 0.6`
- [x] Keep rockspec description in sync with README "About" section
- [x] Move old rockspec to `old/`
- Install locally (Phase 1):

```bash
sudo luarocks make atmos-lang-0.6-1.rockspec --lua-version=5.4
```

### 3. Test examples (Phase 1 — local install)

- [x] `exs/hello.atm`
- [x] `exs/clicks.atm`
- [x] `exs/click-drag-cancel.atm`
- [x] `exs/rx.atm`
- [x] `exs/rx-behavior.atm`

- Manual tests:
    - [x] README.md
    - [x] doc/guide.md — restructured to match lua-atmos, added section 7.2 (threads)

### 3.1 Adapt pico-* to pico-lua v0.3 (done)

- [x] `exs/clicks.atm` — pico v0.3 API
- [x] `exs/click-drag-cancel.atm` — pico v0.3 API
- [x] `exs/x.atm` — pico v0.3 API
- [x] `pico-birds/birds-01..11.atm` — `zet.window`/`zet.dim`
- [x] `pico-birds/README.md` — install v0.6, checkout v0.6
- [x] `pico-rocks/main.atm` — `zet.window`/`zet.dim`
- [x] `pico-rocks/ts.atm` — `layer.images`/`draw.layer`, `get.view().dim`
- [x] `pico-rocks/README.md` — install v0.6, checkout v0.6

### 3.2 Test pico-* (Phase 1)

- [x] `pico-birds/birds-11.atm`
- [x] `pico-rocks/main.atm`

### 4. Update `README.md` (done)

- [x] Add `v0.6` to version list
- [x] Fix stable link (was `v0.4`) to `v0.6`
- [x] Update `Install & Run` section: `install atmos-lang 0.6`
- [x] Restructure About: 2 main + "also complements" (streams & threads)
- [x] Update Environments: separate repos, add env-js
- [x] Add `[Environments]` to nav bar

### 5. Update `HISTORY.md`

```
v0.6 (mar/26)
-------------

- Additions:
    - `thread` block
    - `thread` cancel
    - `thread` no-args
```

### 6. Commit, push main, create release branch

- [x] Single commit: `release: v0.6`
- [x] Push main, check GitHub Actions for green CI
- [x] Create branch `v0.6`
- [x] Update README links: `main` -> `v0.6`
- [x] Commit and push `v0.6`
- [x] Return to main

### 7. Publish rockspec to LuaRocks

```bash
luarocks upload atmos-lang-0.6-1.rockspec
```

### 8. Verify LuaRocks install + test examples again (Phase 2 — remote)

```bash
sudo luarocks --lua-version=5.4 remove atmos-lang
sudo luarocks --lua-version=5.4 install atmos-lang 0.6
```

- [ ] `exs/hello.atm`
- [ ] `exs/clicks.atm`
- [ ] `exs/click-drag-cancel.atm`
- [ ] `exs/rx.atm`
- [ ] `exs/rx-behavior.atm`

### 9. Announce (manual)

- Twitter / BlueSky
- Mailing list
- Students
