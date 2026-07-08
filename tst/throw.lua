require "atmos.lang.exec"

-- SPAWN {} (TRANSPARENT) vs RETURN / BREAK / THROW / ESCAPE
-- characterization: see plans/260708-spawn-return.md
--  - pre: escape runs during sync startup (before any await)
--  - pos: escape runs after an await (woken by an emit)
-- all four cross the transparent block and land in the owner
-- WITH their values (structured: resumer frame on pre,
-- 'atm_error' rethrow at the owner's await point on pos); the
-- spawn block has no atm_func wrapper (prim.lua spawn() sub='lua')
-- precisely so that return joins break/throw/escape

do
    -- return / pre: crosses to the owner, T terminates with 10
    -- (":alive" never prints)
    local src = [[
        val T = task () {
            spawn {
                return(10)
            }
            await(:X)
            print(:alive)
        }
        pin t = spawn T()
        emit(:X)
        print((await(t)))
        print(:end)
    ]]
    print("Testing...", "spawn-return pre")
    local out = atm_test(src)
    assertx(out, "10\nend\n")

    -- return / pos: same, at the owner's await point
    local src = [[
        val T = task () {
            spawn {
                await(:go)
                return(10)
            }
            await(:X)
            print(:alive)
        }
        pin t = spawn T()
        emit(:go)
        emit(:X)
        print((await(t)))
        print(:end)
    ]]
    print("Testing...", "spawn-return pos")
    local out = atm_test(src)
    assertx(out, "10\nend\n")

    -- break / pre: owner's loop breaks with the value
    local src = [[
        val T = task () {
            val v = loop {
                spawn {
                    break(10)
                }
                await(false)
            }
            print(v)
        }
        spawn T()
        print(:end)
    ]]
    print("Testing...", "spawn-break pre")
    local out = atm_test(src)
    assertx(out, "10\nend\n")

    -- break / pos: same, at the owner's await point
    local src = [[
        val T = task () {
            val v = loop {
                spawn {
                    await(:go)
                    break(10)
                }
                await(false)
            }
            print(v)
        }
        spawn T()
        emit(:go)
        print(:end)
    ]]
    print("Testing...", "spawn-break pos")
    local out = atm_test(src)
    assertx(out, "10\nend\n")

    -- throw / pre: owner's catch receives tag and value
    local src = [[
        val T = task () {
            val ok, e, v = catch :X {
                spawn {
                    throw(:X, 10)
                }
                await(false)
            }
            print(ok, e, v)
        }
        spawn T()
        print(:end)
    ]]
    print("Testing...", "spawn-throw pre")
    local out = atm_test(src)
    assertx(out, "false\tX\t10\nend\n")

    -- throw / pos: same, at the owner's await point
    local src = [[
        val T = task () {
            val ok, e, v = catch :X {
                spawn {
                    await(:go)
                    throw(:X, 10)
                }
                await(false)
            }
            print(ok, e, v)
        }
        spawn T()
        emit(:go)
        print(:end)
    ]]
    print("Testing...", "spawn-throw pos")
    local out = atm_test(src)
    assertx(out, "false\tX\t10\nend\n")

    -- escape / pre: owner's do :X evaluates to the value
    local src = [[
        val T = task () {
            val v = do :X {
                spawn {
                    escape(:X, 10)
                }
                await(false)
            }
            print(v)
        }
        spawn T()
        print(:end)
    ]]
    print("Testing...", "spawn-escape pre")
    local out = atm_test(src)
    assertx(out, "10\nend\n")

    -- escape / pos: same, at the owner's await point
    local src = [[
        val T = task () {
            val v = do :X {
                spawn {
                    await(:go)
                    escape(:X, 10)
                }
                await(false)
            }
            print(v)
        }
        spawn T()
        emit(:go)
        print(:end)
    ]]
    print("Testing...", "spawn-escape pos")
    local out = atm_test(src)
    assertx(out, "10\nend\n")
end
