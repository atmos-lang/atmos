local X = require "atmos.x"
require "atmos.lang.exec"

-- AWAIT COMBINATOR OPERATORS: &&  ||  !
--
-- Combinator operators inside `await` require the parenthesized form
-- `await(...)`. The bare form `await :X || :Y` is a user logic error:
-- it compiles as `(await :X) || :Y` (logical OR on the await result).
-- Not enforced -- documented as a rule.

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
            await(:X || @.5)
            print(:ok)
        }
        emit(@.5)
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
        emit :X @{10}
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
            par_or { await(:X || :Y) } with { await(:Z) }
            print(:ok)
        }
        emit(:Y)
    ]]
    print("Testing...", "op_par_or 1")
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
