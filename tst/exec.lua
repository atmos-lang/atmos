-- LUA_PATH="/x/atmos/src/?.lua;" lua5.4 exec.lua

require "lexer"
require "stmt"
require "tostr"
require "coder"
require "exec"

-- EXPR / STRING / TAG

do
    local src = [[
        print("xxx")
        print(:2)
        print(nil || 20)
    ]]
    print("Testing...", "block 1")
    local out = exec_string("anon.atm", src)
    assertx(out, "xxx\n2\n20\n")
end

-- BLOCK / DO / ESCAPE / DEFER

do
    local src = [[
        do {
            print(:ok)
        }
    ]]
    print("Testing...", "block 2")
    init()
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()
    local f = assert(io.open("/tmp/anon.lua", 'w'))
    f:write(coder_stmt(s))
    f:close()
    local exe = assert(io.popen("lua5.4 /tmp/anon.lua", 'r'))
    local out = exe:read('a')
    assert(out == "ok\n")

    local src = [[
        print(:1)
        print(:2)
    ]]
    print("Testing...", "block 3")
    local out = exec_string("anon.atm", src)
    assert(out == "1\n2\n")

    local src = [[
        print(:1)
        do :X {
            print(:2)
            escape:X()
            print(:3)
        }
        print(:4)
    ]]
    print("Testing...", "block 4")
    local out = exec_string("anon.atm", src)
    assertx(out, "1\n2\n4\n")

    local src = [[
        do :X {
            escape :Y()
        }
    ]]
    print("Testing...", "block 5 : err : goto")
    local out = exec_string("anon.atm", src)
    assert(out == "anon.atm : line 2 : no visible label 'Y' for <goto>\n")

    local src = [[
        val a = 1
        do :X {
            val b = 2
            print(a+b)
        }
    ]]
    print("Testing...", "block 6")
    local out = exec_string("anon.atm", src)

    local src = [[
        val a = 1
        do :X {
            val b = 2
        }
        print(a+b)
    ]]
    print("Testing...", "block 6")
    local out = exec_string("anon.atm", src)
    assert(out == "anon.atm : line 5 : attempt to perform arithmetic on a nil value (global 'b')\n")

    local src = [[
        print(:1)
        defer {
            print(:2)
        }
        print(:3)
    ]]
    print("Testing...", "defer 1")
    local out = exec_string("anon.atm", src)
    assert(out == "1\n3\n2\n")

    local src = [[
        val x = do :X {
            do :Y {
                escape:X(10)
            }
        }
        print(x)
    ]]
    print("Testing...", "do-escape 1")
    local out = exec_string("anon.atm", src)
    assert(out == "10\n")
end

-- DCL / VAL / VAR / SET

do
    local src = [[
        var x
        set x = 10
        print(x)
    ]]
    print("Testing...", "var 1")
    local out = exec_string("anon.atm", src)
    assert(out == "10\n")

    local src = [[
        val x = :1
        print(x)
    ]]
    print("Testing...", "var 2")
    local out = exec_string("anon.atm", src)
    assert(out == "1\n")

    local src = [[
        val x
        set x = :1
        print(x)
    ]]
    print("Testing...", "var 3")
    local out = exec_string("anon.atm", src)
    assert(out == "anon.atm : line 2 : attempt to assign to const variable 'x'\n")

    local src = [[
        val _ = 10
        print(_)
    ]]
    print("Testing...", "var 3: _")
    local out = exec_string("anon.atm", src)
    assert(out == "10\n")

    local src = [[
        val x = 10
        print(x)
        do {
            val x = 20
            print(x)
        }
        print(x)
    ]]
    print("Testing...", "block 1")
    local out = exec_string("anon.atm", src)
    assert(out == "10\n20\n10\n")

    local src = [[
        val x, y, z = 10, 20
        print(x, y, z)
    ]]
    print("Testing...", "set 1: multi")
    local out = exec_string("anon.atm", src)
    assert(out == "10\t20\tnil\n")

    local src = [[
        val x, y, z = 10, 20
        set x, y = y, x, z
        print(x, y, z)
    ]]
    print("Testing...", "set 1: multi")
    local out = exec_string("anon.atm", src)
    assert(out == "20\t10\tnil\n")
end

-- TABLE / INDEX

