-- LUA_PATH="/x/atmos/src/?.lua;" lua5.4 expr.lua

require "lexer"
require "parser"
require "tosource"

-- PRIM

do
    local src = " a "
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assert(stringify(e) == "{tag=acc, tk={lin=1, str=a, tag=id}}")

    local src = "1.5"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assert(stringify(e) == "{tag=num, tk={lin=1, str=1.5, tag=num}}")

    local src = "@{"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local ok, msg = pcall(parser)
    assertx(msg, "anon : line 1 : near '<eof>' : expected expression")

    local src = ""
    print("Testing...", "eof")
    init()
    lexer_init("anon", src)
    lexer_next()
    local ok, msg = pcall(parser)
    assert(not ok and msg=="anon : line 1 : near '<eof>' : expected expression")

    local src = [[

    ]]
    print("Testing...", "blanks")
    init()
    lexer_init("anon", src)
    lexer_next()
    local ok, msg = pcall(parser)
    assert(not ok and msg=="anon : line 2 : near '<eof>' : expected expression")

    local src = " ( a ) "
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(stringify(e), "{e={tag=acc, tk={lin=1, str=a, tag=id}}, tag=parens, tk={lin=1, str=(, tag=sym}}")

    local src = " ( a "
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local ok, msg = pcall(parser)
    assert(not ok and msg=="anon : line 1 : near '<eof>' : expected ')'")

    local src = "nil"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assert(stringify(e) == "{tag=nil, tk={lin=1, str=nil, tag=key}}")

    local src = "false true"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e1 = parser()
    assert(stringify(e1) == "{tag=bool, tk={lin=1, str=false, tag=key}}")
    local e2 = parser()
    assert(check('<eof>'))
    assert(stringify(e2) == "{tag=bool, tk={lin=1, str=true, tag=key}}")
end

print '--- STRING / NATIVE ---'

do
    local src = ":x :1._"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e1 = parser()
    assert(stringify(e1) == "{tag=tag, tk={lin=1, str=:x, tag=tag}}")
    local e2 = parser()
    assert(check('<eof>'))
    assert(stringify(e2) == "{tag=tag, tk={lin=1, str=:1._, tag=tag}}")

    local src = "'xxx'\n'''1\n2\n'''"
    print("Testing...", "string 1")
    init()
    lexer_init("anon", src)
    lexer_next()
    local e1 = parser()
    assert(stringify(e1) == "{tag=str, tk={lin=1, str=xxx, tag=str}}")
    local e2 = parser()
    assert(stringify(e2) == "{tag=str, tk={lin=2, str=1\n2\n, tag=str}}")

    local src = "```f()```"
    print("Testing...", "native 1")
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assertx(stringify(e), "{tag=nat, tk={lin=1, str=f(), tag=nat}}")

    local src = "`f`()"
    print("Testing...", "native 2")
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assertx(tosource(e), "`f`()")
end

-- TABLE / INDEX
do
    local src = "@{a}"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(stringify(e), "{tag=table, vs={{k={tag=num, tk={str=1, tag=num}}, v={tag=acc, tk={lin=1, str=a, tag=id}}}}}")

    local src = "@{:x=10}"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local ok, msg = pcall(parser)
    --assertx(msg, "anon : line 1 : near '=' : expected ']'")
    assertx(msg, "anon : line 1 : near '=' : expected '}'")

    local src = "@{ v1, k2=v2, [:k3]=v3, v4 }"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), '@{[1]=v1, [:k2]=v2, [:k3]=v3, [2]=v4}')

    local src = "@{ }"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), '@{}')

    local src = "@{ @{}, k2=@{1,2,3}, [@{1}]=v3 }"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), '@{[1]=@{}, [:k2]=@{[1]=1, [2]=2, [3]=3}, [@{[1]=1}]=v3}')

    local src = "@{1,}"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assert(tosource(e) == '@{[1]=1}')

    local src = "@{f()}"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), '@{[1]=f()}')

    local src = "@{["
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local ok, msg = pcall(parser)
    assertx(msg, "anon : line 1 : near '<eof>' : expected expression")
    --assertx(msg, "anon : line 1 : near '{' : expected expression")

    local src = "@{(["
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local ok, msg = pcall(parser)
    assertx(msg, "anon : line 1 : near '[' : expected expression")
    --assertx(msg, "anon : line 1 : near '{' : expected expression")

    local src = "@{("
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local ok, msg = pcall(parser)
    assert(not ok and msg=="anon : line 1 : near '<eof>' : expected expression")

    local src = "@{(1,2}"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local ok, msg = pcall(parser)
    assertx(msg, "anon : line 1 : near '}' : expected ')'")
    --assertx(msg, "anon : line 1 : near '<eof>' : expected '='")

    local src = "x[1]"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assert(stringify(e) == "{idx={tag=num, tk={lin=1, str=1, tag=num}}, t={tag=acc, tk={lin=1, str=x, tag=id}}, tag=index}")

    local src = "x.a"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assert(tosource(e) == 'x[:a]')

    local src = "t[1"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local ok, msg = pcall(parser)
    assert(not ok and msg=="anon : line 1 : near '<eof>' : expected ']'")

    local src = "x . ."
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local ok, msg = pcall(parser)
    assert(not ok and msg=="anon : line 1 : near '.' : expected <id>")

    local src = "x . 2"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local ok, msg = pcall(parser)
    assert(not ok and msg=="anon : line 1 : near '2' : expected <id>")

    local src = "x[1]().a"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assert(tosource(e) == 'x[1]()[:a]')

    local src = "#t"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assert(stringify(e) == "{e={tag=acc, tk={lin=1, str=t, tag=id}}, op={lin=1, str=#, tag=op}, tag=uno}")

    local src = "1[1]"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(not check('<eof>'))
    assert(tosource(e) == "1")
    --local ok, msg = pcall(parser)
    --assert(not ok and msg=="anon : line 1 : near '[' : index error : expected prefix expression")

    local src = "nil.1"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(not check('<eof>'))
    assertx(tosource(e), "nil")
    --local ok, msg = pcall(parser)
    --assert(not ok and msg=="anon : line 1 : near '.' : field error : expected prefix expression")

    local src = "-x[0]"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assert(tosource(e) == '(-x[0])')

    local src = ":X @{}"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), 'atm_tag_do(:X, @{})')

    local src = ":X (x)"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assert(tosource(e) == 'atm_tag_do(:X, (x))')
