-- LUA_PATH="/x/atmos/src/?.lua;" lua5.4 lexer.lua

require "lexer"

-- SYMBOLS

do
    local src = "{ } ( ; {{ () ) , ][ ."
    print("Testing...", src)
    lexer_string("anon", src)
    assert(xtostring(LEX()) == "{ lin=1, str={, tag=sym }")
    assert(LEX().str == '}')
    assert(LEX().str == '(')
    assert(LEX().str == '{')
    assert(LEX().str == '{')
    assert(LEX().str == '(')
    assert(LEX().str == ')')
    assert(LEX().str == ')')
    assert(LEX().str == ',')
    assert(LEX().str == ']')
    assert(LEX().str == '[')
    assert(LEX().str == '.')
    assert(LEX().tag == 'eof')
    assert(LEX() == nil)
end

-- OPERATORS

do
    local src = "< > = # - == ! != #[ # >= # / || * +"
    print("Testing...", src)
    lexer_string("anon", src)
    assert(LEX().str == '<')
    assert(LEX().str == '>')
    assert(LEX().str == '=')
    assert(LEX().str == '#')
    assert(LEX().str == '-')
    assert(LEX().str == '==')
    assert(LEX().str == '!')
    assert(LEX().str == '!=')
    assert(LEX().str == '#')
    assert(LEX().str == '[')
    assert(LEX().str == '#')
    assert(LEX().str == '>=')
    assert(LEX().str == '#')
    assert(LEX().str == '/')
    assert(LEX().str == '||')
    assert(LEX().str == '*')
    assert(LEX().str == '+')
    assert(LEX().tag == 'eof')
    assert(LEX() == nil)

    local src = "##"
    print("Testing...", src)
    lexer_string("anon", src)
    local ok, msg = pcall(LEX)
    assert(not ok and msg=="anon : line 1 : near '##' : invalid operator")

    local src = "!!"
    print("Testing...", src)
    lexer_string("anon", src)
    local ok, msg = pcall(LEX)
    assert(not ok and msg=="anon : line 1 : near '!!' : invalid operator")
end

-- NUMS

do
    local src = "10 0xF12 1.5 0b12"
    print("Testing...", src)
    lexer_string("anon", src)
    assert(xtostring(LEX()) == "{ lin=1, str=10, tag=num }")
    assert(xtostring(LEX()) == "{ lin=1, str=0xF12, tag=num }")
    assert(xtostring(LEX()) == "{ lin=1, str=1.5, tag=num }")
    local ok, msg = pcall(LEX)
    assert(not ok and msg=="anon : line 1 : near '0b12' : invalid number")
end

-- KEYWORDS, VAR

do
    local src = "x X await"
    print("Testing...", src)
    lexer_string("anon", src)
    assert(xtostring(LEX()) == "{ lin=1, str=x, tag=id }")
    assert(xtostring(LEX()) == "{ lin=1, str=X, tag=id }")
    assert(xtostring(LEX()) == "{ lin=1, str=await, tag=key }")

    local src = "x-1 10-abc"
    print("Testing...", src)
    lexer_string("anon", src)
    assert(LEX().str == "x")
    assert(LEX().str == '-')
    assert(LEX().str == "1")
    assert(LEX().str == "10")
    assert(LEX().str == '-')
    assert(LEX().str == "abc")
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
    lexer_string("anon", src)
    assert(LEX().str == "x")
    assert(LEX().str == '-')
    assert(LEX().str == "y")
    assert(LEX().str == 'var')
    assert(LEX().str == 'val')
    assert(LEX().str == '-')

    local src = [[
        x ;;;
        var ;;x
        val ;;; y
        z
    ]]
    print("Testing...", "comments 2")
    lexer_string("anon", src)
    assert(LEX().str == "x")
    assert(LEX().str == "y")
    assert(LEX().str == "z")

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
    lexer_string("anon", src)
    assert(LEX().str == "x")
    assert(LEX().str == "y")

    local src = [[
        x
        ;;;
        ;;;;
        ;;;
        y
    ]]
    print("Testing...", "comments 4")
    lexer_string("anon", src)
    assert(LEX().str == "x")
    local ok, msg = pcall(LEX)
    assert(not ok and msg=="anon : line 6 : near '<eof>' : unterminated comment")

    local src = [[
        x
        ;;;;
        ;;;
        ;;;;
        y
    ]]
    print("Testing...", "comments 4")
    lexer_string("anon", src)
    assert(LEX().str == "x")
    assert(LEX().str == "y")
    assert(LEX().tag == 'eof')
end

-- TAGS

do
    local src = ":X :a:X:1 ::"
    print("Testing...", src)
    lexer_string("anon", src)
    assert(xtostring(LEX()) == "{ lin=1, str=:X, tag=tag }")
    assert(xtostring(LEX()) == "{ lin=1, str=:a:X:1, tag=tag }")
    assert(xtostring(LEX()) == "{ lin=1, str=::, tag=tag }")

    local src = ":()"
    print("Testing...", src)
    lexer_string("anon", src)
    assert(LEX().str == ':')
    assert(LEX().str == '(')
    assert(LEX().str == ')')
end
