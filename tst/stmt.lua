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

    local src = "do :X { escape(:X) }"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(check_tag("eof"))
    assert(tostr_stmt(s) == trim [[
        do :X {
        escape(:X)
        }
    ]])
end

-- DCL / VAL / VAR

do
    local src = "val x"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(xtostring(s) == "{ e={ tag=tag, tk={ hier={ X }, lin=1, str=:X, tag=tag } }, tag=throw }")

    local src = "var y = 10"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(check_tag("eof"))
    assert(xtostring(s) == "{ blk={ ss={  }, tag=block }, esc={ hier={ X }, lin=1, str=:X, tag=tag }, tag=catch }")
end

-- THROW / CATCH

do
    local src = "throw(:X)"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(xtostring(s) == "{ e={ tag=tag, tk={ hier={ X }, lin=1, str=:X, tag=tag } }, tag=throw }")

    local src = "catch :X { }"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(check_tag("eof"))
    assert(xtostring(s) == "{ blk={ ss={  }, tag=block }, esc={ hier={ X }, lin=1, str=:X, tag=tag }, tag=catch }")
end