end

-- UNO

do
    local src = "#v"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assert(stringify(e) == "{e={tag=acc, tk={lin=1, str=v, tag=id}}, op={lin=1, str=#, tag=op}, tag=uno}")

    local src = "! - x"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assert(tosource(e) == "(!(-x))")
end

-- BIN

do
    local src = "a + 10"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assert(stringify(e) == "{e1={tag=acc, tk={lin=1, str=a, tag=id}}, e2={tag=num, tk={lin=1, str=10, tag=num}}, op={lin=1, str=+, tag=op}, tag=bin}")

    local src = "2 + 3 - 1"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local ok, msg = pcall(parser)
    assert(not ok and msg=="anon : line 1 : near '-' : operation error : use parentheses to disambiguate")

    local src = "2 * (a - 1)"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "(2 * (a - 1))")

    local src = "2 == -1"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assert(tosource(e) == "(2 == (-1))")

    local src = "x || y"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assert(tosource(e) == "(x || y)")

    local src = "- -1"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assert(tosource(e) == "(-(-1))")

    local src = "x++y++z"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "((x ++ y) ++ z)")

    local src = "(10+)"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local ok, msg = pcall(parser)
    assert(not ok and msg=="anon : line 1 : near ')' : expected expression")
end

print '--- IF / IFS ---'

do
    local src = "if x => 10 => 20"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    --assertx(tosource(e), "(x and 10) or 20")
    assertx(trim(tosource(e)), trim [[
        ifs {
            x => {
                10
            }
            else => {
                20
            }
        }
    ]])

    local src = "ifs { x => 10 ; y => nil ; else => 20 }"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    --assertx(tosource(e), "(x and 10) or ((y and nil) or ((true and 20) or (nil)))")
    assertx(trim(tosource(e)), trim [[
        ifs {
            x => {
                10
            }
            y => {
                nil
            }
            else => {
                20
            }
        }
    ]])
end

print '--- IS / IN ---'

do
    local src = "a ?? b"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "(a ?? b)")

    local src = "a ?> b"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "(a ?> b)")

    local src = "(a !? b) || (a <? b) || (a !> b) || (a <! b)"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "((((a !? b) || (a <? b)) || (a !> b)) || (a <! b))")
end

-- CALL / FUNC / RETURN / THROW