do
    local src = [[
        val t = [1, x=10, (:y,20)]
        print(t[0], t[:x], t.y)
    ]]
    print("Testing...", "table 1")
    local out = exec_string("anon.atm", src)
    assert(out == "1\t10\t20\n")

    local src = "print((1)[1])"
    print("Testing...", src)
    local out = exec_string("anon.atm", src)
    assert(out == "anon.atm : line 1 : attempt to index a number value\n")

    local src = "print(([1])[[]])"
    print("Testing...", src)
    local out = exec_string("anon.atm", src)
    assertx(out, "nil\n")

    local src = "print(([[1]])[([0])[0]][0])"
    print("Testing...", src)
    local out = exec_string("anon.atm", src)
    assert(out == "1\n")

    local src = "dump(([[1]])[([0])[0]])"
    print("Testing...", src)
    local out = exec_string("anon.atm", src)
    assert(out == "{ 1 }\n")

    local src = "dump([(:key,:val)])"
    print("Testing...", src)
    local out = exec_string("anon.atm", src)
    assertx(out, "{ key=val }\n")

    local src = "print(type([(:key,:val)]))"
    print("Testing...", src)
    local out = exec_string("anon.atm", src)
    assert(out == "table\n")

    local src = [[
        val t = [(:x,1)]
        print(t[:x], t.x)
    ]]
    print("Testing...", "table 1")
    local out = exec_string("anon.atm", src)
    assert(out == "1\t1\n")
end

-- CALL / FUNC / RETURN

do
    local src = "print(10, nil, false, 2+2)"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local s = parser_stmt()

    local f = assert(io.open("/tmp/anon.lua", "w"))
    f:write(tostr_expr(s.e))
    f:close()

    local exe = assert(io.popen("lua5.4 /tmp/anon.lua", "r"))
    local out = exe:read("a")
    assert(out == "10\tnil\tfalse\t4\n")

    local src = [[
        val f = func (x, y) {
            return (x + y)
        }
        print(f(10,20))
    ]]
    print("Testing...", "func 1")
    local out = exec_string("anon.atm", src)
    assert(out == "30\n")

    local src = [[
        val f = func (x) {
            return (func (y) {
                return (x + y)
            })
        }
        print(f(10)(20))
    ]]
    print("Testing...", "func 2")
    local out = exec_string("anon.atm", src)
    assert(out == "30\n")

    local src = "print(func () {})"
    print("Testing...", src)
    local out = exec_string("anon.atm", src)
    assert(string.find(out, "function: 0x"))

    local src = [[
        val f = func (x) {
            print(v)
        }
        val v = 10
        print(v)
        f()
    ]]
    print("Testing...", "func 3")
    local out = exec_string("anon.atm", src)
    assert(out == "10\nnil\n")

    local src = [[
        func f (v) {
            if v == 0 {
                return (0)
            } else {
                return (v + f(v - 1))
            }
        }
        print(f(4))
    ]]
    print("Testing...", "func 3: recursive")
    local out = exec_string("anon.atm", src)
    assert(out == "10\n")

    local src = [[
        var f, g
        set f = func (v) {
            if v == 0 {
                return (0)
            } else {
                return (v + g(v - 1))
            }
        }
        set g = func (v) {
            if v == 0 {
                return (0)
            } else {
                return (v + f(v - 1))
            }
        }
        print(f(4))
    ]]
    print("Testing...", "func 4: mutual recursive")
    local out = exec_string("anon.atm", src)
    assert(out == "10\n")
end

-- IF-ELSE / LOOP

do
    local src = [[
        if true {
            print(:t)
        }
        if false {
        } else {
            print(:f)
        }
    ]]
    print("Testing...", "if 1")
    local out = exec_string("anon.atm", src)
    assert(out == "t\nf\n")

    local src = [[
        print(:1)
        loop {
            print(:2)
            break
            print(:3)
        }
        print(:4)
    ]]
    print("Testing...", "loop 1")
    local out = exec_string("anon.atm", src)
    assert(out == "1\n2\n4\n")

    local src = [[
        loop x {
            print(x)
            if x == 2 {
                break
            }
        }
    ]]
    print("Testing...", "loop 2")
    local out = exec_string("anon.atm", src)
    assert(out == "0\n1\n2\n")

    local src = [[
        loop x in 2 {
            print(x)
        }
    ]]
    print("Testing...", "loop 3")
    local out = exec_string("anon.atm", src)
    assert(out == "0\n1\n")

    local src = [[
        print(:1)
        loop x in (func () { return(nil) }) {
            print(x)
        }
        print(:2)
    ]]
    print("Testing...", "loop 4")
    local out = exec_string("anon.atm", src)
    assert(out == "1\n2\n")

    local src = [[
        loop i,v in [1,2,3] {
            print(i,v)
        }
    ]]
    print("Testing...", "loop 5")
    local out = exec_string("anon.atm", src)
    assert(out == "0\t1\n1\t2\n2\t3\n")

    local src = [[
        loop k,v in [x=1,y=2] {
            print(k,v)
        }
    ]]
    print("Testing...", "loop 6")
    local out = exec_string("anon.atm", src)
    assert(out=="x\t1\ny\t2\n" or "y\t2\nx\t1\n")
