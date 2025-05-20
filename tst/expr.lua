-- LUA_PATH="/x/atmos/src/?.lua;" lua5.4 expr.lua

require "lexer"
require "expr"
require "tostr"

-- PRIM

do
    local src = " a "
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check('<eof>'))
    assert(stringify(e) == "{ tag=acc, tk={ lin=1, str=a, tag=id } }")

    local src = "1.5"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check('<eof>'))
    assert(stringify(e) == "{ tag=num, tk={ lin=1, str=1.5, tag=num } }")

    local src = "{"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 1 : near '{' : expected expression")

    local src = ""
    print("Testing...", "eof")
    init()
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 1 : near '<eof>' : expected expression")

    local src = [[

    ]]
    print("Testing...", "blanks")
    init()
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 2 : near '<eof>' : expected expression")

    local src = " ( a ) "
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check('<eof>'))
    assertx(stringify(e), "{ e={ tag=acc, tk={ lin=1, str=a, tag=id } }, tag=parens, tk={ lin=1, str=(, tag=sym } }")

    local src = " ( a "
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 1 : near '<eof>' : expected ')'")

    local src = "nil"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check('<eof>'))
    assert(stringify(e) == "{ tag=nil, tk={ lin=1, str=nil, tag=key } }")

    local src = "false true"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local e1 = parser_expr()
    assert(stringify(e1) == "{ tag=bool, tk={ lin=1, str=false, tag=key } }")
    local e2 = parser_expr()
    assert(check('<eof>'))
    assert(stringify(e2) == "{ tag=bool, tk={ lin=1, str=true, tag=key } }")

    local src = ":x :1:_"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local e1 = parser_expr()
    assert(stringify(e1) == "{ tag=tag, tk={ lin=1, str=:x, tag=tag } }")
    local e2 = parser_expr()
    assert(check('<eof>'))
    assert(stringify(e2) == "{ tag=tag, tk={ lin=1, str=:1:_, tag=tag } }")

    local src = "'xxx' '''1\n2\n'''"
    print("Testing...", "string 1")
    init()
    lexer_string("anon", src)
    parser()
    local e1 = parser_expr()
    assert(stringify(e1) == "{ tag=str, tk={ lin=1, str=xxx, tag=str } }")
    local e2 = parser_expr()
    assert(stringify(e2) == "{ tag=str, tk={ lin=1, str=1\n2\n, tag=str } }")
end

-- TABLE / INDEX
do
    local src = "[a]"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check('<eof>'))
    assert(stringify(e) == "{ ps={ { k={ tag=num, tk={ str=1, tag=num } }, v={ tag=acc, tk={ lin=1, str=a, tag=id } } } }, tag=table }")

    local src = "[:x=10]"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 1 : near '=' : expected ']'")

    local src = "[ v1, k2=v2, (:k3,v3), v4 ]"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check('<eof>'))
    assertx(tostr_expr(e), '[(1,v1), (:k2,v2), (:k3,v3), (2,v4)]')

    local src = "[ ]"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check('<eof>'))
    assert(tostr_expr(e) == '[]')

    local src = "[ [], k2=[1,2,3], ([1],v3) ]"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check('<eof>'))
    assert(tostr_expr(e) == '[(1,[]), (:k2,[(1,1), (2,2), (3,3)]), ([(1,1)],v3)]')

    local src = "[1,]"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check('<eof>'))
    assert(tostr_expr(e) == '[(1,1)]')

    local src = "[{"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 1 : near '{' : expected expression")

    local src = "[({"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 1 : near '{' : expected expression")

    local src = "[("
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 1 : near '<eof>' : expected expression")

    local src = "[(1,2]"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 1 : near ']' : expected ')'")

    local src = "x[1]"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check('<eof>'))
    assert(stringify(e) == "{ idx={ tag=num, tk={ lin=1, str=1, tag=num } }, t={ tag=acc, tk={ lin=1, str=x, tag=id } }, tag=index }")

    local src = "x.a"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check('<eof>'))
    assert(tostr_expr(e) == 'x[:a]')

    local src = "t[1"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 1 : near '<eof>' : expected ']'")

    local src = "x . ."
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 1 : near '.' : expected <id>")

    local src = "x . 2"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 1 : near '2' : expected <id>")

    local src = "x[1]().a"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check('<eof>'))
    assert(tostr_expr(e) == 'x[1]()[:a]')

    local src = "#t"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check('<eof>'))
    assert(stringify(e) == "{ e={ tag=acc, tk={ lin=1, str=t, tag=id } }, op={ lin=1, str=#, tag=op }, tag=uno }")

    local src = "1[1]"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 1 : near '[' : index error : expected prefix expression")

    local src = "nil.1"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 1 : near '.' : field error : expected prefix expression")

    local src = "-x[0]"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check('<eof>'))
    assert(tostr_expr(e) == '-x[0]')
end