do
    local src = "f(x,y)"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assert(stringify(e) == "{es={{tag=acc, tk={lin=1, str=x, tag=id}}, {tag=acc, tk={lin=1, str=y, tag=id}}}, f={tag=acc, tk={lin=1, str=f, tag=id}}, tag=call}")
    assert(tosource(e) == "f(x, y)")

    local src = "f(["
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local ok, msg = pcall(parser)
    assertx(msg, "anon : line 1 : near '[' : expected expression")
    --assertx(msg, "anon : line 1 : near '{' : expected expression")

    local src = "f(10"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local ok, msg = pcall(parser)
    assert(not ok and msg=="anon : line 1 : near '<eof>' : expected ')'")

    local src = [[
        (func (x,y) {
            (x + y)
        })(1,2)
    ]]
    print("Testing...", "func 1")
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), trim [[
        (func (x, y) {
            (x + y)
        })(1, 2)
    ]])

    local src = [[
        f()()
    ]]
    print("Testing...", "func 1")
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assert(stringify(e) == "{es={}, f={es={}, f={tag=acc, tk={lin=1, str=f, tag=id}}, tag=call}, tag=call}")

    local src = "func (1) {}"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local ok, msg = pcall(parser)
    assert(not ok and msg=="anon : line 1 : near '1' : expected <id>")

    local src = "throw(:X)"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assertx(stringify(e), "{es={{tag=tag, tk={lin=1, str=:X, tag=tag}}}, tag=throw}")

    local src = "func (it) {}"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assertx(trim(tosource(e)), trim [[
        func (it) {
        }
    ]])
    --local ok, msg = pcall(parser_stmt)
    --assert(not ok and msg=="anon : line 1 : near 'it' : expected <id>")

    local src = "f '10' @{20}"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    check_err('<eof>')
    assertx(tosource(e), 'f("10")(@{[1]=20})')

    local src = "(o+o)::f(10)"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assertx(tosource(e), '(o + o)["f"]((o + o), 10)')
    warn(false, 'BUG: side effects')
end

print '--- FUNC / ... / dots ---'

do
    local src = "func (...) {}"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assertx(trim(tosource(e)), trim [[
        func (...) {
        }
    ]])

    local src = "func (..., a) {}"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local ok, msg = pcall(parser)
    assertx(msg, "anon : line 1 : near ',' : expected ')'")

    local src = "func (a, ...) {}"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assertx(trim(tosource(e)), trim [[
        func (a, ...) {
        }
    ]])

    local src = "..."
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assertx(tosource(e), "...")
end

print '--- CALL / METHOD / PIPE ---'

do
    local src = "10->f()"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "f(10)")

    local src = "10->f(20)"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "f(10, 20)")

    local src = "f() <- 10"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "f(10)")

    local src = "f<-10"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "f(10)")

    local src = "f(10)<-(20)"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "f(10, (20))")

    local src = "(10->f)<-20"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "(f(10, 20))")

    local src = "(func() {}) <- 20"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(trim(tosource(e)), trim [[
        (func () {
        })(20)
    ]])

    local src = "10->10"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "10(10)")
end

print '--- WHERE / PIPE ---'

do
    local src = "x+y where { x=10 ; y=20 }"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(trim(tosource(e)), trim [[
        func () {
            val x = 10
            val y = 20
            (x + y)
        }()
    ]])

    local src = "10-->f()"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "f(10)")

    local src = "10-->f-->g"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "g(f(10))")

    local src = "f<--10"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "f(10)")

    local src = "10-->(f<--20)"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "(f(10, 20))")

    local src = "10+1 --> f where { }"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local ok, msg = pcall(parser)
    assertx(msg, "anon : line 1 : near 'where' : operation error : use parentheses to disambiguate")

    local src = "10+1 <-- f where { }"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local ok, msg = pcall(parser)
    assertx(msg, "anon : line 1 : near 'where' : operation error : use parentheses to disambiguate")

    local src = "(10+1 <-- f) where { }"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(trim(tosource(e)), trim [[
        func () {
            (10 + 1)(f)
        }()
    ]])
end

-- EXEC / CORO / TASK / TASKS / YIELD / SPAWN / RESUME / PUB

do
    local src = "coro(f)"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(stringify(e), "{es={{tag=acc, tk={lin=1, str=f, tag=id}}}, f={tag=acc, tk={lin=1, str=coro, tag=id}}, tag=call}")

    local src = "task(T)"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "task(T)")

    local src = "tasks(10)"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local ok, msg = pcall(parser)
    assertx(msg, "anon : line 1 : near 'tasks' : expected expression")

    local src = "yield(x,10)"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assert(tosource(e) == "yield(x, 10)")

    local src = "emit(:X,10)"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assert(tosource(e) == "emit(nil, :X, 10)")

    local src = "emit(:X,10) in x"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assert(tosource(e) == "emit(x, :X, 10)")

    local src = "resume co()"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assert(tosource(e) == "resume(co)")

    local src = "spawn T(1,2,3)"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "pin _ = spawn(nil, T, 1, 2, 3)")
    --local ok, msg = pcall(parser)
    --assertx(msg, "anon : line 1 : near 'spawn' : expected expression")

    local src = "pub"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), 'pub')
end

print '-=- AWAIT -=-'

do
    local src = "await(:X, x+10)"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), trim [[
        await(:X, func (evt) {
            (x + 10)
        })
    ]])

    local src = "await (@20:x.100)"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "await(:clock, ((0 * 3600000) + ((20 * 60000) + ((x * 1000) + (100 * 1)))))")

    local src = "await(@10,x)"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local ok, msg = pcall(parser)
    assertx(msg, "anon : line 1 : near ',' : expected ')'")
end
