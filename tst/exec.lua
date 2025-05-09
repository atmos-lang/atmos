-- LUA_PATH="/x/atmos/src/?.lua;" lua5.4 exec.lua

require "lexer"
require "stmt"
require "tostr"
require "coder"
require "exec"

local match = string.match

-- BLOCK / DO / ESCAPE

do
    local src = [[
        do {
            print(:ok)
        }
    ]]
    print("Testing...", "block 1")
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    local f = assert(io.open("/tmp/anon.lua", "w"))
    f:write(coder_stmt(s))
    f:close()
    local exe = assert(io.popen("lua5.4 /tmp/anon.lua", "r"))
    local out = exe:read("a")
    assert(out == ":ok\n")

    local src = [[
        print(:1)
        print(:2)
    ]]
    print("Testing...", "block 2")
    local out = exec_string("anon.atm", src)
    assert(out == ":1\n:2\n")

    local src = [[
        print(:1)
        do :X {
            print(:2)
            escape(:X)
            print(:3)
        }
        print(:4)
    ]]
    print("Testing...", "block 3")
    local out = exec_string("anon.atm", src)
    assert(out == ":1\n:2\n:4\n")

    local src = [[
        do :X {
            escape(:Y)
        }
    ]]
    print("Testing...", "block 4")
    local out = exec_string("anon.atm", src)
    assert(match(out, "no visible label 'Y' for %<goto%> at line 2"))
end

-- DCL / VAL / VAR / SET

do
    local src = [[
        var x
        set x = 10
        print(x)
    ]]
    print("Testing...", "var 1")
    local out = exec_string("anon.atm", src)
    assert(out == "10\n")

    local src = [[
        val x = :1
        print(x)
    ]]
    print("Testing...", "var 2")
    local out = exec_string("anon.atm", src)
    assert(out == ":1\n")

    local src = [[
        val x
        set x = :1
        print(x)
    ]]
    print("Testing...", "var 2")
    local out = exec_string("anon.atm", src)
    assert(match(out, "attempt to assign to const variable 'x'"))
end

-- CALL / FUNC / RETURN

do
    local src = "print(10, nil, false, 2+2)"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()

    local f = assert(io.open("/tmp/anon.lua", "w"))
    f:write(tostr_expr(s.e))
    f:close()

    local exe = assert(io.popen("lua5.4 /tmp/anon.lua", "r"))
    local out = exe:read("a")
    assert(out == "10\tnil\tfalse\t4\n")

    local src = [[
        val f = func (x, y) {
            return (x + y)
        }
        print(f(10,20))
    ]]
    print("Testing...", "func 1")
    local out = exec_string("anon.atm", src)
    assert(out == "30\n")
end

-- CATCH / THROW

do
    local src = [[
        print(:1)
        catch :X {
            print(:2)
            throw(:X)
            print(:3)
        }
        print(:4)
    ]]
    print("Testing...", "catch 1")
    local out = exec_string("anon.atm", src)
    assert(out == ":1\n:2\n:4\n")

    local src = [[
        print(:1)
        catch :Y {
            print(:2)
            catch :X {
                print(:3)
                throw(:Y)
                print(:4)
            }
            print(:5)
        }
        print(:6)
    ]]
    print("Testing...", "catch 1")
    local out = exec_string("anon.atm", src)
    assert(out == ":1\n:2\n:3\n:6\n")
end
