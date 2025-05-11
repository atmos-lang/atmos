-- LUA_PATH="/x/atmos/src/?.lua;" lua5.4 expr.lua

require "lexer"
require "expr"
require "tostr"

-- PRIM

do
    local src = " a "
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check("<eof>"))
    assert(xtostring(e) == "{ tag=acc, tk={ lin=1, str=a, tag=id } }")

    local src = "1.5"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check("<eof>"))
    assert(xtostring(e) == "{ tag=num, tk={ lin=1, str=1.5, tag=num } }")

    local src = "{"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 1 : near '{' : expected expression")

    local src = ""
    print("Testing...", "eof")
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 1 : near '<eof>' : expected expression")

    local src = [[

    ]]
    print("Testing...", "blanks")
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 2 : near '<eof>' : expected expression")

    local src = " ( a ) "
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check("<eof>"))
    assert(xtostring(e) == "{ tag=acc, tk={ lin=1, str=a, tag=id } }")

    local src = " ( a "
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 1 : near '<eof>' : expected ')'")

    local src = "nil"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check("<eof>"))
    assert(xtostring(e) == "{ tag=nil, tk={ lin=1, str=nil, tag=key } }")

    local src = "false true"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e1 = parser_expr()
    assert(xtostring(e1) == "{ tag=bool, tk={ lin=1, str=false, tag=key } }")
    local e2 = parser_expr()
    assert(check("<eof>"))
    assert(xtostring(e2) == "{ tag=bool, tk={ lin=1, str=true, tag=key } }")

    local src = ":x :1:_"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e1 = parser_expr()
    assert(xtostring(e1) == "{ tag=tag, tk={ lin=1, str=:x, tag=tag } }")
    local e2 = parser_expr()
    assert(check("<eof>"))
    assert(xtostring(e2) == "{ tag=tag, tk={ lin=1, str=:1:_, tag=tag } }")
end

-- TABLE
do
    local src = "[a]"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check("<eof>"))
    assert(xtostring(e) == "{ ps={ { k={ tag=num, tk={ str=1, tag=num } }, v={ tag=acc, tk={ lin=1, str=a, tag=id } } } }, tag=table }")

    local src = "[ v1, k2=v2, (:k3,v3), v4 ]"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check("<eof>"))
    assert(tostr_expr(e) == '[(1,v1), ("k2",v2), (:k3,v3), (2,v4)]')

    local src = "[ ]"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check("<eof>"))
    assert(tostr_expr(e) == '[]')

    local src = "[ [], k2=[1,2,3], ([1],v3) ]"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check("<eof>"))
    assert(tostr_expr(e) == '[(1,[]), ("k2",[(1,1), (2,2), (3,3)]), ([(1,1)],v3)]')

    local src = "[1,]"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check("<eof>"))
    assert(tostr_expr(e) == '[(1,1)]')

    local src = "[{"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 1 : near '{' : expected expression")

    local src = "[({"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 1 : near '{' : expected expression")

    local src = "[("
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 1 : near '<eof>' : expected expression")

    local src = "[(1,2]"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 1 : near ']' : expected ')'")

    local src = "x[1]"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check("<eof>"))
    assert(xtostring(e) == "{ idx={ tag=num, tk={ lin=1, str=1, tag=num } }, t={ tag=acc, tk={ lin=1, str=x, tag=id } }, tag=index }")

    local src = "x.a"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check("<eof>"))
    assert(tostr_expr(e) == 'x["a"]')

    local src = "t[1"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 1 : near '<eof>' : expected ']'")

    local src = "x . ."
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 1 : near '.' : expected <id>")

    local src = "x . 2"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 1 : near '2' : expected <id>")

    local src = "x[1]().a"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check("<eof>"))
    assert(tostr_expr(e) == 'x[1]()["a"]')

    local src = "#t"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check("<eof>"))
    assert(xtostring(e) == "{ e={ tag=acc, tk={ lin=1, str=t, tag=id } }, op={ lin=1, str=#, tag=op }, tag=uno }")
end

-- UNO

do
    local src = "#v"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check("<eof>"))
    assert(xtostring(e) == "{ e={ tag=acc, tk={ lin=1, str=v, tag=id } }, op={ lin=1, str=#, tag=op }, tag=uno }")

    local src = "! - x"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check("<eof>"))
    assert(tostr_expr(e) == "(!(-x))")
end

-- BIN

do
    local src = "a + 10"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check("<eof>"))
    assert(xtostring(e) == "{ e1={ tag=acc, tk={ lin=1, str=a, tag=id } }, e2={ tag=num, tk={ lin=1, str=10, tag=num } }, op={ lin=1, str=+, tag=op }, tag=bin }")

    local src = "2 + 3 - 1"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 1 : near '-' : binary operation error : use parentheses to disambiguate")

    local src = "2 * (a - 1)"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check("<eof>"))
    assert(tostr_expr(e) == "(2 * (a - 1))")

    local src = "2 == -1"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check("<eof>"))
    assert(tostr_expr(e) == "(2 == (-1))")

    local src = "- -1"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check("<eof>"))
    assert(tostr_expr(e) == "(-(-1))")

    local src = "(10+)"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 1 : near ')' : expected expression")
end

-- CALL / FUNC / RETURN

do
    local src = "f(x,y)"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check("<eof>"))
    assert(xtostring(e) == "{ args={ { tag=acc, tk={ lin=1, str=x, tag=id } }, { tag=acc, tk={ lin=1, str=y, tag=id } } }, f={ tag=acc, tk={ lin=1, str=f, tag=id } }, tag=call }")
    assert(tostr_expr(e) == "f(x, y)")

    local src = "f({"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 1 : near '{' : expected expression")

    local src = "f(10"
    print("Testing...", src)
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
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check("<eof>"))
    assert(tostr_expr(e) == trim [[
        func (x, y) {
            return((x + y))
        }(1, 2)
    ]])

    local src = [[
        f()()
    ]]
    print("Testing...", "func 1")
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check("<eof>"))
    assert(xtostring(e) == "{ args={  }, f={ args={  }, f={ tag=acc, tk={ lin=1, str=f, tag=id } }, tag=call }, tag=call }")

    local src = "func (1) {}"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 1 : near '1' : expected <id>")
end

-- EXEC / CORO / TASK / TASKS / YIELD / SPAWN / RESUME

do
    local src = "coro(f)"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check("<eof>"))
    assert(xtostring(e) == "{ args={ { tag=acc, tk={ lin=1, str=f, tag=id } } }, f={ tag=acc, tk={ str=coro, tag=id } }, tag=call }")

    local src = "task(T)"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check("<eof>"))
    assert(tostr_expr(e) == "task(T)")

    local src = "tasks(10)"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check("<eof>"))
    assert(tostr_expr(e) == "tasks(10)")

    local src = "yield(x,10)"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check("<eof>"))
    assert(tostr_expr(e) == "yield(x, 10)")

    local src = "emit(:X,10)"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check("<eof>"))
    assert(tostr_expr(e) == "emit(:X, 10)")

    local src = "resume co()"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check("<eof>"))
    assert(tostr_expr(e) == "resume(co)")

    local src = "spawn T(1,2,3)"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check("<eof>"))
    assert(tostr_expr(e) == "spawn(T, 1, 2, 3)")

    local src = "spawn (x+10)"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 1 : near 'spawn' : expected call")

    local src = "await(:X, x+10)"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check("<eof>"))
    assert(tostr_expr(e) == trim [[
        await(:X, func (it) {
            return((x + 10))
        })
    ]])
end
