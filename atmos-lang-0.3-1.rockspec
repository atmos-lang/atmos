package = "atmos-lang"
version = "0.3-1"
source = {
   url = "git+https://github.com/atmos-lang/atmos",
   branch = "v0.3",
}
description = {
   summary = [[
    The Programming Language Atmos
   ]],
   detailed = [[
    Atmos is a programming language that reconciles Structured Concurrency,
    Event-Driven Programming, and Functional Streams,
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
    - Functional Streams (à la ReactiveX):
        - Functional combinators for lazy (infinite) lists.
        - Interoperability with tasks & events:
            tasks and events as streams, and
            streams as events.
        - Safe finalization of stateful (task-based) streams.

    Atmos is inspired by synchronous programming languages like Céu
    and Esterel.

    Atmos compiles to Lua and relies on lua-atmos for its
    concurrency runtime.
   ]],
   homepage = "https://github.com/atmos-lang/atmos",
   license = "MIT",
}
dependencies = {
   "lua ~> 5.4", "atmos ~> 0.3",
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
