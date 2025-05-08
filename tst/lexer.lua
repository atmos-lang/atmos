-- LUA_PATH="/x/atmos/src/?.lua;" lua5.4 lexer.lua

require "lexer"

local match = string.match

-- SYMBOLS

do
    local src = "{ } ( ; {{ () ) , ][ ."
    print("Testing...", src)
    local tks = lexer_string(src)
    assert(xtostring(tks()) == "{ str={, tag=sym }")
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
    local src = "< > = # - == ! != #[ # >= # / || * +"
    print("Testing...", src)
    local tks = lexer_string(src)
    assert(tks().str == "<")
    assert(tks().str == ">")
    assert(tks().str == "=")
    assert(tks().str == "#")
    assert(tks().str == "-")
    assert(tks().str == "==")
    assert(tks().str == "!")
    assert(tks().str == "!=")
    assert(tks().str == "#")
    assert(tks().str == "[")
    assert(tks().str == "#")
    assert(tks().str == ">=")
    assert(tks().str == "#")
    assert(tks().str == "/")
    assert(tks().str == "||")
    assert(tks().str == "*")
    assert(tks().str == "+")
    assert(tks().tag == "eof")
    assert(tks() == nil)

    local src = "##"
    print("Testing...", src)
    local tks = lexer_string(src)
    local ok, err = pcall(tks)
    assert(not ok and match(err, "invalid operator : ##$"))

    local src = "!!"
    print("Testing...", src)
    local tks = lexer_string(src)
    local ok, err = pcall(tks)
    assert(not ok and match(err, "invalid operator : !!$"))
end

-- NUMS

do
    local src = "10 0xF12 1.5 0b12"
    print("Testing...", src)
    local tks = lexer_string(src)
    assert(xtostring(tks()) == "{ str=10, tag=num }")
    assert(xtostring(tks()) == "{ str=0xF12, tag=num }")
    assert(xtostring(tks()) == "{ str=1.5, tag=num }")
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
    print("Testing...", "comments 3")
    local tks = lexer_string(src)
    assert(tks().str == "x")
    assert(tks().str == "y")

    local src = [[
        x
        ;;;
        ;;;;
        ;;;
        y
    ]]
    print("Testing...", "comments 4")
    local tks = lexer_string(src)
    assert(tks().str == "x")
    local ok, err = pcall(tks)
    assert(not ok and match(err, "unterminated comment"))

    local src = [[
        x
        ;;;;
        ;;;
        ;;;;
        y
    ]]
    print("Testing...", "comments 4")
    local tks = lexer_string(src)
    assert(tks().str == "x")
    assert(tks().str == "y")
    assert(tks().tag == "eof")
end

-- TAGS

do
    local src = ":X :a:X:1 ::"
    print("Testing...", src)
    local tks = lexer_string(src)
    assert(xtostring(tks()) == "{ hier={ X }, str=:X, tag=tag }")
    assert(xtostring(tks()) == "{ hier={ a, X, 1 }, str=:a:X:1, tag=tag }")
    assert(xtostring(tks()) == "{ hier={ ,  }, str=::, tag=tag }")

    local src = ":()"
    print("Testing...", src)
    local tks = lexer_string(src)
    assert(tks().str == ":")
    assert(tks().str == "(")
    assert(tks().str == ")")
end

--xdump(tks())
