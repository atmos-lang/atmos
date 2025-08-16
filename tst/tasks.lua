require "atmos.lang.exec"

-- PARSER

do
    local src = "coro()"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assert(tosource(e) == "coro()")
    --local ok, msg = pcall(parser)
    --assertx(msg, "anon : line 1 : near ')' : expected expression")

    local src = "await(:1)"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assert(tosource(e) == "await(:1)")

    local src = "await()"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assert(tosource(e) == "await()")
    --local ok, msg = pcall(parser)
    --assert(not ok and msg=="anon : line 1 : near ')' : expected expression")

    local src = "await :X"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local s = parser()
    assert(check('<eof>'))
    assertx(tosource(s), "await(:X)")

    local src = "await x"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local _,msg = pcall(parser)
    assertx(msg, "anon : line 1 : near 'await' : expected call")

    local src = "set y = await(:X)"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local s = parser()
    assert(check('<eof>'))
    assert(tosource(s) == "set y = await(:X)")

    local src = "set x = spawn f()"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    --local ok, msg = pcall(parser)
    --assertx(msg, "anon : line 1 : near 'set' : expected expression")
    lexer_next()
    local _,msg = pcall(parser_main)
    assertx(msg, "anon : line 1 : near '=' : sequence error : expected ';' or new line")
    --assertx(msg, "anon : line 1 : near '=' : expected expression")

    local src = "spawn nil()"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local ok, msg = pcall(parser)
    assertx(msg, "anon : line 1 : near 'spawn' : expected call")
    --assertx(msg, "anon : line 1 : near '(' : call error : expected prefix expression")

    local src = "val x = nil.pub"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local ok, msg = pcall(parser_main)
    --assertx(msg, "anon : line 1 : near '.' : field error : expected prefix expression")
    --assertx(msg, "anon : line 1 : near '.' : expected expression")
    assertx(msg, "anon : line 1 : near '.' : sequence error : expected ';' or new line")
end

-- EXEC

do
    local src = [[
        val T = func (v) { }
        print(T)
    ]]
    print("Testing...", "task 1: proto")
    local out = atm_test(src)
    assertfx(out, "function: 0x")

    local src = [[
        val T1 = func () { }
        val T2 = func () { }
        print(T1 == T1)
        print(T1 == T2)
    ]]
    print("Testing...", "task 2: proto equal")
    local out = atm_test(src)
    assert(string.find(out, "true\nfalse\n"))

    local src = [[
        val T = func () { }
        val t1 = coroutine.create(T)
        pin t2 = task(T)
        print(t1, t2)
    ]]
    print("Testing...", "task 3: coro/task")
    local out = atm_test(src)
    assertfx(out, "thread: 0x.*table: 0x")

    local src = [[
        yield()
    ]]
    print("Testing...", "yield 1: no enclosing exec")
    local out = atm_test(src)
    warn(string.find(out, "thread: 0x.*table: 0x"), "yield error message")
end

-- SPAWN

do
    local src = [[
        val T = func () { }
        pin t = spawn T()
        print(t)
    ]]
    print("Testing...", "spawn 1")
    local out = atm_test(src)
    assert(string.find(out, "table: 0x"))

    local src = [[
        val T = func () { }
        pin t = spawn T()
        coroutine.resume(t)
    ]]
    print("Testing...", "spawn 2")
    local out = atm_test(src)
    warn(out == "anon.atm : line 2 : bad argument #1 to 'resume' (thread expected, got table)\n", "(\\nresume)(...)")

    local src = [[
        spawn(func () {
            print(:ok)
        })()
    ]]
    print("Testing...", "spawn 3")
    local out = atm_test(src)
    assert(out == "ok\n")

    local src = "spawn (nil)() ; nil"
    print("Testing...", src)
    local out = atm_test(src)
    assertx(trim(out), trim [[
        ==> ERROR:
         |  [C]:-1 (call)
         v  [string "anon.atm"]:1 (throw)
        ==> invalid spawn : expected task prototype
    ]])

    local src = [[
        val T = func () { coroutine.yield() }
        pin t = spawn T()
        print(t)
    ]]
    print("Testing...", "yield 2 : error : yield inside task")
    local out = atm_test(src)
    --assertx(out, "anon.atm : line 1 : invalid yield : unexpected enclosing task instance")
    assertfx(out, "table: 0x")

    --[=[
    local src = [[
        val T = func () { await(true) } ;; no longer an error (freezes test)
        val t = T()
        print(t)
    ]]
    print("Testing...", "yield 3 : error : await without enclosing task")
    local out = atm_test(src)
    assertx(out, "anon.atm : line 1 : invalid await : expected enclosing task instance")
    ]=]

    local src = [[
        val T = func () { coroutine.yield() }
        val t = task(T)
        coroutine.resume(t)
    ]]
    print("Testing...", "resume 1 : error : resume task")
    local out = atm_test(src)
    warn(out == "anon.atm : line 2 : bad argument #1 to 'resume' (thread expected, got table)\n", "(\\nresume)(...)")

    local src = [[
        var T
        set T = func (x,y) {
            print(x,y)
        }
        spawn T(1,2)
    ]]
    print("Testing...", "spawn 1")
    local out = atm_test(src)
    assertx(out, "1\t2\n")

    local src = [[
        spawn (func () {}) ()
        print(:ok)
    ]]
    print("Testing...", "spawn 2")
    local out = atm_test(src)
    assertx(out, "ok\n")

    local src = [[
        spawn (func () {})
    ]]
    print("Testing...", "spawn 3: error")
    local out = atm_test(src)
    assertx(out, "anon.atm : line 1 : near 'spawn' : expected call")

    local src = [[
        val T = func (v) {
            spawn (func () {
                await(true)
                print(:ok)
            }) ()
            emit (:ok)
        }
        spawn T(2)
    ]]
    print("Testing...", "spawn 4")
    local out = atm_test(src)
    assertx(out, "ok\n")

    local src = [[
        spawn (func () {
            spawn (func () {
                await(true)
                emit(:ok)
            }) ()
            await(true)
        }) ()
        emit(:ok)
        print(1)
    ]]
    print("Testing...", "spawn 5")
    local out = atm_test(src)
    assertx(out, "1\n")

    local src = [[
        ;;print(:BLOCK0, `:pointer ceu_block`)
        spawn (func () {
            ;;print(:CORO1, `:pointer ceu_x`)
            ;;print(:BLOCK1, `:pointer ceu_block`)
            spawn (func () {
                ;;print(:CORO2, `:pointer ceu_x`)
                ;;print(:BLOCK2, `:pointer ceu_block`)
                await(true)
                ;;print(:1)
                emit(:ok)
            }) ()
            await(true)
            ;;print(:2)
        }) ()
        emit(:ok)
        print(1)
    ]]
    print("Testing...", "spawn 7")
    local out = atm_test(src)
    assertx(out, "1\n")

    local src = [[
        var tk
        set tk = func () {
            xprint((await(true)))
        }
        pin co = spawn tk()
        var f = func () {
            var g = func () {
                emit (:x,@{})
            }
            g()
        }
        f()
    ]]
    print("Testing...", "spawn 8")
    local out = atm_test(src)
    assertx(out, "x\n")

    local src = [[
        var tk
        set tk = func () {
            xprint(await(true))
        }
        pin co = spawn tk()
        var f = func () {
            var g = func () {
                emit (:x,@{})
            }
            g()
        }
        f()
    ]]
    print("Testing...", "spawn 8")
    local out = atm_test(src)
    assertx(out, "x\t{}\n")

    local src = [[
        var tk
        set tk = func () {
            xprint(await(true))
        }
        spawn(tk)()
        ;;var f = func' () {
            emit (:x,@{})
        ;;}
        ;;f()
    ]]
    print("Testing...", "spawn 9")
    local out = atm_test(src)
    assertx(out, "x\t{}\n")

    local src = [[
        var T = func () {
            do {
                xprint(await(true))
            }
        }
        pin t = spawn T()
        ;;print(:1111)
        emit (:x,@{})
        ;;print(:2222)
    ]]
    print("Testing...", "spawn 10")
    local out = atm_test(src)
    assertx(out, "x\t{}\n")
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
    local out = atm_test(src)
    assert(out == "ok\n")

    local src = [[
        val t = func () {
        }
        var co = if true => spawn t() => nil
        print(co)
    ]]
    print("Testing...", "spawn 5")
    local out = atm_test(src)
    --assertfx(out, "anon.atm : line 3 : near 'spawn' : expected expression")
    assertfx(out, "nil\n")

    local src = [[
        val t = func () { print(:ok) }
        val f = func () {
            spawn t()
        }
        f()
    ]]
    print("Testing...", "spawn 6")
    local out = atm_test(src)
    assert(out == "ok\n")

    local src = [[
        val T = func (v) {
            val x = @{}
            print(v)
            await(false)
        }
        pin t = do :X {
            var v
            set v = 10
            escape(:X, (task(func() { return(T(v)) })))
        }
        spawn t()
        print(t)
    ]]
    print("Testing...", "spawn 7")
    local out = atm_test(src)
    assertfx(out, "10\ntable: 0x")

    local src = [[
        val T = func (v) {
        }
        val t = do :X {
            escape(:X, (task(func() { })))
        }
    ]]
    print("Testing...", "spawn 7")
    local out = atm_test(src)
    assertx(trim(out), trim [[
        ==> ERROR:
         |  [C]:-1 (call)
         v  [string "anon.atm"]:3 (throw)
        ==> invalid assignment : expected pinned value
    ]])
