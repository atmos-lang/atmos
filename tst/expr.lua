require "atmos.lang.exec"
require "atmos.lang.parser"
require "atmos.lang.tosource"

-- PRIM

do
    local src = " a "
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assert(xtostring(e) == "{tag=acc, tk={lin=1, sep=1, str=a, tag=id}}")

    local src = "1.5"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assert(xtostring(e) == "{tag=num, tk={lin=1, sep=1, str=1.5, tag=num}}")

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
    assertx(xtostring(e), "{e={tag=acc, tk={lin=1, sep=1, str=a, tag=id}}, tag=parens, tk={lin=1, sep=1, str=(, tag=sym}}")

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
    assert(xtostring(e) == "{tag=nil, tk={lin=1, sep=1, str=nil, tag=key}}")

    local src = "false true"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e1 = parser()
    assert(xtostring(e1) == "{tag=bool, tk={lin=1, sep=1, str=false, tag=key}}")
    local e2 = parser()
    assert(check('<eof>'))
    assert(xtostring(e2) == "{tag=bool, tk={lin=1, sep=1, str=true, tag=key}}")
end

print '--- STRING / NATIVE ---'

do
    local src = ":x\n:1._"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e1 = parser()
    assertx(xtostring(e1), "{tag=tag, tk={lin=1, sep=1, str=:x, tag=tag}}")
    local e2 = parser()
    assert(check('<eof>'))
    assertx(xtostring(e2), "{tag=tag, tk={lin=2, sep=2, str=:1._, tag=tag}}")

    local src = "'xxx'\n'''1\n2\n'''"
    print("Testing...", "string 1")
    init()
    lexer_init("anon", src)
    lexer_next()
    local e1 = parser()
    assert(xtostring(e1) == "{tag=str, tk={lin=1, sep=1, str=xxx, tag=str}}")
    local e2 = parser()
    assert(xtostring(e2) == "{tag=str, tk={lin=2, sep=2, str=1\n2\n, tag=str}}")

    local src = "```f()```"
    print("Testing...", "native 1")
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assertx(xtostring(e), "{tag=nat, tk={lin=1, sep=1, str=f(), tag=nat}}")

    local src = "`f`()"
    print("Testing...", "native 2")
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assertx(tosource(e), "`f`()")

    local src = "f`v`"
    print("Testing...", "native 3")
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assertx(tosource(e), "f(`v`)")
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
    assertx(xtostring(e), "{es={{k={tag=num, tk={str=1, tag=num}}, v={tag=acc, tk={lin=1, sep=1, str=a, tag=id}}}}, tag=table}")

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
    assert(xtostring(e) == "{idx={tag=num, tk={lin=1, sep=1, str=1, tag=num}}, t={tag=acc, tk={lin=1, sep=1, str=x, tag=id}}, tag=index}")

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
    assert(xtostring(e) == "{e={tag=acc, tk={lin=1, sep=1, str=t, tag=id}}, op={lin=1, sep=1, str=#, tag=op}, tag=uno}")

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

    local src = ":X @{} ?? 10"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), '(atm_tag_do(:X, @{}) ?? 10)')

    local src = ":X (x)"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), 'atm_tag_do(:X, (x))')
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
    assert(xtostring(e) == "{e={tag=acc, tk={lin=1, sep=1, str=v, tag=id}}, op={lin=1, sep=1, str=#, tag=op}, tag=uno}")

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
    assert(xtostring(e) == "{e1={tag=acc, tk={lin=1, sep=1, str=a, tag=id}}, e2={tag=num, tk={lin=1, sep=1, str=10, tag=num}}, op={lin=1, sep=1, str=+, tag=op}, tag=bin}")

    local src = "a \n + 10"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assertx(tosource(e), "a")
    local ok, msg = pcall(parser)
    assertx(msg, "anon : line 2 : near '+' : expected expression")

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

    local src = "(x===y) && (x=!=y)"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "((x === y) && (x =!= y))")
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

    local src = "(a !? b) || (a ?> b) || (a !> b)"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "(((a !? b) || (a ?> b)) || (a !> b))")
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
    assert(xtostring(e) == "{es={{tag=acc, tk={lin=1, sep=1, str=x, tag=id}}, {tag=acc, tk={lin=1, sep=1, str=y, tag=id}}}, f={tag=acc, tk={lin=1, sep=1, str=f, tag=id}}, tag=call}")
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
    assert(xtostring(e) == "{es={}, f={es={}, f={tag=acc, tk={lin=1, sep=1, str=f, tag=id}}, tag=call}, tag=call}")

    local src = "f;()"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('('))
    assertx(xtostring(e), "{tag=acc, tk={lin=1, sep=1, str=f, tag=id}}")

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
    assertx(xtostring(e), "{es={{tag=tag, tk={lin=1, sep=1, str=:X, tag=tag}}}, f={tag=acc, tk={lin=1, sep=1, str=throw, tag=id}}, tag=call}")

    local src = ":X -> throw"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assertx(xtostring(e), "{es={{tag=tag, tk={lin=1, sep=1, str=:X, tag=tag}}}, f={tag=acc, tk={lin=1, sep=1, str=throw, tag=id}}, tag=call}")

    local src = ":X -> escape"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assertx(xtostring(e), "{es={{tag=tag, tk={lin=1, sep=1, str=:X, tag=tag}}}, f={tag=acc, tk={lin=1, sep=1, str=escape, tag=id}}, tag=call}")

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
    check_err('@{')
    assertx(tosource(e), 'f("10")')
    --local _,msg = pcall(parser)
    --assertx(msg, "anon : line 1 : near '@{' : expected '<eof>'\n")

    local src = "o::f"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    --local e = parser()
    --assert(check('<eof>'))
    local _,msg = pcall(parser)
    assertx(msg, "anon : line 1 : near '<eof>' : expected '('")
    --assertx(tosource(e), 'o::f')
    --warn(false, "met as expr")

    local src = "(o+o)::f(10)"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assertx(tosource(e), '(o + o)::f(10)')

    local src = "o::f::g(10)"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    --local e = parser()
    --assertx(tosource(e), 'o::f::g(10)')
    local _,msg = pcall(parser)
    assertx(msg, "anon : line 1 : near '::' : expected '('")
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

