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

    local src = "nil.pub"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
    assert(not ok and msg=="anon : line 1 : near '.' : field error : expected prefix expression")

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
    print("Testing...", "yield 2 : error : yield inside task")
    local out = exec_string("anon.atm", src)
    assertx(out, "anon.atm : line 1 : invalid yield : unexpected enclosing task instance\n")

    local src = [[
        val T = func () { await(true) }
        val t = T()
        print(t)
    ]]
    print("Testing...", "yield 3 : error : await without enclosing task")
    local out = exec_string("anon.atm", src)
    assertx(out, "anon.atm : line 1 : invalid await : expected enclosing task instance\n")

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
    print("Testing...", "emit 7")
    local out = exec_string("anon.atm", src)
    assertx(out, "10\n10\n20\n")

    local src = [[
        val T = func (v) {
            val e = await(true)
            dump(e)
        }
        spawn T(10)
        catch true {
            (func () {
                emit ([])
            }) ()
        }
    ]]
    print("Testing...", "emit 8")
    local out = exec_string("anon.atm", src)
    assertx(out, "{  }\n")
end

print "-=- EMIT / SCOPE -=-"

do
    local src = [[
        val T = func (v) {
            val e = await(true)
            dump(e)
        }
        spawn T(10)
        (func () {
            emit ([])
        }) ()
    ]]
    print("Testing...", "emit scope 1")
    local out = exec_string("anon.atm", src)
    assertx(out, "{  }\n")

    local src = [[
        val T = func (v) {
            val x = await(true)
            dump(x)
        }
        spawn T(10)
        (func () {
            emit ([])
        }) ()
    ]]
    print("Testing...", "emit scope 2")
    local out = exec_string("anon.atm", src)
    assertx(out, "{  }\n")

    local src = [[
        val T = func () {
            val e = await(true)
            dump(e)
            await(true)
        }
        spawn T()
        spawn T()
        emit ([])
    ]]
    print("Testing...", "emit scope 3")
    local out = exec_string("anon.atm", src)
    assertx(out, "{  }\n{  }\n")

    local src = [[
        val T = func (v) {
            await(true)
            dump(v)
        }
        spawn T([])
        emit(nil)
    ]]
    print("Testing...", "emit scope 4")
    local out = exec_string("anon.atm", src)
    assertx(out, "{  }\n")

    local src = [[
        val T = func () {
            val e =
                (func (x) {
                    type(x)
                    return(x)
                }) (await(true))
            dump(e)
        }
        spawn T()
        do {
            emit ([20])
        }
        print(:ok)
    ]]
    print("Testing...", "emit scope 5")
    local out = exec_string("anon.atm", src)
    assertx(out, "{ 20 }\n:ok\n")

    local src = [[
        var tk
        set tk = func (v) {
            print(v)
            val e1 = await(true, (type(it)!='table') || (it['tag']!='task'))
            dump(e1)
            val e2 = await(true, (type(it)!='table') || (it['tag']!='task'))
            dump(e2)
        }
        print(:1)
        var co1 = spawn (tk) (10)
        var co2 = spawn (tk) (10)
        val ok,e = catch true {
            return ((func () {
                print(:2)
                emit ([20])
                print(:3)
                emit ([(30,30)])
                escape(true)
            }) ())
        }
        print(e)
    ]]
    print("Testing...", "emit scope 6")
    local out = exec_string("anon.atm", src)
    assertx(trim(out), trim [[
        :1
        10
        10
        :2
        { 20 }
        { 20 }
        :3
        { 30=30 }
        { 30=30 }
        true
    ]])

    local src = [[
        val f = func (v) {
            (func (x) {
                set x[0] = v[0]
                dump(x[0])
            }) ([0])
        }
        var T = func () {
            f(await(true))
        }
        spawn T()
        emit ([ [1] ])
    ]]
    print("Testing...", "emit scope 7")
    local out = exec_string("anon.atm", src)
    assertx(out, "{ 1 }\n")

    local src = [[
        val f = func (v) {
            dump(v[0])
        }
        var T = func () {
            f(await(true))
        }
        spawn T()
        emit ([ [1] ])
    ]]
    print("Testing...", "emit scope 8")
    local out = exec_string("anon.atm", src)
    assertx(out, "{ 1 }\n")

    local src = [[
        val f = func (v) {
            (func (x) {
                set x[0] = v[0]
                dump(x[0])
            }) ([0])
        }
        var T = func () {
            f(await(true))
        }
        spawn T()
        emit ([ [1] ])
    ]]
    print("Testing...", "emit scope 9")
    local out = exec_string("anon.atm", src)
    assertx(out, "{ 1 }\n")

    local src = [[
        val f = func (v) {
            dump(v)
        }
        val T = func () {
            f(await(true))
        }
        spawn T()
        do {
            do {
                do {
                    do {
                        do {
                            emit ([])
                        }
                    }
                }
            }
        }
    ]]
    print("Testing...", "emit scope 10")
    local out = exec_string("anon.atm", src)
    assertx(out, "{  }\n")

    local src = [[
        val f = func (v) {
            dump(v)
        }
        val T = func () {
            do {
                f(await(true))
            }
        }
        spawn T()
        do {
            do {
                do {
                    emit ([])
                }
            }
        }
    ]]
    print("Testing...", "emit scope 11")
    local out = exec_string("anon.atm", src)
    assertx(out, "{  }\n")
