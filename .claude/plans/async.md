# Plan: `async` primitive

## GitHub Issue
https://github.com/atmos-lang/atmos/issues/28

## Context

Add cooperative CPU-bound computation to Atmos, inspired by Céu's
async blocks. Uses Lua 5.4 debug instruction hooks for transparent
yielding, preserving determinism (unlike `thread` which uses OS
threads).

## Semantics

- `async { block }` — CPU-bound block with transparent yielding
- `debug.sethook(co, hook, "", 10000)` yields every 10k instructions
- Hook calls `await(true)` to yield; resumes on next step/emit
- Returns last expression value (like `thread`)
- Always awaited — caller blocks until async completes
- Structured concurrency — follows parent scope lifecycle
- **No sync inside** — await/emit/spawn etc. produce runtime error
- Uses upvalues — no explicit variable list needed
- Hooks are per-coroutine — no interference with other tasks

## Changes

### 1. `src/global.lua:23` — Add `'async'` to KEYS
### 2. `src/prim.lua:703` — Parse `async { block }`
### 3. `src/run.lua` — Add `atm_async(f)` runtime function
### 4. `tst/async.lua` — Tests (parser, codegen, exec)
### 5. `tst/all.lua` — Register test
### 6. `doc/manual.md` — Documentation

## Progress
- [ ] Step 1: global.lua keyword
- [ ] Step 2: prim.lua parser
- [ ] Step 3: run.lua runtime
- [ ] Step 4: tst/async.lua tests
- [ ] Step 5: tst/all.lua registration
- [ ] Step 6: doc/manual.md documentation
