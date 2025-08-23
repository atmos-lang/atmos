--[[
Copyright © 2022 William Quelho Ferreira

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the “Software”), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is furnished
to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
]]

---
-- <h2>A module for functional programming utils.</h2>
-- <h3>About the module</h3>
-- <p style="text-align: justify">This module seeks to provide some utility functions and structures
-- which are too verbose in vanilla lua, in particular with regards to iteration
-- and inline function definition.</p>
-- <p style="text-align: justify">The module is writen completely in vanilla lua,
-- with no dependencies on external packages&period; This was a decision made for
-- portability, and has drawbacks&period; Since none of this was written as a C binding, it is not
-- as performant as it could be.</p>
-- <p style="text-align: justify">For example, <a href="https://github.com/luafun/luafun">luafun</a>
-- is "high-performance functional programming library for Lua designed with
-- <a href="http://luajit.org/luajit.html">LuaJIT</a>'s trace compiler in mind"
-- &period; If your environment allows you to use LuaJIT and performance is a
-- concern, perhaps luafun will be more suited for your needs.</p>
-- <p style="text-align: justify; background: #eeeeee; border: 1px solid black;
-- margin-left: 15%; margin-right: 15%; padding: 10px;">
-- The motivation behind this module is, again, portability&period;
-- If you want to embed this code on a webpage, or use it in some weird
-- system for which a C binding wouldn't work, this project is aimed
-- at you.</p>
-- <h3>Definitions</h3>
-- <h4>Array</h4>
-- <p style="text-align: justify">As lua doesn't have a dedicated array
-- type, the word "array" in this document referes to a table with contiguous
-- non-<code>nil</code> values starting at index <code>1</code>.</p>
-- <h4>Iterable</h4>
-- <p>An <code>iterable</code> refers to either of:
-- <ul>
-- <li> An array (see above); or </li>
-- <li> An instance of <code>Iterator</code>. </li>
-- </ul></p>
-- @module functional
-- @alias M
-- @release 1.6.0
-- @author William Quelho Ferreira
-- @copyright 2021
-- @license MIT
---
local M = {}



--- Module version.
M._VERSION = "1.6.0"
local exports = {}
local internal = {}

--- A lazy-loading Iterator.
-- @type Iterator
local Iterator = {}
local iter__meta = {}

local lambda_function__meta = {}
local curried_function__meta = {}

local unpack = table.unpack or unpack

--- Iterate over the given <code>iterable</code>.
-- <p>If <code>iterable</code> is an array, create an Iterator instance
-- that returns its values one by one. If it is an
-- iterator, return itself.</p>
-- @tparam iterable iterable the values to be iterated over
-- @treturn Iterator the new Iterator
function Iterator.over(iterable)
  internal.assert_table(iterable, "iterable")

  if internal.is_iterator(iterable) then
    return iterable
  else
    local copy = {unpack(iterable)}
    local iterator = internal.base_iter(copy, internal.iter_next, internal.iter_clone)

    iterator.index = 0

    return iterator
  end
end

--- Retrieve the next element from the iterator, if any.
-- @return the next value in the sequence, or <code>nil</code> if there is none
function Iterator:next()
end

--- Iterate over the naturals starting at 1.
-- @treturn Iterator the counter
-- @see Iterator:take
-- @see Iterator:skip
-- @see Iterator:every
function Iterator.counter()
  local iterator = internal.base_iter(nil, internal.counter_next, internal.counter_clone)

  iterator.n = 0

  return iterator
end

--- Create an integer iterator that goes from <code>start</code> to <code>stop</code>, <code>step</code>-wise.
-- @tparam[opt=1] integer start the start of the integer range
-- @tparam integer stop the end of the integer range (inclusive)
-- @tparam[opt=1] integer step the difference between consecutive elements
-- @treturn Iterator the new <code>@{Iterator}</code>
-- @see range
function Iterator.range(start, stop, step)
  local iterator = internal.base_iter(nil, internal.range_next, internal.range_clone)
  local arg1, arg2, arg3 = start, stop, step

  if arg3 then
    internal.assert_not_nil(arg1, "start")
    internal.assert_not_nil(arg2, "stop")
    start = arg1
    stop = arg2
    step = arg3
    if step == 0 then
      error("param step must not be zero")
    end
  else
    step = 1
    if arg2 then
      internal.assert_not_nil(arg1, "start")
      start = arg1
      stop = arg2
    else
      internal.assert_not_nil(arg1, "stop")
      start = 1
      stop = arg1
    end
  end

  iterator.curr = start
  iterator.stop = stop
  iterator.step = step

  return iterator
end

--- Iterate over the function's returned values upon repeated calls.
-- <p>This can effectively convert a vanilla-Lua iterator into a capital I @{Iterator}.
-- For example, <code>Iterator.from(io.lines "my_file.txt")</code> gives you a
-- string iterator over the lines in a file.</p>
-- <p>In general, any expression you can use in a for loop, you can wrap into an <code>Iterator.from</code>
-- to get the same sequence of values in an @{Iterator} form. For more information on iterators,
-- read <a href="http://www.lua.org/pil/7.1.html">chapter 7 of Programming in Lua</a>.</p>
-- <p>Since any repeated function call without arguments can be used as a vanilla Lua iterator,
-- they can also be used with <code>Iterator.from</code>. For an example, see Usage.</p>
-- @usage
-- local i = 0
-- local function my_counter()
--   i = i + 1
--   if i > 10 then return nil end
--   return i
-- end
-- f.from(my_counter):foreach(print) -- prints 1 through 10 and stops
-- @tparam function func the function to call
-- @param is invariant state passed to <code>func</code>
-- @param var initial variable passed to <code>func</code>
-- @treturn Iterator the new <code>@{Iterator}</code>
-- @see Iterator.packed_from
function Iterator.from(func, is, var)
  internal.assert_not_nil(func, "func")
  local iterator = internal.base_iter(nil, internal.func_call_next, internal.func_try_clone)

  iterator.func = func
  iterator.is = is
  iterator.var = var

  return iterator
end

--- Iterate over the function's returned values (packed into a table) upon repeated calls.
-- This is similar to @{Iterator.from}, but instead of the created Iterator
-- generating multiple return values per call, it returns them all
-- packed into an array.
-- @tparam function func the function to call
-- @param is invariant state passed to <code>func</code>
-- @param var initial variable passed to <code>func</code>
-- @treturn Iterator the new <code>@{Iterator}</code>
-- @see Iterator.from
function Iterator.packed_from(func, is, var)
  internal.assert_not_nil(func, "func")
  local iterator = Iterator.from(func, is, var)
  return iterator:map(internal.pack)
end

--- Iterate over the <code>coroutine</code>'s yielded values.
-- <p>For example, assume you have a coroutine that produces messages from
-- clients. One easy way to consume them in a for loop would be as in Usage.</p>
-- @tparam thread co the <code>coroutine</code> to iterate
-- @treturn Iterator the new <code>@{Iterator}</code>
-- @usage
-- local function my_totally_real_message_queue()
--   coroutine.yield("this is a message")
--   coroutine.yield("hello!")
--   coroutine.yield("almost done")
--   coroutine.yield("bye bye")
-- end
--
-- local co = coroutine.create(my_totally_real_message_queue)
-- for count, message in f.Iterator.from_coroutine(co):enumerate() do
--   io.write(count, ": ", message, "\n")
-- end
-- io.write("end")
function Iterator.from_coroutine(co)
  internal.assert_coroutine(co, "co")
  return internal.wrap_coroutine(co)
end

