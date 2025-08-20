require "atmos.lang.aux"

-- VOID / ARGS / ...

do
    local v = io.popen("atmos cmd/void-01.atm"):read('*a')
    assertx(v, "")

    local v = io.popen("atmos cmd/args-01.atm 1 2 3"):read('*a')
    assertx(v, "1\t2\t3\n")
end

-- TEST

do
    local v = io.popen("atmos cmd/test-01.atm"):read('*a')
    assertx(v, "1\n3\n")

    local v = io.popen("atmos cmd/test-01.atm --test"):read('*a')
    assertx(v, "1\n2\n3\n")
end
