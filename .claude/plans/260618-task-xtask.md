# Compiler: `task` keyword + `xtask` (atmos-lang side)

Companion to the lua-atmos runtime work (DONE/GREEN at
`/x/lua-atmos/atmos`, branch `260616-task-xtask`). Covers §3 "Compiler"
of that runtime plan, adapted to the CURRENT runtime API.

## Status: IN PROGRESS

Source compiler changes are DONE and locally verified. Remaining work
is the TEST SWEEP + `atm_behavior` + docs/rockspec. See RESUME HERE.

-------------------------------------------------------------------------------

## RESUME HERE -- NEXT STEPS (ordered, explicit)

### 0. Environment (do this first on the new machine)

- Sibling checkout required: `../lua-atmos` on branch
  `260616-task-xtask` (or wherever the new runtime lives).
- REQUIRED runtime edit (OUTSIDE this worktree, may already be applied
  on the old machine -- RE-CHECK on the new one):
  `lua-atmos/atmos/run.lua:184` trace label must emit `'task'` not
  `'xtask'` (see "Decision: trace label" below). If missing,
  `tst/exec.lua` "defer 4" etc. fail.
- Run the suite:
      cd tst && LUA_PATH="../f-streams/?/init.lua;../lua-atmos/?.lua;../lua-atmos/?/init.lua;;" lua5.4 all.lua
- One-off compile/tosource check (used to regenerate AST dumps without
  the full suite), run from `src/`:
      LUA_PATH="../../../lua-atmos/atmos/?.lua;../../../lua-atmos/atmos/?/init.lua;;" lua5.4 -e '
        package.path="./?.lua;"..package.path
        atmos=require"atmos"; require"atmos.lang.exec"; require"atmos.lang.tosource"
        local X=require"atmos.x"
        local s="task T(a){ a }"
        init(); lexer_init("anon",s); lexer_next(); local e=parser()
        print(atm_to_lua("anon",s)); print(tosource(e)); print(X.tostring(e))'

### 1. Finish the `tst/exec.lua` sweep (was failing at "task 1")

Run the suite; it stops at the first stale test. Known cluster
(line numbers approximate -- grep the test name string):

- "task 1" (~exec.lua:1625): currently
      val T = func (a) { print(a); val b = await(:X); print(b) }
      pin t = task(T)        ;; FAILS: pins a non-closable prototype
      spawn t(10)
  Rewrite (declare a prototype, pre-build an instance, then start it):
      task T (a) { print(a); val b = await(:X); print(b) }
      pin t = xtask(T)       ;; instance is closable -> pin ok
      spawn t(10)            ;; emits spawn(t, 10)
- "task 2" (~exec.lua:1639): `val T = func(a){…}` + `spawn T(10)`
  -> `task T (a) {…}` + `spawn T(10)`.
- "emit 2" (~exec.lua:1729): `val tk = func(v){…}` + `spawn tk()`
  -> `task tk (v) {…}` + `spawn tk()`.
- Keep going until exec.lua is GREEN. Any `spawn <rawfunc>` or bare
  `task(fn)` call is now illegal; convert the source to a `task`
  declaration (proto) and/or `xtask(proto)` (instance).

Rule of thumb:
  - `task(fn)` (make proto from fn)      -> `task NAME(){body}` decl
  - `task(proto)` / make-instance        -> `xtask(proto)`
  - `spawn rawfn`                         -> declare proto + `spawn PROTO`

### 2. Fix `tst/expr.lua` `task(T)` parse test

`task` is now a keyword, so `task(T)` no longer parses as a call.
Grep `task(T)` in expr.lua (parse/tosource test, ~line 1235 area, near
the "coro(f)" / "tasks(10)" tests). Change surface+expected to
`xtask(T)` (a plain call -> tosource `xtask(T)`). Verify `tasks(10)`
still parses (tasks special-cased in val/var/pin and as call).

### 3. Bulk sweep `tst/tasks.lua` (the big one)

- `func T` protos that get spawned          -> `task T`.
- `task(T)` instances                        -> `xtask(T)`.
- `?? :task` checks on a RUNNING instance    -> `?? :xtask`
  (leave `:task` only where a prototype value is meant).
- raw-func spawn (`spawn(func(){…})`, e.g. "spawn 3" ~tasks.lua:153,
  and the `spawn(func()…)` cluster) is now REJECTED by the runtime
  ("invalid spawn : expected task prototype"). Either wrap the proto
  (`spawn(task(func(){…}))`) where the test should pass, or convert to
  a NEGATIVE test asserting the error.
