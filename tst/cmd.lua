require "atmos.lang.exec"

-- VOID / ARGS / ...

do
    print("Testing...", "void-01.atm")
    local v = io.popen("../atmos 2>&1 cmd/void-01.atm"):read('*a')
    assertx(v, "")

    print("Testing...", "args-01.atm")
    local v = io.popen("../atmos 2>&1 cmd/args-01.atm 1 2 3"):read('*a')
    assertx(v, "1\t2\t3\n")

    print("Testing...", "comm-01.atm")
    local v = io.popen("../atmos 2>&1 cmd/comm-01.atm"):read('*a')
    assertx(v, "")
end

-- ERROR
do
    print("Testing...", "error-01.atm")
    local v = io.popen("../atmos 2>&1 cmd/error-01.atm"):read('*a')
    assertfx(v, "cmd%/error%-01.atm : line 1 : near '%*' : expected expression")
end

-- TEST

do
    print("Testing...", "test-01.atm")
    local v = io.popen("../atmos 2>&1 cmd/test-01.atm"):read('*a')
    assertx(v, "1\n3\n")

    print("Testing...", "test-01.atm")
    local v = io.popen("../atmos 2>&1 cmd/test-01.atm --test"):read('*a')
    assertx(v, "1\n2\n3\n")
end

-- REQUIRE

do
    print("Testing...", "require-01.atm")
    local v = io.popen("../atmos 2>&1 cmd/require-01.atm"):read('*a')
    assertx(v, "20\n")
end
