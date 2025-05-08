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

-- NUMS

do
    local src = "10 0xF12 0b12"
    print("Testing...", src)
    local tks = lexer_string(src)
    assert(xtostring(tks()) == "{ str=10, tag=num }")
    assert(xtostring(tks()) == "{ str=0xF12, tag=num }")
    local ok, err = pcall(tks)
    assert(not ok and match(err, "invalid number : 0b12"))
end

-- KEYWORDS, VAR

do
    local src = "x X await"
    print("Testing...", src)
    local tks = lexer_string(src)
    assert(xtostring(tks()) == "{ str=x, tag=var }")
    assert(xtostring(tks()) == "{ str=X, tag=var }")
    assert(xtostring(tks()) == "{ str=await, tag=key }")
end

do
    local src = "x-1 10-abc"
    print("Testing...", src)
    local tks = lexer_string(src)
    assert(tks().str == "x")
    assert(tks().str == "-")
    assert(tks().str == "1")
    assert(tks().str == "10")
    assert(tks().str == "-")
    assert(tks().str == "abc")
end

-- COMMENTS

do
    local src = [[
        x - y ;;
        var ;;x
        ;;
        val ;; x
        ;; -
        -
    ]]
    print("Testing...", "comments 1")
    local tks = lexer_string(src)
    assert(tks().str == "x")
    assert(tks().str == "-")
    assert(tks().str == "y")
    assert(tks().str == "var")
    assert(tks().str == "val")
    assert(tks().str == "-")
end

do
    local src = [[
        x ;;;
        var ;;x
        val ;;; y
        z
    ]]
    print("Testing...", "comments 2")
    local tks = lexer_string(src)
    assert(tks().str == "x")
    assert(tks().str == "y")
    assert(tks().str == "z")
end

do
    local src = [[
        x
        ;;;
        ;;;;
        ;;;
        ;;
        ;;;;
        ;;;;
        ;;;
        ;;;;
        ;;;
        y
    ]]
end

do
    local src = [[
        x
        ;;;
        ;;;;
        ;;;
        y
    ]]
end

do
    local src = [[
        x
        ;;;;
        ;;;
        ;;;;
        y
    ]]
end
