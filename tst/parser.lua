-- LUA_PATH="/x/atmos/src/?.lua;" lua5.4 parser.lua

require "lexer"
require "parser"

local match = string.match

-- EXPR

do
    local src = " a "
    print("Testing...", src)
    local tks = lexer_string(src)
    parser_lexer(tks)
    local e = parser_expr()
    assert(xtostring(e) == "{ tag=var, tk={ str=a, tag=var } }")
    assert(check_tag("eof"))

    local src = "{"
    print("Testing...", src)
    local tks = lexer_string(src)
    parser_lexer(tks)
    local ok, err = pcall(parser_expr)
    assert(not ok and match(err, "expected expression : have {$"))
end

--xdump(parser_expr())
