# Index / Table / Block Sigil Migration

## 1. Context

This plan covers the three non-clock moves of the sigil remap. It
depends on `06-06-clock.md`, which frees `@` by moving clocks to
unit-suffixed literals.

| Concept | Before    | After     | Freed because…                       |
| ------- | --------- | --------- | ------------------------------------ |
| table   | `@{…}`    | `[…]`     | `[ ]` freed by moving index to `@`   |
| block   | `{…}`     | `{…}`     | now mono-purpose → `if f {` is clear |
| index   | `t[…]`    | `t@(…)`   | `@` freed by moving clock off it     |
| clock   | `@5.100`  | `5s` etc  | see `06-06-clock.md`                 |

Every sigil ends up meaning exactly one thing.

## 2. The Ambiguity Being Removed

The original reason for `@{ }` (`doc/manual.md:356-360`) is that `{ }`
served double duty as both block and table, and Atmos control flow takes
unparenthesized conditions:

```
if f { ... }   ;; if f{...}  (call f with a table)
               ;; or  if (f) { ... }  (f is the condition, {…} the body)
```

Moving tables to `[ ]` makes `{ }` mono-purpose. Then `{` after an
expression is always a block, and the ambiguity disappears at the root —
no sigil, no whitespace trick, no parenthesized conditions needed.

```
if f { ... }     ;; unambiguous: condition f, then block
val x = { ... }  ;; do-block (its last value)
val v = [1,2,3]  ;; table literal
```

## 3. `@{}` → `[]` Tables

`[ ]`, freed from indexing (section 4), becomes the table/vector literal.

```
[1, 2, 3]          ;; vector   (was @{1,2,3})
[x = 1, y = 2]     ;; dict     (was @{x=1,y=2})
[1, x = 2]         ;; mixed    (positional + keyed)
[]                 ;; empty table
:Pos [x=1, y=2]    ;; tagged table (tag prefix unchanged)
```