--- Nondestructively return an independent iterable from the given one.
-- <p>If <code>iterable</code> is an Iterator, clone it according
-- to its subtype. If <code>iterable</code> is an array, then
-- return itself.</p>
-- <p>Please note that coroutine and iterated function call iterators
-- cannot be cloned.</p>
-- @tparam iterable iterable the iterable to be cloned
-- @treturn iterable the clone
function Iterator.clone(iterable)
  internal.assert_not_nil(iterable, "iterable")
  if internal.is_iterator(iterable) then
    return iterable:clone()
  else
    return iterable
  end
end

--- Select only values which match the predicate.
-- @tparam predicate predicate the function to evaluate for each value
-- @treturn Iterator the filtering <code>@{Iterator}</code>
function Iterator:filter(predicate)
  internal.assert_not_nil(predicate, "predicate")
  local iterator = internal.base_iter(self, internal.filter_next, internal.filter_clone)

  iterator.predicate = predicate

  return iterator
end

--- Map values into new values.
-- <p>Please note that at no point during iteration may
-- the <code>mapping</code> function return <code>nil</code>
-- as its first value.</p>
-- @tparam function mapping the function to evaluate for each value
-- @treturn Iterator the mapping <code>@{Iterator}</code>
function Iterator:map(mapping)
  internal.assert_not_nil(mapping, "mapping")
  local iterator = internal.base_iter(self, internal.map_next, internal.map_clone)

  iterator.mapping = M.compose(internal.func_nil_guard, mapping)

  return iterator
end

--- Collapse values into a single value.
-- <p>A reducer is a function of the form
-- <pre>function(accumulated_value, new_value)</pre>
-- which returns the reducing or "accumulation" of
-- <code>accumulated_value</code> and <code>new_value</code></p>
-- <p>The definition of "reducing" is flexible, and a few common examples
-- include sum and concatenation.</p>
-- @tparam reducer reducer the collapsing function
-- @param initial_value the initial value passed to the <code>reducer</code>
-- @return the accumulation of all values
function Iterator:reduce(reducer, initial_value)
  internal.assert_not_nil(reducer, "reducer")
  local reduced_result = initial_value
  local function reduce(next_value)
    reduced_result = reducer(reduced_result, next_value)
  end

  self:foreach(reduce)
  return reduced_result
end

--- Apply a function to all values.
-- <p>The main difference between <code>@{Iterator:foreach}</code> and
-- <code>@{Iterator:map}</code> is that <code>foreach</code> ignores the
-- return value(s) of its function, while map uses them and has restrictions
-- on what it can return.</p>
-- <p>Another important difference is that <code>@{Iterator:map}</code>
-- is a lazy evaluator, while <code>@{Iterator:foreach}</code> iterates over
-- its values immediately.</p>
-- @tparam function func the function to apply for each value
function Iterator:foreach(func)
  internal.assert_not_nil(func, "func")

  local next_input = {self:next()}
  while not self:is_complete() do
    func(unpack(next_input))
    next_input = {self:next()}
  end
end

--- Consume the iterator and retrieve the last value it produces.
-- @return the last value produced by the iterator, or <code>nil</code> if there was none.
function Iterator:last()
  local last
  local buffer
  repeat
    last = buffer
    buffer = self:next()
  until buffer == nil
  return last
end

--- Iterate over the <code>n</code> first values and stop.
-- @tparam integer n amount of values to take
-- @treturn Iterator the new <code>@{Iterator}</code>
function Iterator:take(n)
  internal.assert_integer(n, "n")

  local iterator = internal.base_iter(self, internal.take_next, internal.take_clone)

  iterator.n_remaining = n

  return iterator
end

--- Iterate while <code>predicate</code> is <code>true</code> and stop.
-- @tparam predicate predicate the predicate to check against
-- @treturn Iterator the new <code>@{Iterator}</code>
function Iterator:take_while(predicate)
  internal.assert_not_nil(predicate, "predicate")

  local iterator = internal.base_iter(self, internal.take_while_next, internal.take_while_clone)

  iterator.predicate = predicate
  iterator.done_taking = false

  return iterator
end

--- Consume the iterator and produce its <code>n</code> last values in order.
-- @tparam integer n the number of elements to capture
-- @treturn Iterator the new <code>@{Iterator}</code> which will produce said values
function Iterator:take_last(n)
  internal.assert_integer(n, "n")

  local iterator = internal.base_iter(self, internal.take_last_next, internal.take_last_clone)

  iterator.buffer = {}
  iterator.n = n
  iterator.index = 1
  iterator.consumed_source = false

  return iterator
end

--- Iterate while <code>predicate</code> is <code>false</code> and stop.
-- @tparam predicate predicate the predicate to check against
-- @treturn Iterator the new <code>@{Iterator}</code>
function Iterator:take_until(predicate)
  return self:take_while(M.negate(predicate))
end

--- Iterate over the values, starting at the <code>(n+1)</code>th one.
-- @tparam integer n amount of values to skip
-- @treturn Iterator the new <code>@{Iterator}</code>
function Iterator:skip(n)
  internal.assert_integer(n, "n")

  local iterator = internal.base_iter(self, internal.skip_next, internal.skip_clone)

  iterator.n_remaining = n

  return iterator
end

--- Iterate over the values, starting whenever <code>predicate</code> becomes <code>false</code> for the first time.
-- @tparam predicate predicate the predicate to check against
-- @treturn Iterator the new <code>@{Iterator}</code>
function Iterator:skip_while(predicate)
  internal.assert_not_nil(predicate, "predicate")

  local iterator = internal.base_iter(self, internal.skip_while_next, internal.skip_while_clone)

  iterator.predicate = predicate
  iterator.done_skipping = false

  return iterator
end

--- Iterate over the values, starting whenever <code>predicate</code> becomes <code>true</code> for the first time.
-- @tparam predicate predicate the predicate to check against
-- @treturn Iterator the new <code>@{Iterator}</code>
function Iterator:skip_until(predicate)
  return self:skip_while(M.negate(predicate))
end

--- Take 1 value every <code>n</code>.
-- <p>The first value is always taken.</p>
-- @tparam integer n one more than the number of skipped values
-- @treturn Iterator the new <code>@{Iterator}</code>
-- @see Iterator:skip
function Iterator:every(n)
  internal.assert_integer(n, "n")

  local iterator = internal.base_iter(self, internal.every_next, internal.every_clone)

  iterator.n = n
  iterator.first_call = true

  return iterator
end

--- Checks if any values evaluate to <code>true</code>.
-- @tparam predicate predicate the function to evaluate for each value,
-- defaults to <pre>not (value == nil or value == false)</pre>
-- @treturn boolean <code>true</code> if and only if at least one of the
-- values evaluate to <code>true</code>
function Iterator:any(predicate)
  if predicate then
    return self:map(predicate):any()
  else
    for value in self do
      if value then
        return true
      end
    end
    return false
  end
end

--- Checks if all values evaluate to <code>true</code>.
-- @tparam predicate predicate the function to evaluate for each value,
-- defaults to <pre>not (value == nil or value == false)</pre>
-- @treturn boolean <code>true</code> if and only if all of the
-- values evaluate to <code>true</code>
function Iterator:all(predicate)
  if predicate then
    return self:map(predicate):all()
  else
    for value in self do
      if not value then
        return false
      end
    end
    return true
  end
end

--- Counts how many values evaluate to <code>true</code>.
-- @tparam predicate predicate function to evaluate for each value; if
-- <code>nil</code>, then counts all values.
-- @treturn integer the number of values that match the <code>predicate</code>
function Iterator:count(predicate)
  if not predicate then
    predicate = M.constant(true)
  end
  local c = 0
  for e in self do
    if predicate(e) then
      c = c + 1
    end
  end
  return c
