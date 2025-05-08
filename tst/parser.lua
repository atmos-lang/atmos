-- LUA_PATH="/x/atmos/src/?.lua;" lua5.4 parser.lua

require "lexer"
require "parser"
require "tocode"

local match = string.match

-- EXPR PRIM

do
    local src = " a "
    print("Testing...", src)
    local tks = lexer_string(src)
    parser_lexer(tks)
    local e = parser_expr()
    assert(xtostring(e) == "{ tag=var, tk={ str=a, tag=var } }")
    assert(check_tag("eof"))

    local src = "1.5"
    print("Testing...", src)
    local tks = lexer_string(src)
    parser_lexer(tks)
    local e = parser_expr()
    assert(xtostring(e) == "{ tag=num, tk={ str=1.5, tag=num } }")
    assert(check_tag("eof"))

    local src = "{"
    print("Testing...", src)
    local tks = lexer_string(src)
    parser_lexer(tks)
    local ok, err = pcall(parser_expr)
    assert(not ok and match(err, "expected expression : have {$"))

    local src = ""
    print("Testing...", "eof")
    local tks = lexer_string(src)
    parser_lexer(tks)
    local ok, err = pcall(parser_expr)
    assert(not ok and match(err, "expected expression : have <eof>$"))

    local src = [[

    ]]
    print("Testing...", "blanks")
    local tks = lexer_string(src)
    parser_lexer(tks)
    local ok, err = pcall(parser_expr)
    assert(not ok and match(err, "expected expression : have <eof>$"))

    local src = " ( a ) "
    print("Testing...", src)
    local tks = lexer_string(src)
    parser_lexer(tks)
    local e = parser_expr()
    assert(xtostring(e) == "{ tag=var, tk={ str=a, tag=var } }")
    assert(check_tag("eof"))

    local src = " ( a "
    print("Testing...", src)
    local tks = lexer_string(src)
    parser_lexer(tks)
    local ok, err = pcall(parser_expr)
    assert(not ok and match(err, "expected '%)' : have <eof>$"))

    local src = "nil"
    print("Testing...", src)
    local tks = lexer_string(src)
    parser_lexer(tks)
    local e = parser_expr()
    assert(xtostring(e) == "{ tag=nil, tk={ str=nil, tag=key } }")
    assert(check_tag("eof"))

    local src = "false true"
    print("Testing...", src)
    local tks = lexer_string(src)
    parser_lexer(tks)
    local e1 = parser_expr()
    assert(xtostring(e1) == "{ tag=bool, tk={ str=false, tag=key } }")
    local e2 = parser_expr()
    assert(xtostring(e2) == "{ tag=bool, tk={ str=true, tag=key } }")
    assert(check_tag("eof"))

end

-- EXPR BIN

do
    local src = "a + 10"
    print("Testing...", src)
    local tks = lexer_string(src)
    parser_lexer(tks)
    local e = parser_expr()
    assert(xtostring(e) == "{ e1={ tag=var, tk={ str=a, tag=var } }, e2={ tag=num, tk={ str=10, tag=num } }, op={ str=+, tag=op }, tag=bin }")
    assert(check_tag("eof"))

    local src = "2 + 3 - 1"
    print("Testing...", src)
    local tks = lexer_string(src)
    parser_lexer(tks)
    local ok, err = pcall(parser_expr)
    assert(not ok and match(err, "binary operation error : use parentheses to disambiguate$"))

    local src = "2 * (a - 1)"
    print("Testing...", src)
    local tks = lexer_string(src)
    parser_lexer(tks)
    local e = parser_expr()
    assert(expr_tocode(e) == "(2 * (a - 1))")
    assert(check_tag("eof"))
end

--xdump(parser_expr())
