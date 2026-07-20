local X = require "atmos.x"
require "atmos.lang.exec"

do
    local src = [[
        spawn {
            await(:X || :Y)
            print(:ok)
        }
        print(:antes)
        emit(:Y)
        print(:depois)
    ]]
    print("Testing...", "op_or 1")
    local out = atm_test(src)
    assertx(out, "antes\nok\ndepois\n")

    local src = [[
        spawn {
            await(:X && :Y)
            print(:ok)
        }
        emit(:X)
        emit(:X)
        print(:antes)
        emit(:Y)
        print(:depois)
    ]]
    print("Testing...", "op_and 1")
    local out = atm_test(src)
    assertx(out, "antes\nok\ndepois\n")

    local src = [[
        spawn {
            await((:X || :Y) && :Z)
            print(:ok)
        }
        print(:antes)
        emit(:X)
        emit(:Z)
        print(:depois)
    ]]
    print("Testing...", "op_nested 1")
    local out = atm_test(src)
    assertx(out, "antes\nok\ndepois\n")

    local src = [[
        spawn {
            await(!:X && :Y)
            print(:ok)
        }
        print(:antes)
        emit(:Y)
        print(:depois)
    ]]
    print("Testing...", "op_not 1")
    local out = atm_test(src)
    assertx(out, "antes\nok\ndepois\n")

    local src = [[
        spawn {
            watching :X || :Y {
                await(:Z)
                print(:no)
            }
            print(:ok)
        }
        print(:antes)
        emit(:Y)
        print(:depois)
    ]]
    print("Testing...", "op_watching 1")
    local out = atm_test(src)
    assertx(out, "antes\nok\ndepois\n")

    local src = [[
        spawn {
            loop on :A || :B {
                print(:tick)
            }
        }
        emit(:A)
        emit(:B)
        emit(:A)
    ]]
    print("Testing...", "op_every 1")
    local out = atm_test(src)
    assertx(out, "tick\ntick\ntick\n")

    local src = [[
        spawn {
            await(:X || 5ms)
            print(:ok)
        }
        emit(5ms)
    ]]
    print("Testing...", "op_clock_or 1")
    local out = atm_test(src)
    assertx(out, "ok\n")

    local src = [[
        spawn {
            val a = 10
            await(:X until a || 20)
            print(:ok)
        }
        emit :X [10]
    ]]
    print("Testing...", "op_payload_or 1")
    local out = atm_test(src)
    assertx(out, "ok\n")

    local src = [[
        spawn { await(:X || :Y && :Z) }
    ]]
    print("Testing...", "op_mixed_err 1")
    local out = atm_test(src)
    assertx(out, "anon.atm : line 1 : near '&&' : operation error : use parentheses to disambiguate")

    local src = [[
        spawn {
            par :any { await(:X || :Y) } with { await(:Z) }
            print(:ok)
        }
        emit(:Y)
    ]]
    print("Testing...", "op_par :any 1")
    local out = atm_test(src)
    assertx(out, "ok\n")

    local src = [[
        spawn {
            await((!:X) || :Y)
            print(:2)
        }
        emit(:X)
        print :1
        emit(:Y)
    ]]
    print("Testing...", "op_nested_not 1")
    local out = atm_test(src)
    assertx(out, "1\n2\n")
end

-- AWAIT-PATTERN TASK PROMOTION (Option B) -- SPEC, pending implementation
--
-- Promote `T(...)` to a spawn-and-await pattern in every pattern position
-- (bare `await`, `await(PAT)`, `watching`, `loop on`, toggle filters), so a
-- task composes with combinators like an event. The value escape is
-- grouping parens around the call: `await((g()))` awaits g()'s returned
-- value. See plan: .claude/plans/260713-await-patt-task.md

do
    -- regression anchor: bare `await T()` already spawns via runtime sugar
    local src = [[
        task T (v) {
            v * 2
        }
        spawn {
            val x = await T(10)
            print(x)
        }
    ]]
    print("Testing...", "task_promote solo 1")
    local out = atm_test(src)
    assertx(out, "20\n")

    -- SPEC: `watching T() || :X` -- event wins, T aborted silently
    local src = [[
        task T () {
            await(:done)
        }
        spawn {
            watching T() || :X {
                await(:never)
            }
            print(:ok)
        }
        emit(:X)
    ]]
    print("Testing...", "task_promote watching_event 1")
    local out = atm_test(src)
    assertx(out, "ok\n")

    -- SPEC: `watching T() || :X` -- task termination wins
    local src = [[
        task T () {
            await(:done)
            print(:T)
        }
        spawn {
            watching T() || :X {
                await(:never)
            }
            print(:ok)
        }
        emit(:done)
    ]]
    print("Testing...", "task_promote watching_task 1")
    local out = atm_test(src)
    assertx(out, "T\nok\n")

    -- SPEC: `loop on T()` respawns T each iteration
    local src = [[
        task T () {
            await(:step)
        }
        spawn {
            loop on T() {
                print(:tick)
            }
        }
        emit(:step)
        emit(:step)
    ]]
    print("Testing...", "task_promote loop_on 1")
    local out = atm_test(src)
    assertx(out, "tick\ntick\n")

    -- value escape (hazard-b): grouping parens around the call keep
    -- value-await -- `await((g()))` calls g and awaits its result
    local src = [[
        func g () {
            :X
        }
        spawn {
            await((g()))
            print(:ok)
        }
        emit(:X)
    ]]
    print("Testing...", "task_promote paren_value 1")
    local out = atm_test(src)
    assertx(out, "ok\n")

    -- behavior-change guard: promoted non-task callee errors at spawn
    local src = [[
        func g () { }
        spawn {
            watching g() {
                await(:X)
            }
        }
    ]]
    print("Testing...", "task_promote nontask_err 1")
    local out = atm_test(src)
    assertfx(out, "invalid spawn : expected task prototype")
end
