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
            every :A || :B {
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
end