Call-sugar (Lua's `f{…}`, today `f@{…}`) becomes `f[…]`, disambiguated
from a standalone literal by the existing adjacency rule (section 6):

```
f[1,2]     ;; call f([1,2])      — adjacent
f [1,2]    ;; f, then literal     — spaced
```

## 4. `t[]` → `t@(…)` Index

Indexing moves onto `@`. Field access by constant key stays `t.x`.

```
t.x          ;; literal field  (unchanged)
t@i          ;; computed index by variable
t@5          ;; computed index by literal
t@(i+1)      ;; computed index by expression
t@i@j        ;; chained: (t@i)@j
set t@k = v  ;; index assignment
```

`@` reads naturally as "at": `t@i` = "t at i" — a better mnemonic for
indexing than it ever was for clocks.

Trade-off accepted: field vs index stays split (`t.x` and `t@(e)`); only
OCaml's `t.(e)` would unify them, and we prefer `@` here for terseness on
the hot path (`t@5`, `t@i` need no parens).

## 5. Why `@` Works Now

`@`-indexing was previously impossible because `@5` lexes as a clock
literal (`lexer.lua:102-142`), so `t@5` meant "t juxtaposed with clock
@5". Once clocks move to unit-suffixed literals (`06-06-clock.md`), the
greedy `@`-clock branch is removed and `@` becomes a plain one-char
symbol that consumes nothing after it:

| Form      | Old result      | New result        |
| --------- | --------------- | ----------------- |
| `t@5`     | clock `@5`      | index by `5`      |
| `t@i`     | clock `@i`      | index by `i`      |
| `t@(i+1)` | "invalid clock" | index expression  |

This dependency is why the clock plan must land first.

## 6. Adjacency Rule (Reused, Not New)

Both new juxtapositions (`f[…]` call-sugar, `t@…` index) reuse the
existing adjacency check in `parser_2_suf` (`parser.lua:240`):

```lua
local ok = (not no) and is_prefix(e) and
            (TK0.sep==TK1.sep or TK1.str=='.' or TK1.str=='::')
```

A suffix is only taken when adjacency matches — the same mechanism that
already separates `f(x)` (call) from `f (x)` (separate parens). So:

| Code     | Parse                          |
| -------- | ------------------------------ |
| `t@i`    | index (adjacent)               |
| `t @i`   | `t`, then separate (spaced)    |
| `f[1,2]` | call (adjacent)                |
| `f [1,2]`| `f`, then literal (spaced)     |

No new disambiguation machinery is introduced.

## 7. Lexer / Parser / Coder Change Points

| File / place              | Change                                          |
| ------------------------- | ----------------------------------------------- |
| `lexer.lua:102-142`       | drop `@{`/`@clk` branch; `@` → plain symbol     |
| `lexer.lua` symbols       | add `@` one-char symbol; keep `[` `]`           |
| `parser.lua` prim         | `[…]` parses as table literal (was index only)  |
| `parser.lua:248-258`      | repoint `[` from index suffix to literal/call   |
| `parser.lua:234-284`      | add `@(…)` / `@id` index suffix in `2_suf`      |
| `prim.lua` call-arg       | add `[` to `check_call_arg` (`parser.lua:229`)  |
| `coder.lua`               | emit `[…]` as Lua table; emit `@` as index      |
| `tosource.lua`            | print `[…]` tables and `t@(…)` indexing         |

## 8. Edge Cases

| Case        | Behavior                                              |
| ----------- | ---------------------------------------------------- |
| `t@{…}`     | index t by a block's value — legal, odd, unambiguous |
| `f\n[…]`    | glue hazard — pre-existing, same as `f\n(…)` today   |
| `[k=v]`     | dict key syntax shares `[` with vectors (like today) |
| `set t@k=v` | index assignment via `@` instead of `[`              |

## 9. Migration & Open Questions

Migration touches every `.atm` file using `@{`, `t[…]`, or `@clk`. The
two plans should be sequenced: clock first (frees `@`), then this one.

Open questions:

- Dict literal: keep `[k=v]`, or require a marker to separate dicts from
  vectors visually?
- Index assignment: confirm `set t@k = v` (vs a dedicated form).
- Keep `t.x` field sugar, or fold everything into `t@("x")`?
- Should `[ ]` empty literal default to vector or generic table?

## Status

Phase order: index (this) -> table `@{}`->`[]` -> block `{}` mono-purpose.

- [DONE] index `t@(…)` PARSING (src + lexer test; full suite PASSES):
    - `src/lexer.lua` : bare `@` emits a `@` sym (was error); `@{` unchanged.
    - `src/parser.lua` : `parser_2_suf` gains `@` index suffix — `@(e)` (full
      expr in parens) / `@prim` (single primary). Same `{tag='index'}` node, so
      `coder.lua` is unchanged; chaining `t@i@j` and `set t@k=v` fall out free.
    - `tst/lexer.lua` : `@` now lexes to a token (was the error assertion).
    - Decision: `[` indexing KEPT (transitional — both `t[i]` and `t@i` work).
- [DEFERRED] `tosource` printing the `@` form. `src/tosource.lua` was reverted
  to the `t[…]` form, so `@`-indexing round-trips as `t[…]` for now (no tosource
  test churn). Revisit when migrating call sites / printing canonical `@`.
  (The earlier expr/stmt tosource test edits were reverted accordingly.)
- [TODO] migrate `t[…]` -> `t@(…)` call sites in `src/`, `tst/`, `doc/`.
- [TODO] table `@{}` -> `[]` (needs `[` freed: remove `[` index first).
- [TODO] block `{}` mono-purpose (falls out of the table move).

Correction (affects §6; revisit at the TABLE phase — do not rely on §6 as
written): `sep` counts only `;` and `\n` (`lexer.lua:15-20`), NOT spaces. The
suffix-adjacency gate (`parser.lua` `TK0.sep==TK1.sep`) therefore treats `t@i`,
`t @ i`, and `f[…]` vs `f […]` identically — only a `;`/newline separates, never
whitespace. §6's "spacing disambiguates" premise is wrong; the table phase needs
a real disambiguator for `f[…]` call-sugar vs `[…]` literal. Harmless for index
(suffix-only, no competing meaning).
