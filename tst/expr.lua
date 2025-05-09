-- LUA_PATH="/x/atmos/src/?.lua;" lua5.4 expr.lua

require "lexer"
require "expr"
require "tocode"

local match = string.match

-- EXPR PRIM

do
    local src = " a "
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(xtostring(e) == "{ tag=var, tk={ str=a, tag=var } }")
    assert(check_tag("eof"))

    local src = "1.5"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(xtostring(e) == "{ tag=num, tk={ str=1.5, tag=num } }")
    assert(check_tag("eof"))

    local src = "{"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local ok, msg = catch(parser_expr)
    assert(not ok and msg=="anon : expected expression : have {")

    local src = ""
    print("Testing...", "eof")
    lexer_string("anon", src)
    parser()
    local ok, msg = catch(parser_expr)
    assert(not ok and msg=="anon : expected expression : have <eof>")

    local src = [[

    ]]
    print("Testing...", "blanks")
    lexer_string("anon", src)
    parser()
    local ok, msg = catch(parser_expr)
    assert(not ok and msg=="anon : expected expression : have <eof>")

    local src = " ( a ) "
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(xtostring(e) == "{ tag=var, tk={ str=a, tag=var } }")
    assert(check_tag("eof"))

    local src = " ( a "
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local ok, msg = catch(parser_expr)
    assert(not ok and msg=="anon : expected ')' : have <eof>")

    local src = "nil"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(xtostring(e) == "{ tag=nil, tk={ str=nil, tag=key } }")
    assert(check_tag("eof"))

    local src = "false true"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e1 = parser_expr()
    assert(xtostring(e1) == "{ tag=bool, tk={ str=false, tag=key } }")
    local e2 = parser_expr()
    assert(xtostring(e2) == "{ tag=bool, tk={ str=true, tag=key } }")
    assert(check_tag("eof"))

    local src = ":x :1:_"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e1 = parser_expr()
    assert(xtostring(e1) == "{ tag=tag, tk={ hier={ x }, str=:x, tag=tag } }")
    local e2 = parser_expr()
    assert(xtostring(e2) == "{ tag=tag, tk={ hier={ 1, _ }, str=:1:_, tag=tag } }")
    assert(check_tag("eof"))
end

-- EXPR UNO

do
    local src = "#v"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(xtostring(e) == "{ e={ tag=var, tk={ str=v, tag=var } }, op={ str=#, tag=op }, tag=uno }")
    assert(check_tag("eof"))

    local src = "! - x"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(expr_tocode(e) == "(!(-x))")
    assert(check_tag("eof"))
end

-- EXPR BIN

do
    local src = "a + 10"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(xtostring(e) == "{ e1={ tag=var, tk={ str=a, tag=var } }, e2={ tag=num, tk={ str=10, tag=num } }, op={ str=+, tag=op }, tag=bin }")
    assert(check_tag("eof"))

    local src = "2 + 3 - 1"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local ok, msg = catch(parser_expr)
    assert(not ok and msg=="anon : binary operation error : use parentheses to disambiguate")

    local src = "2 * (a - 1)"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(expr_tocode(e) == "(2 * (a - 1))")
    assert(check_tag("eof"))

    local src = "2 == -1"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(expr_tocode(e) == "(2 == (-1))")
    assert(check_tag("eof"))
end

-- EXPR CALL

do
    local src = "f(x,y)"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(xtostring(e) == "{ args={ { tag=var, tk={ str=x, tag=var } }, { tag=var, tk={ str=y, tag=var } } }, f={ tag=var, tk={ str=f, tag=var } }, tag=call }")
    assert(expr_tocode(e) == "f(x, y)")
    assert(check_tag("eof"))
end