end

print "-=- EMIT / ALIEN -=-"

do
    local src = [[
        var x
        set x = []
        emit (x)
        dump(x)
    ]]
    print("Testing...", "alien 0")
    local out = exec_string("anon.atm", src)
    assertx(out, "{  }\n")

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

    local src = [[
        spawn (func () {
            val evt = await(true)
            val x = [nil]
            set x[0] = evt
            dump(x)
        }) ()
        do {
            val x
            emit([10])
        }
    ]]
    print("Testing...", "alien 3")
    local out = exec_string("anon.atm", src)
    assertx(out, "{ { 10 } }\n")

    local src = [[
        spawn (func () {
            val evt = await(true)
            do {
                val x = evt
                dump(x)
                await(true)
            }
        }) ()
        do {
            val x
            emit([10])
        }
    ]]
    print("Testing...", "alien 4")
    local out = exec_string("anon.atm", src)
    assertx(out, "{ 10 }\n")

    local src = [[
        spawn (func () {
            val evt = await(true)
            val x = evt[0]
            dump(x)
        }) ()
        do {
            val e = [ [10] ]
            emit(e)
        }
    ]]
    print("Testing...", "alien 5")
    local out = exec_string("anon.atm", src)
    assertx(out, "{ 10 }\n")
end

-- EMIT-AWAIT / PAYLOAD

