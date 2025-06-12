require "exec"

do
    local src = [[
        match :a.b.c {
            :a.b => 10
            else => 99
        } --> print
    ]]
    print("Testing...", "match 2")
    --local out = atm_test(src, true)
    --assertx(out, "10\n")
    local lua = atm_to_lua("anon.atm", src)
    print(lua)
    local f = assert(io.open("anon.atm.lua",'w'))
    f:write('require "runtime" ; '..lua)
    f:close()
end
