require "atmos.lang.exec"

-- Synchronous timers (lua-atmos#25):
-- each tick splits in pieces, each ending at the nearest timer.

print '--- TIMERS ---'

do
    local src = [[
        spawn {
            await(10ms)
            await(10ms)
            print(:ok)
        }
        emit @:global 25ms              ;; 2nd timer: 15ms late carried
    ]]
    print("Testing...", "timers 1: residual carried")
    local out = atm_test(src)
    assertx(out, "ok\n")

    local src = [[
        spawn {
            par :any {
                await(20ms)
                print(:a)
            } with {
                await(10ms)
                print(:b)
            }
        }
        emit @:global 30ms              ;; b expires first (10ms)
    ]]
    print("Testing...", "timers 2: time order in one tick")
    local out = atm_test(src)
    assertx(out, "b\n")

    local src = [[
        spawn {
            loop i in 3 {
                await(10ms)
                print(i)
            }
        }
        emit @:global 35ms              ;; 3 periods in one tick
    ]]
    print("Testing...", "timers 3: periodic catch-up")
    local out = atm_test(src)
    assertx(out, "1\n2\n3\n")

    local src = [[
        spawn {
            print(await(10ms))
            print(await(10ms))
        }
        emit @:global 25ms              ;; late: 15ms, then 5ms
    ]]
    print("Testing...", "timers 4: late returned")
    local out = atm_test(src)
    assertx(out, "15000\n5000\n")

    local src = [[
        spawn {
            await(10ms)
        }
        spawn {
            loop _ in 2 {
                val dt, late = await(:clock)
                print(dt, late)
            }
        }
        ;; global: resets nearest timer (default target: main task)
        emit @:global 25ms              ;; pieces: 10ms (timer), 15ms (rest)
    ]]
    print("Testing...", "timers 5: clock pieces")
    local out = atm_test(src)
    assertx(out, "10000\t15000\n15000\t0\n")

    local src = [[
        spawn {
            await(10ms)
            spawn {
                await(10ms)             ;; born at 10ms: expires at 20ms
                print(:B)
            }
            await(false)
        }
        emit @:global 25ms
    ]]
    print("Testing...", "timers 6: timer born mid-tick")
    local out = atm_test(src)
    assertx(out, "B\n")

    local src = [[
        pin t = spawn {
            await(10ms)
            print(:ok)
        }
        emit @:global 5ms               ;; 5ms of 10ms
        toggle t(false)
        emit @:global 20ms              ;; frozen: no time passes for t
        toggle t(true)
        print("-")
        emit @:global 5ms               ;; 10ms: expires
    ]]
    print("Testing...", "timers 7: toggle freezes timer")
    local out = atm_test(src)
    assertx(out, "-\nok\n")

    local src = [[
        spawn {
            await(20ms)
            print(:b)
        }
        pin t = spawn {
            await(10ms)
            print(:a)
        }
        toggle t(false)
        emit @:global 1ms               ;; t frozen: timer not re-reported
        toggle t(true)
        emit @:global 30ms              ;; a (10ms) before b (19ms)
    ]]
    print("Testing...", "timers 8: toggle on re-reports timer")
    local out = atm_test(src)
    assertx(out, "a\nb\n")

    local src = [[
        print(atmos.next())             ;; no timer
        spawn {
            await(10ms)
        }
        print(atmos.next())
        emit @:global 4ms
        print(atmos.next())             ;; 6ms left
        atmos.stop()
        print(atmos.next())             ;; reset by stop
    ]]
    print("Testing...", "timers 9: next")
    local out = atm_test(src)
    assertx(out, "nil\n10000\n6000\nnil\n")
end