end

-- EMIT

do
    local src = [[
        val T = func (v) {
            val e = await(true)
            print(v, e)
        }
        spawn T(:1)
        pin t2 = spawn T(:2)
        emit(:1)
    ]]
    print("Testing...", "emit 1 : task term")
    local out = atm_test(src)
    assertfx(out, "1\t1\n2\ttable: 0x")

    local src = [[
        val tk = func (v) {
            val e1 = await(true)
            print(v, e1)
            var e2 = await(true)
            print(v, e2)
        }
        pin co1 = spawn tk(:1)
        spawn tk(:2)
        emit(:1)
        emit(:2)
        emit(:3)
    ]]
    print("Testing...", "emit 2 : task term")
    local out = atm_test(src)
    assert(string.find(out, "1\t1\n2\t1\n1\t2\n2\ttable: 0x"))

    local src = [[
        spawn (func () {
            spawn (func () {
                await(true)              ;; awakes from outer bcast
                print(:2)
            }) ()
            await(true)                  ;; awakes from co2 termination
            print(:1)
        }) ()
        ;;`printf(">>> %d\n", CEU_DEPTH);`
        print(:bcast)
        emit(:ok)
    ]]
    print("Testing...", "emit 3 : task term")
    local out = atm_test(src)
    assert(out == "bcast\n2\n1\n")

    local src = [[
        val T = func () {
            await(true)
            print(:ok)
        }
        spawn T()
        do {
            emit(:1)
        }
    ]]
    print("Testing...", "emit 4")
    local out = atm_test(src)
    assert(out == "ok\n")

    local src = [[
        var tk
        set tk = func () {
            await(true)
            val e = await(true)
            print(e)
        }
        spawn (tk) ()
        spawn tk ()
        do {
             emit(:1)
             emit(:2)
             emit(:3)
        }
    ]]
    print("Testing...", "emit 5")
    local out = atm_test(src)
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
        emit(:1)
        emit(:2)
        emit(:3)
        emit(:4)
    ]]
    print("Testing...", "emit 6")
    local out = atm_test(src)
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
                    set evt2 = await(true, type(evt)!='table')
                }
            }) ()
            set evt1 = await(true)
        }) ()
        emit (:10)
        emit (:20)
    ]]
    print("Testing...", "emit 7")
    local out = atm_test(src)
    assertx(out, "10\n10\n20\n")

    local src = [[
        val T = func (v) {
            val _,e = await(true)
            xprint(e)
        }
        spawn T(10)
        catch true {
            (func () {
                emit (:t,@{})
            }) ()
        }
    ]]
    print("Testing...", "emit 8")
    local out = atm_test(src)
    assertx(out, "{}\n")

    local src = [[
        var T = func () {
            do {
                var _,v =
                    await(true)
                xprint(v)
            }
        }
        spawn T()
        ;;print(:1111)
        var e = @{}
        emit (:t, e)
        ;;print(:2222)
    ]]
    print("Testing...", "emit 9")
    local out = atm_test(src)
    assertx(out, "{}\n")

    local src = [[
        var T = func () {
            var _,v = await(true)
            xprint(v)
        }
        pin t = spawn T()
        do {
            val a
            do {
                val b
                do {
                    var e = @{}
                    emit (:t, e)
                }
            }
        }
    ]]
    print("Testing...", "emit 10")
    local out = atm_test(src)
    assertx(out, "{}\n")

    local src = [[
        var T = func () {
            xprint(await(true))
        }
        spawn T()
        do {
            var e = @{}
            emit (:t, e)
        }
    ]]
    print("Testing...", "emit 11")
    local out = atm_test(src)
    assertx(out, "t\t{}\n")

    local src = [[
        var fff = func (...) {
            xprint(...)
        }
        var T = func () {
            fff(await(true))
        }
        spawn T()
        emit (:t, @{1})
    ]]
    print("Testing...", "emit 12")
    local out = atm_test(src)
    assertx(out, "t\t{1}\n")

    local src = [[
        func t2 () {
            print(">>> B")
            await(:X)
            print("<<< B")
            ;;emit(Event.Task [`mar_exe`])
        }
        spawn {
            pin exe = task(t2)
            spawn exe()
            print(">>> A")
            var e = await(exe)
            print("<<< A")
        }
        emit(:X)
    ]]
    print("Testing...", "emit 13")
    local out = atm_test(src)
    assertx(out, ">>> B\n>>> A\n<<< B\n<<< A\n")
end

print "--- EMIT / SCOPE ---"

do
    local src = [[
        val T = func (v) {
            val _,e = await(true)
            xprint(e)
        }
        spawn T(10)
        (func () {
            emit (:t, @{})
        }) ()
    ]]
    print("Testing...", "emit scope 1")
    local out = atm_test(src)
    assertx(out, "{}\n")

    local src = [[
        val T = func (v) {
            val _,x = await(true)
            xprint(x)
        }
        spawn T(10)
        (func () {
            emit (:t, @{})
        }) ()
    ]]
    print("Testing...", "emit scope 2")
    local out = atm_test(src)
    assertx(out, "{}\n")

    local src = [[
        val T = func () {
            val _,e = await(true)
            xprint(e)
            await(true)
        }
        spawn T()
        spawn T()
        emit (:t, @{})
    ]]
    print("Testing...", "emit scope 3")
    local out = atm_test(src)
    assertx(out, "{}\n{}\n")

    local src = [[
        val T = func (v) {
            await(true)
            xprint(v)
        }
        spawn T(@{})
        emit(:ok)
    ]]
    print("Testing...", "emit scope 4")
    local out = atm_test(src)
    assertx(out, "{}\n")

    local src = [[
        val T = func () {
            val e =
                (func (_,x) {
                    type(x)
                    return(x)
                }) (await(true))
            xprint(e)
        }
        spawn T()
        do {
            emit (:t, @{20})
        }
        print(:ok)
    ]]
    print("Testing...", "emit scope 5")
    local out = atm_test(src)
    assertx(out, "{20}\nok\n")

    local src = [[
        var tk
        set tk = func (v) {
            print(v)
            val e1 = await(func(_,e) { (e,e) })
            xprint(e1)
            val e2 = await(func(_,e) { (e,e) })
            xprint(e2)
        }
        print(:1)
        spawn (tk) (10)
        spawn (tk) (10)
        val ok,e = catch true {
            return ((func () {
                print(:2)
                emit (:t,@{20})
                print(:3)
                emit (:t,@{[30]=30})
                return(true)
            }) ())
        }
        print(e)
    ]]
    print("Testing...", "emit scope 6")
    local out = atm_test(src)
    assertx(trim(out), trim [[
        1
        10
        10
        2
        {20}
        {20}
        3
        {30=30}
        {30=30}
        atm-func
    ]])

    local src = [[
        val f = func (_,v) {
            (func (x) {
                set x[0] = v[0]
                xprint(x[0])
            }) (#{0})
        }
        var T = func () {
            f(await(true))
        }
        spawn T()
        emit (:t,#{#{1}})
    ]]
    print("Testing...", "emit scope 7")
    local out = atm_test(src)
    assertx(out, "#{1}\n")

    local src = [[
        val f = func (_,v) {
            xprint(v[1])
        }
        var T = func () {
            f(await(true))
        }
        spawn T()
        emit (:t,@{@{1}})
    ]]
    print("Testing...", "emit scope 8")
    local out = atm_test(src)
    assertx(out, "{1}\n")

    local src = [[
        val f = func (_,v) {
            (func (x) {
                set x[1] = v[1]
                xprint(x[1])
            }) (@{0})
        }
        var T = func () {
            f(await(true))
        }
        spawn T()
        emit (:t,@{@{1}})
    ]]
    print("Testing...", "emit scope 9")
    local out = atm_test(src)
    assertx(out, "{1}\n")

    local src = [[
        val f = func (_,v) {
            xprint(v)
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
                            emit (:t,@{})
                        }
                    }
                }
            }
        }
    ]]
    print("Testing...", "emit scope 10")
    local out = atm_test(src)
    assertx(out, "{}\n")

    local src = [[
        val f = func (_,v) {
            xprint(v)
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
                    emit (:t,@{})
                }
            }
        }
    ]]
    print("Testing...", "emit scope 11")
    local out = atm_test(src)
    assertx(out, "{}\n")

    local src = [[
        var T = func () {
            var v =
                (func (_,it) {return(it)}) (await(true))
            xprint(v)
        }
        spawn T()
        ;;print(:1111)
        do {
            val a
            do {
                val b
                var e = @{}
                emit (:t,e)
            }
        }
        ;;print(:2222)
    ]]
    print("Testing...", "emit scope 12")
    local out = atm_test(src)
    assertx(out, "{}\n")

    local src = [[
        var T1 = func () {
            await(true)
            spawn( func () {                ;; GC = task (no more)
                val xevt = await(true)
                print(:1)
                var v = xevt
            } )()
        }
        pin t1 = spawn T1()
        var T2 = func () {
            await(true)
            val xevt = await(true)
            ;;print(:2)
            do {
                var v = xevt
                ;;print(:evt, v, xevt)
            }
        }
        pin t2 = spawn T2()
        emit (:t,@{})                      ;; GC = {}
        ;;print(`:number CEU_GC.free`)
        print(:ok)
    ]]
    print("Testing...", "emit scope 13")
    local out = atm_test(src)
    assertx(out, "ok\n")
