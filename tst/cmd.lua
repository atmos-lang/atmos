require "atmos.lang.exec"

-- VOID / ARGS / ...

do
    print("Testing...", "void-01.atm")
    local v = io.popen("atmos cmd/void-01.atm"):read('*a')
    assertx(v, "")

    print("Testing...", "args-01.atm")
    local v = io.popen("atmos cmd/args-01.atm 1 2 3"):read('*a')
    assertx(v, "1\t2\t3\n")

    print("Testing...", "comm-01.atm")
    local v = io.popen("atmos cmd/comm-01.atm"):read('*a')
    assertx(v, "")
end

-- TEST

do
    print("Testing...", "test-01.atm")
    local v = io.popen("atmos cmd/test-01.atm"):read('*a')
    assertx(v, "1\n3\n")

    print("Testing...", "test-01.atm")
    local v = io.popen("atmos cmd/test-01.atm --test"):read('*a')
    assertx(v, "1\n2\n3\n")
end

-- REQUIRE

do
    print("Testing...", "require-01.atm")
    local v = io.popen("atmos cmd/require-01.atm"):read('*a')
    assertx(v, "20\n")
end
