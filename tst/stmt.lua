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
    assert(check("<eof>"))
    assert(xtostring(s) == "{ e={ args={ { tag=var, tk={ lin=1, str=x, tag=var } }, { tag=var, tk={ lin=1, str=y, tag=var } } }, f={ tag=var, tk={ lin=1, str=f, tag=var } }, tag=call }, tag=expr }")
end

-- BLOCK / DO / DEFER

do
    local src = "do {}"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(xtostring(s) == "{ ss={  }, tag=block }")

    local src = "do { var x }"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(tostr_stmt(s) == trim [[
        do {
            var x
        }
    ]])

    local src = "do :X { escape(:X) }"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(check("<eof>"))
    assert(tostr_stmt(s) == trim [[
        do :X {
            escape(:X)
        }
    ]])

    local src = "defer { var x ; f(1) }"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(check("<eof>"))
    assert(tostr_stmt(s) == trim [[
        defer {
            var x
            f(1)
        }
    ]])
end

-- DCL / VAL / VAR / SET

do
    local src = "val x"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(xtostring(s) == "{ id={ lin=1, str=x, tag=var }, tag=dcl, tk={ lin=1, str=val, tag=key } }")

    local src = "set y = 10"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(check("<eof>"))
    assert(xtostring(s) == "{ dst={ tag=var, tk={ lin=1, str=y, tag=var } }, src={ tag=num, tk={ lin=1, str=10, tag=num } }, tag=set }")

    local src = "var y = 10"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(check("<eof>"))
    assert(xtostring(s) == "{ id={ lin=1, str=y, tag=var }, set={ tag=num, tk={ lin=1, str=10, tag=num } }, tag=dcl, tk={ lin=1, str=var, tag=key } }")
end

-- THROW / CATCH

do
    local src = "throw(:X)"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(xtostring(s) == "{ e={ tag=tag, tk={ lin=1, str=:X, tag=tag } }, tag=throw }")

    local src = "catch :X { }"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(check("<eof>"))
    assert(xtostring(s) == "{ blk={ ss={  }, tag=block }, esc={ lin=1, str=:X, tag=tag }, tag=catch }")
end
