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