end

print "--- EMIT / ALIEN ---"

do
    local src = [[
        var x
        set x = @{}
        emit (:t,x)
        xprint(x)
    ]]
    print("Testing...", "alien 0")
    local out = atm_test(src)
    assertx(out, "{}\n")

    local src = [[
        spawn (func () {
            val _,v = await(true)
            xprint(v)
            await(false)
        }) (nil)
        do {
            val e = @{}
            emit(:t,e)
        }
        print(:ok)
    ]]
    print("Testing...", "alien 1")
    local out = atm_test(src)
    assert(out == "{}\nok\n")

    local src = [[
        val T = func () {
            val _,x = await(true)
            xprint(x)
        }
        spawn T()
        do {
            val e = @{}
            (func () { emit(:t,e) })()
        }
        print(:ok)
    ]]
    print("Testing...", "alien 2")
    local out = atm_test(src)
    assert(out == "{}\nok\n")

    local src = [[
        spawn (func () {
            val _,evt = await(true)
            val x = @{nil}
            set x[1] = evt
            xprint(x)
        }) ()
        do {
            val x
            emit(:t,@{10})
        }
    ]]
    print("Testing...", "alien 3")
    local out = atm_test(src)
    assertx(out, "{{10}}\n")

    local src = [[
        spawn (func () {
            val _,evt = await(true)
            do {
                val x = evt
                xprint(x)
                await(true)
            }
        }) ()
        do {
            val x
            emit(:t,@{10})
        }
    ]]
    print("Testing...", "alien 4")
    local out = atm_test(src)
    assertx(out, "{10}\n")

    local src = [[
        spawn (func () {
            val _,evt = await(true)
            val x = evt[0]
            xprint(x)
        }) ()
        do {
            val e = #{#{10}}
            emit(:t,e)
        }
    ]]
    print("Testing...", "alien 5")
    local out = atm_test(src)
    assertx(out, "#{10}\n")

    local src = [=[
        var f = func (_,v) {  ;; *** v is no longer fleeting ***
            val x = v[1]    ;; v also holds x, both are fleeting -> unsafe
            xprint(x)      ;; x will be freed and v would contain dangling pointer
        }
        var T = func () {
            f(await(true))
        }
        spawn T()
        emit (:t,@{@{1}})
    ]=]
    print("Testing...", "alien 6")
    local out = atm_test(src)
    assertx(out, "{1}\n")

    local src = [=[
        var f = func (v) {
            val x = v[1]    ;; v also holds x, both are fleeting -> unsafe
            xprint(x)      ;; x will be freed and v would contain dangling pointer
        }
        var T = func () {
            val xevt = await(true) ;;thus { it => it}   ;; NOT FLEETING (vs prv test)
            f(xevt)
        }
        spawn T()
        emit (:t @{@{1}})
    ]=]
    print("Testing...", "alien 7")
    local out = atm_test(src)
    assertx(out, "{1}\n")
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
        emit <- :t @{2}
        print(:ok)
    ]]
    print("Testing...", "payload 1")
    local out = atm_test(src)
    assert(out == "ok\n")

    local src = [[
        var tk
        set tk = func (v) {
            print(v)
            val e1 = await(func (e) { (type(e)!='table', e) })
            print(:e1,e1)
            val e2 = await(func (e) { (type(e)!='table', e) })
            print(:e2,e2)
        }
        print(:1)
        spawn (tk) (10)
        spawn (tk) (10)
        catch true {
            (func () {
                print(:2)
                emit(:20)
                print(:3)
                emit(:30)
            })()
        }
    ]]
    print("Testing...", "payload 2")
    local out = atm_test(src)
    assert(out == "1\n10\n10\n2\ne1\t20\ne1\t20\n3\ne2\t30\ne2\t30\n")

    local src = [[
        val T = func () {
            val e1 = do :brk {
                loop {
                    val e = await(true)
                    do {
                        val x = e
                        print(:in, e)    ;; TODO: 10
                    }
                    escape(:brk)
                }
            }
        }
        spawn T()
        emit(:10)
    ]]
    print("Testing...", "payload 3")
    local out = atm_test(src)
    assertx(out, "in\t10\n")

    local src = [[
        spawn (func () {
            var _,evt = await(true)
            val x = evt
            xprint(x)
            set _,evt = await(true)
            xprint(x)
        }) ()
        do {
            val e = @{10}
            emit(:t,e)
        }
        emit(:ok)
    ]]
    print("Testing...", "payload 4")
    local out = atm_test(src)
    assertx(out, "{10}\n{10}\n")

    local src = [[
        var fff
        set fff = func (x) { return(x) }
        spawn (func () {
            var evt = await(true)
            do :X {
                loop {
                    if evt[:type]==:x {
                        escape(:X)
                    }
                    set evt = await(true)
                }
            }
            print(99)
        }) ()
        print(1)
        emit (:T @{type=:y})
        print(2)
        emit (:T @{type=:x})
        print(3)
    ]]
    print("Testing...", "payload 5")
    local out = atm_test(src)
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
        emit (:T @{type=:y})
        emit (:T @{[:type]=:x})
    ]]
    print("Testing...", "payload 6")
    local out = atm_test(src)
    assertx(out, "1\n2\n3\n4\n99\n")

    local src = [[
        spawn {
            var evt
            loop {
                xprint(evt)
                set evt = await(true)
            }
        }
        emit <- :T @{}
    ]]
    print("Testing...", "payload 7")
    local out = atm_test(src)
    assertx(out, "nil\n{tag=T}\n")

    local src = [[
        spawn {
            print(await(true))
        }
        emit(:10,:20)
    ]]
    print("Testing...", "payload 8: multi emit/await args")
    local out = atm_test(src)
    assertx(out, "10\t20\n")

    local src = [[
        func tsk () {
            var a,b = await(func (e,v) { (e==:X) && (v==10) })
            print(a,b)
        }
        spawn tsk()
        emit(:X,99)
        emit(:X,10)
        emit(:X,99)
    ]]
    print("Testing...", "payload 9")
    local out = atm_test(src)
    assertx(out, "X\t10\n")

    local src = [[
        func tsk () {
            var e = await(func (e) { (e??:X) && (e.v==10) })
            xprint(e)
        }
        spawn tsk()
        emit(:X @{v=99})
        emit <-- :X @{v=10}
        emit(:X @{v=10})
    ]]
    print("Testing...", "payload 9")
    local out = atm_test(src)
    assertx(out, "{tag=X, v=10}\n")
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
            ;;await(true)                  ;; 3. awakes from outer bcast
            print(:ok)
        }) ()
        print(:2)
        emit(:T@{})
        print(:4)
    ]]
    print("Testing...", "order 1")
    local out = atm_test(src)
    assertx(out, "1\n2\n3\nok\n4\n")

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
        emit(:ok)
        print(:4)
    ]]
    print("Testing...", "order 2")
    local out = atm_test(src)
    assert(out == "1\n2\n3\n4\n")

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
    local out = atm_test(src)
    assert(string.find(out, "1\tout\n2\ttable: 0x"))

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
        emit(:ok)
    ]]
    print("Testing...", "order 4")
    local out = atm_test(src)
    assertx(out, "1\n2\n1\n2\n")
