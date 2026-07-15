v0.8 (???/??)
-------------

- Additions:
    - `await` patterns:
        - `T()` also in `loop on`, `watching`
    - `task` as expression: current running task
    - `task` dot declarations: `task M.T (...)`

- Modifications:
    - tag indexing `@:x` no longer requires parens (`@(:x)`)

- Fixes:
    - `return` crosses (ignores) transparent `spawn`
    - `spawn T()` supports `where` clauses
    - `spawn T()` survives as last expression

v0.7 (jun/26)
-------------

Two major refactorings:

- symbol `@` affecting the syntax of tables, indexing, and clocks
- distinction between `task` (the prototype) vs `xtask` (the instance)

- Additions:
    - `:task` / `:xtask` / `:tasks`: prototype vs instance vs pool
        - `task T () { ... }`: prototype
        - `xtask(T)`: instance
    - `abort` task and tasks
    - `await` patterns:
        - any/all tasks in pools:
            - `await :any ts`, `await :all ts`
        - logical combinators:
            - `a || b`, `a && b`, `! c`
        - predicates:
            - `await until`, `await while` (e.g. `await :X until c`)
    - `toggle ... with <filter>`: optional filter pattern to keep reacting
- Removals:
    - multi-arg events:
        - `emit` now only receives one argument
        - `await` now only receives and returns one argument
    - `t[-]` pop operator
- Modifications:
    - `every` -> `loop on` (e.g., `loop v on :X`)
    - `par_and` / `par_or` -> `par :all` / `par :any`
    - `@{...}` -> `[...]` for table constructors
    - table indexing:
        - `t[10] t[i] t[i+1]` -> `t@10 t@i t@(i+1)`
        - `t[=] t[+]` -> `t@# t@+`
    - spawn/emit targets:
        - `spawn [ts]` -> `spawn @ts`
        - `emit [:x]` -> `emit @(:x)`
    - clock literals as numbers in microseconds
        - `@.100` -> `100ms` (`== 100000`)
        - `@1:x` -> `1min + x*1s`

PATCHES

- `v0.7-2`: desugar `loop-on` into `loop-await`, bump `atmos` version to `v0.7`

v0.6 (mar/26)
-------------

- Additions:
    - `thread` block (CPU parallelism via LuaLanes)
    - lambda syntax `\+` for operators
    - exponentiation operation `**`

v0.5 (jan/26)
-------------

- Additions:
    - local functions  | `val func f () { ... }`
    - integer division | `x // y`
- Bug fixes:
    - multi-line strings
    - tail calls in `spawn_in`
    - lexer error line

v0.4 (oct/25)
-------------

- Additions:
    - stream variables `val x*` (experimental)
- Modifications:
    - examples use `pico` environment
- Documentation:
    - doc/guide.md

v0.3 (oct/25)
-------------

- Additions:
    - command-line options
    - `f-streams` library
    - `test` block
    - `do()` innocuous expression
    - operators:
        - deep equality (`===` and `=!=`)
        - membership (`?>` and `!>`)
    - calls:
        - `f \{}` and `f @clk`
- Modifications:
    - `if x \{...}` to `if x => \{...}`
    - `every e \{...}` to `every v in e {...}`
    - `loop ... in N`: from `1` to `N` (inclusive)
    - operations across multiple lines
- Removals:
    - vectors (`#{...}`)
- Bug fixes:
    - task abortion

v0.2 (aug/25)
---------------

- (no history)