end

--- Iterate over two iterables simultaneously.
-- <p>This results in an Iterator with multiple values per :next() call.</p>
-- <p>The new Iterator will be considered complete as soon as the one the method
-- was called on (<code>self</code>) is completed, regardless of the status of <code>other</code>.</p>
-- @tparam iterable other the other iterable to zip with this one
-- @treturn Iterator the resulting zipped Iterator
function Iterator:zip(other)
  other = exports.iterate(other)
  local iterator = internal.base_iter({self, other}, internal.zip_next, internal.zip_clone)
  return iterator
end

--- Iterate over two iterables simultaneously, giving their values as an array.
-- <p>This results in an Iterator with a single value per :next() call.</p>
-- @tparam iterable other the other iterable to zip with this one
-- @treturn Iterator the resulting zipped Iterator
function Iterator:packed_zip(other)
  return self:zip(other):map(internal.pack)
end

--- Include an index while iterating.
-- <p>The index is given as a single value to the left of all return values. Otherwise,
-- the iterator is unchanged. This is similar to how <code>ipairs</code> iterates over
-- an array, except it can be used with any iterator.</p>
-- @treturn Iterator the resulting indexed Iterator
-- @see enumerate
-- @usage
-- letters = f.every({"a", "b", "c", "d", "e"}, 2)
-- for idx, letter in letters:enumerate() do
--   print(idx, letter)
-- end
function Iterator:enumerate()
  local iterator = internal.base_iter(self, internal.enumerate_next, internal.enumerate_clone)
  iterator.index = 0
  return iterator
end

--- Append elements from <code>other</code> after this iterator has been exhausted.
-- @tparam iterable other the iterator whose elements will be appended
-- @treturn Iterator the concatenation
function Iterator:concat(other)
  other = exports.iterate(other)
  local iterator = internal.base_iter({self, other}, internal.concat_next, internal.concat_clone)
  return iterator
end

--- Create an array out of the <code>@{Iterator}</code>'s values.
-- @treturn array the array of values
function Iterator:to_array()
  local array = {}
  self:foreach(M.bind(table.insert, array))
  return array
end

--- Create a <code>coroutine</code> that yields the values.
-- of the <code>@{Iterator}</code>.
-- @treturn thread The new <code>coroutine</code>
function Iterator:to_coroutine()
  return coroutine.create(internal.coroutine_iter_loop(self))
end

--- Check whether or not the iterator is done.
-- <p>Please note that even if the iterator has reached its actual last
-- value, it has no way of knowing it was the last. Therefore, this function
-- will only return true once the iterator returns <code>nil</code> for the
-- first time.</p>
-- @treturn boolean <code>true</code> if the <code>@{Iterator}</code>
-- has iterated over all its values.
function Iterator:is_complete()
  return self.completed
end

--- @section end

-- RAW FUNCTIONS --

--- Create an <code>@{Iterator}</code> for the <code>iterable</code>.
-- <p>Equivalent to <pre>Iterator.over(iterable)</pre>.</p>
-- @tparam iterable iterable the values to be iterated over
-- @treturn Iterator the new <code>@{Iterator}</code>
-- @function iterate
function exports.iterate(iterable)
  return Iterator.over(iterable)
end

--- Iterate over the naturals starting at 1.
-- @treturn Iterator the counter
-- @see Iterator:take
-- @see Iterator:skip
-- @see Iterator:every
-- @function counter
function exports.counter()
  return Iterator.counter()
end

--- Create an integer iterator that goes from <code>start</code> to <code>stop</code>, <code>step</code>-wise.
-- @tparam[opt=1] integer start the start of the integer range
-- @tparam integer stop the end of the integer range (inclusive)
-- @tparam[opt=1] integer step the difference between consecutive elements
-- @treturn Iterator the new <code>@{Iterator}</code>
-- @function range
-- @see Iterator.range
function exports.range(...)
  return Iterator.range(...)
end

--- Select only values which match the predicate.
-- <p>Equivalent to <pre>iterate(iterable):filter(predicate)</pre>.</p>
-- @tparam iterable iterable the values to be filtered
-- @tparam predicate predicate the function to evaluate for each value
-- @treturn Iterator the filtering <code>@{Iterator}</code>
-- @see iterate
-- @see Iterator:filter
-- @function filter
function exports.filter(iterable, predicate)
  return exports.iterate(iterable):filter(predicate)
end

--- Map values into new values.
-- <p>Equivalent to <pre>iterate(iterable):map(mapping)</pre>.</p>
-- <p>Please note that at no point during iteration may
-- the <code>mapping</code> function return <code>nil</code>
-- as its first value.</p>
-- @tparam iterable iterable the values to be mapped
-- @tparam function mapping the function to evaluate for each value
-- @treturn Iterator the mapping <code>@{Iterator}</code>
-- @see iterate
-- @see Iterator:map
-- @function map
function exports.map(iterable, mapping)
  return exports.iterate(iterable):map(mapping)
end

--- Collapse values into a single value.
-- <p>Equivalent to <pre>iterate(iterable):reduce(reducer, initial_value)</pre>.</p>
-- <p>A reducer is a function of the form
-- <pre>function(accumulated_value, new_value)</pre>
-- which returns the reducing or "accumulation" of
-- <code>accumulated_value</code> and <code>new_value</code></p>
-- <p>The definition of "reducing" is flexible, and a few common examples
-- include sum and concatenation.</p>
-- @tparam iterable iterable the values to be collapsed
-- @tparam reducer reducer the collapsing function
-- @param initial_value the initial value passed to the <code>reducer</code>
-- @return the accumulation of all values
-- @see iterate
-- @see Iterator:reduce
-- @function reduce
function exports.reduce(iterable, reducer, initial_value)
  return exports.iterate(iterable):reduce(reducer, initial_value)
end

--- Apply a function to all values.
-- <p>Equivalent to <pre>iterate(iterable):foreach(func)</pre>.</p>
-- <p>The main difference between <code>@{foreach}</code> and
-- <code>@{map}</code> is that <code>foreach</code> ignores the
-- return value(s) of its function, while map uses them and has restrictions
-- on what it can return.</p>
-- <p>Another important difference is that <code>@{map}</code>
-- is a lazy evaluator, while <code>@{foreach}</code> iterates over
-- its values immediately.</p>
-- @tparam iterable iterable the values to be iterated over
-- @tparam function func the function to apply for each value
-- @see iterate
-- @see Iterator:foreach
-- @function foreach
function exports.foreach(iterable, func)
  return exports.iterate(iterable):foreach(func)
end