print '--- LAMBDA ---'

do
    local src = "\\{it}"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assertx(trim(tosource(e)), trim [[
        func (it) {
            it
        }
    ]])

    local src = "\\x{}"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assertx(trim(tosource(e)), trim [[
        func (x) {
        }
    ]])

    local src = "\\(){}"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assertx(trim(tosource(e)), trim [[
        func () {
        }
    ]])

    local src = "\\(x,...){(x,...)}"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assertx(trim(tosource(e)), trim [[
        func (x, ...) {
            (x, ...)
        }
    ]])
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
    --local ok, msg = pcall(parser)
    --assertx(msg, "anon : line 1 : near 'where' : operation error : use parentheses to disambiguate")
    local e = parser()
    assert(check('<eof>'))
    assertx(trim(tosource(e)), trim [[
        func () {
            f((10 + 1))
        }()
    ]])

    local src = "10+1 <-- f where { }"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    --local ok, msg = pcall(parser)
    --assertx(msg, "anon : line 1 : near 'where' : operation error : use parentheses to disambiguate")
    local e = parser()
    assert(check('<eof>'))
    assertx(trim(tosource(e)), trim [[
        func () {
            (10 + 1)(f)
        }()
    ]])


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

    local src = "10+1 where { }"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(trim(tosource(e)), trim [[
        func () {
            (10 + 1)
        }()
    ]])

    local src = "f<--10->g"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "f(g(10))")

    local src = "f <-- 10+10"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "f((10 + 10))")

    local src = "spawn T(v) where {v=10}"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(trim(tosource(e)), trim [[
        pin _ = func () {
            val v = 10
            spawn(false, T, v)
        }()
    ]])

    local src = "spawn {}"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(trim(tosource(e)), trim [[
        pin _ = spawn(true, {
        })
    ]])

    local src = "(a,b) where {a,b=(10,10)}"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(trim(tosource(e)), trim [[
        func () {
            val a, b = (10, 10)
            (a, b)
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
    assertx(xtostring(e), "{es={{tag=acc, tk={lin=1, sep=1, str=f, tag=id}}}, f={tag=acc, tk={lin=1, sep=1, str=coro, tag=id}}, tag=call}")

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
    assert(tosource(e) == "emit(:X, 10)")

    local src = "emit [xs] (:X,10)"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "emit_in(xs, :X, 10)")

    local src = "emit :X @{}"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('@{'))
    assertx(tosource(e), "emit(:X)")

    local src = "emit :X(10)"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('('))
    assertx(tosource(e), "emit(:X)")

    local src = "spawn T(1,2,3)"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "pin _ = spawn(false, T, 1, 2, 3)")
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

print '--- CLOCK ---'

do
    local src = "@1:v1:3.x"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "@1:v1:3.x")

    local src = "@3.x"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "@0:0:3.x")

    local src = "@.10"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "@0:0:0.10")
end

print '--- AWAIT ---'

do
    local src = "await(:X, x+10)"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "await(:X, (x + 10))")
--[=[
    assertx(tosource(e), trim [[
        await(:X, func (evt) {
            (x + 10)
        })
    ]])
]=]

    local src = "await @20:x.100"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    --assertx(tosource(e), "await(:clock, ((0 * 3600000) + ((20 * 60000) + ((x * 1000) + (100 * 1)))))")
    assertx(tosource(e), "await(@0:20:x.100)")

    local src = "await(@10,x)"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    --local ok, msg = pcall(parser)
    --assertx(msg, "anon : line 1 : near ',' : expected ')'")
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "await(@0:0:10.0, x)")

    local src = "await T()"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "await(spawn(T))")
--[=[
    assertx(trim(tosource(e)), trim [[
        do {
            pin atm_1 = spawn(nil, T, false)
            await(atm_1)
        }
    ]])
]=]
end

print '--- TOGGLE ---'

do
    local src = "toggle t(true)"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "toggle(t, true)")

    local src = "toggle x"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local ok, msg = pcall(parser)
    assertx(msg, "anon : line 1 : near 'toggle' : expected call syntax")

    local src = "toggle"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local ok, msg = pcall(parser)
    assertx(msg, "anon : line 1 : near '<eof>' : expected expression")

    local src = "toggle x(1,2)"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "toggle(x, 1, 2)")

    local src = "toggle f()"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "toggle(f)")
end
