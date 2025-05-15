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
    warn(out == "anon.atm : line 2 : bad argument #1 to 'resume' (thread expected, got table)\n", "(\\nresume)(...)")

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
    warn(out == "anon.atm : line 2 : bad argument #1 to 'resume' (thread expected, got table)\n", "(\\nresume)(...)")
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
    assert(out == ":bcast\n:2\n:1\n")

    local src = [[
        val T = func () {
            await(true)
            print(:ok)
        }
        var t = spawn T()
        do {
            emit(1)
        }
    ]]
    print("Testing...", "emit 4")
    local out = exec_string("anon.atm", src)
    assert(out == ":ok\n")

    local src = [[
        var tk
        set tk = func () {
            await(true)
            val e = await(true)
            print(e)
        }
        var co1 = spawn (tk) ()
        var co2 = spawn tk ()
        do {
             emit(1)
             emit(2)
             emit(3)
        }
    ]]
    print("Testing...", "emit 5")
    local out = exec_string("anon.atm", src)
    assert(string.find(out, "2\ntable: 0x"))

    local src = [[
        var tk
        set tk = func () {
            val e1 = await(true)
            var e2
            do {
                print(e1)
                set e2 = await(true)
                print(e2)
            }
            do {
                print(e2)
                val e3 = await(true)
                print(e3)
            }
        }
        spawn tk ()
        emit(1)
        emit(2)
        emit(3)
        emit(4)
    ]]
    print("Testing...", "emit 6")
    local out = exec_string("anon.atm", src)
    assert(out == "1\n2\n2\n3\n")

    local src = [[
        spawn (func () {
            var evt1 = await(true)
            val evtx = evt1
            print(evt1)
            spawn (func () {
                var evt2 = evtx
                loop {
                    print(evt2)    ;; lost reference
                    set evt2 = await(true, type(it)!='table')
                }
            }) ()
            set evt1 = await(true)
        }) ()
        emit (10)
        emit (20)
    ]]
    print("Testing...", "emit 6")
    local out = exec_string("anon.atm", src)
    assertx(out, "10\n10\n20\n")
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
    print("Testing...", "alien 1")
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
            (func () { emit(e) })()
        }
        print(:ok)
    ]]
    print("Testing...", "alien 2")
    local out = exec_string("anon.atm", src)
    assert(out == "{  }\n:ok\n")
end

-- EMIT-AWAIT / PAYLOAD

do
    local src = [[
        val T = func () {
            loop {
                val it = await(true)
            }
        }
        spawn T ()
        emit([2])
        print(:ok)
    ]]
    print("Testing...", "payload 1")
    local out = exec_string("anon.atm", src)
    assert(out == ":ok\n")

    local src = [[
        var tk
        set tk = func (v) {
            print(v)
            val e1 = await(true, type(it)!='table')
            print(:e1,e1)
            val e2 = await(true, type(it)!='table')
            print(:e2,e2)
        }
        print(:1)
        var co1 = spawn (tk) (10)
        var co2 = spawn (tk) (10)
        catch true {
            (func () {
                print(:2)
                emit(20)
                print(:3)
                emit(30)
            })()
        }
    ]]
    print("Testing...", "payload 2")
    local out = exec_string("anon.atm", src)
    assert(out == ":1\n10\n10\n:2\n:e1\t20\n:e1\t20\n:3\n:e2\t30\n:e2\t30\n")

    local src = [[
        val T = func () {
            val e1 = do :brk {
                loop {
                    val it = await(true)
                    do {
                        val x = it
                        print(:in, it)    ;; TODO: 10
                    }
                    escape :brk()
                }
            }
        }
        spawn T()
        emit(10)
    ]]
    print("Testing...", "payload 3")
    local out = exec_string("anon.atm", src)
    assertx(out, ":in\t10\n")
end

-- LEXICAL ORDER

do
    local src = [[
        spawn (func () {
            spawn (func () {
                print(:1)
                await(true)              ;; 1. awakes from outer bcast
                print(:3)
            }) ()
            await(true)                  ;; 2. awakes from nested task
            await(true)                  ;; 3. awakes from outer bcast
            print(:ok)
        }) ()
        print(:2)
        emit([])
        print(:4)
    ]]
    print("Testing...", "order 1")
    local out = exec_string("anon.atm", src)
    assert(out == ":1\n:2\n:3\n:ok\n:4\n")

    local src = [[
        spawn (func () {
            spawn (func () {
                print(:1)
                await(true)              ;; awakes from outer bcast
                print(:3)
            }) ()
            await(true)                  ;; awakes from nested task
            ;;delay
            await(true)                  ;; does not awake from outer bcast
            print(:no)
        }) ()
        print(:2)
        emit()
        print(:4)
    ]]
    print("Testing...", "order 2")
    local out = exec_string("anon.atm", src)
    assert(out == ":1\n:2\n:3\n:no\n:4\n")

    local src = [[
        spawn (func () {
            spawn (func () {
                print(:1, await(true)) ;; awakes from outer bcast
            }) ()
            spawn (func () {
                loop {
                    await(true)
                }
            }) ()
            print(:2, await(true))      ;; awakes from :1 termination
        }) ()               ;; kill anon task which is pending on traverse
        emit(:out)
    ]]
    print("Testing...", "order 3")
    local out = exec_string("anon.atm", src)
    assert(string.find(out, ":1\t:out\n:2\ttable: 0x"))

    local src = [[
        var T
        set T = func (v) {
            spawn (func () {
                print(v)
                await(true)
                print(v)
            }) ()
            loop { await(true) }
        }
        spawn T(1)
        spawn T(2)
        emit()
    ]]
    print("Testing...", "order 4")
    local out = exec_string("anon.atm", src)
    assertx(out, "1\n2\n1\n2\n")
end

print '-=- EMIT IN -=- '

do
    local src = [[
        emit() in nil
        print(:ok)
    ]]
    print("Testing...", "emit-in 1")
    local out = exec_string("anon.atm", src)
    assertx(out, ":ok\n")

    local src = [[
        spawn (func () {
            val x = await(true)
            print(:ok, x)
        }) ()
        spawn (func () {
            emit(10) in :global
        }) ()
    ]]
    print("Testing...", "emit-in 2")
    local out = exec_string("anon.atm", src)
    assertx(out, ":ok\t10\n")

    local src = [[
        spawn (func () {
            val x = await(true)
            print(:ok, x)
        }) ()
        spawn (func () {
            emit(10) in :task
            print(:no)
            emit(20) in :global
        }) ()
    ]]
    print("Testing...", "emit-in 3")
    local out = exec_string("anon.atm", src)
    assertx(out, ":no\n:ok\t20\n")

    warn(false, 'TODO :parent')
end
