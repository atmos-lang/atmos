-- LUA_PATH="/x/atmos/src/?.lua;" lua5.4 stmt.lua

require "lexer"
require "stmt"
require "tostr"

-- CALL

do
    local src = "f(x,y)"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(check_tag("eof"))
    assert(xtostring(s) == "{ e={ args={ { tag=var, tk={ lin=1, str=x, tag=var } }, { tag=var, tk={ lin=1, str=y, tag=var } } }, f={ tag=var, tk={ lin=1, str=f, tag=var } }, tag=call }, tag=expr }")
end

-- BLOCK

do
    local src = "do {}"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(xtostring(s) == "{ ss={  }, tag=block }")

    local src = "do :X { f() }"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(check_tag("eof"))
    assert(stmt_tostr(s) == trim [[
        do :X {
        f()
        }
    ]])
end