end

-- CATCH / THROW

do
    local src = [[
        print(:1)
        catch :X {
            print(:2)
            throw(:X)
            print(:3)
        }
        print(:4)
    ]]
    print("Testing...", "catch 1")
    local out = exec_string("anon.atm", src)
    assertx(out, "1\n2\n4\n")

    local src = [[
        print(:1)
        catch true {
            print(:2)
            throw()
            print(:3)
        }
        print(:4)
    ]]
    print("Testing...", "catch 2")
    local out = exec_string("anon.atm", src)
    assert(out == "1\n2\n4\n")

    local src = [[
        print(:1)
        catch :Y {
            print(:2)
            catch :X {
                print(:3)
                throw(:Y)
                print(:4)
            }
            print(:5)
        }
        print(:6)
    ]]
    print("Testing...", "catch 3")
    local out = exec_string("anon.atm", src)
    assert(out == "1\n2\n3\n6\n")

    local src = [[
        print(:1)
        catch true, it==10 {
            print(:2)
            catch true, it!=10 {
                print(:3)
                throw(10)
                print(:4)
            }
            print(:5)
        }
        print(:6)
    ]]
    print("Testing...", "catch 4")
    local out = exec_string("anon.atm", src)
    assert(out == "1\n2\n3\n6\n")

    local src = [[
        val ok,v = catch true {
            throw(10)
        }
        print(ok,v)
    ]]
    print("Testing...", "catch 5")
    local out = exec_string("anon.atm", src)
    assertx(out, "false\t10\n")

    local src = [[
        val ok,v = catch true {
            return(10)
        }
        print(ok,v)
    ]]
    print("Testing...", "catch 6")
    local out = exec_string("anon.atm", src)
    assertx(out, "true\t10\n")
end

-- EXEC / CORO / TASK / TASKS / YIELD / SPAWN / RESUME / TASKS

