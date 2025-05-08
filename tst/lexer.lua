-- LUA_PATH="/x/atmos/src/?.lua;" lua5.4 lexer.lua

require "lexer"

local match = string.match

-- SYMBOLS

do
    local src = "{ } ( ; {{ () ) , ][ ."
    print("Testing...", src)
    local tks = lexer_string(src)
    assert(tks().str == "{")
    assert(tks().str == "}")
    assert(tks().str == "(")
    assert(tks().str == "{")
    assert(tks().str == "{")
    assert(tks().str == "(")
    assert(tks().str == ")")
    assert(tks().str == ")")
    assert(tks().str == ",")
    assert(tks().str == "]")
    assert(tks().str == "[")
    assert(tks().str == ".")
    assert(tks().tag == "eof")
    assert(tks() == nil)
end

-- OPERATORS

do
    local src = "< > = # - == #[ # # / * +"
    print("Testing...", src)
    local tks = lexer_string(src)
    assert(tks().str == "<")
    assert(tks().str == ">")
    assert(tks().str == "=")
    assert(tks().str == "#")
    assert(tks().str == "-")
    assert(tks().str == "==")
    assert(tks().str == "#")
    assert(tks().str == "[")
    assert(tks().str == "#")
    assert(tks().str == "#")
    assert(tks().str == "/")
    assert(tks().str == "*")
    assert(tks().str == "+")
    assert(tks().tag == "eof")
    assert(tks() == nil)
end

do
    local src = "##"
    print("Testing...", src)
    local tks = lexer_string(src)
    local ok, err = pcall(tks)
    assert(not ok and match(err, "invalid operator : ##$"))
end

-- KEYWORDS, IDS

do
    local src = "x X await"
    print("Testing...", src)
    local tks = lexer_string(src)
    assert(xtostring(tks()) == "{ str=x, tag=id }")
    assert(xtostring(tks()) == "{ str=X, tag=id }")
    assert(xtostring(tks()) == "{ str=await, tag=key }")
end
