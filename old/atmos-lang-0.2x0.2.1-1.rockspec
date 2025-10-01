package = "atmos-lang"
version = "0.2x0.2.1-1"
source = {
   url = "git+https://github.com/atmos-lang/atmos",
   branch = "v0.2_0.2.1",
}
description = {
   summary = [[
    The Programming Language Atmos
   ]],
   detailed = [[
    Atmos is a programming language reconciles *Structured
    Concurrency* with *Event-Driven Programming*, extending classical
    structured programming with two main functionalities:

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

    Atmos is inspired by synchronous programming languages like Ceu and
    Esterel.
   ]],
   homepage = "https://github.com/atmos-lang/atmos",
   license = "MIT",
}
dependencies = {
   "lua ~> 5.4", "atmos",
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
