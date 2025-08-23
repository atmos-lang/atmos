require "atmos.lang.exec"

local src = [[
    val f = require "atmos.lang.functional"
    val my_counter = f.counter()
    val my_capped_counter = my_counter::take(5)
    val my_array = my_capped_counter::to_array()
    print(type(my_array))
    loop i,v in my_array {
      print(i,v)
    }
]]
print("Testing...", "func 1")
local out = atm_test(src)
assertx(out, "table\n1\t1\n2\t2\n3\t3\n4\t4\n5\t5\n")

local src = [[
    val f = require "atmos.lang.functional"
    val my_array =
        f.counter()::
            take(5)
    loop v in my_array {
      print(v)
    }
]]
print("Testing...", "func 2")
local out = atm_test(src)
assertx(out, "1\n2\n3\n4\n5\n")

local src = [[
    val f = require "atmos.lang.functional"
    val names = @{
      "Arya",
      "Beatrice",
      "Caleb",
      "Dennis"
    }
    val names_with_b = f.filter(names, \{it::find("[Bb]")})::to_array()
    xprint(names_with_b)
]]
print("Testing...", "func 3")
local out = atm_test(src)
assertx(out, "{Beatrice, Caleb}\n")

local src = [[
    val f = require "atmos.lang.functional"
    val names = @{
      "Arya",
      "Beatrice",
      "Caleb",
      "Dennis"
    }
    val names_with_b = f.filter(names, \{it::find("[Bb]")})::
        map(string.upper)::
        to_array()
    xprint(names_with_b)
]]
print("Testing...", "func 4")
local out = atm_test(src)
assertx(out, "{BEATRICE, CALEB}\n")

local src = [[
    val f = require "atmos.lang.functional"
    f.range(1, 10)::    ;; run through all the numbers from 1 to 10 (inclusive)
      filter(\{(it%2)==0})::  ;; take only even numbers
      foreach(print)   ;; run print for every value individually
]]
print("Testing...", "func 5")
local out = atm_test(src)
assertx(out, "2\n4\n6\n8\n10\n")

local src = [[
    val f = require "atmos.lang.functional"
    val names = @{"hellen", "oDYSseuS", "aChIlLeS", "PATROCLUS"}
    val fix_case = func (name) {
      name::sub(1,1)::upper() ++ name::sub(2)::lower()
    }
    loop name in f.map(names, fix_case) {
      print(name)
    }
]]
print("Testing...", "func 6")
local out = atm_test(src)
assertx(out, "Hellen\nOdysseus\nAchilles\nPatroclus\n")

local src = [[
    val f = require "atmos.lang.functional"
    val numbers = f.range(10,15)
    val sum = numbers::reduce(\(acc,new){acc+new}, 0)
    print(sum)
]]
print("Testing...", "func 7")
local out = atm_test(src)
assertx(out, "75\n")

local src = [[
    val f = require "atmos.lang.functional"
    val numbers = @{2, 1, 3, 4, 7, 11, 18, 29}

    val is_even = \{(it % 2) == 0}
    xprint <-- f.filter(numbers, is_even)::to_array()

    xprint <-- f.filter(numbers, \{(it % 2) == 0})::to_array()
]]
print("Testing...", "func 8")
local out = atm_test(src)
assertx(out, "{2, 4, 18}\n{2, 4, 18}\n")

local src = [[
    val f = require "atmos.lang.functional"
    val matrix = @{
      @{1, 2, 3}, ;; first element of matrix
      @{4, 5, 6}, ;; second element of matrix
      @{7, 8, 9}  ;; third element of matrix
    }
    ;; map will iterate through each row, and the lambda
    ;; indexes each to retrieve the first element
    xprint <-- f.map(matrix, \{it[1]})::to_array()
]]
print("Testing...", "func 9")
local out = atm_test(src)
assertx(out, "{1, 4, 7}\n")