do
    local src = [[
        val F = func (a) {
            val b = yield(10)
            val c = yield()
            print(a, b, c)
            return(20)
        }
        val f = coro(F)
        val a = resume f(1)
        val b = resume f(nil)
        val c = resume f(2)
        print(a, b, c)
    ]]
    print("Testing...", "coro 1")
    local out = exec_string("anon.atm", src)
    assert(out == "1\tnil\t2\ntrue\ttrue\ttrue\n")

    local src = [[
        val T = func (a) {
            print(a)
            val b = await(:X)
            print(b)
        }
        val t = task(T)
        spawn t(10)
        emit(:X)
    ]]
    print("Testing...", "task 1")
    local out = exec_string("anon.atm", src)
    assertx(out, "10\nX\n")

    local src = [[
        val T = func (a) {
            print(a)
            val b = await(true)
            print(b)
        }
        spawn T(10)
        emit()
    ]]
    print("Testing...", "task 2")
    local out = exec_string("anon.atm", src)
    assertx(out, "10\nnil\n")

    local src = [[
        val F = func (a,b) {
            val c,d = yield(a+1,b*2)
            return(c+1, d*2)
        }
        val f = coro(F)
        val _,a,b = resume f(1,2)
        val _,c,d = resume f(a+1,b*2)
        print(c, d)
    ]]
    print("Testing...", "coro 2: multi")
    local out = exec_string("anon.atm", src)
    assert(out == "4\t16\n")

    local src = [[
        val t = func (v) {
            var vx = v
            print(vx)          ;; 1
            set vx = yield(vx+1)
            print(vx)          ;; 3
            set vx = yield(vx+1)
            print(vx)          ;; 5
            return (vx+1)
        }
        val a = coro(t)
        val _,v = resume a(1)
        print(v)
        val _,v = resume a(v+1)
        print(v)              ;; 4
        val _,v = resume a(v+1)
        print(v)              ;; 6

    ]]
    print("Testing...", "coro 3: multi")
    local out = exec_string("anon.atm", src)
    assert(out == "1\n2\n3\n4\n5\n6\n")

    local src = [[
        print(emit(1))
    ]]
    print("Testing...", "emit 1")
    local out = exec_string("anon.atm", src)

    local src = [[
        val tk = func (v) {
            val e1 = await(true)
            print(:1, e1)
            val e2 = await(true)
            print(:2, e2)
        }
        spawn tk ()
        emit(1)
        emit(2)
        emit(3)

    ]]
    print("Testing...", "emit 2")
    local out = exec_string("anon.atm", src)
    assert(out == "1\t1\n2\t2\n")

    local src = [[
        emit(1) in false
    ]]
    print("Testing...", "emit 1")
    local out = exec_string("anon.atm", src)
    assertx(out, "anon.atm : line 1 : invalid emit : invalid target\n")

    local src = [[
        spawn (func () {
            spawn (func () {
                throw(:X)
            }) ()
        }) ()
    ]]
    print("Testing...", "task-throw-catch 1")
    local out = exec_string("anon.atm", src)
    warnx(out, "anon.atm : line 1 : invalid emit : invalid target\n")

    local src = [[
        spawn (func () {
            set pub = 10
            print(pub)
        }) ()
    ]]
    print("Testing...", "pub 1")
    local out = exec_string("anon.atm", src)
    assertx(out, "10\n")

    local src = [[
        val t = spawn (func () {
            set pub = 10
        }) ()
        print(t.pub)
    ]]
    print("Testing...", "pub 2")
    local out = exec_string("anon.atm", src)
    assertx(out, "10\n")

    local src = [[
        print(:1)
        do {
            print(:2)
            val x = spawn (func () {
                defer {
                    print(:defer)
                }
                await(true)
            } )()
            print(:3)
        }
        print(:4)
    ]]
    print("Testing...", "abort 1")
    local out = exec_string("anon.atm", src)
    assertx(out, "1\n2\n3\n4\ndefer\n")

    local src = [[
        print(:1)
        do {
            print(:2)
            pin x = spawn {
                defer {
                    print(:defer)
                }
                await(true)
            }
            print(:3)
        }
        print(:4)
    ]]
    print("Testing...", "abort 2")
    local out = exec_string("anon.atm", src)
    assertx(out, "1\n2\n3\ndefer\n4\n")

    local src = [[
        print(:1)
        do {
            print(:2)
            spawn {
                defer {
                    print(:defer)
                }
                await(true)
            }
            print(:3)
        }
        print(:4)
    ]]
    print("Testing...", "abort 3")
    local out = exec_string("anon.atm", src)
    assertx(out, "1\n2\n3\ndefer\n4\n")

    local src = [[
        catch :e {
            spawn {
                throw(:e)
                print(:no)
            }
            print(:no)
        }
        print(:ok)
    ]]
    print("Testing...", "task - catch 1")
    local out = exec_string("anon.atm", src)
    assertx(out, "ok\n")

    local src = [[
        spawn {
            catch :e {
                spawn {
                    print(:1)
                    await(true)
                    print(:e)
                    throw(:e)
                    print(:no1)
                }
                print(:2)
                await(true)
                print(:no2)
            }
            print(:4)
        }
        print(:3)
        emit(true)
        print(:5)
    ]]
    print("Testing...", "task - catch 2")
    local out = exec_string("anon.atm", src)
    assertx(out, "1\n2\n3\ne\n4\n5\n")

    local src = [[
        print(tasks())
    ]]
    print("Testing...", "tasks 1")
    local out = exec_string("anon.atm", src)
    assertfx(out, "table: 0x")

    local src = [[
        print(type(tasks()))
    ]]
    print("Testing...", "tasks 2")
    local out = exec_string("anon.atm", src)
    assertx(out, "table\n")

    local src = [[
        val T = func () {
            print(:in)
        }
        val ts = tasks()
        spawn T() in ts
        print(:out)
    ]]
    print("Testing...", "tasks 3")
    local out = exec_string("anon.atm", src)
    assertx(out, "in\nout\n")
end

-- ERROR / LINE NUMBER

do
    local src = [[
        val f = func (x) {
            return (func (y) {
                return(x+nil)
            })
        }
        print(f(10)(20))
    ]]
    print("Testing...", "func 4")
    local out = exec_string("anon.atm", src)
    assert(out == "anon.atm : line 3 : attempt to perform arithmetic on a nil value\n")
end
