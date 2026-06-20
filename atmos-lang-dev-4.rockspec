package = "atmos-lang"
version = "dev-4"
source = {
   url = "git+https://github.com/atmos-lang/atmos",
   branch = "main",
}
description = {
   summary = [[
    The Programming Language Atmos
   ]],
   detailed = [[
    Atmos is a programming language that reconciles Structured
    Concurrency and Event-Driven Programming, extending classical
    structured programming with two main functionalities:

    - Structured Deterministic Concurrency:
        - A `task` primitive with deterministic scheduling provides predictable
          behavior and safe abortion.
        - Structured primitives compose concurrent tasks with lexical scope (e.g.,
          `watching`, `loop on`, `par_or`).
        - A `tasks` container primitive holds attached tasks and controls their
          lifecycle.
        - A `pin` declaration attaches a task or tasks to its enclosing lexical
          scope.
    - Event Signaling Mechanisms:
        - An `await` primitive suspends a task and waits for events.
        - An `emit` primitive signals events and awakes awaiting tasks.

    Atmos also complements its core synchronous concurrency model with
    Functional Streams (à la ReactiveX) and Multithreading Parallelism
    (via LuaLanes):

    - Functional Streams:
        - Interoperability with tasks & events.
        - Safe finalization of stateful streams.
    - Asynchronous Parallelism:
        - A `thread` primitive offloads computations to isolated OS threads.
        - Safe abortion and finalization for threads.

    Atmos compiles to Lua and relies on lua-atmos for its
    concurrency runtime.

    Atmos is inspired by synchronous programming languages like Céu
    and Esterel.
   ]],
   homepage = "https://github.com/atmos-lang/atmos",
   license = "MIT",
}
dependencies = {
   "lua >= 5.4", "atmos",
}
build = {
   type = "builtin",
   install = {
      bin = {
         ["atmos"] = "atmos"
      },
   },
   copy_directories = { "exs" },
   modules = {
      ["atmos.lang.aux"]       = "src/aux.lua",
      ["atmos.lang.argparse"]  = "src/argparse.lua",
      ["atmos.lang.await"]     = "src/await.lua",
      ["atmos.lang.coder"]     = "src/coder.lua",
      ["atmos.lang.exec"]      = "src/exec.lua",
      ["atmos.lang.global"]    = "src/global.lua",
      ["atmos.lang.lexer"]     = "src/lexer.lua",
      ["atmos.lang.parser"]    = "src/parser.lua",
      ["atmos.lang.prim"]      = "src/prim.lua",
      ["atmos.lang.run"]       = "src/run.lua",
      ["atmos.lang.tosource"]  = "src/tosource.lua",
   },
}