- ADD negative tests:
    - `T()` direct-call of a prototype fails.
    - `spawn F()` / `await F()` of a plain func fails.
    - `xtask(p)` where `p` is not a prototype fails.
      RUNTIME DEPENDENCY (blocks this test): surface `xtask(rawfunc)`
      currently SUCCEEDS because `M.xtask` (lua-atmos run.lua:405) falls
      back to `or T` for any function. That fallback is only meant for
      the internal transparent-spawn path (`tra=true`). Runtime must gate
      it to that path:
          local f = (getmetatable(T)==meta_task and T._.f) or (tra and T)
      Until applied, a negative test for `xtask(\{})` stays RED. The
      negative test "is 3b" is in `tst/x.lua` right after "is 3" but its
      `assertx` is COMMENTED OUT (`--[=[ ... ]=]`) so the suite is green.
      TODO: once the runtime gate above lands, UNCOMMENT the "is 3b"
      `assertx` block in `tst/x.lua` and confirm it passes.
- Also re-check `exs/*.atm` for raw `spawn func`/`task(`/`:task`.

### Open runtime question: task-term `pin t =` double-pin

`tst/tasks.lua` "task-term 1/2/3" (former `spawn (\{}) ()` lambda-
spawns, now `spawn (task(){}) ()`) emit a trailing
`invalid assignment : expected unpinned value` at the `pin t = spawn
(...) ()` line. NOT a simple root-spawn auto-pin: verified that
  pin t = spawn T()            -- at root, ALONE -> CLEAN
  val t = spawn T()            -- at root -> "expected pinned value"
so a lone root spawn leaves the instance UNPINNED (pin pins it, val
fails). The double-pin error appears ONLY in the two-spawn structure
(a preceding awaiting `spawn { pin e = await(true) ... }` block, THEN
`pin t = spawn (...) ()`): there `atm_pin_chk_set(pin=true)` sees
`t.pin` already true. Exact mechanism (why the prior block leaves the
later instance pre-pinned) is UNCLEAR -- needs runtime investigation.

Tests still PASS (assertfx = `string.find`, finds `ok\txtask: 0x`
before the trailing error), so nothing is broken -- latent question,
not a failure. Confirm alongside the `xtask` gate above. Left as `pin`
for now (not masked with `val`).

### 4. `src/aux.lua` `atm_behavior` -- DONE

The local `T` (behavior task body) is a raw function; new `spawn_in`
needs a task PROTOTYPE. Fixed by blessing once per call before the
loop:
    function atm_behavior (id, tsks, tab, ss)
        local Tp = task(T)
        for k,s in pairs(ss) do spawn_in(tsks, Tp, id, tab, k, s) end
    end
Blessed at CALL time (not module level) so the runtime `task` global
is guaranteed available. Verified: streams.lua "beh 3" (table behavior
`pin x* = [s1, s2]`) emits `x.1/x.2` correctly. The tosource test
"pin x* = 10" expected `spawn(true,{...})` -> updated to `do_spawn({...})`.
(NOTE: the non-table behavior path in prim.lua already emits
`do_spawn` via the `spawn` helper -- no proto needed there.)

### 5. `doc/manual.md` (NEVER manual-out.md)

- keyword lists: add `task`; drop `task` from the reserved comment.
- value/ref type lists: add `xtask`.
- Task chapter: split prototype (`task`) vs instance (`xtask`);
  show `task T(){}`, `spawn T()`, `pin t = xtask(T)`, `t ?? :xtask`.

### 6. `*.rockspec` -- bump the lua-atmos dependency to the new major.

### 7. Resolve open questions (parser-level)

1. `::` method form for `task` -- REJECTED (helper gates `::` to
   `sub=='func'`). Done.
2. Anonymous `task (...) { ... }` expression -- INCLUDED. Done.
3. `pin task T()` -- reject in parser? (protos are not pinnable).
   STILL OPEN -- decide and, if rejecting, add the check + a test.
4. `toggle T()` on a prototype vs instances only -- lean instances.
   STILL OPEN.
5. Task proto DECL (the `val/var/pin task NAME` decl form, NOT the
   `set NAME = task ...` form) should REQUIRE `NAME` to begin with an
   uppercase letter. Add the parser check + a negative test.
   STILL OPEN.

### Known limitation: no surface bless `task(f) -> :task`

You CANNOT turn an existing function value `f` into a task prototype
at surface level. `task` is a keyword, so `task(f)` reads `(f)` as the
anonymous-proto PARAM LIST and then demands a `{ body }` (`task(f)`
alone -> "expected '{'"). It is ambiguous with `task (a,b) { ... }`
and `task(f){...}` (a proto whose single param is `f`) -- there is no
syntactic room to also mean "bless f". Symmetric note: once the
`xtask` runtime gate lands (see §3), `xtask(f)` from a raw func also
fails, so NEITHER proto-from-func nor instance-from-func is surface-
expressible. This is intentional: task-ness is DECLARED, never
retrofitted onto a plain `func`.

