# Plan: Operators as Functions (Issue #19)

## Overview

Support lambda syntax that treats operators as first-class functions.
The syntax `\op` (e.g., `\+`) creates a function wrapping the operator,
allowing operators to be passed as arguments to higher-order functions.

## Examples

```
f(\+, 10, 20)        ;; pass operator as argument
val add = \+         ;; add(3, 5) ==> 8
(\*)(2, 3)           ;; ==> 6 (parens required for direct call)
(\!)(true)           ;; ==> false
(\#)(@{1,2,3})       ;; ==> 3
```

## Semantics

- `\op` where `op` is a **binary** operator produces:
  `func (a, b) { a op b }`
- `\op` where `op` is a **unary-only** operator produces:
  `func (a) { op a }`
- When an operator is both unary and binary (e.g., `-`),
  binary takes precedence.
- Like all lambdas in Atmos, `\op` must be wrapped in parentheses
  for direct call: `(\+)(1, 2)`. Passing as argument works without
  parens: `f(\+, 1, 2)`.

## Supported Operators

### Binary (2 parameters)

`==` `!=` `===` `=!=` `??` `!?`
`+` `-` `*` `/` `//` `%`
`>` `<` `>=` `<=`
`||` `&&`
`++`
`?>` `!>`

### Unary (1 parameter)

`#` `!`

Note: `-` is both unary and binary; `\-` produces the binary version.
Use `\(a){-a}` for the unary minus function.

## Implementation

### File: `src/parser.lua` (function `parser_lambda`, ~line 121)

**Change:** After accepting `\`, check if the next token is an operator.
If so, generate a synthetic `func` AST node wrapping the operator
expression instead of requiring a block `{...}`.

- Binary operators: AST with 2 params (`a`, `b`) and a `bin` node body.
- Unary operators: AST with 1 param (`a`) and a `uno` node body.
- No changes needed in lexer, coder, or runtime (reuses existing AST
  node types).

### File: `tst/expr.lua` (after lambda tests, ~line 805)

**Change:** Add parser tests verifying that `\+`, `\===`, `\#`, `\!`
produce the correct AST (using `tosource`).

### File: `tst/exec.lua`

**Change:** Add execution tests verifying that operator functions work
correctly at runtime (e.g., `(\+)(10, 20)` prints `30`).

## Status

- [x] Plan created
- [x] Implement parser change in `src/parser.lua`
- [x] Add parser tests in `tst/expr.lua`
- [x] Add execution tests in `tst/exec.lua`
