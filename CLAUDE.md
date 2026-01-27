# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

**Run all tests:**
```bash
cd tst && lua5.4 all.lua
```

**Run a single test file:**
```bash
cd tst && lua5.4 lexer.lua    # or expr.lua, stmt.lua, exec.lua, tasks.lua, cmd.lua, streams.lua
```

**Run with dependencies (CI environment):**
```bash
cd tst && LUA_PATH="../f-streams/?/init.lua;../lua-atmos/?.lua;../lua-atmos/?/init.lua;;" lua5.4 all.lua
```

**Run the compiler:**
```bash
./atmos <file.atm>
```

## Architecture

Atmos is a source-to-source compiler that transforms Atmos (.atm) to Lua. It depends on [lua-atmos](https://github.com/lua-atmos/atmos/) for runtime task/event scheduling.

**Compilation pipeline:**
```
Atmos Source → [lexer] → [parser] → [coder] → Lua Source → [lua-atmos runtime]
```

**Source files (`src/`):**
- `lexer.lua` - Tokenization (symbols, operators, keywords, strings, clocks, tags, natives)
- `parser.lua` - Recursive descent parser with 7 precedence levels (`parser_1_prim` → `parser_7_out`)
- `coder.lua` - AST-to-Lua code generation
- `exec.lua` - Pipeline orchestration
- `run.lua` - Runtime support (tasks, pins, loops, exceptions)
- `prim.lua` - Primitive parsers and statement parsing (spawn/emit/await)
- `global.lua` - Global state and keyword/operator definitions
- `aux.lua` - Utility functions
- `tosource.lua` - AST pretty-printer for debugging

**Global state variables:**
- `FILE`, `LEX` - Source file and lexer state
- `TK0`, `TK1` - Previous and current tokens
- `LIN`, `SEP` - Line tracking
- `_n_`, `_l_` - Counter and line number for Lua output

**AST nodes** use `tag` field for type identification: `acc`, `nat`, `clk`, `index`, `table`, `uno`, `bin`, `call`, `func`, `dcl`, `set`, `do`, `defer`, `ifs`, `loop`, `catch`, `block`, `stmts`, etc.

## Language Syntax Quick Reference

- Blocks: `{ ... }`
- Clocks: `@5` (5 sec), `@1:30.500` (1 min 30.5 sec)
- Tags (events): `:EventName`, `:a:b:c`
- Native Lua: `` `lua_code` ``
- Declarations: `val x = ...`, `var x = ...`, `pin t = ...`
- String concat: `++`
- Deep equality: `===`, `=!=`
- Membership: `?>`, `!>`

## Code Style

- 4-space indentation
- 80-column lines
- Comments before blocks, not inline
- Function prefixes: `parser_*`, `coder_*`, `lexer_*`, `atm_*`, `tosource_*`
