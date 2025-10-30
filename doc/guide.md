# Guide

1. [Tasks & Events](#1-tasks--events)
2. [External Environments](#2-external-environments)
3. [Lexical Structure](#3-lexical-structure)
4. [Compound Statements](#4-compound-statements)
5. [Functional Streams](#5-functional-streams)
6. [More about Tasks](#6-more-about-tasks)
7. [Errors](#7-errors)

# 1. Tasks & Events

Tasks are the basic units of execution in Atmos.

The `spawn` primitive starts a task from a function prototype:

```
func T (...) {
    ...
}
pin t1 = spawn T(...)   ;; starts `t1`
pin t2 = spawn T(...)   ;; starts `t2`
...                     ;; t1 & t2 started and are now waiting
```

The [`pin`](manual-out.md#declarations-and-assignments) declarations, which we
detail further, attach the tasks into the current scope.

Tasks are based on Lua coroutines, meaning that they rely on cooperative
scheduling with explicit suspension points.
The key difference is that tasks can react to each other through events.

The `await` primitive suspends a task until a matching event occurs:

```
func T (i) {
    await :X
    print("task " ++ i ++ " awakes on X")
}
```

The `emit` primitive broadcasts an event, awaking all tasks awaiting it:

```
spawn T(1)
spawn T(2)
emit :X
    ;; "task 1 awakes on X"
    ;; "task 2 awakes on X"
```

In the example, `:X` is a [tag](manual-out.md#hierarchical-tags), which here is
equivalent to string `"X"`.

Although explicit suspension points are still required, note that Atmos
provides *reactive scheduling* for tasks based on `await` and `emit`
primitives.

# 2. External Environments

An environment is the external component that bridges input events from the
real world into an Atmos application.
These events can be timers, key presses, network packets, or other kinds of
inputs, depending on the environment.

The environment is loaded through `require` and depends on an outer `call`
primitive to handle events:

```
require "x"         ;; environment "x" with events X.A, X.B, ...

await :X.A          ;; awakes when "x" emits "X.A"
```

The environment internally executes a continuous loop that polls external
events from the real world and forwards them to Atmos through `emit` calls.
The main body of the program is an anonymous task that can await and react to
the environment.

The next example relies on the built-in [clock environment](atmos/env/clock/)
to count 5 seconds:

```
require "atmos.env.clock"

print "Counts 5 seconds:"
loop _ in 5 {
    await @1
    print "1 second..."
}
print "5 seconds elapsed."
```

Note that `@1` is a [clock value](manual-out.md#clock) in the format
`@HH:MM:SS.sss`, allowing Atmos to await time.

# 3. Lexical Structure

In Atmos, the lexical organization of tasks determines their lifetimes and also
how they are scheduled, which helps to reason about programs more statically
based on the source code.

## 3.1. Lexical Scheduling

The reactive scheduler of Atmos is deterministic and cooperative:

1. `deterministic`:
    When multiple tasks spawn or awake concurrently, they activate in the order
    they appear in the source code.
2. `cooperative`:
    When a task spawns or awakes, it takes full control of the application and
    executes until it awaits or terminates.

Consider the code that spawns two anonymous tasks concurrently and await the
same event `:X` as follows:

<table>
<tr><td>
<pre>
print "-=-=- 3.1 -=-=-"
print "1"
spawn {         ;; concurrent anonymous task #1
    print "a1"
    await :X
    print "a2"
}
print "2"
spawn {         ;; concurrent anonymous task #2
    print "b1"
    await :X
    print "b2"
}
print "3"
emit :X
print "4"
</pre>
</td><td>
<pre>
;; Output:
;; 1
;; a1
;; 2
;; b1
;; 3
;; a2
;; b2
;; 4
</pre>
</td></tr>
</table>

In the example, the scheduling behaves as follows:

- Main application prints `1` and spawns the first task.
- The first task takes control, prints `a1`, and suspends, returning the
  control back to the main application.
- The main application prints `2` and spawns the second task.
- The second task starts, prints `b1`, and suspends.
- The main application prints `3`, and broadcasts `:X`.
- The first task awakes, prints `a2`, and suspends.
- The second task awakes, prints `b2`, and suspends.
- The main application prints `4`.

## 3.2. Lexical Hierarchy

Tasks form a hierarchy based on the source position in which they are spawned.
Therefore, the lexical structure of the program determines the lifetime of
tasks.

In the next example, the outer task terminates and aborts the inner task before
it has the chance to awake:

```
spawn {
    spawn {
        await :Y    ;; never awakes after :X occurs
        print "never prints"
    }
    await :X        ;; awakes and aborts the whole task hierarchy
}
emit :X
emit :Y
```

### 3.2.1. Deferred Statements

A task can register deferred statements to execute when they terminate or abort
within its hierarchy:

```
spawn(function ()
    spawn(function ()
        local _ <close> = defer(function ()
            print "nested task aborted"
        end)
        await(false) ;; never awakes
    end)
    ;; will abort nested task
end)
```

The nested spawned task never awakes, but executes its `defer` clause when
its enclosing hierarchy terminates.

Since Atmos is a pure-Lua library, note that the annotation `local _ <close> =`
is necessary when bounding a `defer` to a lexical scope.

Tasks and deferred statements can also be attached to the scope of explicit
blocks:

```
do
    local _ <close> = spawn(function ()
        <...>   ;; aborted with the enclosing `do`
    end)
    local _ <close> = defer(function ()
        <...>   ;; aborted with the enclosing `do`
    end)
    <...>
end
```

In the example, we attach a `spawn` and a `defer` to an explicit block.
When the block goes out of scope, it automatically aborts the task and executes
the deferred statement.
The aborted task may also have pending defers, which also execute immediately.
The defers execute in the reverse order in which they appear in the source
code.

Note that the annotation `local _ <close> =` is also required to attach a task
to an explicit block.
We can omit this annotation only when we want to attach the `spawn` to its
enclosing task.

# 4. Compound Statements

Atmos provides many compound statements built on top of tasks:

- The `every` statement expands to a loop that awaits its first argument at the
  beginning of each iteration:

```
every(clock{s=1}, function ()
    print "1 second elapses"    ;; prints every second
end)
```

- The `watching` statement awaits the given body to terminate, or aborts if its
  first argument occurs:

```
watching(clock{s=1}, function ()
    await 'X'
    print "X happens before 1s" ;; prints unless 1 second elapses
end)
```

- The `par`, `par_and`, `par_or` statements spawn multiple bodies and rejoin
  after their bodies terminates: `par` never rejoins, `par_and`
  rejoins after all terminate, `par_or` rejoins after any terminates:

```
par_and(function ()
    await 'X'
end, function ()
    await 'Y'
end, function ()
    await 'Z'
end)
print "X, Y, and Z occurred"
```

# 5. Functional Streams

Functional data streams represent incoming values over continuous time, and can
be combined a pipeline for real-time processing.
Atmos extends the [f-streams][f-streams] library to interoperate with tasks
and events.

The next example creates a stream that awaits occurrences of event `X`:

```
local S = require "atmos.streams"
spawn(function ()
    S.fr_await('X')                                 ;; X1, X2, ...
        :filter(function(x) return x.v%2 == 1 end)  ;; X1, X3, ...
        :map(function(x) return x.v end)            ;; 1, 3, ...
        :tap(print)
        :to()
end)
for i=1, 10 do
    await(clock{s=1})
    emit { tag='X', v=i }   ;; `X` events carrying `v=1`
end
```

The example spawns a dedicated task for the stream pipeline with source
`S.fr_await('X')`, which runs concurrently with a loop that generates events
`X` carrying field `v=i` on every second.
The pipeline filters only odd occurrences of `v`, then maps to these values,
and prints them.
The call to sink `to()` activates the stream and starts to pull values from
the source, making the task to await.
The loop takes 10 seconds to emit `1,2,...,10`, whereas the stream takes 10
seconds to print `1,3,...,9`.

The full stream pipeline of the example is analogous to the awaiting loop as
follows:

```
while true do
    print(map(filter(await('X')))
end
```

Atmos provides stateful streams by supporting tasks as stream sources.
The next example creates a task stream that packs awaits to `X` and `Y` in
sequence:

```
function T ()
    await('X')
    await('Y')
end
spawn(function ()
    S.fr_await(T)                           ;; XY, XY, ...
        :zip(S.from(1))                     ;; {XY,1}, {XY,2} , ...
        :map(function (t) return t[2] end)  ;; 1, 2, ...
        :take(2)                            ;; 1, 2
        :tap(print)
        :to()
end)
emit('X')
emit('X')
emit('Y')   ;; 1
emit('X')
emit('Y')   ;; 2
emit('Y')
```

In the example, `S.fr_await(T)` is a stream of complete executions of task `T`.
Therefore, each item is generated only after `X` and `Y` occur in sequence.
The pipeline is zipped with an increasing sequence of numbers, and then mapped
to only generate the numbers.
The example only takes the first two numbers, prints them, and terminates.

[f-streams]: https://github.com/lua-atmos/f-streams/tree/v0.2

`TODO: better task example (deb?)`

`TODO: safe finalization of stateful (task-based) streams`

# 6. More about Tasks

## 6.1. Public Data

A task is a Lua table, and can hold public data fields as usual.
It is also possible to self refer to the running task with a call to `task()`:

```
function T ()
    task().v = 10
end
local t = spawn(T)
print(t.v)  ;; 10
```

## 6.2. Task Pools

A task pool, created with `tasks` primitive, allows that multiple tasks share a
parent container in the hierarchy.
When the pool goes out of scope, all attached tasks are aborted.
When a task terminates, it is automatically removed from the pool.

```
function T (id, ms)
    task().id = id
    print('start', id, ms)
    await(clock{ms=ms})
    print('stop', id, ms)
end

do
    local ts <close> = tasks()
    for i=1, 10 do
        spawn_in(ts, T, i, math.random(500,1500))
    end
    await(clock{s=1})
end
```

In the example, we first create a pool `ts`.
Then we use `spawn_in` to spawn and attach 10 tasks into the pool.
Each task sleeps between `500ms` and `1500ms` before terminating.
After `1s`, the `ts` block goes out of scope, aborting all tasks that did not
complete.

Task pools provide a `pairs` iterator to traverse currently attached tasks:

```
for _,t in pairs(ts) do
    print(t.id)
end
```

If we include this loop after the `await(clock{s=1})` in the previous example,
it will print the task ids that did not awake.

## 6.3. Task Toggling

A task can be toggled off (and back to on) to remain alive but unresponsive
(and back to responsive) to upcoming events:

```
local t = spawn (function ()
    await 'X'
    print "awakes from X"
end)
toggle(t, false)
emit 'X'    ;; ignored
toggle(t, true)
emit 'X'    ;; awakes
```

The `toggle` statement awaits the given body to terminate, while also observing
its first argument as a boolean event:
When receiving `false`, the body toggles off.
When receiving `true`, the body toggles on.

```
toggle('X', function ()
    every(clock{s=1}, function ()
        print "1s elapses"
    end)
end)
emit('X', false)    ;; body above toggles off
<...>
emit('X', true)     ;; body above toggles on
<...>
```

# 7. Errors

Atmos provides `throw` and `catch` primitives to handle errors, which take in
consideration task hierarchy, i.e., a parent task catches errors from child
tasks.

```
function T ()
    spawn (function ()
        await 'X'
        throw 'Y'
    end)
    await(false)
end

spawn(function ()
    local ok, err = catch('Y', function ()
        spawn(T)
        await(false)
    end)
    print(ok, err)
end)

emit 'X'

;; "false, Y"
```

In the example, we spawn a parent task that catches errors of type `Y`.
Then we spawn a named task `T`, which spawns an anonymous task, which awaits
`X` to finally throw `Y`.
Outside the task hierarchy, we `emit X`, which only awakes the nested task.
Nevertheless, the error propagates up in the task hierarchy until it is caught
by the top-level task, returning `false` and the error `Y`.

## 7.1. Bidimensional Stack Traces

An error trace may cross multiple tasks from a series of emits and awaits,
e.g.: an `emit` in one task awakes an `await` in another task, which may `emit`
and match an `await` in a third task.
However, *cross-task traces* do not inform how each task in the trace started
and reached its `emit`, i.e. each of the *intra-task* traces, which is as much
as insightful to understand the errors.

Atmos provides bidimensional stack traces, which include cross-task and
intra-task traces.

In the next example, we spawn 3 tasks in `ts`, and then `emit` an event
targeting the task with `id=2`.
Only this task awakes and generates an uncaught error:

```
function T (id)
    await('X', id)
    throw 'error'
end

local ts <close> = tasks()
spawn_in(ts, T, 1)
spawn_in(ts, T, 2)
spawn_in(ts, T, 3)

emit('X', 2)
```

The stack trace identifies that the task lives in `ts` in line 6 and spawns in
line 8, before throwing the error in line 3:

```
==> ERROR:
 |  x.lua:11 (emit)
 v  x.lua:3 (throw) <- x.lua:8 (task) <- x.lua:6 (tasks)
==> error
```
