-- LUA_PATH="/x/atmos/src/?.lua;" lua5.4 exec.lua

require "lexer"
require "stmt"
require "tostr"
require "code"
require "exec"

-- CALL

do
    local src = "print(10, nil, false, 2+2)"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()

    local f = assert(io.open("/tmp/anon.lua", "w"))
    f:write(expr_tostr(s.e))
    f:close()

    local exe = assert(io.popen("lua5.4 /tmp/anon.lua", "r"))
    local out = exe:read("a")
    assert(out == "10\tnil\tfalse\t4\n")
end

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
    f:write(stmt_code(s))
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
end
