# Plan: `await :any/:all ts` as pure broadcast event

# Problem

- old: death stored in `ts.ret`, awaiter consumed it (`ts.ret = nil`)
    - first awaiter stole the death: others never awoke
    - `/tmp/y.atm`: only "A" saw deaths, "B" starved
- root: instant pre-yield wake on persistent pool state

# Semantics (settled)

- pool termination = broadcast event
    - all awaiters awake on each death
    - `:all` only on the death that empties the pool
- no buffering: only observable while awaiting
- empty pool blocks (user checks `#ts` if needed)

# Changes

## lua-atmos:atmos/run.lua

- `task_result`: drop `ts.ret` buffer, keep up-redirect
- `M.await` entry: validate `mode` once
- pre-yield: remove `ts.ret` polling branch
- post-yield: match dead-task event
    - `emt` is xtask and `emt._.up == ts`
    - `mode=='any'` or no live member left
        - raw `dns` scan, not `#ts == 0`
        - gc-pruning lags the death event (`ing` held)

## tests

- lua-atmos:tst/tasks.lua
    - "pools :any broadcast to all awaiters"
    - "pools :any late awaiter -> misses past death"
    - reworded stale `ts.ret`/consume comments
- atmos-lang:tst/exec.lua
    - "await :any ts consume" (wake once per death)
    - "await :any ts broadcast"
    - "await :any ts late"

## docs

- lua-atmos:api.md: `:all` result `v,t,ts`; broadcast note
- atmos-lang:doc/manual.md: same two changes
- both HISTORY.md v0.8: broadcast/no-buffer entries

# Status -- COMPLETE

- [x] runtime rewrite (user-reviewed)
- [x] `:all` fix: live-member scan (gc lags death event)
- [x] tests added/updated in both repos
- [x] docs + HISTORY in both repos (user-reworded)
- [x] both suites green (user-verified)
- move to `done/`
