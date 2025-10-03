require "atmos.lang.exec"

local src = [[
    val S = require "atmos.streams"
    val my_counter = S.fr_counter()
    val my_capped_counter = my_counter::take(5)
    val my_array = my_capped_counter::table()::to()
    print(type(my_array))
    loop i,v in my_array {
      print(i,v)
    }
]]
print("Testing...", "func 1")
local out = atm_test(src)
assertx(out, "table\n1\t1\n2\t2\n3\t3\n4\t4\n5\t5\n")

local src = [[
    val S = require "atmos.streams"
    val my_array =
        S.from()::
            take(5)
    loop v in my_array {
      print(v)
    }
]]
print("Testing...", "func 2")
local out = atm_test(src)
assertx(out, "1\n2\n3\n4\n5\n")

local src = [[
    val S = require "atmos.streams"
    val names = @{
      "Arya",
      "Beatrice",
      "Caleb",
      "Dennis"
    }
    val names_with_b = S.from(names)
        ::filter(\{it::find("[Bb]")})
        ::table()
        ::to()
    xprint(names_with_b)
]]
print("Testing...", "func 3")
local out = atm_test(src)
assertx(out, "{Beatrice, Caleb}\n")

local src = [[
    val S = require "atmos.streams"
    val names = @{
      "Arya",
      "Beatrice",
      "Caleb",
      "Dennis"
    }
    val names_with_b = S.from(names)
        ::filter(\{it::find("[Bb]")})
        ::map(string.upper)
        ::table()
        ::to()
    xprint(names_with_b)
]]
print("Testing...", "func 4")
local out = atm_test(src)
assertx(out, "{BEATRICE, CALEB}\n")

local src = [[
    val S = require "atmos.streams"
    S.fr_range(1, 10)           ;; run through all the numbers from 1 to 10 (inclusive)
        ::filter(\{(it%2)==0})  ;; take only even numbers
        ::tap(print)            ;; run print for every value individually
        ::to()
]]
print("Testing...", "func 5")
local out = atm_test(src)
assertx(out, "2\n4\n6\n8\n10\n")

local src = [[
    val S = require "atmos.streams"
    val names = @{"hellen", "oDYSseuS", "aChIlLeS", "PATROCLUS"}
    val fix_case = func (name) {
      name::sub(1,1)::upper() ++ name::sub(2)::lower()
    }
    loop name in S.from(names)::map(fix_case) {
      print(name)
    }
]]
print("Testing...", "func 6")
local out = atm_test(src)
assertx(out, "Hellen\nOdysseus\nAchilles\nPatroclus\n")

local src = [[
    val S = require "atmos.streams"
    val numbers = S.from(10,15)
    val sum = numbers::acc0(0, \(acc,new){acc+new})::to()
    print(sum)
]]
print("Testing...", "func 7")
local out = atm_test(src)
assertx(out, "75\n")

local src = [[
    val S = require "atmos.streams"
    val numbers = @{2, 1, 3, 4, 7, 11, 18, 29}

    val is_even = \{(it % 2) == 0}
    xprint <-- S.from(numbers)::filter(is_even)::table()::to()

    xprint <-- S.from(numbers)::filter(\{(it % 2) == 0})::table()::to()
]]
print("Testing...", "func 8")
local out = atm_test(src)
assertx(out, "{2, 4, 18}\n{2, 4, 18}\n")

local src = [[
    val S = require "atmos.streams"
    val matrix = @{
      @{1, 2, 3}, ;; first element of matrix
      @{4, 5, 6}, ;; second element of matrix
      @{7, 8, 9}  ;; third element of matrix
    }
    ;; map will iterate through each row, and the lambda
    ;; indexes each to retrieve the first element
    xprint <-- S.from(matrix)::map(\{it[2]})::table()::to()
]]
print("Testing...", "func 9")
local out = atm_test(src)
assertx(out, "{2, 5, 8}\n")
