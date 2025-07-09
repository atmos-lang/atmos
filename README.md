# The Programming Language Atmos

<img src="atmos-logo.png" width="250" align="right">

***Structured Event-Driven Concurrency***

[
    [About](#about)                 |
    [Install](#install)             |
    [Hello World!](#hello-world)    |
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

# Hello World!

During 5 seconds, displays `Hello World!` every second:

```
require "atmos.env.clock"

main {
    watching @5 {
        every @1 {
            print "Hello World!"
        }
    }
}
```

We first import the builtin `clock` environment, which provides timers to
applications.
The `main` primitive starts a task in Atmos that behaves as follows:

- The `watching` command will execute its body during 5 seconds.
- The `every` loop will execute its body every second.
- After the `watching` terminates, the `main` reaches its end and program
  terminates.