Escapes / non-issues:
- rare bless-an-existing-function: native ``\`task(f)\``` (calls the
  runtime constructor directly -- verified works).
- compiler-internal blessing (e.g. `atm_behavior`, §4) just emits Lua
  `task(fn)` directly -- no surface form needed.
- if ever wanted at surface, it must be a DISTINCT non-keyword builtin
  (e.g. `proto(f)`), not a reuse of `task(...)`. Likely unwarranted.

-------------------------------------------------------------------------------

## DONE (history)

### Sidetrack: `every` -> `loop_on` emission

Runtime renamed `M.every` -> `M.loop_on`. The surface keyword was
already `loop on`; only the emitted name was stale.

| file                      | change                          |
|---------------------------|---------------------------------|
| src/prim.lua              | `loop on` desugar emits `loop_on` |
| tst/stmt.lua              | 5 tosource asserts `every(`->`loop_on(` |
| exs/{hello,rx-behavior,clicks,click-drag-cancel}.atm | `every` -> `loop on` |

### Decision: error traces label instances `task`, not `xtask`

`trace()` frame label is a human string only; identity is the
metatable. Users write `task`/`spawn`, never `xtask`, so traces echo
their vocabulary. Pool frames read `tasks`. APPLIED in runtime
`run.lua:184` (`'xtask'`->`'task'`); atmos-lang keeps `(task)` in
tst/exec.lua expectations -- NO change here.

### Spawn emission (src/prim.lua)

- block `spawn {}`        -> `do_spawn(fn)` (via the `spawn` helper).
- `spawn T()`            -> `spawn(T, …)` (dropped the `false`).
- `spawn @ts T()`        -> `spawn_in(ts, T, …)` (unchanged).
- pin-wrap triggers unless `spawn_in` (wraps `do_spawn` too, for its
  `<close>` handle).
- transparent-reject (`val x = spawn {}`) detects `f.str=='do_spawn'`.
- `await T()` already emitted `spawn(T,…)` -- unchanged.
- src/run.lua:5 `atm_pin_chk_set`: `X.is(t,'task')` -> `'xtask'`.
- tst/{stmt,expr}.lua tosource: dropped `false` from `spawn(false,T…)`;
  `spawn(true,{})` -> `do_spawn({})`.

### `task` keyword

- global.lua: `'task'` moved into KEYS.
- Surface model: `task` is DECL-ONLY; instance-from-proto is the plain
  call `xtask(T)` (xtask stays a non-keyword id). Old surface
  `task(fn)` call form is GONE.

### AST refactor: `tag='proto'`, `sub='lua'|'func'|'task'`

Rationale: a function literal IS a prototype (Lua compiles each body to
a `Proto`; closures wrap it). The three kinds are mutually exclusive,
so ONE discriminator `sub` replaces both the old `lua=true` and the
interim `task=true` flags.

- prim.lua: `parser_proto(sub, dcl)` unifies func/task across all 3
  locations (anon expr, named `set`, val/var/pin `dcl`); `::` gated to
  `sub=='func'`. 4 decl call sites -> one-liners.
- coder.lua: SOLE reader -- `sub=='lua'`->raw `(function…)`; else
  `atm_func(…)`, then `task(…)` when `sub=='task'`.
- tosource.lua / await.lua / parser.lua: `tag=='func'`->`'proto'`;
  tosource keyword via `sub=='task'`.
- tst/stmt.lua (5 AST dumps) + tst/thread.lua tag check regenerated.

Verified by compiling snippets: `sub` drives raw / atm_func / task
wrapping; tosource round-trips `func`/`task`; dumps match parser.

-------------------------------------------------------------------------------

## Reference

### Runtime vocabulary

| concept              | runtime name | notes                           |
|----------------------|--------------|---------------------------------|
| prototype (abstract) | `task`       | non-callable tagged value       |
| instance (executing) | `xtask`      | `xtask()` = me, `xtask(T)` = new |
| pool                 | `tasks`      | unchanged                       |
| spawn proto/instance | `spawn`      | `spawn(t, …)`; t : task|xtask    |
| spawn anon block     | `do_spawn`   | transparent; returns close handle |
| spawn into pool      | `spawn_in`   | `spawn_in(tsks, t, …)`; t : task |
| event loop           | `loop_on`    | (was `every`)                   |

`_is_`: prototype `'task'`, instance `'xtask'`, pool `'tasks'`.
Type checks use TAGS (`x ?? :xtask`), not the bare keyword -- so
`task` being a keyword does NOT affect `??`/`match`. Runtime is native:
NO `spawn`/`task` shadowing, NO `atm_is` remap in src/aux.lua.

### Desugaring

```
task T (...) { ... }       -->  T = task(atm_func(function (...) ... end))
val task T (...) { ... }   -->  local T = task(atm_func(function (...) ... end))
spawn T(a)                 -->  pin _ = spawn(T, a)
pin t = xtask(T)           -->  local t <close> = atm_pin_chk_set(true,true, xtask(T))
spawn {}                   -->  pin _ = do_spawn(function () ... end)
```

`xtask` is a plain runtime identifier and a plain tag (already lexable).

## Notes

- Rollout: runtime first (DONE), then this compiler work, then
  f-streams audit of `spawn_in` call sites reached from streams.