do
    local src = [[
        val T = func () {
            loop {
                val e = await(true)
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
                    val e = await(true)
                    do {
                        val x = e
                        print(:in, e)    ;; TODO: 10
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

    local src = [[
        spawn (func () {
            var evt = await(true)
            val x = evt
            dump(x)
            set evt = await(true)
            dump(x)
        }) ()
        do {
            val e = [10]
            emit(e)
        }
        emit(nil)
    ]]
    print("Testing...", "payload 4")
    local out = exec_string("anon.atm", src)
    assertx(out, "{ 10 }\n{ 10 }\n")

    local src = [[
        var fff
        set fff = func (x) { return(x) }
        spawn (func () {
            var evt = await(true)
            do :X {
                loop {
                    if evt[:type]==:x {
                        escape :X()
                    }
                    set evt = await(true)
                }
            }
            print(99)
        }) ()
        print(1)
        emit ([type=:y])
        print(2)
        emit ([type=:x])
        print(3)
    ]]
    print("Testing...", "payload 5")
    local out = exec_string("anon.atm", src)
    assertx(out, "1\n2\n99\n3\n")

    local src = [[
        val fff = func (x) { return (x) }
        spawn (func () {
            print(1)
            var evt
            do {
                print(2)
                set evt = await(true)
                print(3)
            }
            print(4)
            fff(evt[:type])
            print(99)
        }) ()
        emit ([(:type,:y)])
        emit ([(:type,:x)])
    ]]
    print("Testing...", "payload 6")
    local out = exec_string("anon.atm", src)
    assertx(out, "1\n2\n3\n4\n99\n")

    local src = [[
        spawn {
            var evt
            loop {
                dump(evt)
                set evt = await(true)
            }
        }
        emit([])
    ]]
    print("Testing...", "payload 7")
    local out = exec_string("anon.atm", src)
    assertx(out, "nil\n{  }\n")

    local src = [[
        spawn {
            print(await(true))
        }
        emit(10,20)
    ]]
    print("Testing...", "payload 8: multi emit/await args")
    local out = exec_string("anon.atm", src)
    assertx(out, "20\t10\n")
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
    assert(string.find(out, ":1\t:out\t:out\n:2\ttable: 0x"))

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

print "-=- EMIT / IN -=-"

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

    local src = [[
        var T
        set T = func (v) {
            await(true)
            print(v)
            await(true)
        }
        var t1
        set t1 = spawn T (1)
        do {
            var t2
            set t2 = spawn T (2)
            emit(nil) in t2
        }
    ]]
    print("Testing...", "emit-in 4: in t2")
    local out = exec_string("anon.atm", src)
    assertx(out, "2\n")

    warn(false, 'TODO :parent')
end

print '-=- TASK / TERMINATION -=-'

do
    local src = [[
        spawn {
            val e = await(true)
            print(:ok, e)
        }
        val t = spawn {
        }
        emit(t)
    ]]
    print("Testing...", "task-term 1")
    local out = exec_string("anon.atm", src)
    assert(string.find(out, ":ok\ttable: 0x"))

    local src = [[
        spawn {
            val x = await(true)
            print(:ok, x)
        }
        val t = spawn {
        }
        emit(t)
    ]]
    print("Testing...", "task-term 2")
    local out = exec_string("anon.atm", src)
    assert(string.find(out, ":ok\ttable: 0x"))

    local src = [[
        spawn {
            await(true)
            print(:1)
            val x = await(true)
            print(:ok, x)
        }
        val t = spawn {
            await(true)
            print(:2)
        }
        emit(nil)
        emit(t)
    ]]
    print("Testing...", "task-term 3")
    local out = exec_string("anon.atm", src)
    assert(string.find(out, ":1\n:2\n:ok\ttable: 0x"))

    local src = [[
        spawn {
            val t = spawn {
                val e = await(true)
                print(:1, e)
            }
            print(:0)
            (func (x) {
                if (type(x) == 'table') {
                    print(:2, x == t)
                }
            }) (await(true))
        }
        emit(:a)
        emit(:b)
    ]]
    print("Testing...", "task-term 4")
    local out = exec_string("anon.atm", src)
    assertx(out, ":0\n:1\t:a\n:2\ttrue\n")
end

print '-=- PUB -=-'

do
    local src = [[
        val t = func () {
            set pub = []
            return (pub)
        }
        val a = spawn (t) ()
        val x = a.pub
        dump(x)
    ]]
    print("Testing...", "pub 1")
    local out = exec_string("anon.atm", src)
    assertx(out, "{  }\n")

    local src = [[
        val T = func () {
            print(pub)
            await(true)
        }
        val t = spawn T()
        print(t.pub)
    ]]
    print("Testing...", "pub 2")
    local out = exec_string("anon.atm", src)
    assertx(out, "nil\nnil\n")

    local src = [[
        val T = func () {
            set pub = 10
            await(true)
        }
        val t = spawn T()
        print(t.pub)
    ]]
    print("Testing...", "pub 3")
    local out = exec_string("anon.atm", src)
    assertx(out, "10\n")

    local src = [[
        val T = func () {
            do {
                val x = []
                set pub = x
                return(pub)
            }
        }
        val t = spawn T()
        dump(t.pub)
    ]]
    print("Testing...", "pub 4")
    local out = exec_string("anon.atm", src)
    assertx(out, "{  }\n")

    local src = [[
        val T = func () {
        }
        val t = spawn T()
        do {
            val x = []
            set t.pub = x
        }
        dump(t.pub)
    ]]
    print("Testing...", "pub 5")
    local out = exec_string("anon.atm", src)
    assertx(out, "{  }\n")
end

print '-=- NESTED -=-'

do
    local src = [[
        spawn (func () {
            val v = 10
            spawn( func () {
                print(v)
            }) ()
            await(true)
        }) ()
    ]]
    print("Testing...", "nested 1")
    local out = exec_string("anon.atm", src)
    assertx(out, "10\n")

    local src = [[
        val F = func () {
            val v = 10
            val f = func () {
                return(v)
            }
            return(f())
        }
        print(F())
    ]]
    print("Testing...", "nested 2")
    local out = exec_string("anon.atm", src)
    assertx(out, "10\n")

    local src = [[
        spawn( func () {
            val t = []
            spawn (func () {
                await(true)
                dump(t)
            }) ()
            await(true)
        }) ()
        coro(func () { })
        emit(true)
    ]]
    print("Testing...", "nested 3")
    local out = exec_string("anon.atm", src)
    assertx(out, "{  }\n")

    local src = [[
        do {
            val v = 10
            spawn (func () {
                print(v)
            }) ()
        }
    ]]
    print("Testing...", "nested 4")
    local out = exec_string("anon.atm", src)
    assertx(out, "10\n")

    local src = [[
        spawn (func () {
            do {
                spawn (func () {
                    await(true)
                }) ()
                await(true)
            }
            emit([])
        })()
        emit(99)
        print(:ok)
    ]]
    print("Testing...", "nested 4")
    local out = exec_string("anon.atm", src)
    assertx(out, ":ok\n")

    local src = [[
        spawn (func () {
            val fff = func () {
                print(:ok)
            }
            val T = func () {
                fff()
            }
            await(true)
            spawn T()
            await(true)
        }) ()
        emit(true)
    ]]
    print("Testing...", "nested 5")
    local out = exec_string("anon.atm", src)
    assertx(out, ":ok\n")

    local src = [[
        spawn (func () {
            do {
                spawn (func () {
                    await(true)
                    print(:2)
                }) ()
                loop { await(true) } ;;thus { it => nil }
            }
            print(333)
        }) ()
        do {
            print(:1)
            emit(true)
            print(:3)
        }
        print(:END)
    ]]
    print("Testing...", "nested 6")
    local out = exec_string("anon.atm", src)
    assertx(out, ":1\n:2\n:3\n:END\n")
end

print '-=- ABORTION -=-'

do
    local src = [[
        spawn (
            func () {
                defer {
                    print(:defer)
                }
            }
        ) ()
    ]]
    print("Testing...", "abort 1")
    local out = exec_string("anon.atm", src)
    assertx(out, ":defer\n")

    local src = [[
        spawn (
            func () {
                defer {
                    print(:defer)
                }
                await(false)
            }
        ) ()
    ]]
    print("Testing...", "abort 2")
    local out = exec_string("anon.atm", src)
    assertx(out, ":defer\n")

    local src = [[
        print(:1)
        var x = 0
        do :X {
            loop {
                if x == 2 {
                    escape :X()
                }
                set x = x + 1
                print(:2)
                spawn( func () {
                    defer {
                        print(:defer)
                    }
                    await(false)
                }) ()
                print(:3)
            }
        }
        print(:4)
    ]]
    print("Testing...", "abort 3")
    local out = exec_string("anon.atm", src)
    assertx(out, ":1\n:2\n:3\n:defer\n:2\n:3\n:defer\n:4\n")

    local src = [[
        spawn (func () {
            val t = spawn( func () {
                await(false)
            }) ()
            await(false)
        } )()
        emit(true)
        print(:ok)
    ]]
    print("Testing...", "abort 4")
    local out = exec_string("anon.atm", src)
    assertx(out, ":ok\n")

    local src = [[
        do {
            spawn (func () {
                do {
                    val t1 = spawn (func () {
                        val t2 = spawn (func () {
                            await(true)
                            print(:1)
                        }) ()
                        await(true, it==t2)
                        print(:2)
                    }) ()
                    await(true, it==t1)
                    print(:3)
                }
                await(:X)
                print(:99)
            }) ()
            print(:0)
            emit(true)
            print(:4)
        }
    ]]
    print("Testing...", "abort 5")
    local out = exec_string("anon.atm", src)
    assertx(out, ":0\n:1\n:2\n:3\n:4\n")

    local src = [[
        spawn (func () {
            ;;print(:x, `:number ceu_depth(ceu_block)`)
            do {
                spawn (func () {
                    await(true)
                }) ()
                await(true)
            }
            ;;print(:y, `:number *ceu_dmin`)
            do {
                val x1
                do {
                    val x2
                    ;;print(:z, `:number *ceu_dmin`, `:number ceu_depth(ceu_block)`)
                    await(true)
                }
            }
        }) ()
        emit(true)
        print(:ok)
    ]]
    print("Testing...", "abort 6")
    local out = exec_string("anon.atm", src)
    assertx(out, ":ok\n")

    local src = [[
        spawn (func () {
            do {
                spawn (func () {
                    spawn (func () {
                        await(true)
                        print(:1)
                    }) ()
                    await(true)
                    print(:2)
                }) ()
                await(true)
                print(:3)
            }
            print(:4)
            await(true)
            print(:5)
        }) ()
        print(:0)
        emit(true)
        print(:6)
    ]]
    print("Testing...", "abort 7")
    local out = exec_string("anon.atm", src)
    assertx(out, ":0\n:1\n:2\n:3\n:4\n:5\n:6\n")

    local src = [[
        spawn (func () {
            spawn(func () {
                await(true)
                emit(true) in :global
            })()
            await(true)
        })()
        emit(true)
        print(:ok)
    ]]
    print("Testing...", "abort 8")
    local out = exec_string("anon.atm", src)
    assertx(out, ":ok\n")

    local src = [[
        spawn (func () {
            val T = func () {
                print(:1)
                await(true)
                print(:a)
                await(true)
            }
            val t = spawn T()
            spawn( func () {
                print(:2)
                await(true)
                print(:b)
                emit(true) in t     ;; pending
                print(999)
            } )()
            print(:3)
            await(true)
            print(:ok)
        })()
        emit(true)
    ]]
    print("Testing...", "abort 9")
    local out = exec_string("anon.atm", src)
    assertx(out, ":1\n:2\n:3\n:a\n:b\n:ok\n")

    local src = [[
        spawn (func () {
            val T = func () {
                await(true)
                await(true)
            }
            val t = spawn T()
            spawn( func () {
                await(true)
                emit(true) in t
                print(999)
            } )()
            await(true)
            print(:ok)
        })()
        emit(true)
    ]]
    print("Testing...", "abort 10")
    local out = exec_string("anon.atm", src)
    assertx(out, ":ok\n")

    local src = [[
        val T = func () {
            await(true)
        }
        val t = spawn T()
        ;;spawn( func () {
            spawn (func () {
                print(:A)
                (func (it) { print(it==t) }) (await(true))
                print(:C)
            }) ()
            emit(true) in t
        ;;})()
        print(:ok)
    ]]
    print("Testing...", "abort 11")
    local out = exec_string("anon.atm", src)
    assertx(out, ":A\ntrue\n:C\n:ok\n")

    local src = [[
        val T = func () {
            print(:1)
            defer {
                print(:ok)
            }
            print(:2)
            loop {
                await(true)
            }
            print(999)
        }
        spawn T()
    ]]
    print("Testing...", "abort 12")
    local out = exec_string("anon.atm", src)
    assertx(out, ":1\n:2\n:ok\n")

    local src = [[
        spawn (func () {
            ;;await(true)
            do {
                spawn (func () {
                    await(true)
                }) ()
                await(true)
            }
            emit([])
        })()
        ;;emit(true)
        emit(true)
        print(:ok)
    ]]
    print("Testing...", "abort 13")
    local out = exec_string("anon.atm", src)
    assertx(out, ":ok\n")

    local src = [[
        spawn (func () {
            await(true)
            do {
                spawn (func () {
                    await(true)
                    emit(true) in :global
                }) ()
                await(true)
            }
            emit(true)
        })()
        emit(true)
        print(:ok)
    ]]
    print("Testing...", "abort 14")
    local out = exec_string("anon.atm", src)
    assertx(out, ":ok\n")

    local src = [[
        spawn (func () {
            val T = func () {
                print(:1)
                await(true)
                print(:a)
                await(true)
            }
            val t = spawn T()
            spawn( func () {
                print(:2)
                await(true)
                print(:b)
                emit(true) in t
                print(999)
            } )()
            print(:3)
            await(true)
            print(:ok)
        })()
        emit(true)
    ]]
    print("Testing...", "abort 15")
    local out = exec_string("anon.atm", src)
    assertx(out, ":1\n:2\n:3\n:a\n:b\n:ok\n")

    local src = [[
        spawn (func () {
            val T = func () {
                await(true)
                await(true)
                print(:2)
            }
            val t = spawn T()
            spawn( func () {
                await(true)
                do {
                    print(:1)
                    emit(true) in t
                    print(:no)
                }
                print(:no)
            } )()
            await(true)
            print(:3)
        })()
        print(:0)
        emit(true)
        print(:4)
    ]]
    print("Testing...", "abort 16")
    local out = exec_string("anon.atm", src)
    assertx(out, ":0\n:1\n:2\n:3\n:4\n")

    local src = [[
        spawn (func () {
            spawn (func () {
                await(true)
                defer {
                    print(:1)
                }
                emit(true) in :global
            }) ()
            await(true)
            print(:0)
        }) ()
        emit(true)
        print(:2)
    ]]
    print("Testing...", "abort 17")
    local out = exec_string("anon.atm", src)
    assertx(out, ":0\n:1\n:2\n")

    local src = [[
        spawn (func () {
            val T = func () {
                await(true)
                await(true)
                print(:2)
            }
            val t = spawn T()
            spawn( func () {
                await(true)
                do {
                    defer {
                        print(:ok)
                    }
                    print(:1)
                    emit(true) in t
                    print(:no)
                }
                print(:no)
            } )()
            await(true)
            print(:3)
        })()
        print(:0)
        emit(true)
        print(:4)
    ]]
    print("Testing...", "abort 18")
    local out = exec_string("anon.atm", src)
    assertx(out, ":0\n:1\n:2\n:3\n:ok\n:4\n")

    local src = [[
        spawn (func () {
            val T = func () {
                await(true)
                await(true)
                print(:2)
            }
            val t = spawn T()
            spawn( func () {
                await(true)
                do {
                    defer {
                        print(:ok)
                    }
                    print(:1)
                    (func () {
                        emit(true) in t
                    }) ()
                    print(:no)
                }
                print(:no)
            } )()
            await(true)
            print(:3)
        })()
        print(:0)
        emit(true)
        print(:4)
    ]]
    print("Testing...", "abort 19")
    local out = exec_string("anon.atm", src)
    assertx(out, ":0\n:1\n:2\n:3\n:ok\n:4\n")

    local src = [[
        val f = func (t) {
            defer {
                print(:ok)
            }
            print(:1)
            emit(true) in t
            print(:no)
        }
        spawn (func () {
            val T = func () {
                await(true)
                await(true)
                print(:2)
            }
            var t = spawn T()
            spawn( func () {
                await(true)
                do {
                    f(t)
                    print(:no)
                }
                print(:no)
            } )()
            await(true)
            print(:3)
        })()
        print(:0)
        emit(true)
        print(:4)
    ]]
    print("Testing...", "abort 20")
    local out = exec_string("anon.atm", src)
    assertx(out, ":0\n:1\n:2\n:3\n:ok\n:4\n")

    local src = [[
        spawn (func () {
            spawn (func () {
                await(true)
                do {
                    defer {
                        print(:3)
                    }
                    print(:1)
                    emit(true) in :global
                    print(:999)
                }
            }) ()
            await(true)
            print(:2)
        }) ()
        emit(true) in :global
    ]]
    print("Testing...", "abort 21")
    local out = exec_string("anon.atm", src)
    assertx(out, ":1\n:2\n:3\n")

    local src = [[
        spawn (func () {
            spawn (func () {
                await(true)
                print(:1)
                emit(true) in :global
                print(:999)
            }) ()
            await(true)
            print(:2)
        }) ()
        emit(true) in :global
        print(:3)
    ]]
    print("Testing...", "abort 22")
    local out = exec_string("anon.atm", src)
    assertx(out, ":1\n:2\n:3\n")

    local src = [[
        spawn (func () {
            spawn (func () {
                await(true)
                emit(true) in :global
            }) ()
            await(true)
        }) ()
        emit(true)
        print(:ok)
    ]]
    print("Testing...", "abort 23")
    local out = exec_string("anon.atm", src)
    assertx(out, ":ok\n")

    local src = [[
        val f = func () {
            do {
                defer {
                    print(:4)    ;; TODO: aborted func should execute defer
                }
                print(:1)
                emit(true) in :global
                print(:999)
            }
        }
        spawn (func () {
            spawn (func () {
                await(true)
                do {
                    defer {
                        print(:3)
                    }
                    f()
                    print(:999)
                }
            }) ()
            await(true)
            print(:2)
        }) ()
        emit(true) in :global
    ]]
    print("Testing...", "abort 24")
    local out = exec_string("anon.atm", src)
    assertx(out, ":1\n:2\n:4\n:3\n")

    local src = [[
        spawn (func () {
            spawn (func () {
                await(true)
                do {
                    defer {
                        print(:3)
                    }
                    print(:1)
                    resume (coro (func () {
                        ;; TODO: coro hides outer t.co and consumes the error
                        emit(true) in :global
                    })) ()
                    print(:999)
                }
            }) ()
            await(true)
            print(:2)
        }) ()
        emit(true) in :global
    ]]
    print("Testing...", "abort 25")
    local out = exec_string("anon.atm", src)
    warnx(out, "TODO - coro - emit") --":1\n:2\n:3\n")

    local src = [[
        spawn (func () {
            spawn (func () {
                await(true)
                spawn (func () {
                    emit(true) in :global
                }) ()
            }) ()
            await(true)
        }) ()
        emit(true) in :global
        print(:ok)
    ]]
    print("Testing...", "abort 26")
    local out = exec_string("anon.atm", src)
    assertx(out, ":ok\n")

    local src = [[
        spawn (func () {
            spawn (func () {
                await(true)
                do {
                    defer {
                        print(:3)
                    }
                    print(:1)
                    spawn (func () {
                        emit(true) in :global
                    }) ()
                    print(:999)
                }
            }) ()
            await(true)
            print(:2)
        }) ()
        emit(true) in :global
    ]]
    print("Testing...", "abort 27")
    local out = exec_string("anon.atm", src)
    assertx(out, ":1\n:2\n:3\n")

    local src = [[
        val f = func () {
            do {
                defer {
                    print(:4)    ;; TODO: aborted func should execute defer
                }
                print(:1)
                ;;resume (coro(func () {
                    emit(true) in :global
                ;;})) ()
                print(:y999)
            }
        }
        spawn (func () {
            spawn (func () {
                await(true)
                do {
                    defer {
                        print(:3)
                    }
                    f()
                    print(:x999)
                }
            }) ()
            await(true)
            print(:2)
        }) ()
        emit(true) in :global
    ]]
    print("Testing...", "abort 28")
    local out = exec_string("anon.atm", src)
    assertx(out, ":1\n:2\n:4\n:3\n")

    local src = [[
        val f = func () {
            val x = []
            emit(true) in :global
        }
        spawn (func () {
            spawn (func () {
                await(true)
                f()
                print(:nooo)
            }) ()
            await(true)
        }) ()
        emit(true)
        print(:ok)
    ]]
    print("Testing...", "abort 29")
    local out = exec_string("anon.atm", src)
    assertx(out, ":ok\n")

    local src = [[
        val f = func () {
            do {
                defer {
                    print(:4)    ;; TODO: aborted func' should execute defer
                }
                print(:1)
                spawn (func () {
                    emit(true) in :global
                }) ()
                print(:y999)
            }
        }
        spawn (func () {
            spawn (func () {
                await(true)
                do {
                    defer {
                        print(:3)
                    }
                    f()
                    print(:x999)
                }
            }) ()
            await(true)
            print(:2)
        }) ()
        emit(true) in :global
    ]]
    print("Testing...", "abort 30")
    local out = exec_string("anon.atm", src)
    assertx(out, ":1\n:2\n:4\n:3\n")

    local src = [[
        spawn (func () {
            spawn (func () {
                await(true)
                do {
                    ;;resume (coroutine (coro' () {
                        do {
                            defer {
                                print(:3)
                            }
                            print(:1)
                            emit(true) in :global
                        }
                    ;;})) ()
                    print(:999)
                }
            }) ()
            await(true)
            print(:2)
        }) ()
        emit(true) in :global
    ]]
    print("Testing...", "abort 31")
    local out = exec_string("anon.atm", src)
    assertx(out, ":1\n:2\n:3\n")

    local src = [[
        spawn (func () {
            spawn (func () {
                await(true)
                do {
                    spawn (func () {
                        do {
                            defer {
                                print(:3)
                            }
                            print(:1)
                            emit(true) in :global
                        }
                    }) ()
                    print(:999)
                }
            }) ()
            await(true)
            print(:2)
        }) ()
        emit(true) in :global
    ]]
    print("Testing...", "abort 32")
    local out = exec_string("anon.atm", src)
    assertx(out, ":1\n:2\n:3\n")

    local src = [[
        spawn (func () {
            print(:1)
            ;;resume (coroutine (coro' () {
            spawn {
                defer {
                    print(:ok)
                }
                print(:2)
                await(true)
                print(:999)
            }
            ;;})) ()
            ;; refs=0 --> :ok
            print(:3)
        }) ()
    ]]
    print("Testing...", "abort 33")
    local out = exec_string("anon.atm", src)
    --assertx(out, ":1\n:2\n:ok\n:3\n")
    assertx(out, ":1\n:2\n:3\n:ok\n")

    local src = [[
        spawn (func () {
            print(:1)
            val co = (coro (func () {
                defer {
                    print(:ok)
                }
                print(:2)
                yield()
                print(:999)
            }))
            resume co ()
            print(:3)
            coroutine['close'](co)
        }) ()
    ]]
    print("Testing...", "abort 34")
    local out = exec_string("anon.atm", src)
    assertx(out, ":1\n:2\n:3\n:ok\n")

    local src = [[
        spawn (func () {
            print(:1)
            ;;resume (coro (func () {
            spawn {
                defer {
                    print(:ok)
                }
                print(:2)
                await(true)
            }
            ;;})) ()
            ;; refs=0 --> :ok
            await(true)
            print(:3)
        }) ()
        emit(true)
        print(:4)
    ]]
    print("Testing...", "abort 35")
    local out = exec_string("anon.atm", src)
    assertx(out, ":1\n:2\n:ok\n:3\n:4\n")

    local src = [[
        spawn (func () {
            print(:1)
            spawn (func () {
                print(:2)
                await(true)
                print(:6)
                emit(true) in :global
            }) ()
            ;;resume (coro (func () {
            spawn {
                defer {
                    print(:ok)
                }
                print(:3)
                await(true)
            }
            ;;})) ()
            print(:4)
            await(true)
            print(:7)
        }) ()
        print(:5)
        emit(true)
        print(:8)
    ]]
    print("Testing...", "abort 36")
    local out = exec_string("anon.atm", src)
    --assertx(out, ":1\n:2\n:3\n:ok\n:4\n:5\n:6\n:7\n:8\n")
    assertx(out, ":1\n:2\n:3\n:4\n:5\n:6\n:ok\n:7\n:8\n")
end

print '-=- THROW / CATCH -=-'

do
    local src = [[
        spawn (func () {
            catch :e1 ;;;(it | it==:e1);;; {
                error(:e1)
            }
            print(:e1)
            await(true)
            error(:e2)
        })()
        catch :e2 ;;;(it| :e2);;; {
            emit(true)
            emit(true)
            print(99)
        }
        print(:e2)
    ]]
    print("Testing...", "catch 1")
    local out = exec_string("anon.atm", src)
    assertx(out, ":e1\n:e2\n")
end
