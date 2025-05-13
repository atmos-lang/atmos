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

    local src = "spawn nil()"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 1 : near '(' : call error : expected prefix expression")
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
    warn(string.find(out, "thread: 0x.*table: 0x"), "yield error message")
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
    print("Testing...", "spawn 2")
    local out = exec_string("anon.atm", src)
    assert(out == "anon.atm : line 3 : bad argument #1 to 'resume' (thread expected, got table)\n")

    local src = [[
        spawn(func () {
            print(:ok)
        })()
    ]]
    print("Testing...", "spawn 3")
    local out = exec_string("anon.atm", src)
    assert(out == ":ok\n")

    local src = "spawn (nil)()"
    print("Testing...", src)
    local out = exec_string("anon.atm", src)
    assert(out == "anon.atm : line 1 : invalid spawn : expected task prototype\n")

    local src = [[
        val T = func () { yield() }
        val t = spawn T()
        print(t)
    ]]
    print("Testing...", "yield 1 : error : yield inside task")
    local out = exec_string("anon.atm", src)
    assert(out == "anon.atm : line 1 : invalid yield : unexpected task instance\n")

    local src = [[
        val T = func () { yield() }
        val t = task(T)
        resume t()
    ]]
    print("Testing...", "resume 1 : error : resume task")
    local out = exec_string("anon.atm", src)
    assert(out == "anon.atm : line 3 : bad argument #1 to 'resume' (thread expected, got table)\n")
end

-- SPAWN (scope)

do
    local src = [[
        do {
            spawn (func(){}) ()
        }
        print(:ok)
    ]]
    print("Testing...", "spawn 4")
    local out = exec_string("anon.atm", src)
    assert(out == ":ok\n")

    local src = [[
        val t = func () {
        }
        var co = if true => spawn t() => nil
        print(co)
    ]]
    print("Testing...", "spawn 5")
    local out = exec_string("anon.atm", src)
    assert(string.find(out, "table: 0x"))

    local src = [[
        val t = func () { print(:ok) }
        val f = func () {
            spawn t()
        }
        f()
    ]]
    print("Testing...", "spawn 6")
    local out = exec_string("anon.atm", src)
    assert(out == ":ok\n")

    local src = [[
        val T = func (v) {
            val x = []
            print(v)
            await(false)
        }
        val t = do :X {
            var v
            set v = 10
            escape :X(spawn T(v))
        }
        print(t)
    ]]
    print("Testing...", "spawn 7")
    local out = exec_string("anon.atm", src)
    assert(string.match(out, "10\ntable: 0x"))
end

-- EMIT

do
    local src = [[
        val T = func (v) {
            val e = await(true)
            print(v, e)
        }
        var t1 = spawn T(:1)
        var t2 = spawn T(:2)
        emit(1)
    ]]
    print("Testing...", "emit 1 : task term")
    local out = exec_string("anon.atm", src)
    assert(string.find(out, ":1\t1\n:2\ttable: 0x"))

    local src = [[
        val tk = func (v) {
            val e1 = await(true)
            print(v, e1)
            var e2 = await(true)
            print(v, e2)
        }
        var co1 = spawn tk(:1)
        spawn tk(:2)
        emit(1)
        emit(2)
        emit(3)
    ]]
    print("Testing...", "emit 2 : task term")
    local out = exec_string("anon.atm", src)
    assert(string.find(out, ":1\t1\n:2\t1\n:1\t2\n:2\ttable: 0x"))

    local src = [[
        var co1 = spawn (func () {
            var co2 = spawn (func () {
                await(true)              ;; awakes from outer bcast
                print(:2)
            }) ()
            await(true)                  ;; awakes from co2 termination
            print(:1)
        }) ()
        ;;`printf(">>> %d\n", CEU_DEPTH);`
        print(:bcast)
        emit()
    ]]
    print("Testing...", "emit 3 : task term")
    local out = exec_string("anon.atm", src)
print(out)
    assert(out == ":bcast\n:2\n:1\n")
end

-- EMIT (alien)

do
    local src = [[
        spawn (func () {
            val v = await(true)
            dump(v)
            await(false)
        }) (nil)
        do {
            val e = []
            emit(e)
        }
        print(:ok)
    ]]
    print("Testing...", "emit 1")
    local out = exec_string("anon.atm", src)
    assert(out == "{  }\n:ok\n")

    local src = [[
        val T = func () {
            val x = await(true)
            dump(x)
        }
        spawn T()
        do {
            val e = []
            emit(e)
        }
        print(:ok)
    ]]
    print("Testing...", "emit 2")
    local out = exec_string("anon.atm", src)
    assert(out == "{  }\n:ok\n")
end