--- Return the last value of the given iterable.
-- <p>If <code>iterable</code> is an iterator, this call is equivalent to <code>iterable:last()</code>.
-- Otherwise, this call accesses the last element in the array.</p>
-- @tparam iterable iterable the sequence whose last element is to be accessed
-- @return the last element in the sequence
-- @see Iterator:last
-- @function last
function M.last(iterable)
  if internal.is_iterator(iterable) then
    return iterable:last()
  else
    return iterable[#iterable]
  end
end

--- Iterate over the <code>n</code> first values and stop.
-- <p>Equivalent to <pre>iterate(iterable):take(n)</pre>.</p>
-- @tparam iterable iterable the values to be iterated over
-- @tparam integer n amount of values to take
-- @treturn Iterator the new <code>@{Iterator}</code>
-- @see iterate
-- @see Iterator:take
-- @function take
function exports.take(iterable, n)
  return exports.iterate(iterable):take(n)
end

--- Iterate over the values, starting at the <code>(n+1)</code>th one.
-- <p>Equivalent to <pre>iterate(iterable):skip(n)</pre>.</p>
-- @tparam iterable iterable the values to be iterated over
-- @tparam integer n amount of values to skip
-- @treturn Iterator the new <code>@{Iterator}</code>
-- @see iterate
-- @see Iterator:skip
-- @function skip
function exports.skip(iterable, n)
  return exports.iterate(iterable):skip(n)
end

--- Take 1 value every <code>n</code>.
-- <p>Equivalent to <pre>iterate(iterable):every(n)</pre>.</p>
-- <p>The first value is always taken.</p>
-- @tparam iterable iterable the values to be iterated over
-- @tparam integer n one more than the number of skipped values
-- @treturn Iterator the new <code>@{Iterator}</code>
-- @see Iterator:every
-- @see iterate
-- @see skip
-- @function every
function exports.every(iterable, n)
  return exports.iterate(iterable):every(n)
end

--- Checks if any values evaluate to <code>true</code>.
-- <p>Equivalent to <pre>iterate(iterable):any(predicate)</pre>.</p>
-- @tparam iterable iterable the values to be iterated over
-- @tparam predicate predicate the function to evaluate for each value,
-- defaults to <pre>not (value == nil or value == false)</pre>
-- @treturn boolean <code>true</code> if and only if at least one of the
-- values evaluate to <code>true</code>
-- @see Iterator:any
-- @see iterate
-- @function any
function exports.any(iterable, predicate)
  return exports.iterate(iterable):any(predicate)
end

--- Checks if all values evaluate to <code>true</code>.
-- <p>Equivalent to <pre>iterate(iterable):all(predicate)</pre>.</p>
-- @tparam iterable iterable the values to be iterated over
-- @tparam predicate predicate the function to evaluate for each value,
-- defaults to <pre>not (value == nil or value == false)</pre>
-- @treturn boolean <code>true</code> if and only if all of the
-- values evaluate to <code>true</code>
-- @see Iterator:all
-- @see iterate
-- @function all
function exports.all(iterable, predicate)
  return exports.iterate(iterable):all(predicate)
end

--- Iterate over two iterables simultaneously.
-- @see Iterator:zip
-- @function zip
function exports.zip(iter1, iter2)
  return exports.iterate(iter1):zip(iter2)
end

--- Iterate over two iterables simultaneously.
-- @see Iterator:packed_zip
-- @function packed_zip
function exports.packed_zip(iter1, iter2)
  return exports.iterate(iter1):packed_zip(iter2)
end

--- Iterate with an added index.
-- @see Iterator:enumerate
-- @function enumerate
function exports.enumerate(iter)
  return exports.iterate(iter):enumerate()
end

--- Concatenate two iterables into an Iterator.
-- @see Iterator:concat
-- @function concat
function exports.concat(iter1, iter2)
  return exports.iterate(iter1):concat(iter2)
end

--- Does nothing.
-- @function nop
function exports.nop()
end

--- Returns its arguments in the same order.
-- @param ... the values to be returned
-- @return the given values
-- @function identity
function exports.identity(...)
  return ...
end

--- Create a lambda function from a given definition string.
-- <p><em>DO NOT USE THIS WITH UNTRUSTED AND/OR UNKNOWN STRINGS!</em></p>
-- <p>This and @{clambda} are meant to facilitate the creation of inline
-- functions, given the vanilla Lua syntax is quite verbose (especially with
-- higher order functions).</p>
-- <p>To attempt limit user error and naïve attacks, some restrictions are put
-- in place with respect to the definition:</p>
-- <ul>
-- <li>It must be of the form <code>(arglist) => body</code>, where
-- <code>body</code> is either another lambda definition or an expression that
-- could normally be put inside parenthesis in Lua.</li>
-- <li>The <code>()=></code> chain must not be longer than 10 steps.</li>
-- <li>The environment <code>env</code> must not contain more than 150 string keys.</li>
-- <li>The definition string must not be longer than 100 bytes.</li>
-- <li>The definition string must not contain a newline ("<code>\n</code>") character.</li>
-- <li>The definition string must not contain the substring "<code>--</code>".</li>
-- <li>The definition string must not contain the word "<code>end</code>".</li>
-- </ul>
-- @usage
-- local add = f.lambda "(x, y) => x + y"
-- print(add(2, 3)) --> 5
-- local emphasis = f.lambda("(x)=>x..suffix", {suffix = "!!"})
-- -- f.lambda can even create higher order functions easily
-- local linear_combinator = f.lambda "(m) => (x, y) => m*x + y"
-- local comb2 = linear_combinator(2)
-- print(comb2(3, 4)) --> 10
-- -- lambdas can "see" variables given in their environment
-- local emphasis = f.lambda("(x)=>x..suffix", {suffix = "!!"})
-- emphasis = f.lambda{"(x)=>x..suffix", suffix = "!!"} -- alternative way to define environment
-- print(emphasis("Hello")) --> Hello!!
-- @tparam string|table lambda_def the definition to be made into a function
-- @tparam[opt={}] table env the function environment
-- @treturn function the generated function
-- @see clambda
-- @function lambda
function exports.lambda(lambda_def, env, token)
  -- token is for internal use only
  local calling_from_clambda = (token == internal.proof_clambda_call)
  local err_level = calling_from_clambda and 3 or 2
  assert(load or loadstring) -- sanity check
  if type(lambda_def) == "table" then
    lambda_def, env = lambda_def[1], lambda_def
    env[1] = nil
  end

  lambda_def, env = internal.sanitize_lambda(lambda_def, env, err_level)

  local lambda_lines = internal.expand_lambda(lambda_def, 1, "")
  local lambda_body = table.concat(lambda_lines, "\n")

  local ctx = debug.getinfo(err_level, "nSl")
  local chunk_name = ("lambda(%s:%s)"):format(ctx.source, ctx.currentline)
  local chunk
  if loadstring then
    -- Lua 5.1 and LuaJIT support
    chunk = loadstring(lambda_body, chunk_name)
  else
    chunk = load(lambda_body, chunk_name, "t", env)
  end

  if not chunk then
    error("Load failed for lambda:\n" .. lambda_body, err_level)
  end

  local f = chunk()

  if setfenv then
    setfenv(f, env)
  end
  local lbd = {}
  lbd.func = f
  lbd.expr = lambda_def
  lbd.body = lambda_body:match "^return%s*(.*)$"
  setmetatable(lbd, lambda_function__meta)
  return lbd
end

--- Create a context-aware lambda function.
-- <p><em>DO NOT USE THIS WITH UNTRUSTED AND/OR UNKNOWN STRINGS!</em></p>
-- <p>This works similarly to @{lambda}, except it automatically adds
-- any globals and locals visible to the calling context into its environment.</p>
-- <p>See @{lambda} for more information on restrictions and usage.</p>
-- @usage
-- local angle = math.pi / 3
-- local offset_sin = f.clambda "(x) => math.sin(x + angle)"
-- print(offset_sin(math.pi)) --> -0.866
-- print(offset_sin(2 * math.pi / 3)) --> 0
-- local alternative = f.clambda("(x)=>sin(x + angle)", {sin=math.sin})
-- local or_even = f.clambda{"(x)=>sin(x+angle)", sin=math.sin}
-- @tparam string|table expr the expression to be made into a function
-- @tparam table extra_env additional values to insert into the environment
-- @see lambda
-- @function clambda
function exports.clambda(expr, extra_env)
  if type(expr) == "table" then
    expr, extra_env = expr[1], expr
    extra_env[1] = nil
  end
  local env = {}

  internal.merge_env(env, _G)
  internal.merge_env(env, internal.get_locals(2))
  internal.merge_env(env, extra_env or {})

  return exports.lambda(expr, env, internal.proof_clambda_call)
end
internal.proof_clambda_call = {}

--- Create a lambda function from a given expression string.
-- <p><em>DO NOT USE THIS WITH UNTRUSTED OR UNKNOWN STRINGS!</em></p>
-- <p>This is meant to facilitate writing inline functions, since
-- the vanilla Lua way is very verbose.</p>
-- <p>The expression must abide by several criteria:</p>
-- <ul>
-- <li>It <em>must</em> be an expression that would make sense if put inside parenthesis in vanilla Lua;
-- <li>It <em>must not</em> start with the word "return";
-- <li>It <em>must not</em> contain any newlines (if you need multiple lines, it shouldn't be a lambda);
-- <li>It <em>must not</em> contain comments, or the sequence <code>--</code> inside strings;
-- <li>It <em>must not</em> contain the words "end" or "_ENV", <em>even inside strings</em>.
-- </ul>
-- <p>If any of the above criteria fail to be met, the lambda creator will error.</p>
-- <p>Even with these measures, it is still not safe to create lambdas from untrusted sources.
-- These are attempts to prevent the most basic and naïve attacks, as well as mistakes on the part
-- of the programmer.</p>
-- <p>Inside the expression, the names <code>_1</code>, <code>_2</code>, <code>_3</code>, <code>_4</code>,
-- <code>_5</code>, <code>_6</code>, <code>_7</code>, <code>_8</code>, and <code>_9</code> can be used
-- to refer to the arguments given to the function. Alternatively, the letters <code>a</code> through
-- <code>i</code> can also be used. For the first 3 arguments, an additional alias exists: <code>x</code>,
-- <code>y</code>, and <code>z</code>. And lastly, for the first argument, simply <code>_</code> or <code>v</code> may be used.</p>
-- <p>The lambda function is isolated into a sandboxed environment. That means it cannot read or write
-- to local or global variables. If the function must access variables that are not given as arguments,
-- you must add them to the <code>env</code> table. Setting a key <code>k</code> of that table to a
-- value <code>v</code> will provide the given lambda with a variable called <code>k</code>
-- with value <code>v</code>.</p>
-- <p>When using <code>env</code> to overwrite the parameter name aliases (i.e., <code>a-i</code>,
-- <code>x-z</code>, and <code>v</code>), it is important that the new value is neither <code>nil</code> nor <code>false</code>.
-- Due to the internal mechanism used to detect when to set these aliases, having a falsy value counts
-- as not being defined. In order to minimize debugging and frustration in this niche use case of <code>env</code>,
-- the lambda will not be created and instead it will error stating which alias would fail to be set.</p>
-- <p>For convenience, it is also allowed to call <code>lambda</code> with a single table as an argument. This table
-- must contain the lambda expression in index <code>1</code>, and all other keys are interpreted as part of its
-- environment.</p>
-- <p>Examples:</p>
-- <ul>
-- <li> <code>add = f.lambda "_1 + _2" -- adds its 2 arguments</code>
-- <li> <code>add = f.lambda "a + b" -- same as above</code>
-- <li> <code>add = f.lambda "x + y" -- same as above</code>
-- <li> <code>inc = f.lambda "_1 + 1" -- adds 1 to its argument</code>
-- <li> <code>inc = f.lambda "a + 1" -- same as above</code>
-- <li> <code>inc = f.lambda "x + 1" -- same as above</code>
-- <li> <code>inc = f.lambda "_ + 1" -- same as above</code>
-- <li> <code>double_plus_one = f.lambda("_ + inc(_)", {inc = inc}) -- lets lambda "see" inc exists</code>
-- <li> <code>double_plus_one = f.lambda{"_ + inc(_)", inc = inc} -- this is also a valid way to call it</code>
-- <li> <code>valid_env = f.lambda("v + 2*i", {i = complex.i}) -- defines i as complex.i instead of an alias for _9</code>
-- <li> <code>valid_env = f.lambda{"v + 2*i", i = complex.i} -- also valid</code>
-- <li> <code>invalid_env = f.lambda("v and not f", {f = false}) -- ERROR! f cannot be assigned a falsy value because it's an alias for _6</code>
-- </ul>
-- @tparam string expr the expression to be made into a function
-- @tparam[opt={}] table env the function environment
-- @treturn function the generated function
-- @see clambda
local function lambda_old(expr, env)
  -- Just making sure I didn't forget any major version
  assert(load or loadstring)

  if type(expr) == "table" then
    expr, env = expr[1], expr
    env[1] = nil
  end

  expr, env = internal.sanitize_lambda(expr, env)
  local body = [[
return function(_1, _2, _3, _4, _5, _6, _7, _8, _9)
  local _, x, a, v = _1, x or _1, a or _1, v or _1
  local y, b = y or _2, b or _2
  local z, c = z or _3, c or _3
  local d, e, f, g, h, i = d or _4, e or _5, f or _6, g or _7, h or _8, i or _9
  return ]] .. expr .. [[ -- This comment is here to force a newline
end]]

  -- Get context that created lambda for debug purposes
  local ctx = debug.getinfo(2, "nSl")
  local chunk_name = ("lambda(%s:%s)"):format(
    ctx.source, -- file name
    ctx.currentline
  )
  local chunk
  if loadstring then
    -- Lua 5.1 and LuaJIT support
    chunk = loadstring(body, chunk_name)
  else
    chunk = load(body, chunk_name, "t", env)
  end

  if not chunk then
    error("Load failed for lambda body: " .. expr, 2)
  end

  local f = chunk()
  -- Lua 5.1 and LuaJIT support
  if setfenv then
    setfenv(f, env)
  end

  local lbd = {}
  lbd.func = f
  lbd.expr = expr
  setmetatable(lbd, lambda_function__meta)
  return lbd
end

function internal.indent_str(levels)
  return ("  "):rep(levels)
end

-- syntax: (optional arguments) => <anything>
function internal.lambda_split_params(def)
  local arrow_after_parens = def:find "^%s*%([^%)]*%)%s*=>%s*"
  if not arrow_after_parens then
    -- just the lambda body
    return nil, def
  end
  local arrow_start, arrow_end = def:find "%s*=>%s*"
  local before_arrow = def:sub(1, arrow_start-1)
  local body = def:sub(arrow_end+1)
  local _, param_list_start = before_arrow:find "^%s*%("
  local param_list = before_arrow:match("%(([%w%s,]*)%)", param_list_start)
  return param_list, body
end

-- for use with new lambda only
-- returns list of lines
function internal.expand_lambda(def, level, indent)
  -- this is an attack, stop now
  if level > 10 then
    error("Lambda function tried to nest too deep", level + 2)
  end
  def = internal.trim(def)
  local param_list, body = internal.lambda_split_params(def)
  if param_list then
    body = internal.expand_lambda(body, level + 1, indent .. "  ")
    local lambda_start = indent .. ("return function(%s)"):format(param_list)
    local lambda_end = indent .. "end"
    table.insert(body, 1, lambda_start)
    table.insert(body, lambda_end)
    return body
  else
    -- body of last level of lambda
    return {indent .."return " .. body}
  end
end

-- level 1 = caller's frame
-- level 0 = get_locals itself
function internal.get_locals(level)
  level = level + 1
  local vars = {}
  local i = 1
  while true do
    local name, value = debug.getlocal(level, i)
    if not name then
      break
    end
    vars[name] = value
    i = i + 1
  end
  return vars
end

local function safe_add_to_env(env, name, value)
  if value then
    env[name] = value
  end
end

--- Create a context-aware lambda function.
-- <p><em>DO NOT USE THIS WITH UNTRUSTED OR UNKNOWN STRINGS!</em></p>
-- <p>This works similarly to @{lambda}, except it automatically adds
-- any non-<code>false</code> and non-<code>nil</code> locals and globals
-- into its environment. As a flip-side, its environment is now read-only.</p>
-- <p>See @{lambda} for more information on restrictions and usage.</p>
-- @usage
-- local angle = math.pi / 3
-- local offset_sin = f.clambda "math.sin(x + angle)"
-- print(offset_sin(math.pi))
-- print(offset_sin(2 * math.pi / 3))
-- @tparam string expr the expression to be made into a function
-- @tparam table extra_env additional values to insert into the environment
-- @see lambda
local function clambda_old(expr, extra_env)
  if type(expr) == "table" then
    expr, extra_env = expr[1], expr
    extra_env[1] = nil
  end
  local env = {}

  for k, v in pairs(_G) do
    safe_add_to_env(env, k, v)
  end

  for k, v in pairs(get_locals(2)) do
    safe_add_to_env(env, k, v)
  end

  for k, v in pairs(extra_env or {}) do
    -- purposefully unsafe add
    env[k] = v
  end

  return exports.lambda(expr, env)
end

function internal.merge_env(env, new)
  for k, v in pairs(new) do
    if type(k) == "string" then
      env[k] = v
    end
  end
end

internal.lambda_invalid_env_var_names_pattern = "^_%d?$"
internal.lambda_param_autoalias = {
  a = true,
  b = true,
  c = true,
  d = true,
  e = true,
  f = true,
  g = true,
  h = true,
  i = true,

  v = true,

  x = true,
  y = true,
  z = true,
}

--- Return an array version of the <code>iterable</code>.
-- <p>If <code>iterable</code> is an array, return itself.</p>
-- <p>If <code>iterable</code> is an <code>@{Iterator}</code>,
-- return <pre>iterable:to_array()</pre>
-- @tparam iterable iterable the values to make an array out of
-- @treturn array the array
-- @see Iterator:to_array
-- @see iterate
-- @function to_array
function M.to_array(iterable)
  internal.assert_table(iterable, "iterable")
  if internal.is_iterator(iterable) then
    return iterable:to_array()
  else
    return iterable
  end
end

--- Create a <code>coroutine</code> that yields the values.
-- of the <code>iterable</code>.
-- <p>Equivalent to <pre>iterate(iterable):to_coroutine()</pre>.</p>
-- @tparam iterable iterable the values to be iterated over
-- @treturn thread The new <code>coroutine</code>
-- @see Iterator:to_coroutine
-- @see iterate
-- @function to_coroutine
function M.to_coroutine(iterable)
  return exports.iterate(iterable):to_coroutine()
end

-- MISC FUNCTIONS --

--- Create a negated function of <code>predicate</code>.
-- @tparam predicate predicate the function to be negated
-- @treturn predicate the inverted predicate
function M.negate(predicate)
  internal.assert_not_nil(predicate, "predicate")
  return function(...)
    return not predicate(...)
  end
end

--- Create a function composition from the given functions.
-- @tparam function f1 the outermost function of the composition
-- @tparam function f2 the second outermost function of the composition
-- @tparam function... ... any further functions to add to the composition,
-- in order
-- @treturn function the composite function
function M.compose(f1, f2, ...)
  internal.assert_not_nil(f1, "f1")
  internal.assert_not_nil(f2, "f2")

  if select("#", ...) > 0 then
    local part = M.compose(f2, ...)
    return M.compose(f1, part)
  else
    return function(...)
      return f1(f2(...))
    end
  end
end

--- Create a function with bound arguments.
-- <p>The bound function returned will call <code>func</code>
-- with the arguments passed on to its creation.</p>
-- <p>If more arguments are given during its call, they are
-- appended to the original ones.</p>
-- @tparam function func the function to create a binding of
-- @param ... the arguments to bind to the function.
-- @treturn function the bound function
function M.bind(func, ...)
  internal.assert_not_nil(func, "func")

  local saved_args = {...}
  return function(...)
    local args = {unpack(saved_args)}
    for _, arg in ipairs({...}) do
      table.insert(args, arg)
    end
    return func(unpack(args))
  end
end

--- Curries a function by the given amount of arguments.
-- <p>Currying is, in simple terms, transforming a function <code>f</code> which is used as:</p>
-- <pre>res = f(x, y, z)</pre>
-- <p>Into a function <code>g</code> which is used as:</p>
-- <pre>h = g(x); i = h(y); res = i(z)</pre>
-- <p>Or, chaining all the calls into a single statement:</p>
-- <pre>res = g(x)(y)(z)</pre>
-- <p>You can read more about currying in the <a href="https://en.wikipedia.org/wiki/Currying">Wikipedia
-- page on currying</a></p>
-- <p>In all levels except the deepest, any arguments past the first are ignored. In the deepest
-- level, though, they are passed along to the function as normal. For an example, see Usage.</p>
-- @usage
-- local function func(a, b, c, d) return a * b * c * d end
-- local cfunc = f.curry(func, 3) -- 3 levels deep curry
-- local c1 = cfunc(1) -- binds a = 1; 2 levels left after the call
-- local c2 = c1(2, 3) -- binds b = 2, drops the 3; 1 level left after the call
-- local res = c2(4, 5) -- calls w/ c = 4 & d = 5; this was the last level</pre>
-- @tparam function func the function to be curried
-- @tparam integer levels the number of levels to curry for
-- @treturn function the curried function
function M.curry(func, levels)
  internal.assert_not_nil(func, "func")
  internal.assert_integer(levels, "levels")
  if levels < 1 then
    error(internal.ERR_POSITIVE_INTEGER_EXPECTED:format("levels", tostring(levels)), 2)
  end

  local cf = {}
  cf.func = func
  cf.levels = levels
  cf.args = {}
  setmetatable(cf, curried_function__meta)
  return cf
end

function internal.curried_function_call(cf, newarg, ...)
  if cf.levels == 1 then
    -- append last arg to fixed ones
    local args = {unpack(cf.args)}
    table.insert(args, newarg)
    for _, a in ipairs {...} do
      table.insert(args, a)
    end

    -- do the actual function call at the end of all this madness
    return cf.func(unpack(args))
  else
    -- we must create a new curried function one level deeper
    local successor = {}

    -- same function
    successor.func = cf.func

    -- one fewer levels
    successor.levels = cf.levels - 1

    -- same args as the current one, plus the one just given
    successor.args = {unpack(cf.args)}
    table.insert(successor.args, newarg)

    setmetatable(successor, curried_function__meta)
    return successor
  end
end

--- Create a function that accesses <code>t</code>.
-- <p>Creates a function that reads from <code>t</code>. The new
-- function's argument is used as the key to index <code>t</code>.</p>
-- @tparam table t the table to be indexed
-- @treturn function the dictionary function
function M.dict(t)
  internal.assert_table(t, "t")
  return function(k)
    return t[k]
  end
end

--- Create a function that accesses the key <code>k</code> for any table.
-- <p>The argument passed to the returned function is used as the table
-- <code>t</code> to be accessed. The value of <code>t[k]</code>
-- is returned.</p>
-- @param k the key to access
-- @treturn function the table indexer
function M.indexer(k)
  return function(t)
    return t[k]
  end
end

--- Create a bound function whose first argument is <code>t</code>.
-- <p>Particularly useful to pass a method as a function.</p>
-- <p>Equivalent to <pre>bind(t[k], t, ...)</pre>.</p>
-- @tparam table t the table to be accessed
-- @param k the key to be accessed
-- @param ... further arguments to bind to the function
-- @treturn function the binding for <code>t[k]</code>
function M.bind_self(t, k, ...)
  internal.assert_not_nil(t, "t")
  return M.bind(t[k], t, ...)
end

--- Create a function that always returns the same value.
-- @param value the constant to be returned
-- @treturn function the constant function
function M.constant(value)
  return function()
    return value
  end
end

--- Import <code>@{Iterator}</code>, <code>@{lambda}</code>, and commonly used functions into a given scope.
-- <p>Upon calling this, the following module entries will be
-- added to the given environment. If <code>env</code> is <code>nil</code>,
-- <code>_G</code> (global scope) is assumed.</code></p>
-- <ul>
-- <li> @{Iterator} </li>
-- <li> @{iterate} </li>
-- <li> @{filter} </li>
-- <li> @{map} </li>
-- <li> @{reduce} </li>
-- <li> @{foreach} </li>
-- <li> @{take} </li>
-- <li> @{skip} </li>
-- <li> @{every} </li>
-- <li> @{any} </li>
-- <li> @{all} </li>
-- <li> @{zip} </li>
-- <li> @{packed_zip} </li>
-- <li> @{enumerate} </li>
-- <li> @{concat} </li>
-- <li> @{nop} </li>
-- <li> @{identity} </li>
-- <li> @{lambda} </li>
-- <li> @{clambda} </li>
-- </ul>
-- <p>They can still be accessed as usual through the module after the call.</p>
-- @tparam[opt=_G] table env the environment to import into
function M.import(env)
  if env == nil then
    env = _G
  end
  for k, v in pairs(exports) do
    env[k] = v
  end

  return M
end

-- INTERNAL --

internal.iterator_flag = {}
Iterator[internal.iterator_flag] = true

function internal.is_iterator(t)
  return t[internal.iterator_flag] ~= nil
end

function internal.func_nil_guard(value, ...)
  assert(value ~= nil, "iterated function cannot return nil as the first value")
  return value, ...
end

function internal.pack(...)
  return {...}
end

function internal.trim(s)
  return s:gsub("^%s*(.-)%s*$", "%1")
end

local function sanitize_lambda_old(expr, env)
  env = env or {}
  if type(expr) ~= "string" then
    error("Expected string for expr, got " .. type(expr), 2)
  end
  if type(env) ~= "table" then
    error("Expected table for env, got " .. type(env), 2)
  end

  local proper_env = {}
  for k, v in pairs(env) do
    if type(k) == "string" then
      if k:match(internal.lambda_invalid_env_var_names_pattern) then
        error(("Illegal key in lambda environment: \"%s\""):format(k), 3)
      elseif internal.lambda_param_autoalias[k] and not v then
        error(
          ("Lambda environment has special key \"%s\" set to a falsy value; it will get overwritten inside the lambda"):format(
            k
          ), 3
        )
      end

      proper_env[k] = v
    end
  end

  -- Trim from PiL2 20.4
  -- Found here: http://lua-users.org/wiki/StringTrim
  expr = internal.trim(expr)

  if expr:find "\n" then
    error("Lambda function bodies cannot contain newlines", 3)
  elseif expr:find "%-%-" then
    error("Lambda function bodies cannot contain comments", 3)
  elseif expr:find "%f[%w]end%f[%W]" then
    error("Lambda functions cannot include the word `end`", 3)
  elseif expr:find "^return%f[%W]" then
    error("`return` is implied in lambda expressions, please do not include it yourself", 3)
  elseif expr:find "%f[%w]_ENV%f[%W]" then
    error("Please do not mess with _ENV inside lambdas", 3)
  end

  local encased_expr = "(" .. expr .. ")"
  local s, e = encased_expr:find "%b()"
  if s ~= 1 or e ~= #encased_expr then
    error("Expression has unbalanced parenthesis: " .. expr, 2)
  end

  return expr, proper_env
end

function internal.sanitize_lambda(def, env, parent_err_level)
  local err_level = parent_err_level + 1
  env = env or {}
  if type(def) ~= "string" then
    error("Expected string for lambda definition, got " .. type(def), err_level)
  elseif type(env) ~= "table" then
    error("Expected table for env, got " .. type(env), err_level)
  elseif #def > 100 then -- Possible attack
    error("Lambda definition is too long", err_level)
  end

  local proper_env = {}
  local num_env_variables = 0
  for k, v in pairs(env) do
    if type(k) == "string" then
      proper_env[k] = v
      num_env_variables = num_env_variables + 1
      if num_env_variables > 150 then -- Possible attack
        error("Lambda environment has too many variables", err_level)
      end
    end
  end

  def = internal.trim(def)

  if def:find "\n" then
    error("Lambda function definitions cannot contain line breaks", err_level)
  elseif not def:find "^%s*%(.-%)%s*=>" then
    error("Lambda function definitions must start with '(arguments) =>'", err_level)
  elseif def:find "%-%-" then
    error("Lambda function definitions cannot contain comments", err_level)
  elseif def:find "%f[%w]end%f[%W]" then
    error("Lambda function definitions cannot include the word `end`", err_level)
  end

  local encased_def = ("(%s)"):format(def)
  local s, e = encased_def:find "%b()"
  if s ~= 1 or e ~= #encased_def then
    error("Definition has unbalanced parenthesis: " .. def, err_level)
  end

  return def, proper_env
end

-- ITER FUNCTIONS --

function internal.base_iter(source, next_f, clone)
  local iterator = {}
  setmetatable(iterator, iter__meta)

  iterator.source = source
  iterator.completed = false
  iterator.next = next_f
  iterator.clone = clone
  return iterator
end

function internal.iter_next(iter)
  if iter.completed then
    return nil
  end
  iter.index = iter.index + 1
  local next_input = iter.source[iter.index]
  iter.completed = next_input == nil
  return next_input
end

function internal.iter_clone(iter)
  local new_iter = exports.iterate(Iterator.clone(iter.source))
  new_iter.index = iter.index
  new_iter.completed = iter.completed
  return new_iter
end

function internal.counter_next(iter)
  iter.n = iter.n + 1
  return iter.n
end

function internal.counter_clone(iter)
  local new_iter = Iterator.counter()
  new_iter.count = iter.count
  return new_iter
end

function internal.range_next(iter)
  if iter.completed then
    return nil
  end
  local val = iter.curr
  iter.curr = iter.curr + iter.step
  if iter.step > 0 and val <= iter.stop or iter.step < 0 and val >= iter.stop then
    return val
  else
    iter.completed = true
    return nil
  end
end

function internal.filter_next(iter)
  if iter.completed then
    return nil
  end
  local next_input = {iter.source:next()}
  while next_input[1] ~= nil do
    if iter.predicate(unpack(next_input)) then
      return unpack(next_input)
    end
    next_input = {iter.source:next()}
  end

  iter.completed = true
  return nil
end

function internal.filter_clone(iter)
  return exports.filter(Iterator.clone(iter.source), iter.predicate)
end

function internal.map_next(iter)
  if iter.completed then
    return nil
  end
  local next_input = {iter.source:next()}
  if #next_input == 0 then
    iter.completed = true
    return nil
  end

  return iter.mapping(unpack(next_input))
end

function internal.map_clone(iter)
  return exports.map(Iterator.clone(iter.source), iter.mapping)
end

function internal.take_next(iter)
  if iter.completed then
    return nil
  end
  local next_input = {iter.source:next()}
  if #next_input == 0 then
    iter.completed = true
    return nil
  end

  if iter.n_remaining > 0 then
    iter.n_remaining = iter.n_remaining - 1
    return unpack(next_input)
  else
    iter.completed = true
    return nil
  end
end

function internal.take_clone(iter)
  return exports.take(Iterator.clone(iter.source), iter.n_remaining)
end

function internal.take_while_next(iter)
  if iter.done_taking then
    iter.completed = true
  end

  if iter.completed then
    return nil
  end
  local next_input = {iter.source:next()}
  if #next_input == 0 then
    iter.completed = true
    return nil
  end

  if not iter.predicate(unpack(next_input)) then
    -- Still needs to return this one, but will
    -- correctly set completed tag on next call
    iter.done_taking = true
  end
  return unpack(next_input)
end

function internal.take_while_clone(iter)
  return exports.take_while(Iterator.clone(iter.source), iter.predicate)
end

local function take_last_consume_source(iter)
  -- consume source stream and fill buffer with relevant window
  if iter.consumed_source then
    return
  end

  while true do
    -- peek input stream
    local next = iter.source:next()
    if next == nil then
      -- we're done, break the loop and save the current buffer
      break
    end
    table.insert(iter.buffer, next)

    -- shift everything and erase oldest element
    if #iter.buffer > iter.n then
      for i = 1, iter.n+1 do
        iter.buffer[i] = iter.buffer[i+1]
      end
    end
  end
  iter.consumed_source = true
end

function internal.take_last_next(iter)
  if iter.completed then
    return nil
  end
  take_last_consume_source(iter)
  if iter.index > iter.n then
    iter.completed = true
    return nil
  end
  local value = iter.buffer[iter.index]
  iter.index = iter.index + 1
  return value
end

function internal.take_last_clone(iter)
  take_last_consume_source(iter)
  return exports.iterate(iter.buffer)
end

function internal.skip_while_next(iter)
  if iter.completed then
    return nil
  end
  local next_input
  repeat
    next_input = {iter.source:next()}
    if #next_input == 0 then
      iter.completed = true
      iter.done_skipping = true
      return nil
    end

    if iter.done_skipping then
      -- Early break so it doesn't evaluate predicate when
      -- it doesn't need to
      break
    end

    if not iter.predicate(unpack(next_input)) then
      iter.done_skipping = true
      break
    end
  until false
  return unpack(next_input)
end

function internal.skip_next(iter)
  if iter.completed then
    return nil
  end

  while iter.n_remaining > 0 do
    iter.source:next()
    iter.n_remaining = iter.n_remaining - 1
  end

  local next_input = {iter.source:next()}
  if #next_input == 0 then
    iter.completed = true
    return nil
  end

  return unpack(next_input)
end

function internal.skip_clone(iter)
  return exports.skip(Iterator.clone(iter.source), iter.n_remaining)
end

function internal.every_next(iter)
  if iter.completed then
    return nil
  end

  local next_input
  if iter.first_call then
    iter.first_call = nil
  else
    for _ = 1, iter.n - 1 do
      iter.source:next()
    end
  end

  next_input = {iter.source:next()}
  if #next_input == 0 then
    iter.completed = true
    return nil
  end

  return unpack(next_input)
end

function internal.every_clone(iter)
  return exports.every(Iterator.clone(iter.source), iter.n)
end

function internal.zip_next(iter)
  if iter.completed or iter.source[1].completed then
    iter.completed = true
    return nil, nil
  end
  local source1_next, source2_next = {iter.source[1]:next()}, {iter.source[2]:next()}
  if iter.source[1].completed then
    iter.completed = true
    return nil, nil
  end
  local zipped = source1_next
  for _, v in ipairs(source2_next) do
    table.insert(zipped, v)
  end
  return unpack(zipped)
end

function internal.zip_clone(iter)
  return exports.zip(iter.source[1]:clone(), iter.source[2]:clone())
end

function internal.enumerate_next(iter)
  if iter.completed then
    return nil
  end
  local next_vals = {iter.source:next()}
  if #next_vals == 0 then
    iter.completed = true
    return nil
  else
    iter.index = iter.index + 1
    return iter.index, unpack(next_vals)
  end
end

function internal.enumerate_clone(iter)
  local new = iter.source:clone():enumerate()
  new.index = iter.index
  return new
end

function internal.concat_next(iter)
  if iter.completed then
    return nil
  end
  local next_vals = {iter.source[1]:next()}
  if #next_vals == 0 then
    next_vals = {iter.source[2]:next()}
  end
  if #next_vals == 0 then
    iter.completed = true
    return nil
  end
  return unpack(next_vals)
end

function internal.concat_clone(iter)
  return exports.concat(iter.source[1]:clone(), iter.source[2]:clone())
end

function internal.wrap_coroutine(co)
  local iter = internal.base_iter(nil, internal.iter_coroutine_next, internal.coroutine_try_clone)
  iter.coroutine = co
  return iter
end

function internal.iter_coroutine_next(iter)
  if iter.completed then
    return nil
  end
  local yield = {coroutine.resume(iter.coroutine)}
  local status = yield[1]
  assert(status, yield[2])

  local next_value = {select(2, unpack(yield))}
  if #next_value == 0 then
    iter.completed = true
    return nil
  end

  return unpack(next_value)
end

function internal.coroutine_try_clone()
  error(internal.ERR_COROUTINE_CLONE)
end

function internal.coroutine_iter_loop(iter)
  return function()
    iter:foreach(coroutine.yield)
  end
end

function internal.func_call_next(iter)
  if iter.completed then
    return nil
  end
  local result = {iter.func(iter.is, iter.var)}
  if #result == 0 then
    iter.completed = true
    return nil
  end

  iter.var = result[1]
  return unpack(result)
end

function internal.func_try_clone()
  error(internal.ERR_FUNCTION_CLONE)
end

-- ERROR CHECKING --

function internal.assert_table(value, param_name)
  if type(value) ~= "table" then
    error(internal.ERR_TABLE_EXPECTED:format(param_name, tostring(value)), 3)
  end
end

function internal.assert_integer(value, param_name)
  if type(value) ~= "number" or value % 1 ~= 0 then
    error(internal.ERR_INTEGER_EXPECTED:format(param_name, tostring(value)), 3)
  end
end

function internal.assert_coroutine(value, param_name)
  if type(value) ~= "thread" then
    error(internal.ERR_COROUTINE_EXPECTED:format(param_name, tostring(value)), 3)
  end
end

function internal.assert_not_nil(value, param_name)
  if value == nil then
    error(internal.ERR_NIL_VALUE:format(param_name), 3)
  end
end

internal.ERR_COROUTINE_CLONE = "cannot clone coroutine iterator; try :to_array() and iterate over it"
internal.ERR_FUNCTION_CLONE =
  "cannot clone vanilla Lua iterator; try :to_array() and iterate over it"

internal.ERR_INTEGER_EXPECTED = "param %s expected integer, got: %s"
internal.ERR_POSITIVE_INTEGER_EXPECTED = "param %s expected a positive integer, got: %s"
internal.ERR_TABLE_EXPECTED = "param %s expected table, got: %s"
internal.ERR_COROUTINE_EXPECTED = "param %s expected coroutine, got: %s"
internal.ERR_NIL_VALUE = "param %s is nil"

iter__meta.__index = Iterator
iter__meta.__call = function(iter)
  return iter:next()
end

lambda_function__meta.__call = function(lbd, ...)
  return lbd.func(...)
end

lambda_function__meta.__tostring = function(lbd)
  return ("lambda[[%s]]"):format(lbd.expr)
end

curried_function__meta.__call = internal.curried_function_call

exports.Iterator = Iterator

for name, exported_func in pairs(exports) do
  M[name] = exported_func
end

return M
