require "lexer"
require "parser"
require "tosource"
require "coder"
require "exec"

-- EXPR / STRING / TAG

do
    local src = [[
        print("xxx")
        print(:2)
        print(nil || 20)
    ]]
    print("Testing...", "expr 1")
    local out = atm_test(src)
    assertx(out, "xxx\n2\n20\n")

    local src = [[
        print('a' ++ 'b' ++ 'c')
        dump(@{x=1} ++ @{y=2} ++ @{z=3})
        dump(#{1} ++ #{2} ++ #{3})
    ]]
    print("Testing...", "expr 2")
    local out = atm_test(src)
    assertx(out, "abc\n{x=1, y=2, z=3}\n#{1, 2, 3}\n")

    local src = "print(!false)"
    print("Testing...", src)
    local out = atm_test(src)
    assertx(out, "true\n")
end

print "--- NATIVE ---"

do
    local src = [[
        ```
        print 'ok'
        ```
    ]]
    print("Testing...", "native 1")
    local out = atm_test(src)
    assertx(out, "ok\n")

    local src = [[
        var x = 1 + `10`
        `print(x)`
    ]]
    print("Testing...", "native 2")
    local out = atm_test(src)
    assertx(out, "11\n")

    local src = [[
        ```
        _xy = { 10,20 }
        ```
        print(_xy[2])
    ]]
    print("Testing...", "native 3")
    local out = atm_test(src)
    assertx(out, "20\n")

    local src = "`print`(10)"
    print("Testing...", src)
    local out = atm_test(src)
    assertx(out, "10\n")

    local src = "`print`(`10`+10)"
    print("Testing...", src)
    local out = atm_test(src)
    assertx(out, "20\n")

    local src = [[
        assert(10 == `10`)
        print `'ok'`
    ]]
    print("Testing...", "native 3")
    local out = atm_test(src)
    assertx(out, "ok\n")
end

-- BLOCK / DO

do
    local src = [[
        do {
            print(:ok)
        }
    ]]
    print("Testing...", "block 2")
    init()
    lexer_init("anon", src)
    lexer_next()
    local s = parser()
    local f = assert(io.open("/tmp/anon.lua", 'w'))
    f:write('require "run";\n')
    f:write(coder(s))
    f:close()
    local exe = assert(io.popen("lua5.4 /tmp/anon.lua", 'r'))
    local out = exe:read('a')
    assertx(out, "ok\n")

    local src = [[
        print(:1)
        print(:2)
    ]]
    print("Testing...", "block 3")
    local out = atm_test(src)
    assert(out == "1\n2\n")

    local src = [[
        val a = 1
        do {
            val b = 2
            print(a+b)
        }
    ]]
    print("Testing...", "block 4")
    local out = atm_test(src)

    local src = [[
        val a = 1
        do {
            val b = 2
        }
        print(a+b)
    ]]
    print("Testing...", "block 5")
    local out = atm_test(src)
    --assertx(out, "anon.atm : line 5 : attempt to perform arithmetic on a nil value (global 'b')")
    assertx(trim(out), trim [[
        ==> ERROR:
         |  [C]:-1 (call)
         v  [C]:-1 (throw)
        ==> [string "anon.atm"]:5: attempt to perform arithmetic on a nil value (global 'b')
    ]])

    local src = [[
        val x = do {
            10
        }
        print(x)
    ]]
    print("Testing...", "do 1")
    local out = atm_test(src)
    assertx(out, "10\n")

    local src = [[
        val x = do {
            10 ; 20
        }
        print(x)
    ]]
    print("Testing...", "do 2")
    local out = atm_test(src)
    assertx(out, "anon.atm : line 2 : unexpected symbol near '10'\n")

    local src = [[
        val x = do {
            do(10) ; 20
        }
        print(x)
    ]]
    print("Testing...", "do 2")
    local out = atm_test(src)
    assertx(out, "20\n")
end

print "--- DO / ESCAPE ---"

do
    local src = [[
        val x = do :X {
            do :Y {
                escape(:X,10)
            }
        }
        dump(x)
    ]]
    print("Testing...", "do 0")
    local out = atm_test(src)
    assertx(out, "10\n")

    local src = [[
        val x = do :X {
            var x
            set x = @{0}
            escape(:X,x)   ;; escape but no access
        }
        dump(x)
    ]]
    print("Testing...", "do 1")
    local out = atm_test(src)
    assertx(out, "{0}\n")

    local src = [[
        val a,b = do :X {
            escape(:X,10,20)
        }
        print(a,b)
    ]]
    print("Testing...", "do 2")
    local out = atm_test(src)
    assertx(out, "10\t20\n")

    local src = [[
        val a,b = do :X {
            (10,20)
        }
        print(a,b)
    ]]
    print("Testing...", "do 3")
    local out = atm_test(src)
    assertx(out, "10\t20\n")

    local src = [[
        val x = do :X {
            escape <- :X @{10}
        }
        dump(x)
    ]]
    print("Testing...", "do 4")
    local out = atm_test(src)
    assertx(out, "{10, tag=X}\n")

    local src = [[
        do :X.Z {
            do :X.Y {
                escape(:X.Z)
                print(99)
            }
            print(99)
        }
        print(10)
    ]]
    print("Testing...", "do 5")
    local out = atm_test(src)
    assertx(out, "10\n")
end

print "--- DEFER ---"

do
    local src = [[
        print(:1)
        defer {
            print(:2)
        }
        print(:3)
    ]]
    print("Testing...", "defer 1")
    local out = atm_test(src)
    assert(out == "1\n3\n2\n")

    local src = [[
        print(:1)
        defer { print(:2) }
        defer { print(:3) }
        print(:4)
    ]]
    print("Testing...", "defer 2")
    local out = atm_test(src)
    assert(out == "1\n4\n3\n2\n")

    local src = [[
        print(1)
        defer { print(2) }
        do {
            defer { print(3) }
            defer { print(4) }
            nil ;; TODO
        }
        defer { print(5) }
        print(6)
    ]]
    print("Testing...", "defer 3")
    local out = atm_test(src)
    assertx(out, "1\n4\n3\n6\n5\n2\n")
    warn(false, "TODO: defer as last stmt")

    local src = [[
        do {
            defer {
                print(10)
            }
            throw(:X)
            print(99)
        }
    ]]
    print("Testing...", "defer 4")
    local out = atm_test(src)
    assertx(trim(out), trim [[
        10
        ==> ERROR:
         |  [C]:-1 (call)
         v  [string "anon.atm"]:5 (throw) <- [C]:-1 (task)
        ==> X
    ]])
end

-- DCL / VAL / VAR / SET

do
    local src = [[
        var x
        set x = 10
        print(x)
    ]]
    print("Testing...", "var 1")
    local out = atm_test(src)
    assertx(out, "10\n")

    local src = [[
        val x = :1
        print(x)
    ]]
    print("Testing...", "var 2")
    local out = atm_test(src)
    assert(out == "1\n")

    local src = [[
        val x
        set x = :1
        print(x)
    ]]
    print("Testing...", "var 3")
    local out = atm_test(src)
    assertx(out, "anon.atm : line 2 : attempt to assign to const variable 'x'\n")

    local src = [[
        val _ = 10
        print(_)
    ]]
    print("Testing...", "var 3: _")
    local out = atm_test(src)
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
    local out = atm_test(src)
    assert(out == "10\n20\n10\n")

    local src = [[
        val x, y, z = (10, 20)
        print(x, y, z)
    ]]
    print("Testing...", "set 1: multi")
    local out = atm_test(src)
    assertx(out, "10\t20\tnil\n")

    local src = [[
        val x, y, z = (10, 20)
        set x, y = (y, (x, z))
        print(x, y, z)
    ]]
    print("Testing...", "set 1: multi")
    local out = atm_test(src)
    assert(out == "20\t10\tnil\n")
end

-- TABLE / INDEX / VECTOR

do
    local src = [[
        val t = @{1, x=10, [:y]=20}
        print(t[0], t[1], t[:x], t.y)
    ]]
    print("Testing...", "table 1")
    local out = atm_test(src)
    assertx(out, "nil\t1\t10\t20\n")

    local src = "print((1)[1])"
    print("Testing...", src)
    local out = atm_test(src)
    assertx(trim(out), trim [[
        ==> ERROR:
         |  [C]:-1 (call)
         v  [C]:-1 (throw)
        ==> [string "anon.atm"]:1: attempt to index a number value
    ]])

    local src = "print((#{1})[#{}])"
    print("Testing...", src)
    local out = atm_test(src)
    assertx(out, "nil\n")

    local src = "print((#{#{1}})[(#{0})[0]][0])"
    print("Testing...", src)
    local out = atm_test(src)
    assertx(out, "1\n")

    local src = "dump((#{#{1}})[(#{0})[0]])"
    print("Testing...", src)
    local out = atm_test(src)
    assertx(out, "#{1}\n")

    local src = "dump(@{[:key]=:val})"
    print("Testing...", src)
    local out = atm_test(src)
    assertx(out, "{key=val}\n")

    local src = "print(type(@{[:key]=:val}))"
    print("Testing...", src)
    local out = atm_test(src)
    assert(out == "table\n")

    local src = [[
        val t = @{[:x]=1}
        print(t[:x], t.x)
    ]]
    print("Testing...", "table 1")
    local out = atm_test(src)
    assert(out == "1\t1\n")

    local src = "dump(:X @{10})"
    print("Testing...", src)
    local out = atm_test(src)
    assertx(out, "{10, tag=X}\n")

    local src = [[
        val t = #{}
        print(#t)
        set t[#t] = 10
        print(t[0])
        print(#t)
    ]]
    print("Testing...", src)
    local out = atm_test(src)
    assertx(out, "0\n10\n1\n")

    local src = [[
        val t = #{}
        print(#t)
        set t[#t] = 1
        print(#t)
        set t[#t-1] = nil
        print(#t)
    ]]
    print("Testing...", src)
    local out = atm_test(src)
    assertx(out, "0\n1\n0\n")

    local src = [[
        val t = #{}
        val x = t
        print(#x)
        set t[#t] = 1
        print(#x)
        set t[#t-1] = nil
        print(#x)
    ]]
    print("Testing...", src)
    local out = atm_test(src)
    assertx(out, "0\n1\n0\n")

    local src = [[
        val x = #{1,2,3}
        val t = #{}
        set t[#t] = 4
        set t[#t] = 5
        set t[#t-1] = nil
        dump(x ++ t ++ #{5,6,7})
    ]]
    print("Testing...", src)
    local out = atm_test(src)
    assertx(out, "#{1, 2, 3, 4, 5, 6, 7}\n")
end

-- CALL / FUNC / RETURN

do
    local src = "print(10, nil, false, 2+2)"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local s = parser()

    local f = assert(io.open("/tmp/anon.lua", "w"))
    f:write(tosource(s))
    f:close()

    local exe = assert(io.popen("lua5.4 /tmp/anon.lua", "r"))
    local out = exe:read("a")
    assert(out == "10\tnil\tfalse\t4\n")

    local src = [[
        val f = func (x, y) {
            (x + y)
        }
        print(f(10,20))
    ]]
    print("Testing...", "func 1")
    local out = atm_test(src)
    assertx(out, "30\n")

    local src = [[
        val f = func (x, y) {
            print(:1)
            return <- (x, y)
            print(:2)
        }
        print(f(10,20))
    ]]
    print("Testing...", "func 2")
    local out = atm_test(src)
    assertx(out, "1\n10\t20\n")

    local src = [[
        val f = func (x, y) {
            (x, y)
        }
        print(f(10,20))
    ]]
    print("Testing...", "func 2")
    local out = atm_test(src)
    assertx(out, "10\t20\n")

    local src = [[
        val f = func (x) {
            (func (y) {
                (x + y)
            })
        }
        print(f(10)(20))
    ]]
    print("Testing...", "func 2")
    local out = atm_test(src)
    assert(out == "30\n")

    local src = "print(func () {})"
    print("Testing...", src)
    local out = atm_test(src)
    --assertfx(out, "table: 0x")
    assertfx(out, "function: 0x")

    local src = [[
        val f = func (x) {
            print(v)
        }
        val v = 10
        print(v)
        f()
    ]]
    print("Testing...", "func 3")
    local out = atm_test(src)
    assert(out == "10\nnil\n")

    local src = [[
        func f (v) {
            if v == 0 {
                (0)
            } else {
                v + f(v - 1)
            }
        }
        print(f(4))
    ]]
    print("Testing...", "func 3: recursive")
    local out = atm_test(src)
    assertx(out, "10\n")

    local src = [[
        var f, g
        set f = func (v) {
            if v == 0 {
                0
            } else {
                (v + g(v - 1))
            }
        }
        set g = func (v) {
            if v == 0 {
                0
            } else {
                v + f(v - 1)
            }
        }
        print(f(4))
    ]]
    print("Testing...", "func 4: mutual recursive")
    local out = atm_test(src)
    assert(out == "10\n")

    local src = [[
        func f (v) {
            if v > 0 {
                @{f(v - 1)}
            } else {
                0
            }
        }
        dump(f(2))
    ]]
    print("Testing...", "func 5: recursive table")
    local out = atm_test(src)
    assertx(out, "{{0}}\n")

    local src = [[
        func f (v) {
            if v > 0 {
                val x = f(v - 1)
                @{x} ;; invalid return
            } else {
                0
            }
        }
        dump(f(3))
    ]]
    print("Testing...", "func 7: recursive table")
    local out = atm_test(src)
    assertx(out, "{{{0}}}\n")

    local src = [[
        func f (v) {
            if v != 0 {
                print(v)
                f(v - 1)
            }
        }
        f(3)
    ]]
    print("Testing...", "func 8: recursive")
    local out = atm_test(src)
    assertx(out, "3\n2\n1\n")

    local src = [[
        func f (a, ...) {
            print(a)
            print('x', ...)
        }
        f('a', 1, 2, 3)
    ]]
    print("Testing...", "func 6: dots ...")
    local out = atm_test(src)
    assertx(out, "a\nx\t1\t2\t3\n")

    local src = [[
        var i = 10
        func f () {
            var j = 20
            func g () {
                return(i + j)
            }
            print(g())
        }
        f()
    ]]
    print("Testing...", "func 7: nested")
    local out = atm_test(src)
    assertx(out, "30\n")

    local src = [[
        do {
            var i = 10
            func f () {
                do {
                    var j = 20
                    func g () {
                        return(i + j)
                    }
                    return(g)
                }
            }
            var gg = f()
            print(gg())
        }
    ]]
    print("Testing...", "func 8: nested")
    local out = atm_test(src)
    assertx(out, "30\n")

    local src = "return()"
    print("Testing...", "return")
    local out = atm_test(src)
    --assertx(out, "")
end

print "--- IF-ELSE / IFS / MATCH ---"

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
    local out = atm_test(src)
    assert(out == "t\nf\n")

    local src = "print(if false => 1 => 2)"
    print("Testing...", src)
    local out = atm_test(src)
    assertx(out, "2\n")

    local src = "print(if true => 1 => 2)"
    print("Testing...", src)
    local out = atm_test(src)
    assert(out=="1\n")

    local src = "print(if true => if true => 1 => 99 => 99)"
    print("Testing...", src)
    local out = atm_test(src)
    assert(out=="1\n")

    local src = "print(ifs { false=>99 ; true=>100 })"
    print("Testing...", src)
    local out = atm_test(src)
    assertx(out, "100\n")

    local src = "print(ifs { false=>0 ; true=>nil ; else=>99 })"
    print("Testing...", src)
    local out = atm_test(src)
    assertx(out, "nil\n") -- TODO: true=>nil

    local src = [[
        match 100 {
            10 => {}
            100 => print(:ok)
        }
    ]]
    print("Testing...", "match 1")
    local out = atm_test(src)
    assertx(out, "ok\n")

    local src = [[
        match :a.b.c {
            :a.b => 10
            else => 99
        } --> print
    ]]
    print("Testing...", "match 2")
    local out = atm_test(src)
    assertx(out, "10\n")

    local src = [[
        var x = :X.A @{a=10}
        match x {
            :X.A => { print(x.a) }
            else => { throw()  }
        }
    ]]
    print("Testing...", "match 3")
    local out = atm_test(src)
    assertx(out, "10\n")
end

print "--- LOOP / BREAK / UNTIL / WHILE / ITER ---"

do
    local src = [[
        print(:1)
        val x = loop {
            print(:2)
            break(10)
            print(:3)
        }
        print(:4)
        print(x)
    ]]
    print("Testing...", "loop 1")
    local out = atm_test(src)
    assertx(out, "1\n2\n4\n10\n")

    local src = [[
        loop x {
            print(x)
            if x == 2 {
                break()
            }
        }
    ]]
    print("Testing...", "loop 2")
    local out = atm_test(src)
    assertx(out, "0\n1\n2\n")

    local src = [[
        loop x in 2 {
            print(x)
        }
    ]]
    print("Testing...", "loop 3")
    local out = atm_test(src)
    assert(out == "0\n1\n")

    local src = [[
        print(:1)
        loop x in (func () { return<-nil }) {
            print(x)
        }
        print(:2)
    ]]
    print("Testing...", "loop 4")
    local out = atm_test(src)
    assertx(out, "1\n2\n")

    local src = [[
        loop k,v in @{1,2,3} {
            print(k,v)
        }
    ]]
    print("Testing...", "loop 5")
    local out = atm_test(src)
    assertx(out, "3\t3\n1\t1\n2\t2\n")

    local src = [[
        loop i,v in #{1,2,3} {
            print(i,v)
        }
    ]]
    print("Testing...", "loop 6")
    local out = atm_test(src)
    assertx(out, "0\t1\n1\t2\n2\t3\n")

    local src = [[
        loop k,v in @{x=1,y=2} {
            print(k,v)
        }
    ]]
    print("Testing...", "loop 7")
    local out = atm_test(src)
    assert(out=="x\t1\ny\t2\n" or out=="y\t2\nx\t1\n")

    local src = [[
        var i = 3
        func f () {
            set i = i - 1
            if i == 0 => nil => i
        }
        loop v in f {
            print(v)
        }
    ]]
    print("Testing...", "iter 1: func")
    local out = atm_test(src)
    assert(out == "2\n1\n")

    local src = [[
        var n = 0
        var i = 5
        loop {
            if i == 0 {
                break()
            }
            set n = n + i
            set i = i - 1
        }
        print(n)
    ]]
    print("Testing...", "loop 7")
    local out = atm_test(src)
    assertx(out, "15\n")

    local src = [[
        print(1)
        val x = loop {
            print(2)
            if true {
                break(10)
            }
            print(99)
        }
        print(3)
        print(x)
    ]]
    print("Testing...", "loop 8")
    local out = atm_test(src)
    assertx(out, "1\n2\n3\n10\n")

    local src = [[
        print(1)
        val x = loop {
            print(2)
            until <- (true,10)
            print(99)
        }
        print(3)
        print(x)
    ]]
    print("Testing...", "loop 9")
    local out = atm_test(src)
    assertx(out, "1\n2\n3\n10\n")

    local src = [[
        print(1)
        val x = loop {
            print(2)
            until <- 10
            print(99)
        }
        print(3)
        print(x)
    ]]
    print("Testing...", "loop 10")
    local out = atm_test(src)
    assertx(out, "1\n2\n3\n10\n")

    local src = [[
        print(1)
        val x = loop {
            print(2)
            while(false,10)
            print(99)
        }
        print(3)
        print(x)
    ]]
    print("Testing...", "loop 11")
    local out = atm_test(src)
    assertx(out, "1\n2\n3\n10\n")
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
    local out = atm_test(src)
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
    local out = atm_test(src)
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
    local out = atm_test(src)
    assert(out == "1\n2\n3\n6\n")

    local src = [[
        print(:1)
        catch (func (e) {e==10}) {
            print(:2)
            catch (func (e) {e!=10}) {
                print(:3)
                throw(10)
                print(:4)
            }
            print(:5)
        }
        print(:6)
    ]]
    print("Testing...", "catch 4")
    local out = atm_test(src)
    assert(out == "1\n2\n3\n6\n")

    local src = [[
        val ok,v = catch true {
            throw(10)
        }
        print(ok,v)
    ]]
    print("Testing...", "catch 5")
    local out = atm_test(src)
    assertx(out, "false\t10\n")

    local src = [[
        val ok,v = catch true {
            (10)
        }
        print(ok,v)
    ]]
    print("Testing...", "catch 6")
    local out = atm_test(src)
    assertx(out, "true\t10\n")

    local src = [[
        print(:1)
        catch :X {
            print(:2)
            throw(:X)
            print(:3)
        }
        print(:4)
    ]]
    print("Testing...", "catch 7")
    local out = atm_test(src)
    assertx(out, "1\n2\n4\n")

    local src = [[
        catch :X {
            throw(:Y)
        }
    ]]
    print("Testing...", "catch 8 : err : goto")
    local out = atm_test(src)
    --assertx(out, "anon.atm : line 2 : no visible label 'Y' for <goto>\n")
    assertx(trim(out), trim [[
        ==> ERROR:
         |  [C]:-1 (call)
         v  [C]:-1 (throw) <- [C]:-1 (task)
        ==> Y
    ]])
    warn(false, "error stack")

    local src = [[
        val a = 1
        catch :X {
            val b = 2
            print(a+b)
        }
    ]]
    print("Testing...", "catch 9")
    local out = atm_test(src)
    assertx(out, "3\n")

    local src = [[
        val a = 1
        catch :X {
            val b = 2
        }
        print(a+b)
    ]]
    print("Testing...", "catch 10")
    local out = atm_test(src)
    assertx(trim(out), trim [[
        ==> ERROR:
         |  [C]:-1 (call)
         v  [C]:-1 (throw)
        ==> [string "anon.atm"]:5: attempt to perform arithmetic on a nil value (global 'b')
    ]])

    local src = [[
        val _,x = catch :X {
            catch :Y {
                throw <- :X @{10}
            }
        }
        dump(x)
    ]]
    print("Testing...", "catch 11")
    local out = atm_test(src)
    assertx(out, "{10, tag=X}\n")

    local src = [[
        val x = catch :X {
            catch :Y {
                throw (:Z ;;;@{10};;;)
            }
            :ok
        }
        print(:ok)
    ]]
    print("Testing...", "catch 12")
    local out = atm_test(src)
--[=[
    assertx(trim(out), trim [[
        ==> ERROR:
         |  [C]:-1 (call)
         v  ??:?? (throw) <- [C]:-1 (task)
        ==> Z
    ]])
]=]
    --assertx(out, "uncaught throw : {10, tag=Z}")

    local src = [[
        val x = catch :Y.X {
            catch :Z {
                throw (:Y @{10})
            }
            :ok
        }
        print(:ok)
    ]]
    print("Testing...", "catch 13")
    local out = atm_test(src)
    --assertx(out, "uncaught throw : {10, tag=Y}")

    local src = [[
        val _,x = catch :Y {
            catch :Z {
                (func() { throw (:Y.X @{10}) })()
            }
            :ok
        }
        dump(x)
    ]]
    print("Testing...", "catch 14")
    local out = atm_test(src)
    assertx(out, "{10, tag=Y.X}\n")
end

-- EXEC / CORO / TASK / YIELD / SPAWN / RESUME

do
    local src = [[
        val F = func (a) {
            val b = coroutine.yield(10)
            val c = coroutine.yield()
            print(a, b, c)
            return <-- 20
            ;;20
        }
        val f = coroutine.create(F)
        val a = coroutine.resume(f,1)
        val b = coroutine.resume(f,nil)
        val c = coroutine.resume(f,2)
        print(a, b, c)
    ]]
    print("Testing...", "coro 1")
    local out = atm_test(src)
    --assertx(out, "1\tnil\t2\ntrue\ttrue\ttrue\n")

    local src = [[
        emit(true)
        nil
    ]]
    print("Testing...", "emit 1: err")
    local out = atm_test(src)
    --assertx(out, "anon.atm : line 1 : invalid emit : expected tag")
    warn(false, "tail call in emit hides line")

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
    local out = atm_test(src)
    assertx(out, "10\nX\n")

    local src = [[
        val T = func (a) {
            print(a)
            val b = await(true)
            print(b)
        }
        spawn T(10)
        emit(:ok)
    ]]
    print("Testing...", "task 2")
    local out = atm_test(src)
    assertx(out, "10\nok\n")

    local src = [[
        val F = func (a,b) {
            val c,d = coroutine.yield(a+1,b*2)
            (c+1, d*2)
        }
        val f = coroutine.create(F)
        val _,a,b = coroutine.resume(f,1,2)
        val _,c,d = coroutine.resume(f,a+1,b*2)
        print(c, d)
    ]]
    print("Testing...", "coro 2: multi")
    local out = atm_test(src)
    assert(out == "4\t16\n")

    local src = [[
        val t = func (v) {
            var vx = v
            print(vx)          ;; 1
            set vx = coroutine.yield(vx+1)
            print(vx)          ;; 3
            set vx = coroutine.yield(vx+1)
            print(vx)          ;; 5
            return (vx+1)
        }
        val a = coroutine.create(t)
        val _,v = coroutine.resume(a,1)
        print(v)
        val _,v = coroutine.resume(a,v+1)
        print(v)              ;; 4
        val _,v = coroutine.resume(a,v+1)
        print(v)              ;; 6

    ]]
    print("Testing...", "coro 3: multi")
    local out = atm_test(src)
    assert(out == "1\n2\n3\n4\n5\n6\n")

    local src = [[
        val t = func () {
            defer {
                print :ok
            }
            coroutine.yield()
        }
        val a = coroutine.create(t)
        print :end
    ]]
    print("Testing...", "coro 4")
    local out = atm_test(src)
    assertx(out, "end\n")

    local src = [[
        val t = func () {
            defer {
                print :ok
            }
            coroutine.yield()
        }
        pin a = coroutine.create(t)
        print :end
    ]]
    print("Testing...", "coro 5")
    local out = atm_test(src)
    --assertx(out, "end\n")

    local src = [[
        print(emit(1))
    ]]
    print("Testing...", "emit 1")
    local out = atm_test(src)

    local src = [[
        val tk = func (v) {
            val e1 = await(true)
            print(:1, e1)
            val e2 = await(true)
            print(:2, e2)
        }
        spawn tk ()
        emit(:1)
        emit(:2)
        emit(:3)

    ]]
    print("Testing...", "emit 2")
    local out = atm_test(src)
    assertx(out, "1\t1\n2\t2\n")

    local src = [[
        emit [false] (:1)
        nil
    ]]
    print("Testing...", "emit 1")
    local out = atm_test(src)
    --assertx(out, "anon.atm : line 1 : invalid emit : invalid target")
    warn(false, "tail call in emit hides line")

    local src = [[
        spawn (func () {
            spawn (func () {
                throw(:X)
            }) ()
        }) ()
    ]]
    print("Testing...", "task-throw-catch 1")
    local out = atm_test(src)
    warnx(out, "anon.atm : line 1 : invalid emit : invalid target\n")

    local src = [[
        spawn (func () {
            set pub = 10
            print(pub)
        }) ()
    ]]
    print("Testing...", "pub 1")
    local out = atm_test(src)
    assertx(out, "10\n")

    local src = [[
        pin t = spawn (func () {
            set pub = 10
        }) ()
        print(t.pub)
    ]]
    print("Testing...", "pub 2")
    local out = atm_test(src)
    assertx(out, "10\n")

    local src = [[
        print(:1)
        do {
            print(:2)
            spawn (func () {
                defer {
                    print(:defer)
                }
                await(true)
            } )()
            print(:3)
        }
        print(:4)
    ]]
    print("Testing...", "abort 1: no pin")
    local out = atm_test(src)
    assertx(out, "1\n2\n3\ndefer\n4\n")

    local src = [[
        print(:1)
        do {
            print(:2)
            pin x = spawn (func () {
                defer {
                    print(:defer)
                }
                await(true)
            } )()
            print(:3)
        }
        print(:4)
    ]]
    print("Testing...", "abort 1: pin")
    local out = atm_test(src)
    assertx(out, "1\n2\n3\ndefer\n4\n")

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
    local out = atm_test(src)
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
    local out = atm_test(src)
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
    local out = atm_test(src)
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
        emit(:ok)
        print(:5)
    ]]
    print("Testing...", "task - catch 2")
    local out = atm_test(src)
    assertx(out, "1\n2\n3\ne\n4\n5\n")

    local src = [[
        catch :z {
            spawn {
                throw(:x)
            }
        }
        print(10)
    ]]
    print("Testing...", "task - throw")
    local out = atm_test(src)
    warnx(out, "ok\n")  -- TODO: call stack

    local src = [[
        spawn {
            loop {
                pin t = spawn {
                    await(:X)
                    print(:in)
                }
                await(t)
            }
        }
        emit :X
        print :out
    ]]
    print("Testing...", "task abort loop")
    local out = atm_test(src)
    assertx(out, "in\nout\n")
end

print '--- TASKS ---'

do
    local src = [[
        pin ts = tasks()
        print(ts)
    ]]
    print("Testing...", "tasks 1")
    local out = atm_test(src)
    assertfx(out, "table: 0x")

    local src = [[
        pin ts = tasks()
        print(type(ts))
    ]]
    print("Testing...", "tasks 2")
    local out = atm_test(src)
    assertx(out, "table\n")

    local src = [[
        val T = func () {
            print(:in)
        }
        pin ts = tasks()
        spawn [ts] T()
        print(:out)
    ]]
    print("Testing...", "tasks 3")
    local out = atm_test(src)
    assertx(out, "in\nout\n")

    local src = [[
        val T = func () {
            print(:ok)
        }
        pin ts = tasks(2)
        spawn [ts] T()
        spawn [ts] T()
    ]]
    print("Testing...", "tasks 4")
    local out = atm_test(src)
    assertx(out, "ok\nok\n")

    local src = [[
        var T
        set T = func () {
            await(true)
        }
        pin ts = tasks()
        spawn [ts] T(1)
        spawn [ts] T(2)
        print(1)
    ]]
    print("Testing...", "tasks 5")
    local out = atm_test(src)
    assertx(out, "1\n")

    local src = [[
        var T
        set T = func (v) {
            defer {
                print(v)
            }
            await(true)
        }
        pin ts = tasks()
        spawn [ts] T(1)
        spawn [ts] T(2)
        print(0)
    ]]
    print("Testing...", "tasks 6")
    local out = atm_test(src)
    assertx(out, "0\n1\n2\n")

    local src = [[
        do {
            pin ts = tasks()
            var T
            set T = func (v) {
                print(v)
                val vx = await(true)
                print(vx)
            }
            spawn [ts] T(1)
        }
        emit(:2)
    ]]
    print("Testing...", "tasks 7")
    local out = atm_test(src)
    assertx(out, "1\n")

    local src = [[
        do {
            pin ts = tasks()
            var T
            set T = func (v) {
                print(v)
                val vx = await(true)
                print(vx)
            }
            spawn [ts] T(1)
        }
        emit(:2)
    ]]
    print("Testing...", "tasks 8: ts not pinned, no awake")
    local out = atm_test(src)
    assertx(out, "1\n")

    local src = [[
        val T = func () {
        }
        pin ts = tasks(1)
        val ok1 = spawn [ts] T()
        val ok2 = spawn [ts] T()
        print(type(ok1)=='table', type(ok2)=='table')
    ]]
    print("Testing...", "tasks 9: max")
    local out = atm_test(src)
    assertx(out, "true\ttrue\n")

    local src = [[
        val T = func () {
            await(true)
        }
        pin ts = tasks(1)
        val ok1 = spawn [ts] T()
        val ok2 = spawn [ts] T()
        print(type(ok1)=='table', ok2)
    ]]
    print("Testing...", "tasks 10: max")
    local out = atm_test(src)
    assertx(out, "true\tnil\n")

    local src = [[
        val T = func () {
            await(true)
        }
        pin ts = tasks()
        spawn [ts] T()
        spawn [ts] T()
        loop _,t in ts {
            print(t ?? :task)
        }
    ]]
    print("Testing...", "tasks 11: iter")
    local out = atm_test(src)
    assertx(out, "true\ntrue\n")

    local src = [[
        val T = func () {
            set pub = 10
            print(pub)
            spawn {
                set pub = 20
                print(pub)
            }
            print(pub)
        }
        spawn T()
    ]]
    print("Testing...", "tasks 12: fake")
    local out = atm_test(src)
    assertx(out, "10\n20\n20\n")

    local src = [[
        spawn {
            watching :X {
                defer {
                    print:defer
                }
                await(false)
            }
            print:abort
        }
        print:antes
        emit :X
        print:depois
    ]]
    print("Testing...", "tasks 13: abort")
    local out = atm_test(src)
    assertx(out, "antes\ndefer\nabort\ndepois\n")

    local src = [[
        val T = func (i) {
            every :X {
                print(:X, i)
            }
        }
        spawn {
            var i = 1
            loop {
                watching :Y {
                    pin ts = tasks()
                    do {
                        spawn [ts] T(i)
                        spawn [ts] T(i+1)
                    }
                    emit(:X)
                    await(false)
                }
                set i = i + 8
            }
        }
        print '==='
        emit :Y
        print '---'
        emit :X
        print :ok
    ]]
    print("Testing...", "tasks 13: abort")
    local out = atm_test(src)
    assertx(out, "X\t1\nX\t2\n===\nX\t9\nX\t10\n---\nX\t9\nX\t10\nok\n")

    local src = [[
        spawn {
            loop {
                await(:X)
                print :1
                watching(:X) {
                    await(:Y)
                }
                print :2
            }
        }
        emit(:X)
        emit(:X)
    ]]
    print("Testing...", "tasks 14: loop")
    local out = atm_test(src)
    assertx(out, "1\n2\n")
end

print '--- AWAIT / TASK ---'

do
    local src = [[
        spawn {
            pin t = spawn { return(10) }
            val x = await(t)
            print(:ok, x)
        }
    ]]
    print("Testing...", "await task 1")
    local out = atm_test(src)
    assertx(out, "ok\t10\n")

    local src = [[
        spawn {
            pin t = spawn {
                await(:X)
                return(10)
            }
            val x = await(t)
            print(:ok, x)
        }
        emit(:X)
    ]]
    print("Testing...", "await task 2")
    local out = atm_test(src)
    assertx(out, "ok\t10\n")

    local src = [[
        func T (v) {
            v * 2
        }
        spawn {
            val x = await T(10)
            print(x)
        }
    ]]
    print("Testing...", "await task 3")
    local out = atm_test(src)
    assertx(out, "20\n")
end

print '--- AWAIT / CLOCK ---'

do
    local src = [[
        spawn {
            await(:X,
                x+10)
        }
        emit(:X,10)
    ]]
    print("Testing...", "await 1")
    local out = atm_test(src)
    --assertx(out, "anon.atm : line 3 : attempt to perform arithmetic on a nil value (global 'x')")

    local src = [[
        spawn {
            await(@10.100)
            print(:y)
        }
        emit(clock@{s=10})
        print(:x)
        emit(clock@{ms=100})
    ]]
    print("Testing...", "await 2: clock")
    local out = atm_test(src)
    assertx(out, "x\ny\n")
end

print '--- TOGGLE ---'

do
    local src = "toggle (1)(true) ; nil"
    print("Testing...", "toggle 1")
    local out = atm_test(src)
    --assertx(out, "anon.atm : line 1 : invalid toggle : expected task")

    local src = [[
        val f = task(func () {})
        toggle f() ; nil
    ]]
    print("Testing...", "toggle 2")
    local out = atm_test(src)
    --assertx(out, "anon.atm : line 2 : invalid toggle : expected bool argument")

    local src = [[
        val T = func () {
            print :1
            await(true)
            print :2
        }
        pin t = task(T)

        print :A
        toggle t (false)
        emit :X

        print :B
        spawn t()
        emit :X

        print :C
        toggle t (true)
        emit :X
    ]]
    print("Testing...", "toggle 3")
    local out = atm_test(src)
    assertx(out, "A\nB\n1\nC\n2\n")

    local src = [[
        val T = func () {
            await(true)
            print(10)
        }
        pin t = spawn T()
        toggle t (false)
        print(1)
        emit(:X)
        emit(:X)
        toggle t (true)
        print(2)
        emit(:X)
    ]]
    print("Testing...", "toggle 4")
    local out = atm_test(src)
    assertx(out, "1\n2\n10\n")

    local src = [[
        var T
        set T = func () {
            defer {
                print(10)
            }
            await(true)
            print(999)
        }
        pin t = spawn T()
        toggle t (false)
        print(1)
        emit (:nil)
        print(2)
    ]]
    print("Testing...", "toggle 5")
    local out = atm_test(src)
    assertx(out, "1\n2\n10\n")

    local src = [[
        val T = func () {
            nil
        }
        pin t = spawn T()
        toggle t (false)
    ]]
    print("Testing...", "toggle 6")
    local out = atm_test(src)
    --assertx(out, "anon.atm : line 5 : invalid toggle : expected awaiting task")

    local src = [[
        val T = func () {
            spawn (func () {
                await(:nil)
                print(3)
            }) ()
            await(:nil)
            print(4)
        }
        print(1)
        pin t = spawn T()
        toggle t (false)
        emit (:nil)
        print(2)
        toggle t (true)
        emit (:nil)
    ]]
    print("Testing...", "toggle 7")
    local out = atm_test(src)
    assertx(out, "1\n2\n3\n4\n")

    local src = [[
        func T (v) {
            set pub = v
            toggle :Show {
                print(pub)
                every :Draw {
                    print(evt)
                }
            }
        }
        spawn T(0)
        emit(:Draw, 1)
        emit(:Show, false)
        emit(:Show, false)
        emit(:Draw, 99)
        emit(:Show, true)
        emit(:Show, true)
        emit(:Draw, 2)
    ]]
    print("Testing...", "toggle 8")
    local out = atm_test(src)
    --assertx(out, "0\n1\n2\n")

    local src = [[
        spawn {
            val x = toggle :Show {
                10
            }
            print(x)
        }
        print(:ok)
    ]]
    print("Testing...", "toggle 9")
    local out = atm_test(src)
    assertx(out, "10\nok\n")
end

print '--- IS / IN ---'

do
    local src = [[
        print(10 ?? :number)
        print(@{} !? :table)
        print(:x ?? :number)
    ]]
    print("Testing...", "is 1")
    local out = atm_test(src)
    assertx(out, "true\nfalse\nfalse\n")

    local src = [[
        print(@{} ?? :bool)
        print(@{} ?? :table)
        print(1 !? :table)
        print(1 !? :number)
    ]]
    print("Testing...", "is 1")
    local out = atm_test(src)
    assertx(out, "false\ntrue\ntrue\nfalse\n")

    local src = [[
        val t = @{1,2,3}
        print(2 ?> t)
        print(t <? 4)
        print(2 !> t)
        print(t <! 4)
    ]]
    print("Testing...", "is 1")
    local out = atm_test(src)
    assertx(out, "true\nfalse\nfalse\ntrue\n")
end

print '--- CALL / METHOD / PIPE ---'

do
    local src = "print(10 -> 10)"
    print("Testing...", "is 1")
    local out = atm_test(src)
    assertx(out, "anon.atm : line 1 : ')' expected near '('\n")

    local src = "print(10 -> (10))"
    print("Testing...", "is 1")
    local out = atm_test(src)
    --assertx(out, "anon.atm : line 1 : attempt to call a number value")

    local src = [[
        func f (v) { return(v) }
        val v = 10->f()
        print(v)
    ]]
    print("Testing...", "method 1")
    local out = atm_test(src)
    assertx(out, "10\n")

    local src = [[
        func f (v) { return(10) }
        func g (v) { return(v) }
        val v = 99->f()->g()
        print(v)
    ]]
    print("Testing...", "method 2")
    local out = atm_test(src)
    assertx(out, "10\n")

    local src = [[
        func f (v) { return(10) }
        func g (v) { return(v) }
        val v = 99->f->g
        print(v)
    ]]
    print("Testing...", "method 3")
    local out = atm_test(src)
    assertx(out, "10\n")

    local src = [[
        func f (v,x) { return(v - x) }
        val v = 10->f(20)
        print(v)
    ]]
    print("Testing...", "method 4")
    local out = atm_test(src)
    assertx(out, "-10\n")

    local src = [[
        func f (v) { return(v) }
        val v = f<-20
        print(v)
    ]]
    print("Testing...", "method 5")
    local out = atm_test(src)
    assertx(out, "20\n")

    local src = [[
        func f (v,x) { return(v - x) }
        val v = f(10)<-20
        print(v)
    ]]
    print("Testing...", "method 6")
    local out = atm_test(src)
    assertx(out, "-10\n")

    local src = [[
        func f (self,v) { self.v+v }
        val o = @{v=10,f=f}
        print(o::f(20))
    ]]
    print("Testing...", "method 6")
    local out = atm_test(src)
    assertx(out, "30\n")

    local src = [[
        func f (...) { print(...) }
        (10,20) --> f(30,40)
    ]]
    print("Testing...", "method 6")
    local out = atm_test(src)
    assertx(out, "10\t20\t30\t40\n")
end

print '--- WHERE ---'

do
    local src = "print(x+y where { x=10 ; y=20 })"
    print("Testing...", src)
    local out = atm_test(src)
    assertx(out, "30\n")
end

-- ERROR / LINE NUMBER

do
    local src = [[
        val f = func (x) {
            return (func (y) {
                return (x+nil)
            })
        }
        print(f(10)(20))
    ]]
    print("Testing...", "func 4")
    local out = atm_test(src)
    --assertx(out, "anon.atm : line 3 : attempt to perform arithmetic on a nil value")

    local src = [[ error("hello") ]]
    print("Testing...", src)
    local out = atm_test(src)
    --assert(out == "anon.atm : line 1 : hello")

    local src = [[
        spawn {
            print(t.x)
        }
    ]]
    print("Testing...", "error 1")
    local out = atm_test(src)
    --assertx(out, "anon.atm : line 2 : attempt to index a nil value (global 't')")

    local src = [[
        print <- spawn T()
    ]]
    print("Testing...", "error 2")
    local out = atm_test(src)
    --assertx(out, "anon.atm : line 2 : attempt to index a nil value (global 't')\n")
    warn(false, "TODO: check spawn up")
end

print "--- REQUIRE ---"

do
    local src = [[
        val X,f = require "x"
        print(f, X.f(10))
    ]]
    print("Testing...", "require 1")
    local out = atm_test(src)
    --assertx(out, "./x.atm\t20\n")
end
