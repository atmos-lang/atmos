-- LUA_PATH="/x/atmos/src/?.lua;" lua5.4 exec.lua

require "lexer"
require "stmt"
require "tocode"

-- STMT CALL

do
    local src = "print(10, nil, false, 2+2)"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()

    local f = assert(io.open("/tmp/anon.lua", "w"))
    f:write(expr_tocode(s.e))
    f:close()

    local exe = assert(io.popen("lua5.4 /tmp/anon.lua", "r"))
    local out = exe:read("a")
    assert(out == "10\tnil\tfalse\t4\n")
end
