# The Programming Language Atmos

[![Tests][badge]][test]

[badge]: https://github.com/atmos-lang/atmos/actions/workflows/test.yml/badge.svg
[test]:  https://github.com/atmos-lang/atmos/actions/workflows/test.yml

***Structured Event-Driven Concurrency***

[
    [`v0.4`](https://github.com/atmos-lang/atmos/tree/v0.4)      |
    [`v0.3`](https://github.com/atmos-lang/atmos/tree/v0.3)      |
    [`v0.2`](https://github.com/atmos-lang/atmos/tree/v0.2_0.2.1)
]

This is the unstable `main` branch.
Please, switch to stable [`v0.4`](https://github.com/atmos-lang/atmos/tree/v0.4).
<!--
-->

[
    [About](#about)                 |
    [Hello World!](#hello-world)    |
    [Install & Run](#install--run)  |
    [Documentation](#documentation) |
    [Resources](#resources)
]

<img src="atmos-logo.png" width="250" align="right">

# About

Atmos is a programming language that reconciles *[Structured Concurrency][sc]*,
*[Event-Driven Programming][events]*, and *[Functional Streams][streams]*,
extending classical structured programming with three main functionalities:

- Structured Deterministic Concurrency:
    - A `task` primitive with deterministic scheduling provides predictable
      behavior and safe abortion.
    - Structured primitives compose concurrent tasks with lexical scope (e.g.,
      `watching`, `every`, `par_or`).
    - A `tasks` container primitive holds attached tasks and control their
      lifecycle.
    - A `pin` declaration attaches a task or tasks to its enclosing lexical
      scope.
- Event Signaling Mechanisms:
    - An `await` primitive suspends a task and wait for events.
    - An `emit` primitive signals events and awake awaiting tasks.
- Functional Streams (à la [ReactiveX][rx]):
    - *(experimental)*
    - Functional combinators for lazy (infinite) lists.
    - Interoperability with tasks & events:
        tasks and events as streams, and
        streams as events.
    - Safe finalization of stateful (task-based) streams.

Atmos is inspired by [synchronous programming languages][sync] like [Céu][ceu]
and [Esterel][esterel].

Atmos compiles to [Lua][lua] and relies on [lua-atmos][lua-atmos] for its
concurrency runtime.

[sc]:           https://en.wikipedia.org/wiki/Structured_concurrency
[events]:       https://en.wikipedia.org/wiki/Event-driven_programming
[streams]:      https://en.wikipedia.org/wiki/Stream_(abstract_data_type)
[rx]:           https://en.wikipedia.org/wiki/ReactiveX
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

```
sudo luarocks install atmos-lang --lua-version=5.4
atmos <lua-path>/atmos/lang/exs/hello.lua
```

You may also clone the repository and copy part of the source tree, as follows,
into your `lua-atmos` path (e.g., `/usr/local/share/lua/5.4/atmos/`):

```
TODO
```

The Atmos distribution includes the single-file project
[argparse](https://github.com/mpeterv/argparse).

Atmos depends on [lua-atmos][lua-atmos].

# Documentation

- [Guide](doc/guide.md)
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
- [`atmos.env.pico`][atmos-pico]
    An environment that relies on [pico-sdl][pico-sdl] as a simpler alternative
    to SDL.
- [`atmos.env.iup`][atmos-iup]
    An environment that relies on [IUP][iup] ([iup-lua][iup-lua]) to provide
    graphical user interfaces (GUIs).

[atmos-clock]:  https://github.com/lua-atmos/atmos/tree/main/atmos/env/clock/
[atmos-socket]: https://github.com/lua-atmos/atmos/tree/main/atmos/env/socket/
[atmos-sdl]:    https://github.com/lua-atmos/atmos/tree/main/atmos/env/sdl/
[atmos-pico]:   https://github.com/lua-atmos/atmos/tree/main/atmos/env/pico/
[atmos-iup]:    https://github.com/lua-atmos/atmos/tree/main/atmos/env/iup/

[luasocket]:    https://lunarmodules.github.io/luasocket/
[luasdl]:       https://github.com/Tangent128/luasdl2/
[iup]:          https://www.tecgraf.puc-rio.br/iup/
[iup-lua]:      https://www.tecgraf.puc-rio.br/iup/en/basic/index.html
[pico-sdl]:     https://github.com/fsantanna/pico-sdl/

# Resources

- [A toy problem][toy]: Drag, Click, or Cancel
    - [click-drag-cancel.atm](exs/click-drag-cancel.atm)
- A simple but complete 2D game in Atmos:
    - https://github.com/atmos-lang/sdl-rocks/
- Academic publications (Céu):
    - http://ceu-lang.org/chico/#ceu
- Mailing list (Céu & Atmos):
    - https://groups.google.com/g/ceu-lang

[toy]: https://fsantanna.github.io/toy.html
