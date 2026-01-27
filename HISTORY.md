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
