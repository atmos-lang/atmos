require "atmos.lang.exec"

print '--- EQ ---'

do
    local src = "print(0xA === 10)"
    print("Testing...", src)
    local out = atm_test(src)
    assertx(out, "true\n")

    local src = "print([1,2,3] === [1,2,3])"
    print("Testing...", src)
    local out = atm_test(src)
    assertx(out, "true\n")

    local src = "print(\\{} =!= \\{})"
    print("Testing...", src)
    local out = atm_test(src)
    assertx(out, "true\n")

    local src = "print([x=1] =!= [x=1])"
    print("Testing...", src)
    local out = atm_test(src)
    assertx(out, "false\n")

    local src = [=[
        print([ ] =!= [ ])
        print([1] === [1])
        print([ ] === [1])
        print([1] =!= [1])
        print([1,[],[1,2,3]] === [1,[],[1,2,3]])
        print([nil,[[1,1],1]] === [nil,[[1,1],1]])
        print([1,[1],1] =!= [1,[1],1])
        print([@(:y)=false] === [@(:x)=true])
        print([[]] === [[]])
        print([@([])=true] === [@([])=true])  ;; table keys (=== false)
    ]=]
    print("Testing...", "expr ===")
    local out = atm_test(src)
    assertx(out, "false\ntrue\nfalse\nfalse\ntrue\ntrue\nfalse\nfalse\ntrue\nfalse\n")

    local src = [[
        print([] ==  [])
        print([] === [])
        print([] !=  [])
        print([] =!= [])
    ]]
    print("Testing...", "expr === :table")
    local out = atm_test(src)
    assertx(out, "false\ntrue\ntrue\nfalse\n")

    local src = [[
        print([]  ==  [])
        print([1] === [1])
        print([1] !=  [1])
        print([]  =!= [])
    ]]
    print("Testing...", "expr === :vector")
    local out = atm_test(src)
    assertx(out, "false\ntrue\ntrue\nfalse\n")

    local src = [=[
        print([[],[]] ==  [[],[]])
        print([[],[]] !=  [[],[]])
        print([[1],[@(:y)=false,@(:x)=true]] === [[1],[@(:x)=true,@(:y)=false]])
        print([[],[]] =!= [[],[]])
    ]=]
    print("Testing...", "expr === :vector")
    local out = atm_test(src)
    assertx(out, "false\ntrue\ntrue\nfalse\n")
end

print '--- GTE ---'

do
    -- `=>=` : X.gte(a,b) : a is a supertype of b
    -- scalars compare by equality (NOT numeric ordering);
    -- tags by prefix (`:x` supertypes `:x.y`); tables structurally
    -- (the emptier/looser table supertypes the richer one)
    local src = [[
        print(10 =>= 10)
        print(10 =>= 20)
        print(:x =>= :x.y)
        print(:x.y =>= :x)
        print([] =>= [1,2,3])
        print([1,2,3] =>= [])
    ]]
    print("Testing...", "gte 1")
    local out = atm_test(src)
    assertx(out, "true\nfalse\ntrue\nfalse\ntrue\nfalse\n")

    -- `=<=` : X.gte(b,a) : the flipped relation (no `X.lte` exists)
    local src = [[
        print(10 =<= 10)
        print(10 =<= 20)
        print(:x =<= :x.y)
        print(:x.y =<= :x)
        print([] =<= [1,2,3])
        print([1,2,3] =<= [])
    ]]
    print("Testing...", "lte 1")
    local out = atm_test(src)
    assertx(out, "true\nfalse\nfalse\ntrue\nfalse\ntrue\n")
end

print '--- CAT ---'

do
    local src = [[
        print('a' ++ 'b' ++ 'c')
    ]]
    print("Testing...", "cat 1")
    local out = atm_test(src)
    assertx(out, "abc\n")

    local src = [[
        print('a' ++ " b " ++ 'c')
    ]]
    print("Testing...", "cat 2")
    local out = atm_test(src)
    assertx(out, "a b c\n")

    local src = [[
        val x = [1,2,3]
        val t = []
        set t@(#t+1) = 4
        set t@(#t+1) = 5
        set t@(#t) = nil
        X.print(x ++ t ++ [5,6,7])
    ]]
    print("Testing...", "cat 3: vector")
    local out = atm_test(src)
    assertx(out, "[1, 2, 3, 4, 5, 6, 7]\n")

    local src = [[
        X.print([x=1] ++ [y=2] ++ [z=3])
        X.print([1] ++ [2] ++ [3])
    ]]
    print("Testing...", "cat 4: table")
    local out = atm_test(src)
    assertx(out, "[x=1, y=2, z=3]\n[1, 2, 3]\n")
end

print '--- IS / IN ---'

do
    local src = [[
        print(10 ?? :number)
        print([] !? :table)
        print <-- :x ?? :number
    ]]
    print("Testing...", "is 1")
    local out = atm_test(src)
    assertx(out, "true\nfalse\nfalse\n")

    local src = [[
        print([] ?? :bool)
        print([] ?? :table)
        print(1 !? :table)
        print(1 !? :number)
    ]]
    print("Testing...", "is 2")
    local out = atm_test(src)
    assertx(out, "false\ntrue\ntrue\nfalse\n")

    local src = [[
        print([] ?? :table)
        print(1s ?? :number)
        print(task () {} ?? :task)
        print(xtask(task () {}) ?? :xtask)
        pin xs = tasks()
        print(xs ?? :tasks)
    ]]
    print("Testing...", "is 3")
    local out = atm_test(src)
    assertx(out, "true\ntrue\ntrue\ntrue\ntrue\n")

    -- RED until runtime gate lands: surface xtask(rawfunc) must reject a
    -- non-prototype (M.xtask `or T` fallback should be `or (tra and T)`).
    local src = [[
        xtask(\{})
        print :ok
    ]]
    print("Testing...", "is 3b: xtask non-proto fails")
    local out = atm_test(src)
    assertx(trim(out), trim [[
        ==> ERROR:
         |  [C]:-1 (loop)
         v  [string "anon.atm"]:1 (throw)
        ==> invalid xtask : expected task prototype
    ]])

    local src = [[
        print([] ?? [])
        print([1,2,3] === [1,2,3])
        print(\{} !? \{})
    ]]
    print("Testing...", "is 4")
    local out = atm_test(src)
    assertx(out, "false\ntrue\ntrue\n")

    local src = [[
        val t = [1,2,3]
        print(2 ?> t)
        print(4 ?> t)
        print(2 !> t)
        print(4 !> t)
    ]]
    print("Testing...", "in 1")
    local out = atm_test(src)
    assertx(out, "true\nfalse\nfalse\ntrue\n")

    local src = [=[
        print([tag=[]] ?? :number)
    ]=]
    print("Testing...", "is 5")
    local out = atm_test(src)
    assertx(out, "false\n")
end

print '--- OPERATOR AS FUNCTION ---'

do
    -- binary: \===
    local src = [[
        print((\===)([1,2], [1,2]))
    ]]
    print("Testing...", "\\===")
    local out = atm_test(src)
    assertx(out, "true\n")

    -- binary: \++
    local src = [[ print((\++)('a', 'b')) ]]
    print("Testing...", "\\++")
    local out = atm_test(src)
    assertx(out, "ab\n")
end