end

print "--- EMIT / IN ---"

do
    local src = [[
        emit[nil](:ok)
        print(:ok)
    ]]
    print("Testing...", "emit-in 1")
    local out = atm_test(src)
    assertx(out, "ok\n")

    local src = [[
        spawn (func () {
            val x = await(true)
            print(:ok, x)
        }) ()
        spawn (func () {
            emit [:global] (:10)
        }) ()
    ]]
    print("Testing...", "emit-in 2")
    local out = atm_test(src)
    assertx(out, "ok\t10\n")

    local src = [[
        spawn (func () {
            val x = await(true)
            print(:ok, x)
        }) ()
        spawn (func () {
            emit [:task] (:10)
            print(:no)
            emit [:global] (:20)
        }) ()
    ]]
    print("Testing...", "emit-in 3")
    local out = atm_test(src)
    assertx(out, "no\nok\t20\n")

    local src = [[
        var T
        set T = func (v) {
            await(true)
            print(v)
            await(true)
        }
        var t1
        pin t1 = spawn T (1)
        do {
            var t2
            pin t2 = spawn T (2)
            emit [t2] (:nil)
        }
    ]]
    print("Testing...", "emit-in 4: in t2")
    local out = atm_test(src)
    assertx(out, "2\n")

    --warn(false, 'TODO :parent')
end

print '--- PIN ---'

do
    local src = [[
        val T = \{}
        val t = spawn T()
    ]]
    print("Testing...", "pin 1")
    local out = atm_test(src)
    --assertx(out, "anon.atm : line 1 : invalid tasks limit : expected number")
    assertx(trim(out), trim [[
        ==> ERROR:
        |  [C]:-1 (call)
        v  [string "anon.atm"]:2 (throw)
        ==> invalid assignment : expected pinned value
    ]])

    local src = [[
        val t = tasks()
    ]]
    print("Testing...", "pin 2")
    local out = atm_test(src)
    --assertx(out, "anon.atm : line 1 : invalid tasks limit : expected number")
    assertx(trim(out), trim [[
        ==> ERROR:
        |  [C]:-1 (call)
        v  [string "anon.atm"]:1 (throw)
        ==> invalid assignment : expected pinned value
    ]])

    local src = [[
        val t = tasks()
    ]]
    print("Testing...", "pin 2")
    local out = atm_test(src)
    --assertx(out, "anon.atm : line 1 : invalid tasks limit : expected number")
    assertx(trim(out), trim [[
        ==> ERROR:
        |  [C]:-1 (call)
        v  [string "anon.atm"]:1 (throw)
        ==> invalid assignment : expected pinned value
    ]])

    local src = [[
        pin t = tasks()
        pin x = t
    ]]
    print("Testing...", "pin 3")
    local out = atm_test(src)
    --assertx(out, "anon.atm : line 1 : invalid tasks limit : expected number")
    assertx(trim(out), trim [[
        ==> ERROR:
         |  [C]:-1 (call)
         v  [string "anon.atm"]:2 (throw)
        ==> invalid assignment : expected unpinned value
    ]])

    local src = [[
        pin t = spawn {}
        print(t)
    ]]
    print("Testing...", "pin 4")
    local out = atm_test(src)
    assertx(out, "anon.atm : line 1 : near 'pin' : invalid assignment : unexpected transparent task")
end

print '--- TASK / TERMINATION ---'

