# Plan: emit-target counts transparent tasks (target-bug)

## Status

- [x] Diagnose root cause
- [x] Add failing test here (`tst/tasks.lua`)
- [x] Apply runtime fix in lua-atmos (`fto`) — see runtime plan
- [x] Confirm failing test turns green (all tests pass)

## Summary

`emit @N :tag` (numeric target = N task levels up) must be
*identity-based*:
it should skip transparent tasks, the same way task identity (`me`)
already does.
Today it counts transparent tasks, so the level needed depends on
whether an intermediate body was written as `spawn {}` or `do {}`.

This compiler repo holds only the failing test.
The actual fix lives in the runtime repo `lua-atmos`.

## Repro

```
task Inner () {
    await :go
    emit @1 :h1
    emit @2 :h2
    emit @3 :h3
}
task Mid () {
    spawn {
        await Inner()
    }
    await(false)
}
spawn Mid()
par:any {
    await :h1  print("@1")
} with {
    await :h2  print("@2 expected")
} with {
    await :h3  print("@3 buggy")
} with {
    emit :go
}
```

- With `spawn {}` : prints `@3` (one level too far).
- With `do {}`    : prints `@2` (correct).

## Root cause

`emit @N` lowers to `emit_in(N, tag)`, which calls `fto` in the
runtime (`/x/lua-atmos/atmos/atmos/run.lua`).

The `tra` (transparent) flag is honored in exactly one place, `_me_`,
which picks the *start* task.
The upward climb in `fto` ignores it:

```lua
to = me or TASKS        -- _me_ already skipped transparent here
while n > 0 do
    to = to._.up        -- plain hop : no `_.tra` check
    n = n - 1
end
```

For `emit @2` from `Inner`:

| step  | task      | tra?  | counted?            |
|-------|-----------|-------|---------------------|
| start | Inner     | false | (anchor)            |
| n -> 1| SpawnBlk  | true  | yes (should skip)   |
| n -> 0| Mid       | false | yes                 |

`spawn {}` is transparent (`do_spawn` -> `run.spawn(..., tra=true)`),
same flag as a `par` branch, yet `fto` still counts it.

Asymmetry, confirmed empirically:

- Emitting *from inside* the transparent block: `@1` reaches the top
  (start anchor skips the block).
- Emitting *through* the same block from a real child: the block costs
  a level.

## Decision

Targeting is *identity-based*: transparent tasks (and pools) are
invisible to `@N`.
Fix `fto` to skip them at every hop, mirroring `_me_`.

## Failing test (here)

Added at the end of `tst/tasks.lua`
(label `emit target : transparent spawn-block`):

```
task Inner () {
    await :go
    emit @2 :h
}
task Mid () {
    spawn {
        await Inner()
    }
    await(false)
}
spawn Mid()
par:any {
    await :h
    print("ok")
} with {
    emit :go
}
```

- Expected (fixed): `"ok\n"`.
- Current  (buggy): `""` (par ends on the emit branch; `@2` lands on
  `Mid`, never reaches the top `par`).

Stays red until the `fto` fix lands in lua-atmos.

## Pending

- Runtime fix in `lua-atmos` plan `260628-target-bug.md`.
