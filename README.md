# The Programming Language Atmos

[
    [`v0.2`](https://github.com/atmos-lang/atmos/tree/v0.2_0.2.1)
]

<img src="atmos-logo.png" width="250" align="right">

***Structured Event-Driven Concurrency***

[
    [About](#about)                 |
    [Hello World!](#hello-world)    |
    [Install & Run](#install--run)  |
    [Documentation](#documentation) |
    [Resources](#resources)
]

# About

Atmos is a programming language reconciles *[Structured Concurrency][sc]* with
*[Event-Driven Programming][events]*, extending classical structured
programming with two main functionalities:

- Structured Deterministic Concurrency:
    - A `task` primitive with deterministic scheduling provides predictable
      behavior and safe abortion.
    - A `tasks` container primitive holds attached tasks and control their
      lifecycle.
    - A `pin` declaration attaches a task or tasks to its enclosing lexical
      scope.
    - Structured primitives compose concurrent tasks with lexical scope (e.g.,
      `watching`, `every`, `par_or`).
- Event Signaling Mechanisms:
    - An `await` primitive suspends a task and wait for events.
    - An `emit` primitive broadcasts events and awake awaiting tasks.

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

<!--
- [Guide](TODO)
-->

- [Manual](doc/manual-out.md)

# Environments

An environment is an external component that bridges input events from the real
world into an Atmos application.

The standard distribution of Atmos provides the following environments:

- [`atmos.env.clock`][atmos-clock]
    A simple pure-Lua environment that uses `os.clock` to issue timer events.
- [`atmos.env.socket`][atmos-socket]
    An environment that relies on [luasocket][luasocket] to provide network
    communication.
- [`atmos.env.sdl`][atmos-sdl]
    An environment that relies on [lua-sdl2][luasdl] to provide window, mouse,
    key, and timer events.
- [`atmos.env.iup`][atmos-iup]
    An environment that relies on [IUP][iup] ([iup-lua][iup-lua]) to provide
    graphical user interfaces (GUIs).

[atmos-clock]:  https://github.com/lua-atmos/atmos/tree/main/atmos/env/clock/
[atmos-socket]: https://github.com/lua-atmos/atmos/tree/main/atmos/env/socket/
[atmos-sdl]:    https://github.com/lua-atmos/atmos/tree/main/atmos/env/sdl/
[atmos-iup]:    https://github.com/lua-atmos/atmos/tree/main/atmos/env/iup/

# Resources

- [A toy problem][toy]: Drag, Click, or Cancel
    - [click-drag-cancel.atm](exs/click-drag-cancel.atm)
- A simple but complete 2D game in Atmos:
    - https://github.com/atmos-lang/sdl-rocks/
- Academic publications (Ceu):
    - http://ceu-lang.org/chico/#ceu
- Mailing list (Ceu):
    - https://groups.google.com/g/ceu-lang

[toy]: https://fsantanna.github.io/toy.html
