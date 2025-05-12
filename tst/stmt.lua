-- LUA_PATH="/x/atmos/src/?.lua;" lua5.4 stmt.lua

require "lexer"
require "stmt"
require "tostr"

-- CALL / FUNC

do
    local src = "f(x,y)"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(check('<eof>'))
    assert(xtostring(s) == "{ e={ args={ { tag=acc, tk={ lin=1, str=x, tag=id } }, { tag=acc, tk={ lin=1, str=y, tag=id } } }, f={ tag=acc, tk={ lin=1, str=f, tag=id } }, tag=call }, tag=expr }")

    local src = "func f (v) { val x }"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(check('<eof>'))
    assert(xtostring(s) == "{ ids={ { lin=1, str=f, tag=id } }, sets={ { blk={ ss={ { ids={ { lin=1, str=x, tag=id } }, tag=dcl, tk={ lin=1, str=val, tag=key } } }, tag=block }, pars={ { lin=1, str=v, tag=id } }, tag=func } }, tag=dcl, tk={ str=val, tag=key } }")
end

-- BLOCK / DO / DEFER / SEQ / ; / MAIN

do
    local src = "do {}"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(xtostring(s) == "{ ss={  }, tag=block }")

    local src = "do { var x }"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(tostr_stmt(s) == trim [[
        do {
            var x
        }
    ]])

    local src = "do :X { escape(:X) }"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(check('<eof>'))
    assert(tostr_stmt(s) == trim [[
        do :X {
            escape(:X)
        }
    ]])

    local src = "defer { var x ; f(1) }"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(check('<eof>'))
    assert(tostr_stmt(s) == trim [[
        defer {
            var x
            f(1)
        }
    ]])

    local src = "defer { var x ; f(1) }"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(check('<eof>'))
    assert(tostr_stmt(s) == trim [[
        defer {
            var x
            f(1)
        }
    ]])

    local src = "; f () ; g () h()\ni() ;\n;"
    print("Testing...", "seq 1")
    init()
    lexer_string("anon", src)
    parser()
    local s = parser_main()
    assert(tostr_stmt(s) == trim [[
        do {
            f()
            g()
            h()
            i()
        }
    ]])

    local src = "var v2 ; [tp,v1,v2]"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_main)
    assert(not ok and msg=="anon : line 1 : near '[' : expected statement")
end

-- DCL / VAL / VAR / SET

do
    local src = "val x"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(xtostring(s) == "{ ids={ { lin=1, str=x, tag=id } }, tag=dcl, tk={ lin=1, str=val, tag=key } }")

    local src = "set y = 10"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(check('<eof>'))
    assert(xtostring(s) == "{ dsts={ { tag=acc, tk={ lin=1, str=y, tag=id } } }, srcs={ { tag=num, tk={ lin=1, str=10, tag=num } } }, tag=set }")

    local src = "var y = 10"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(check('<eof>'))
    assert(xtostring(s) == "{ ids={ { lin=1, str=y, tag=id } }, sets={ { tag=num, tk={ lin=1, str=10, tag=num } } }, tag=dcl, tk={ lin=1, str=var, tag=key } }")

    local src = "val [10]"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_stmt)
    assert(not ok and msg=="anon : line 1 : near '[' : expected <id>")

    local src = "set 1 = 1"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_stmt)
    assert(not ok and msg=="anon : line 1 : near '1' : expected assignable expression")

    local src = "set [1] = 1"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_stmt)
    assert(not ok and msg=="anon : line 1 : near '[' : expected assignable expression")

    local src = "set x, y, z = 10, 20"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(check('<eof>'))
    assert(tostr_stmt(s) == "set x, y, z = 10, 20")

    local src = "val x, y = 10, 20, 30"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(check('<eof>'))
    assert(tostr_stmt(s) == "val x, y = 10, 20, 30")
end

-- IF-ELSE

do
    local src = "if cnd { } else { val f }"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(check('<eof>'))
    assert(xtostring(s) == "{ cnd={ tag=acc, tk={ lin=1, str=cnd, tag=id } }, f={ ss={ { ids={ { lin=1, str=f, tag=id } }, tag=dcl, tk={ lin=1, str=val, tag=key } } }, tag=block }, t={ ss={  }, tag=block }, tag=if }")

    local src = "if true { }"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(check('<eof>'))
    assert(xtostring(s) == "{ cnd={ tag=bool, tk={ lin=1, str=true, tag=key } }, f={ ss={  }, tag=block }, t={ ss={  }, tag=block }, tag=if }")

    local src = "if f() { if (cnd) { val x } else { val y } }"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(check('<eof>'))
    assert(trim(tostr_stmt(s)) == trim [[
        if f() {
            if cnd {
                val x
            } else {
                val y
            }
        } else {

        }
    ]])

    local src = "loop { break }"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(check('<eof>'))
    assert(xtostring(s) == "{ blk={ ss={ { tag=break } }, tag=block }, tag=loop }")

    local src = "loop x in f() {}"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(check('<eof>'))
    assert(trim(tostr_stmt(s)) == trim [[
        loop x in f() {
        }
    ]])

    local src = "loop in f() {}"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(check('<eof>'))
    assert(trim(tostr_stmt(s)) == trim [[
        loop in f() {
        }
    ]])

    local src = "loop x {}"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(check('<eof>'))
    assert(trim(tostr_stmt(s)) == trim [[
        loop x {
        }
    ]])

    local src = "loop { until x }"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(check('<eof>'))
    assert(trim(tostr_stmt(s)) == trim [[
        loop {
            if x {
                break
            } else {
            }
        }
    ]])

    local src = "loop { while x }"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(check('<eof>'))
    assert(trim(tostr_stmt(s)) == trim [[
        loop {
            if x {
            } else {
                break
            }
        }
    ]])
end

-- CATCH

do
    local src = "catch :X { }"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(check('<eof>'))
    assert(xtostring(s) == "{ blk={ ss={  }, tag=block }, cnd={ e={ tag=tag, tk={ lin=1, str=:X, tag=tag } } }, tag=catch }")

    local src = "catch { }"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_main)
    assert(not ok and msg=="anon : line 1 : near '{' : expected expression")

    local src = "catch true, it>0 { }"
    print("Testing...", src)
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(check('<eof>'))
    assert(trim(tostr_stmt(s)) == trim [[
        catch true, func (it) {
            return((it > 0))
        } {
        }
    ]])
end
