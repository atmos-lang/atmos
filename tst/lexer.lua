-- LUA_PATH="/x/atmos/src/?.lua;" lua5.4 lexer.lua

require "lexer"

-- SYMBOLS

do
    local src = "{ } ( ; {{ () ) , ][ ."
    print("Testing...", src)
    lexer_string("anon", src)
    assert(stringify(LEX()) == "{lin=1, str={, tag=sym}")
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

    local src = ". .. ... .. ."
    print("Testing...", src)
    lexer_string("anon", src)
    assert(LEX().str == '.')
    assert(LEX().str == '.')
    assert(LEX().str == '.')
    assert(LEX().str == '...')
    assert(LEX().str == '.')
    assert(LEX().str == '.')
    assert(LEX().str == '.')
    assert(LEX().tag == 'eof')
    assert(LEX() == nil)
end

-- OPERATORS

do
    local src = "< > = # - == ! ++ != #[ # >= # / || * +"
    print("Testing...", src)
    lexer_string("anon", src)
    assert(LEX().str == '<')
    assert(LEX().str == '>')
    assert(LEX().str == '=')
    assert(LEX().str == '#')
    assert(LEX().str == '-')
    assert(LEX().str == '==')
    assert(LEX().str == '!')
    assert(LEX().str == '++')
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

    local src = "!> ?? <? <! !? ?>"
    print("Testing...", src)
    lexer_string("anon", src)
    assert(LEX().str == '!>')
    assert(LEX().str == '??')
    assert(LEX().str == '<?')
    assert(LEX().str == '<!')
    assert(LEX().str == '!?')
    assert(LEX().str == '?>')
    assert(LEX().tag == 'eof')
    assert(LEX() == nil)

    local src = "--> <- --> <-"
    print("Testing...", src)
    lexer_string("anon", src)
    assert(LEX().str == '-->')
    assert(LEX().str == '<-')
    assert(LEX().str == '-->')
    assert(LEX().str == '<-')
    assert(LEX().tag == 'eof')
    assert(LEX() == nil)

end

-- NUMS / STRS