do
    local src = [[
        spawn {
            pin e = await(true)
            print(:ok, e)
        }
        pin t = spawn (\{
        })()
        emit(:T, t)
    ]]
    print("Testing...", "task-term 1")
    local out = atm_test(src)
    assertfx(out, "ok\ttable: 0x")

    local src = [[
        spawn {
            pin x = await(true)
            print(:ok, x)
        }
        pin t = spawn (\{
        }) ()
        emit(t)
    ]]
    print("Testing...", "task-term 2")
    local out = atm_test(src)
    assertfx(out, "ok\ttable: 0x")

    local src = [[
        spawn {
            await(true)
            print(:1)
            val x = await(true)
            print(:ok, x)
        }
        pin t = spawn (\{
            await(true)
            print(:2)
        }) ()
        emit(:nil)
        emit(:T, t)
    ]]
    print("Testing...", "task-term 3")
    local out = atm_test(src)
    assert(string.find(out, "1\n2\nok\ttable: 0x"))

    local src = [[
        spawn {
            pin t = spawn (\{
                val e = await(true)
                print(:1, e)
            }) ()
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
    local out = atm_test(src)
    assertx(out, "0\n1\ta\n2\ttrue\n")

    local src = [[
        func t2 () {
            print(">>> B")
            await(:X)
            print("<<< B")
            ;;emit(Event.Task [`mar_exe`])
        }
        spawn {
            print(">>> A")
            await t2()
            print("<<< A")
        }
        emit(:X)
    ]]
    print("Testing...", "task await 5")
    local out = atm_test(src)
    assertx(out, ">>> A\n>>> B\n<<< B\n<<< A\n")
end

print '--- PUB ---'

do
    local src = [[
        val t = func () {
            set pub = @{}
            return (pub)
        }
        pin a = spawn (t) ()
        val x = a.pub
        xprint(x)
    ]]
    print("Testing...", "pub 1")
    local out = atm_test(src)
    assertx(out, "{}\n")

    local src = [[
        val T = func () {
            print(pub)
            await(true)
        }
        pin t = spawn T()
        print(t.pub)
    ]]
    print("Testing...", "pub 2")
    local out = atm_test(src)
    assertx(out, "nil\nnil\n")

    local src = [[
        val T = func () {
            set pub = 10
            await(true)
        }
        pin t = spawn T()
        print(t.pub)
    ]]
    print("Testing...", "pub 3")
    local out = atm_test(src)
    assertx(out, "10\n")

    local src = [[
        val T = func () {
            do {
                val x = @{}
                set pub = x
                return(pub)
            }
        }
        pin t = spawn T()
        xprint(t.pub)
    ]]
    print("Testing...", "pub 4")
    local out = atm_test(src)
    assertx(out, "{}\n")

    local src = [[
        val T = func () {
        }
        pin t = spawn T()
        do {
            val x = @{}
            set t.pub = x
        }
        xprint(t.pub)
    ]]
    print("Testing...", "pub 5")
    local out = atm_test(src)
    assertx(out, "{}\n")

    local src = [[
        print(pub)  ;; now runs inside task
    ]]
    print("Testing...", "pub 6")
    local out = atm_test(src)
    assertx(out, "nil\n")
    --assertx(out, "anon.atm : line 1 : invalid pub : expected enclosing task")

    local src = [[
        val T = func () {
            set pub = 10
            await(func (e,v) { (e==:X) && (v==pub) })
            print(pub)
        }
        pin t = spawn T()
        emit(:X, 10)
    ]]
    print("Testing...", "pub 7")
    local out = atm_test(src)
    assertx(out, "10\n")
end

print '--- NESTED ---'

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
    local out = atm_test(src)
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
    local out = atm_test(src)
    assertx(out, "10\n")

    local src = [[
        spawn( func () {
            val t = @{}
            spawn (func () {
                await(true)
                xprint(t)
            }) ()
            await(true)
        }) ()
        coroutine.create(func () { })
        emit(:true)
    ]]
    print("Testing...", "nested 3")
    local out = atm_test(src)
    assertx(out, "{}\n")

    local src = [[
        do {
            val v = 10
            spawn (func () {
                print(v)
            }) ()
        }
    ]]
    print("Testing...", "nested 4")
    local out = atm_test(src)
    assertx(out, "10\n")

    local src = [[
        spawn (func () {
            do {
                spawn (func () {
                    await(true)
                }) ()
                await(true)
            }
            emit(:T@{})
        })()
        emit(:99)
        print(:ok)
    ]]
    print("Testing...", "nested 4")
    local out = atm_test(src)
    assertx(out, "ok\n")

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
        emit(:true)
    ]]
    print("Testing...", "nested 5")
    local out = atm_test(src)
    assertx(out, "ok\n")

    local src = [[
        spawn (func () {
            do {
                spawn (func () {
                    await(true)
                    print(:2)
                }) ()
                loop { await(true) }
            }
            print(333)
        }) ()
        do {
            print(:1)
            emit(:true)
            print(:3)
        }
        print(:END)
    ]]
    print("Testing...", "nested 6")
    local out = atm_test(src)
    assertx(out, "1\n2\n3\nEND\n")
end

print '--- ABORTION ---'

do
    local src = [[
        spawn (
            func () {
                defer {
                    print(:defer)
                }
                nil
            }
        ) ()
    ]]
    print("Testing...", "abort 1")
    local out = atm_test(src)
    assertx(out, "defer\n")

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
    local out = atm_test(src)
    assertx(out, "defer\n")

    local src = [[
        print(:1)
        var x = 0
        do :X {
            loop {
                if x == 2 {
                    escape (:X)
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
    local out = atm_test(src)
    assertx(out, "1\n2\n3\ndefer\n2\n3\ndefer\n4\n")

    local src = [[
        spawn (func () {
            pin t = spawn( func () {
                await(false)
            }) ()
            await(false)
        } )()
        emit(:true)
        print(:ok)
    ]]
    print("Testing...", "abort 4")
    local out = atm_test(src)
    assertx(out, "ok\n")

    local src = [[
        do {
            spawn (func () {
                do {
                    pin t1 = spawn (func () {
                        pin t2 = spawn (func () {
                            await(true)
                            print(:1)
                        }) ()
                        await(true, evt==t2)
                        print(:2)
                    }) ()
                    await(true, evt==t1)
                    print(:3)
                }
                await(:X)
                print(:99)
            }) ()
            print(:0)
            emit(:true)
            print(:4)
        }
    ]]
    print("Testing...", "abort 5")
    local out = atm_test(src)
    assertx(out, "0\n1\n2\n3\n4\n")

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
        emit(:true)
        print(:ok)
    ]]
    print("Testing...", "abort 6")
    local out = atm_test(src)
    assertx(out, "ok\n")

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
        emit(:true)
        print(:6)
    ]]
    print("Testing...", "abort 7")
    local out = atm_test(src)
    assertx(out, "0\n1\n2\n3\n4\n6\n")

    local src = [[
        spawn {
            spawn {
                await(true)
                emit [:global] (:true)
            }
            await(true)
        }
        emit(:true)
        print(:ok)
    ]]
    print("Testing...", "abort 8")
    local out = atm_test(src)
    assertx(out, "ok\n")

    local src = [[
        spawn {
            spawn(func () {
                await(true)
                emit [:global] (:true)
            })()
            await(true)
        }
        emit(:true)
        print(:ok)
    ]]
    print("Testing...", "abort 9")
    local out = atm_test(src)
    assertx(out, "ok\n")

    local src = [[
        spawn (func () {
            val T = func () {
                print(:1)
                await(true)
                print(:a)
                await(true)
            }
            pin t = spawn T()
            spawn( func () {
                print(:2)
                await(true)
                print(:b)
                emit[t](:)     ;; pending
                print(999)
            } )()
            print(:3)
            await(true)
            print(:ok)
        })()
        emit(:)
    ]]
    print("Testing...", "abort 9")
    local out = atm_test(src)
    assertx(out, "1\n2\n3\na\nb\nok\n")

    local src = [[
        spawn (func () {
            val T = func () {
                await(true)
                await(true)
            }
            pin t = spawn T()
            spawn( func () {
                await(true)
                emit [t] (:)
                print(999)
            } )()
            await(true)
            print(:ok)
        })()
        emit(:)
    ]]
    print("Testing...", "abort 10")
    local out = atm_test(src)
    assertx(out, "ok\n")

    local src = [[
        val T = func () {
            await(true)
            10
        }
        pin t = spawn T()
        ;;spawn( func () {
            spawn (func () {
                print(:A)
                (func (it) { print(it==10) }) (await(t))
                print(:C)
            }) ()
            emit[t] (:)
        ;;})()
        print(:ok)
    ]]
    print("Testing...", "abort 11")
    local out = atm_test(src)
    assertx(out, "A\ntrue\nC\nok\n")

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
    local out = atm_test(src)
    assertx(out, "1\n2\nok\n")

    local src = [[
        spawn (func () {
            ;;await(true)
            do {
                spawn (func () {
                    await(true)
                }) ()
                await(true)
            }
            emit(@{})
        })()
        ;;emit(:)
        emit(:)
        print(:ok)
    ]]
    print("Testing...", "abort 13")
    local out = atm_test(src)
    assertx(out, "ok\n")

    local src = [[
        spawn (func () {
            await(true)
            do {
                spawn (func () {
                    await(true)
                    emit [:global](:)
                }) ()
                await(true)
            }
            emit(:)
        })()
        emit(:)
        print(:ok)
    ]]
    print("Testing...", "abort 14")
    local out = atm_test(src)
    assertx(out, "ok\n")

    local src = [[
        spawn (func () {
            val T = func () {
                print(:1)
                await(true)
                print(:a)
                await(true)
            }
            pin t = spawn T()
            spawn( func () {
                print(:2)
                await(true)
                print(:b)
                emit[t](:)
                print(999)
            } )()
            print(:3)
            await(true)
            print(:ok)
        })()
        emit(:)
    ]]
    print("Testing...", "abort 15")
    local out = atm_test(src)
    assertx(out, "1\n2\n3\na\nb\nok\n")

    local src = [[
        spawn (func () {
            val T = func () {
                await(true)
                await(true)
                print(:2)
            }
            pin t = spawn T()
            spawn( func () {
                await(true)
                do {
                    print(:1)
                    emit[t](:)
                    print(:no)
                }
                print(:no)
            } )()
            await(true)
            print(:3)
        })()
        print(:0)
        emit(:)
        print(:4)
    ]]
    print("Testing...", "abort 16")
    local out = atm_test(src)
    assertx(out, "0\n1\n2\n3\n4\n")

    local src = [[
        spawn {
            spawn {
                await(true)
                defer {
                    print(:1)
                }
                emit[:global](:)
            }
            await(true)
            print(:0)
        }
        emit(:)
        print(:2)
    ]]
    print("Testing...", "abort 17")
    local out = atm_test(src)
    assertx(out, "0\n1\n2\n")

    local src = [[
        spawn (func () {
            val T = func () {
                await(true)
                await(true)
                print(:2)
            }
            pin t = spawn T()
            spawn( func () {
                await(true)
                do {
                    defer {
                        print(:ok)
                    }
                    print(:1)
                    emit[t](:)
                    print(:no)
                }
                print(:no)
            } )()
            await(true)
            print(:3)
        })()
        print(:0)
        emit(:)
        print(:4)
    ]]
    print("Testing...", "abort 18")
    local out = atm_test(src)
    assertx(out, "0\n1\n2\n3\nok\n4\n")

    local src = [[
        spawn (func () {
            val T = func () {
                await(true)
                await(true)
                print(:2)
            }
            pin t = spawn T()
            spawn( func () {
                await(true)
                do {
                    defer {
                        print(:ok)
                    }
                    print(:1)
                    (func () {
                        emit[t](:)
                    }) ()
                    print(:no)
                }
                print(:no)
            } )()
            await(true)
            print(:3)
        })()
        print(:0)
        emit(:)
        print(:4)
    ]]
    print("Testing...", "abort 19")
    local out = atm_test(src)
    assertx(out, "0\n1\n2\n3\nok\n4\n")

    local src = [[
        val f = func (t) {
            defer {
                print(:ok)
            }
            print(:1)
            emit[t](:)
            print(:no)
        }
        spawn (func () {
            val T = func () {
                await(true)
                await(true)
                print(:2)
            }
            pin t = spawn T()
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
        emit(:)
        print(:4)
    ]]
    print("Testing...", "abort 20")
    local out = atm_test(src)
    assertx(out, "0\n1\n2\n3\nok\n4\n")

    local src = [[
        spawn (func () {
            spawn (func () {
                await(true)
                do {
                    defer {
                        print(:3)
                    }
                    print(:1)
                    emit [:global] (:)
                    print(:999)
                }
            }) ()
            await(true)
            print(:2)
        }) ()
        emit[ :global ](:)
    ]]
    print("Testing...", "abort 21")
    local out = atm_test(src)
    assertx(out, "1\n2\n3\n")

    local src = [[
        spawn (func () {
            spawn (func () {
                await(true)
                print(:1)
                emit [:global] (:)
                print(:999)
            }) ()
            await(true)
            print(:2)
        }) ()
        emit[:global] (:)
        print(:3)
    ]]
    print("Testing...", "abort 22")
    local out = atm_test(src)
    assertx(out, "1\n2\n3\n")

    local src = [[
        spawn (func () {
            spawn (func () {
                await(true)
                emit[:global](:)
            }) ()
            await(true)
        }) ()
        emit(:)
        print(:ok)
    ]]
    print("Testing...", "abort 23")
    local out = atm_test(src)
    assertx(out, "ok\n")

    local src = [[
        val f = func () {
            do {
                defer {
                    print(:4)    ;; TODO: aborted func should execute defer
                }
                print(:1)
                emit [:global] (:)
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
        emit[:global] (:)
    ]]
    print("Testing...", "abort 24")
    local out = atm_test(src)
    assertx(out, "1\n2\n4\n3\n")

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
                        emit [:global](:)
                    })) ()
                    print(:999)
                }
            }) ()
            await(true)
            print(:2)
        }) ()
        emit[:global](:)
    ]]
    print("Testing...", "abort 25")
    local out = atm_test(src)
    warnx(out, "TODO - coro - emit") --":1\n:2\n:3\n")

    local src = [[
        spawn (func () {
            spawn (func () {
                await(true)
                spawn (func () {
                    emit [:global](:)
                }) ()
            }) ()
            await(true)
        }) ()
        emit [:global] (:)
        print(:ok)
    ]]
    print("Testing...", "abort 26")
    local out = atm_test(src)
    assertx(out, "ok\n")

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
                        emit[:global](:)
                    }) ()
                    print(:999)
                }
            }) ()
            await(true)
            print(:2)
        }) ()
        emit[:global](:)
    ]]
    print("Testing...", "abort 27")
    local out = atm_test(src)
    assertx(out, "1\n2\n3\n")

    local src = [[
        val f = func () {
            do {
                defer {
                    print(:4)    ;; TODO: aborted func should execute defer
                }
                print(:1)
                ;;resume (coro(func () {
                    emit[:global](:)
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
        emit[:global](:)
    ]]
    print("Testing...", "abort 28")
    local out = atm_test(src)
    assertx(out, "1\n2\n4\n3\n")

    local src = [[
        val f = func () {
            val x = @{}
            emit[:global](:)
        }
        spawn (func () {
            spawn (func () {
                await(true)
                f()
                print(:nooo)
            }) ()
            await(true)
        }) ()
        emit(:)
        print(:ok)
    ]]
    print("Testing...", "abort 29")
    local out = atm_test(src)
    assertx(out, "ok\n")

    local src = [[
        val f = func () {
            do {
                defer {
                    print(:4)    ;; TODO: aborted func' should execute defer
                }
                print(:1)
                spawn (func () {
                    emit[:global](:)
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
        emit[:global](:)
    ]]
    print("Testing...", "abort 30")
    local out = atm_test(src)
    assertx(out, "1\n2\n4\n3\n")

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
                            emit[:global](:)
                        }
                    ;;})) ()
                    print(:999)
                }
            }) ()
            await(true)
            print(:2)
        }) ()
        emit[:global](:)
    ]]
    print("Testing...", "abort 31")
    local out = atm_test(src)
    assertx(out, "1\n2\n3\n")

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
                            emit [:global] (:)
                        }
                    }) ()
                    print(:999)
                }
            }) ()
            await(true)
            print(:2)
        }) ()
        emit[:global](:)
    ]]
    print("Testing...", "abort 32")
    local out = atm_test(src)
    assertx(out, "1\n2\n3\n")

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
    local out = atm_test(src)
    --assertx(out, ":1\n:2\n:ok\n:3\n")
    assertx(out, "1\n2\n3\nok\n")

    local src = [[
        spawn (func () {
            print(:1)
            val co = coroutine.create (func () {
                defer {
                    print(:ok)
                }
                print(:2)
                coroutine.yield()
                print(:999)
            })
            coroutine.resume(co)
            print(:3)
            coroutine['close'](co)
        }) ()
    ]]
    print("Testing...", "abort 34")
    local out = atm_test(src)
    assertx(out, "1\n2\n3\nok\n")

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
        emit(:)
        print(:4)
    ]]
    print("Testing...", "abort 35")
    local out = atm_test(src)
    assertx(out, "1\n2\nok\n3\n4\n")

    local src = [[
        spawn (func () {
            print(:1)
            spawn (func () {
                print(:2)
                await(true)
                print(:6)
                emit[:global](:)
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
        emit(:)
        print(:8)
    ]]
    print("Testing...", "abort 36")
    local out = atm_test(src)
    --assertx(out, ":1\n:2\n:3\n:ok\n:4\n:5\n:6\n:7\n:8\n")
    assertx(out, "1\n2\n3\n4\n5\n6\nok\n7\n8\n")

    local src = [[
        func t2 () {
            defer {
                print("first")
            }
            await(true)
        }
        spawn {
            defer {
                print("last")
            }
            pin exe = task(t2)
            spawn exe()
        }
    ]]
    print("Testing...", "abort 37")
    local out = atm_test(src)
    assertx(out, "first\nlast\n")
end

print '--- THROW / CATCH ---'

do
    local src = [[
        spawn {
            catch :e1 {
                throw(:e1)
            }
            print(:e1)
            await(true)
            throw(:e2)
        }
        catch :e2 {
            emit(:)
            emit(:)
            print(99)
        }
        print(:e2)
    ]]
    print("Testing...", "catch 1")
    local out = atm_test(src)
    assertx(out, "e1\ne2\n")

    local src = [[
        spawn (func () {
            catch :e1 ;;;(it| it==:e1);;; {
                ;;resume (coroutine (coro' () {
                    ;;await(true)
                    throw(:e1)
                ;;})) ()
                loop {
                    await(true)
                }
            }
            print(:e1)
            await(true)
            throw(:e2)
        })()
        catch :e2 ;;;(it | it==:e2 );;; {
            emit(:)
            emit(:)
            print(99)
        }
        print(:e2)
    ]]
    print("Testing...", "catch 2")
    local out = atm_test(src)
    assertx(out, "e1\ne2\n")

    local src = [[
        val T = func () {
            print(:ok1)
            throw(:e2)
            print(:no)
        }
        spawn {
            catch :e2 {
                spawn T()
                await(false)
                print(:no)
            }
            print(:ok2)
        }
        emit(:)
        print(:ok3)
    ]]
    print("Testing...", "catch 3")
    local out = atm_test(src)
    assertx(out, "ok1\nok2\nok3\n")

    local src = [[
        spawn {
            await(true)
            print(:ok1)
            throw(:e3)
            print(:no)
        }
        catch :e3 {
            emit(:)
            print(:no)
        }
        print(:ok2)
    ]]
    print("Testing...", "catch 4")
    local out = atm_test(src)
    assertx(out, "ok1\nok2\n")

    local src = [[
        val T = func () {
            await(true)
            print(:ok1)
            throw(:e2)
            print(:no1)
        }
        spawn {
            catch :e2 {
                spawn T()
                await(false)
            }
            print(:ok2)
            throw(:e3)
            print(:no2)
        }
        catch :e3 {
            emit(:)
            print(:no3)
        }
        print(:ok3)
    ]]
    print("Testing...", "catch 5")
    local out = atm_test(src)
    assertx(out, "ok1\nok2\nok3\n")

    local src = [[
        val T = func () {
            catch :e1 {
                spawn {
                    await(true)
                    throw(:e1)
                    print(:no)
                }
                await(false)
            }
            print(:ok1)
            throw(:e2)
            print(:no)
        }
        spawn {
            catch :e2 {
                spawn T()
                await(false)
            }
            print(:ok2)
            throw(:e3)
            print(:no)
        }
        catch :e3 {
            emit(:)
            print(:no)
        }
        print(:ok3)
    ]]
    print("Testing...", "catch 6")
    local out = atm_test(src)
    assertx(out, "ok1\nok2\nok3\n")

    local src = [[
        spawn {
            spawn {
                await(true)
            }
            await(true)
            throw(nil)
        }
        print(1)
    ]]
    print("Testing...", "catch 7")
    local out = atm_test(src)
    assertx(out, "1\n")

    local src = [[
        catch true {
            spawn {
                throw(:x)
            }
        }
        print(1)
    ]]
    print("Testing...", "catch 8")
    local out = atm_test(src)
    assertx(out, "1\n")

    local src = [[
        spawn {
            catch :or {
                spawn {
                    await(true)
                    ;;print(:evt, evt)
                    ;;print(111)
                    throw(:or)
                }
                spawn {
                    await(true)
                    ;;print(:evt, evt)
                    ;;print(222)
                    throw(:or)
                }
                await(true)
                ;;print(:in)
            }
            ;;print(:out)
        }
        ;;print(:bcast-in)
        emit (:)
        ;;print(:bcast-out)
        print(1)
    ]]
    print("Testing...", "catch 9")
    local out = atm_test(src)
    assertx(out, "1\n")

    local src = [[
        var tk = func (v) {
            await(true)
            val v = await(true)
            throw(:1)
        }
        spawn tk ()
        spawn tk ()
        catch :1 {
            (func () {
                print(1)
                emit(:1)
                print(2)
                emit(:2)
                print(3)
                emit(:3)
            })()
        }
        print(99)
    ]]
    print("Testing...", "catch 10")
    local out = atm_test(src)
    assertx(out, "1\n2\n99\n")
end

print '--- RETURN ---'

do
    local src = [[
        pin t = spawn (func () {
            set pub = @{1}
            await(true)
            return(@{2})
        } )()
        xprint(atmos.status(t), t.pub)
        emit(:)
        xprint(atmos.status(t), t.pub, t.ret)
    ]]
    print("Testing...", "return 1")
    local out = atm_test(src)
    assertx(out, "suspended\t{1}\ndead\t{1}\t{2}\n")

    local src = [[
        spawn {
            spawn {
                await(true)
                return(10)
            }
            (func (it) { print(it.ret) }) (await(true))
        }
        emit(:)
        print(:ok)
    ]]
    print("Testing...", "return 2")
    local out = atm_test(src)
    assertx(out, "10\nok\n")
end

print '--- TASKS ---'

do
    local src = [[
        pin ts = tasks()
        print(:ok)
    ]]
    print("Testing...", "tasks 1")
    local out = atm_test(src)
    assertx(out, "ok\n")

    local src = [[
        do {
            pin ts = tasks()
        }
        print(:ok)
    ]]
    print("Testing...", "tasks 2")
    local out = atm_test(src)
    assertx(out, "ok\n")

    local src = [[
        pin ts = tasks()
        spawn [ts] (func () { print(:in) })()
        print(:out)
    ]]
    print("Testing...", "tasks 3")
    local out = atm_test(src)
    assertx(out, "in\nout\n")

    local src = [[
        val T = func () {
            await(true)
            print(:in)
        }
        pin ts = tasks()
        spawn [ts] T()
        print(:out)
        emit(:)
    ]]
    print("Testing...", "tasks 4")
    local out = atm_test(src)
    assertx(out, "out\nin\n")

    local src = [[
        val T = func () {
            await(true)
        }
        pin ts = tasks()
        val ok = spawn [ts] T()
        print(ok)
    ]]
    print("Testing...", "tasks 5")
    local out = atm_test(src)
    assertfx(out, "table: 0x")

    local src = [[
        pin ts = tasks()
        print(ts == nil)
    ]]
    print("Testing...", "tasks 6")
    local out = atm_test(src)
    assertx(out, "false\n")

    local src = [[
        val T = func (v) { }
        pin ts = tasks()
        var x = 0
        do :X {
            loop {
                spawn [ts] T()
                set x = x + 1
                if x==500 {
                    escape (:X)
                }
            }
        }
        print(:ok)
    ]]
    print("Testing...", "tasks 7")
    local out = atm_test(src)
    assertx(out, "ok\n")

    local src = [[
        pin ts = tasks()
        print(type(ts))
        var T
        set T = func (v) {
            print(v)
            val evt = await(true)
            print(evt)
        }
        do {
            spawn [ts] T(1)
        }
        emit(:2)
    ]]
    print("Testing...", "tasks 8")
    local out = atm_test(src)
    assertx(out, "table\n1\n2\n")

    local src = [[
        val T = func () {
            set pub = @{}
            await(true)
        }
        pin ts = tasks(1)
        do {
            spawn [ts] T()
            spawn [ts] T()
            spawn [ts] T()
            emit(:T@{})
            spawn [ts] T()
            spawn [ts] T()
            spawn [ts] T()
            emit(:T@{})
            spawn [ts] T()
            spawn [ts] T()
            spawn [ts] T()
            emit(:T@{})
            spawn [ts] T()
            spawn [ts] T()
            spawn [ts] T()
            spawn [ts] T()
            emit(:T@{})
            print(:ok)
        }
    ]]
    print("Testing...", "tasks 9")
    local out = atm_test(src)
    assertx(out, "ok\n")

    local src = [[
        var T
        set T = func () {
            await(true)
        }
        pin ts = tasks()
        spawn [ts] T()
        print(1)
    ]]
    print("Testing...", "tasks 10")
    local out = atm_test(src)
    assertx(out, "1\n")

    local src = [[
        pin ts = tasks(2)
        val T = func (v) {
            print(10)
            defer {
                print(20)
                print(30)
            }
            await(func (e) { e !? :task })
            if v {
                await(func (e) { e !? :task })
            }
        }
        print(0)
        spawn [ts] T(false)
        spawn [ts] T(true)
        print(1)
        emit(:99)
        print(2)
        emit(:99)
        print(3)
    ]]
    print("Testing...", "tasks 11")
    local out = atm_test(src)
    assertx(out, "0\n10\n10\n1\n20\n30\n2\n20\n30\n3\n")

    local src = [[
        pin ts = tasks(2)
        var T
        set T = func (v) {
            print(10)
            defer {
                print(20)
                print(30)
            }
            await(func (e) { e !? :task })
            if v {
                await(func (e) { e !? :task })
            }
        }
        print(0)
        spawn [ts] T(false)
        spawn [ts] T(true)
        print(1)
        emit(:99)
        print(2)
        emit(:99)
        print(3)
    ]]
    print("Testing...", "tasks 12")
    local out = atm_test(src)
    assertx(out, "0\n10\n10\n1\n20\n30\n2\n20\n30\n3\n")

    local src = [[
        pin ts = tasks(2)
        var T
        set T = func (v) {
            defer {
                print(v)
            }
            catch :ok ;;;(err|err==:ok);;; {
                spawn {
                    await(true)
                    if v == 1 {
                        throw(:ok)
                    }
                    loop { await(true) }
                }
                loop { await(true) }
            }
            print(v)
        }
        spawn [ts] T(1)
        spawn [ts] T(2)
        emit(:)
        emit(:)
        print(999)
    ]]
    print("Testing...", "tasks 13")
    local out = atm_test(src)
    assertx(out, "1\n1\n999\n2\n")

    local src = [[
        pin ts = tasks(2)
        var T
        set T = func (v) {
            defer {
                print(v)
            }
            catch :ok ;;;(err|err==:ok);;; {
                spawn {
                    await(true)
                    if v == 2 {
                        throw(:ok)
                    }
                    loop { await(true) }
                }
                loop { await(true) }
            }
            print(v)
        }
        spawn [ts] T(1)
        spawn [ts] T(2)
        emit(:)
        emit(:)
        print(999)
    ]]
    print("Testing...", "tasks 14")
    local out = atm_test(src)
    assertx(out, "2\n2\n999\n1\n")

    local src = [[
        val tup = @{}
        val T = func () {
            set ;;;task.;;;pub = tup
            await(true)
        }
        pin ts = tasks()
        spawn [ts] T()
        spawn [ts] T()
        print(:ok)
    ]]
    print("Testing...", "tasks 15")
    local out = atm_test(src)
    assertx(out, "ok\n")

    local src = [[
        var T = func () {
            set pub = @{10}
            await(true)
        }
        pin ts = tasks()
        spawn [ts] T()
        loop _,t in ts {
            var x = t.pub
            emit [t] (:nil)
            xprint(x)
        }
        print(999)
    ]]
    print("Testing...", "tasks 16")
    local out = atm_test(src)
    assertx(out, "{10}\n999\n")

    local src = [[
        func T () {}
        pin ts = tasks(0)
        val x = spawn [ts] T()
        print(x)
    ]]
    print("Testing...", "tasks 17")
    local out = atm_test(src)
    assertx(out, "nil\n")

    local src = [[
        pin x = tasks(true)
    ]]
    print("Testing...", "tasks 18")
    local out = atm_test(src)
    --assertx(out, "anon.atm : line 1 : invalid tasks limit : expected number")
    assertx(trim(out), trim [[
        ==> ERROR:
         |  [C]:-1 (call)
         v  [string "anon.atm"]:1 (throw)
        ==> invalid tasks limit : expected number
    ]])

    local src = [[
        pin ts = tasks(1)
        var T = func () { await(true) }
        val t1 = spawn [ts] T()
        val t2 = spawn [ts] T()
        emit [ts] (:)
        val t3 = spawn [ts] T()
        val t4 = spawn [ts] T()
        print(t1??:task, t2??:task, t3??:task, t4??:task)
    ]]
    print("Testing...", "tasks 19")
    local out = atm_test(src)
    assertx(out, "true\tfalse\ttrue\tfalse\n")

    local src = [[
        pin ts = tasks(1)
        var T
        set T = func () { await(true) }
        val ok1 = spawn [ts] T()
        emit [ts] (:)
        val ok2 = spawn [ts] T()
        print(atmos.status(ok1), atmos.status(ok2))
    ]]
    print("Testing...", "tasks 20")
    local out = atm_test(src)
    assertx(out, "dead\tsuspended\n")

    local src = [[
        var T = func (n) {
            set pub = n
            await(tostring(n))
        }
        pin ts = tasks(2)
        spawn [ts] T(1)
        spawn [ts] T(2)
        loop _,t in ts {
            print(:t, t.pub)
            emit(:2)        ;; opens hole for 99 below
            val ok = spawn [ts] T(99)     ;; must not fill hole b/c ts in the stack
            print(ok)
        }
        loop _,t in ts {
            print(:t, t.pub)
        }
    ]]
    print("Testing...", "tasks 21")
    local out = atm_test(src)
    assertx(out, "t\t1\nnil\nt\t2\nnil\nt\t1\n")

    local src = [[
        func T () {
            await(true)
        }
        pin ts = tasks()
        spawn [ts] T()
        spawn {
            loop _ in ts {
                break()
            }
        }
        print(ts._.ing)
    ]]
    print("Testing...", "tasks 22")
    local out = atm_test(src)
    assertx(out, "0\n")

    local src = [[
        func T () {
            await(true)
        }
        pin ts = tasks()
        spawn [ts] T()
        spawn {
            val x = loop _,t in ts {
                break(t)
            }
            await(x)
            print :ok
        }
        emit(:X)
    ]]
    print("Testing...", "tasks 23: awake t.up.up")
    local out = atm_test(src)
    assertx(out, "ok\n")

    local src = [[
        func T () { await(false) }
        pin xs = tasks()
        pin ys = tasks()
        val x = spawn [xs] T()
        val y = spawn [ys] T()
        val ts = xs ++ ys
        print(#(xs ++ ys), x?>ts, y?>ts, 10?>ts)
    ]]
    print("Testing...", "tasks 24: ++")
    local out = atm_test(src)
    assertx(out, "2\ttrue\ttrue\tfalse\n")
end

print '--- EVERY ---'

do
    local src = [[
        spawn {
            every :X {
                print(:X)
            }
        }
        emit(:X)
        emit(:Y)
        emit(:X)
    ]]
    print("Testing...", "every 1")
    local out = atm_test(src)
    assertx(out, "X\nX\n")

    local src = [[
        spawn {
            every :X,10 \(_,v){
                print(:X, v)
            }
        }
        emit(:X)
        emit(:Y)
        emit(:X,10)
    ]]
    print("Testing...", "every 2")
    local out = atm_test(src)
    assertx(out, "X\t10\n")

    local src = [[
        spawn {
            every :X {
                x where {
                    x = match x {
                        x => x
                    }
                }
            }
        }
        print(:ok)
    ]]
    print("Testing...", "every-where")
    local out = atm_test(src)
    assertx(out, "ok\n")

    local src = [[
        spawn {
            par {
                every :X {
                    print("x")
                }
            } with {
                every @.10 {
                    print("ms")
                }
            }
        }
        emit(@.10)
        emit(:X)
        emit(@.5)
        emit(:X)
        emit(@.5)
    ]]
    print("Testing...", "every-clock")
    local out = atm_test(src)
    assertx(out, "ms\nx\nx\nms\n")

    local src = [[
        spawn {
            every :X \{
                print(it.v)
            }
        }
        emit <-- :X @{v=10}
    ]]
    print("Testing...", "every table")
    local out = atm_test(src)
    assertx(out, "10\n")
end

print '--- PAR / PAR_AND / PAR_OR / WATCHING ---'

do
    local src = [[
        spawn {
            par {
            } with {
            }
        }
        print(:X)
    ]]
    print("Testing...", "par 0")
    local out = atm_test(src)
    assertx(out, "X\n")

    local src = [[
        spawn {
            par {
                every :X {
                    print(:X)
                }
            } with {
                every :Y {
                    print(:Y)
                }
            }
        }
        emit(:X)
        emit(:Y)
        emit(:X)
    ]]
    print("Testing...", "par 1")
    local out = atm_test(src)
    assertx(out, "X\nY\nX\n")

    local src = [[
        spawn {
            par {
                await(:X)
            } with {
                await(:Y)
            }
            print(:ok)
        }
        emit(:X)
        emit(:X)
        print(:antes)
        emit(:Y)
        print(:depois)
    ]]
    print("Testing...", "par 2")
    local out = atm_test(src)
    assertx(out, "antes\ndepois\n")

    local src = [[
        spawn {
            par_and {
                await(:X)
            } with {
                await(:Y)
            }
            print(:ok)
        }
        emit(:X)
        emit(:X)
        print(:antes)
        emit(:Y)
        print(:depois)
    ]]
    print("Testing...", "par_and 1")
    local out = atm_test(src)
    assertx(out, "antes\nok\ndepois\n")

    local src = [[
        spawn {
            par_or {
                await(:X)
            } with {
                await(:Y)
            }
            print(:ok)
        }
        emit(:X)
        emit(:X)
        print(:antes)
        emit(:Y)
        print(:depois)
    ]]
    print("Testing...", "par_or 1")
    local out = atm_test(src)
    assertx(out, "ok\nantes\ndepois\n")

    local src = [[
        spawn {
            par_or {
                await(:X)
                print(:x)
            } with {
                defer {
                    print(:y)
                }
                await(:Y)
                print(:no)
            }
            print(:ok)
        }
        emit(:X)
        emit(:X)
        print(:antes)
        emit(:Y)
        print(:depois)
    ]]
    print("Testing...", "par_or 2")
    local out = atm_test(src)
    assertx(out, "x\ny\nok\nantes\ndepois\n")

    local src = [[
        spawn {
            watching :X {
                await(:Y)
                print(:y)
                await(:Z)
                print(:z)
            }
            print(:x)
        }
        print(:antes)
        emit(:Y)
        emit(:X)
        emit(:Z)
        print(:depois)
    ]]
    print("Testing...", "watching 1")
    local out = atm_test(src)
    assertx(out, "antes\ny\nx\ndepois\n")

    local src = [[
        val x = do {
            10
        }
        print(x)
    ]]
    print("Testing...", "do: return")
    local out = atm_test(src)
    assertx(out, "10\n")

    local src = [[
        spawn {
            val x = par_or {
                await(false)
            } with {
                10
            }
            print(x)
        }
    ]]
    print("Testing...", "par_or 3: return")
    local out = atm_test(src)
    assertx(out, "10\n")

    local src = [[
        spawn {
            val x = par_and {
                await(true)
                10
            } with {
                20
            }
            emit(:10)
            xprint(x)
        }
    ]]
    print("Testing...", "par_and 3: return")
    local out = atm_test(src)
    assertx(out, "{10, 20}\n")

    local src = [[
        spawn {
            watching :X {
                print :Y
            }
            print :X
        }
    ]]
    print("Testing...", "watching 2")
    local out = atm_test(src)
    assertx(out, "Y\nX\n")

    local src = [[
        spawn {
            par_or {
                await(:X)
                print("x")
            } with {
                every :X {
                    print("no")
                }
            }
            print("or")
        }
        emit(:X)
        emit(:X)
        emit(:X)
        emit(:X)
        print("ok")
    ]]
    print("Testing...", "par_or 4")
    local out = atm_test(src)
    assertx(out, "x\nor\nok\n")

    local src = [[
        spawn {
            par_or {
                await(:X)
                print("x")
            } with {
                every :X {
                    print("no")
                }
            }
            print("or")
        }
        emit(:X)
        print("ok")
    ]]
    print("Testing...", "par_or 5")
    local out = atm_test(src)
    assertx(out, "x\nor\nok\n")
end