-- UNO

do
    local src = "#v"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check('<eof>'))
    assert(stringify(e) == "{ e={ tag=acc, tk={ lin=1, str=v, tag=id } }, op={ lin=1, str=#, tag=op }, tag=uno }")

    local src = "! - x"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check('<eof>'))
    assert(tostr_expr(e) == "!-x")
end

-- BIN

do
    local src = "a + 10"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check('<eof>'))
    assert(stringify(e) == "{ e1={ tag=acc, tk={ lin=1, str=a, tag=id } }, e2={ tag=num, tk={ lin=1, str=10, tag=num } }, op={ lin=1, str=+, tag=op }, tag=bin }")

    local src = "2 + 3 - 1"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 1 : near '-' : binary operation error : use parentheses to disambiguate")

    local src = "2 * (a - 1)"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check('<eof>'))
    assertx(tostr_expr(e), "2 * (a - 1)")

    local src = "2 == -1"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check('<eof>'))
    assert(tostr_expr(e) == "2 == -1")

    local src = "x || y"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check('<eof>'))
    assert(tostr_expr(e) == "x || y")

    local src = "- -1"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check('<eof>'))
    assert(tostr_expr(e) == "--1")

    local src = "(10+)"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 1 : near ')' : expected expression")

    local src = "if x => 10 => 20"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check('<eof>'))
    assert(tostr_expr(e) == "x and 10 or 20")
end

-- CALL / FUNC / RETURN / THROW

do
    local src = "f(x,y)"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check('<eof>'))
    assert(stringify(e) == "{ args={ { tag=acc, tk={ lin=1, str=x, tag=id } }, { tag=acc, tk={ lin=1, str=y, tag=id } } }, f={ tag=acc, tk={ lin=1, str=f, tag=id } }, tag=call }")
    assert(tostr_expr(e) == "f(x, y)")

    local src = "f({"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 1 : near '{' : expected expression")

    local src = "f(10"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 1 : near '<eof>' : expected ')'")

    local src = [[
        (func (x,y) {
            return (x + y)
        })(1,2)
    ]]
    print("Testing...", "func 1")
    init()
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check('<eof>'))
    assertx(tostr_expr(e), trim [[
        (func (x, y) {
            return(x + y)
        })(1, 2)
    ]])

    local src = [[
        f()()
    ]]
    print("Testing...", "func 1")
    init()
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check('<eof>'))
    assert(stringify(e) == "{ args={  }, f={ args={  }, f={ tag=acc, tk={ lin=1, str=f, tag=id } }, tag=call }, tag=call }")

    local src = "func (1) {}"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 1 : near '1' : expected <id>")

    local src = "throw(:X)"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(stringify(e) == "{ args={ { tag=tag, tk={ lin=1, str=:X, tag=tag } }, { tag=num, tk={ str=0 } } }, f={ tag=acc, tk={ lin=1, str=error, tag=id } }, tag=call }")

    local src = "func (it) {}"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assertx(trim(tostr_expr(e)), trim [[
        func (it) {
        }
    ]])
    --local ok, msg = pcall(parser_stmt)
    --assert(not ok and msg=="anon : line 1 : near 'it' : expected <id>")

end

-- EXEC / CORO / TASK / TASKS / YIELD / SPAWN / RESUME / PUB

do
    local src = "coro(f)"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check('<eof>'))
    assert(stringify(e) == "{ args={ { tag=acc, tk={ lin=1, str=f, tag=id } } }, f={ tag=acc, tk={ lin=1, str=coro, tag=id } }, tag=call }")

    local src = "task(T)"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check('<eof>'))
    assert(tostr_expr(e) == "task(T)")

    local src = "tasks(10)"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check('<eof>'))
    assert(tostr_expr(e) == "tasks(10)")

    local src = "tasks()"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check('<eof>'))
    assert(tostr_expr(e) == "tasks()")

    local src = "yield(x,10)"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check('<eof>'))
    assert(tostr_expr(e) == "yield(x, 10)")

    local src = "emit(:X,10)"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check('<eof>'))
    assert(tostr_expr(e) == "emit(nil, :X, 10)")

    local src = "emit(:X,10) in x"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check('<eof>'))
    assert(tostr_expr(e) == "emit(x, :X, 10)")

    local src = "resume co()"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check('<eof>'))
    assert(tostr_expr(e) == "resume(co)")

    local src = "spawn T(1,2,3)"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check('<eof>'))
    assertx(tostr_expr(e), "spawn(nil, T, 1, 2, 3)")

    local src = "spawn (x+10)"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 1 : near 'spawn' : expected call")

    local src = "await(:X, x+10)"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check('<eof>'))
    assert(tostr_expr(e) == trim [[
        await(:X, func (it) {
            return(x + 10)
        })
    ]])

    local src = "pub"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check('<eof>'))
    assertx(tostr_expr(e), 'pub')
end