do
    local src = "10 0xF2 1.5 35 0xff 0xEaA 3.0 1.5F"
    print("Testing...", src)
    lexer_string("anon", src)
    assert(stringify(LEX()) == "{lin=1, str=10, tag=num}")
    assert(stringify(LEX()) == "{lin=1, str=0xF2, tag=num}")
    assert(stringify(LEX()) == "{lin=1, str=1.5, tag=num}")
    assert(stringify(LEX()) == "{lin=1, str=35, tag=num}")
    assert(stringify(LEX()) == "{lin=1, str=0xff, tag=num}")
    assert(stringify(LEX()) == "{lin=1, str=0xEaA, tag=num}")
    assert(stringify(LEX()) == "{lin=1, str=3.0, tag=num}")
    local ok, msg = pcall(LEX)
    assert(not ok and msg=="anon : line 1 : near '1.5F' : invalid number")

    local src = "3.1416 3.6e-2 0.4E1 34e1 0x0.1E 0xA3p-4 0X1.9F2D8P+1 0b12"
    print("Testing...", src)
    lexer_string("anon", src)
    assert(stringify(LEX()) == "{lin=1, str=3.1416, tag=num}")
    assert(stringify(LEX()) == "{lin=1, str=3.6e-2, tag=num}")
    assert(stringify(LEX()) == "{lin=1, str=0.4E1, tag=num}")
    assert(stringify(LEX()) == "{lin=1, str=34e1, tag=num}")
    assert(stringify(LEX()) == "{lin=1, str=0x0.1E, tag=num}")
    assert(stringify(LEX()) == "{lin=1, str=0xA3p-4, tag=num}")
    assert(stringify(LEX()) == "{lin=1, str=0X1.9F2D8P+1, tag=num}")
    local ok, msg = pcall(LEX)
    assert(not ok and msg=="anon : line 1 : near '0b12' : invalid number")

    local src = "'xx' \"zzz\" '' '\\n\\z10' \"\\d\" '\n"
    print("Testing...", "string 1")
    lexer_string("anon", src)
    assert(stringify(LEX()) == "{lin=1, str=xx, tag=str}")
    assert(stringify(LEX()) == "{lin=1, str=zzz, tag=str}")
    assert(stringify(LEX()) == "{lin=1, str=, tag=str}")
    assert(stringify(LEX()) == "{lin=1, str=\\n\\z10, tag=str}")
    assert(stringify(LEX()) == "{lin=1, str=\\d, tag=str}")
    local ok, msg = pcall(LEX)
    assert(not ok and msg=="anon : line 1 : near ''' : unterminated string")

    local src = [[
        """
        x
        """
        """"
        ""
        """""
        """""
        """"
    ]]
    print("Testing...", "string 2: multi-line")
    lexer_string("anon", src)
    assert(trim(LEX().str) == "x")
    assert(trim(LEX().str) == '""\n"""""\n"""""')

    local src = [[
        '''
        ''
        '''''
        ''''
    ]]
    print("Testing...", "string 3: multi-line unterminated")
    lexer_string("anon", src)
    local ok, msg = pcall(LEX)
    assertx(msg, "anon : line 1 : near ''''' : unterminated string")
end

-- KEYWORDS, VAR

do
    local src = "x X await every"
    print("Testing...", src)
    lexer_string("anon", src)
    assert(stringify(LEX()) == "{lin=1, str=x, tag=id}")
    assert(stringify(LEX()) == "{lin=1, str=X, tag=id}")
    assert(stringify(LEX()) == "{lin=1, str=await, tag=key}")
    assert(stringify(LEX()) == "{lin=1, str=every, tag=key}")

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
    assert(not ok and msg=="anon : line 2 : near ';;;' : unterminated comment")

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
    assert(stringify(LEX()) == "{lin=1, str=:X, tag=tag}")
    assert(stringify(LEX()) == "{lin=1, str=:a:X:1, tag=tag}")
    assert(stringify(LEX()) == "{lin=1, str=::, tag=tag}")

    local src = ":() :"
    print("Testing...", src)
    lexer_string("anon", src)
    assert(LEX().str == ':')
    assert(LEX().str == '(')
    assert(LEX().str == ')')
    assert(LEX().str == ':')
end

print "--- NATIVE ---"

do
    local src = "` abc `"
    print("Testing...", src)
    lexer_string("anon", src)
    assertx(stringify(LEX()), "{lin=1, str= abc , tag=nat}")

    local src = "``` \n ```` \n `` \n ```"
    print("Testing...", "native 1")
    lexer_string("anon", src)
    assertx(stringify(LEX()), "{lin=1, str= \n ```` \n `` \n , tag=nat}")

    local src = "``` \n ```` \n `` \n `````"
    print("Testing...", "native 2")
    lexer_string("anon", src)
    local ok, msg = pcall(LEX)
    assertx(msg, "anon : line 1 : near '```' : unterminated native")
end

print "--- CLOCK ---"

do
    local src = "@1:2:3.4"
    print("Testing...", src)
    lexer_string("anon", src)
    assertx(stringify(LEX()), "{clk={1, 2, 3, 4}, lin=1, str=1:2:3.4, tag=clk}")

    local src = "@10:05"
    print("Testing...", src)
    lexer_string("anon", src)
    assertx(stringify(LEX()), "{clk={0, 10, 05, 0}, lin=1, str=10:05, tag=clk}")

    local src = "@1:v1:3.x"
    print("Testing...", src)
    lexer_string("anon", src)
    assertx(stringify(LEX()), "{clk={1, v1, 3, x}, lin=1, str=1:v1:3.x, tag=clk}")

    local src = "@.x1"
    print("Testing...", src)
    lexer_string("anon", src)
    assertx(stringify(LEX()), "{clk={0, 0, 0, x1}, lin=1, str=.x1, tag=clk}")

    local src = "@1:v1:3."
    print("Testing...", src)
    lexer_string("anon", src)
    local ok, msg = pcall(LEX)
    assertx(msg, "anon : line 1 : near '1:v1:3.' : invalid clock")
end
