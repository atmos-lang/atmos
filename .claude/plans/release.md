# Plan: Release v0.6

## Context

Atmos-lang v0.5 is the current stable release.
For v0.6, the main new feature is `thread` support
(thread block, thread cancel, thread no-args).
This plan uses release branches (not tags) for versioning.
Depends on lua-atmos v0.6 (already released).
Note: env-iup has pending tests (`iup-net.lua`) in lua-atmos.

## Steps

### 1. Run tests (done)

```bash
cd tst && lua5.4 all.lua
```

### 2. Create rockspec `atmos-lang-0.6-1.rockspec`

- Copy from `atmos-lang-0.5-1.rockspec`
- Change `version` to `"0.6-1"`
- Change `branch` to `"v0.6"`
- Change dependency from `atmos ~> 0.5` to `atmos ~> 0.6`
- Keep rockspec description in sync with README "About" section
- Move old rockspec to `old/`
- Install locally (Phase 1):

```bash
sudo luarocks make atmos-lang-0.6-1.rockspec --lua-version=5.4
```

### 3. Test examples (Phase 1 — local install)

- [ ] `exs/hello.atm`
- [ ] `exs/clicks.atm`
- [ ] `exs/click-drag-cancel.atm`
- [ ] `exs/rx.atm`
- [ ] `exs/rx-behavior.atm`

### 4. Update `README.md`

- Add `v0.6` to version list
- Update stable link from `v0.5` to `v0.6`
- Update `Install & Run` section: `install atmos-lang 0.6`

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

- [ ] Single commit: `release: v0.6`
- [ ] Push main, check GitHub Actions for green CI
- [ ] Create branch `v0.6`
- [ ] Update README links: `main` -> `v0.6`
- [ ] Commit and push `v0.6`
- [ ] Return to main

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
