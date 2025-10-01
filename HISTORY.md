v0.3 (oct/25)
-------------

- Additions:
    - command-line options
    - `f-streams` library
    - `test` block
    - `do()` innocuous expression
    - operators:
        - deep comparison (`===` and `=!=`)
        - membership (`?>` and `!>`)
    - calls:
        - `f \{}` and `f @clk`
- Modifications:
    - `if x \{...}` to `if x => \{...}`
    - `every e \{...}` to `every v in e {...}`
- Removals:
    - vectors (`#{...}`)
- Bug fixes:
    - task abortion

v0.2 (aug/25)
---------------

- (no history)
