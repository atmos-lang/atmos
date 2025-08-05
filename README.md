# The Programming Language Atmos

<img src="atmos-logo.png" width="250" align="right">

***Structured Event-Driven Concurrency***

[
    [About](#about)                 |
    [Hello World!](#hello-world)    |
    [Install](#install)             |
    [Documentation](#documentation) |
    [Resources](#resources)
]

# About

Atmos is a programming language reconciles *[Structured Concurrency][sc]* with
*[Event-Driven Programming][events]*, extending classical structured
programming with two main functionalities:

- Structured Deterministic Concurrency:
    - The `task` primitive with deterministic scheduling provides predictable
      behavior and safe abortion.
    - Structured primitives compose concurrent tasks with lexical scope (e.g.,
      `watching`, `every`, `par_or`).
    - The `tasks` container primitive holds attached tasks and control their
      lifecycle.
- Event Signaling Mechanisms:
    - The `await` primitive suspends a task and wait for events.
    - The `emit` primitive signal events and awake awaiting tasks.

Atmos is inspired by [synchronous programming languages][sync] like [Ceu][ceu]
and [Esterel][esterel].

Atmos compiles to [Lua][lua] and relies on [lua-atmos][lua-atmos] for its
concurrency runtime.

[sc]:           https://en.wikipedia.org/wiki/Structured_concurrency
[events]:       https://en.wikipedia.org/wiki/Event-driven_programming
[sync]:         https://fsantanna.github.io/sc.html
[ceu]:          http://www.ceu-lang.org/
[esterel]:      https://en.wikipedia.org/wiki/Esterel
[lua]:          https://www.lua.org/
[lua-atmos]:    https://github.com/lua-atmos/atmos/

# Hello World!

During 5 seconds, displays `Hello World!` every second:

```
require "atmos.env.clock"

watching @5 {
    every @1 {
        print "Hello World!"
    }
}
```

We first import the builtin `clock` environment, which provides timers to
applications.
The program body is a task in Atmos that behaves as follows:

- The `watching` command will execute its block during 5 seconds.
- The `every` loop will execute its block every second.
- Once the `watching` terminates, the body reaches its end, and the program
  exits cleanly.

# Install & Run

Atmos depends on [lua-atmos][lua-atmos].

```
sudo luarocks install atmos-lang --lua-version=5.4
atmos <lua-path>/atmos/lang/exs/hello.lua
```

You may also clone the repository and copy part of the source tree, as follows,
into your `lua-atmos` path (e.g., `/usr/local/share/lua/5.4/atmos/`):

```
TODO
```

# Documentation

- [Manual](docs/manual-out.md)
- [Guide](TODO)

# Resources

`TODO`
