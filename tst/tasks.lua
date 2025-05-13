-- LUA_PATH="/x/atmos/src/?.lua;" lua5.4 tasks.lua

-- PARSER

do
    local src = "coro()"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 1 : near ')' : expected expression")

    local src = "await(:1)"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check('<eof>'))
    assert(tostr_expr(e) == "await(:1)")

    local src = "await()"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 1 : near ')' : expected expression")

    local src = "await :X"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 1 : near ':X' : expected '('")

    local src = "await x"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 1 : near 'x' : expected '('")

    local src = "set y = await(:X)"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(check('<eof>'))
    assert(tostr_stmt(s) == "set y = await(:X)")

    local src = "set x = spawn f()"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    assert(check('<eof>'))
    assert(tostr_stmt(s) == "set x = spawn(f)")
end

-- EXEC

do
    local src = [[
        val T = func (v) { }
        print(T)
    ]]
    print("Testing...", "task 1: proto")
    local out = exec_string("anon.atm", src)
    assert(string.find(out, "function: 0x"))

    local src = [[
        val T1 = func () { }
        val T2 = func () { }
        print(T1 == T1)
        print(T1 == T2)
    ]]
    print("Testing...", "task 2: proto equal")
    local out = exec_string("anon.atm", src)
    assert(string.find(out, "true\nfalse\n"))

    local src = [[
        val T = func () { }
        val t1 = coro(T)
        val t2 = task(T)
        print(t1, t2)
    ]]
    print("Testing...", "task 3: coro/task")
    local out = exec_string("anon.atm", src)
    assert(string.find(out, "thread: 0x.*table: 0x"))

    local src = [[
        yield()
    ]]
    print("Testing...", "yield 1: no enclosing exec")
    local out = exec_string("anon.atm", src)
    warn(string.find(out, "thread: 0x.*table: 0x"))
end

-- SPAWN

do
    local src = [[
        val T = func () { }
        val t = spawn T()
        print(t)
    ]]
    print("Testing...", "spawn 1")
    local out = exec_string("anon.atm", src)
    assert(string.find(out, "table: 0x"))

    local src = [[
        val T = func () { }
        val t = spawn T()
        resume t()
    ]]
    print("Testing...", "spawn 1")
    local out = exec_string("anon.atm", src)
    assert(out == "anon.atm : line 3 : bad argument #1 to 'resume' (thread expected, got table)\n")
end
