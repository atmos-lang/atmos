local X = require "atmos.x"
require "atmos.lang.exec"

-- PARSER

do
    local src = "thread { 10 }"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assert(e.tag == 'call')
    assert(e.f.tk.str == 'thread')
    assert(e.es[1].tag == 'func')
    assert(e.es[1].lua == true)
    assert(#e.es[1].pars == 0)
    assertx(tosource(e), "thread({\n10\n})")

    local src = "val x = thread { 10 }"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assert(e.tag == 'dcl')
    assert(e.set.tag == 'call')
    assert(e.set.f.tk.str == 'thread')

    local src = "var n = 10 \n thread { n * 2 }"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser_main()
    assert(e.tag == 'do')
    assert(e.blk.es[2].tag == 'call')
    assert(e.blk.es[2].f.tk.str == 'thread')
end

-- CODEGEN

do
    local src = "thread { print(:ok) }"
    print("Testing...", src)
    local lua = atm_to_lua("anon.atm", src)
    assertfx(lua, 'thread%(%(function %(%)')
end

-- EXEC

do
    local src = [[
        spawn {
            thread { await :OK }
        }
        `os.execute("sleep 0.1")`
        emit()
    ]]
    print("Testing...", "thread exec 00")
    local out = atm_test(src)
    assertfx(out, trim [[
        ==> invalid await : expected enclosing task
    ]])
end

do
    local src = [[
        spawn {
            val v = thread { 42 }
            print(v)
        }
        `os.execute("sleep 0.1")`
        emit()
    ]]
    print("Testing...", "thread exec 01")
    local out = atm_test(src)
    assertx(out, "42\n")
end

do
    local src = [[
        spawn {
            val v = thread {
                ;; non-awaiting heavy computation
                var sum = 0
                loop i in 100 {
                    set sum = sum + i
                }
                sum
            }
            print(v)
        }
        `os.execute("sleep 0.1")`
        emit()
    ]]
    print("Testing...", "thread exec 02")
    local out = atm_test(src)
    assertx(out, "5050\n")
end

do
    local src = [[
        math.randomseed()

        val func cpu (max) {
            var sum = 0
            loop i in max {
                set sum = sum + i
            }
            sum
        }

        spawn {
            val t = watching @20 {
                par_or {
                    val v = thread {
                        loop {
                            cpu(math.random(10000000))
                        }
                    }
                    @{worker="A", value=v}
                } with {
                    val v = thread {
                        cpu(100)
                    }
                    @{worker="B", value=v}
                }
            }

            if t == :clock {
                print("Computation timeout...")
            } else {
                print(t.worker ++ " yields " ++ t.value)
            }
        }
        `os.execute("sleep 0.1")`
        emit()
    ]]
    print("Testing...", "thread exec 03")
    local out = atm_test(src)
    assertx(out, "B yields 5050\n")
end
