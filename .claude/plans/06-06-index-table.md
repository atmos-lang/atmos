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
- [DONE] `tosource` prints the `@` form. `src/tosource.lua` index case ->
  `tosource(e.t)..'@('..tosource(e.idx)..')'` (uniform: computed, string, AND
  tag/field all render `t@(idx)`; `.x` is input-only sugar now).
- [DONE] test suite converted to the `@(…)` expected results; FULL SUITE PASSES.
    - `tst/expr.lua` : `x@(:a)`, `x@(1)()@(:a)`, `(-x@(0))`.
    - `tst/stmt.lua` : `set M@("f")`, `set M@("o")@("f")`, `set x, t@(1) = …`.
    - `tst/lexer.lua` : `@` lexes to a token.
    - `tst/exec.lua` (+ runtime tests) : unaffected — execution via `coder`
      (unchanged); only 1 non-index `tosource` use.
- [DONE] migrate `t[…]` -> `t@…` call sites in `tst/`, and REMOVE `[` index.
  (`src/` is the compiler in Lua -> NOT migrated.) Conventions settled:
    - Programmer source: bare `t@i` / `t@1` for ident/number, parens
      `t@(:x)` / `t@("f")` / `t@(#t+1)` for tag/string/expression. Mix of
      bare/parens for coverage. `tosource` UNCHANGED (always `t@(…)`).
    - Tip indexing is now two bare markers only — `t@#` (last) and `t@+`
      (next/append) — see `06-09-ppp.md`. The earlier operandless-`#`-in-parens
      distinction (`t@(#+1)` tip vs `t@(#t+1)` explicit) was DROPPED; `#`
      inside `@(…)` is always the ordinary length operator now.
    - [DONE] all `tst/`: expr, stmt, exec, streams, guide.atm, tasks, +
      missed `(@{1})[@{}]` (the `@{`-on-line blind spot of the sweep greps).
    - [DONE] `src/parser.lua`: the `accept('[')` index branch REMOVED. `[`
      now only serves `@{[k]=v}` dict-keys and `[ts]`/`emit[t]` pools.
      Suite GREEN.
    - [DONE] `doc/`: `exp-12`/`val-02`/`val-03`/`exp-08`/`03-tags`/`exp-28`
      exs; manual `## Indexing` grammar (`[`->`@`) + prose (`t.x` -> `t@("x")`)
      + all inline examples + precedence-list `t[]` + nav; `guide.md`. TOC
      regenerates clean. (`manual-out.md` left to the doc build.)
- ppp accessors: replaced by tip indexing `t@#` (last) / `t@+` (append) — see
  `06-09-ppp.md` (implemented, tests pass).
- [TODO] table `@{}` -> `[]` (now unblocked: `[` is freed at the suffix
  level; still used by dict-keys/pools, to be reworked in this move).
- [TODO] block `{}` mono-purpose (falls out of the table move).

Correction (affects §6; revisit at the TABLE phase — do not rely on §6 as
written): `sep` counts only `;` and `\n` (`lexer.lua:15-20`), NOT spaces. The
suffix-adjacency gate (`parser.lua` `TK0.sep==TK1.sep`) therefore treats `t@i`,
`t @ i`, and `f[…]` vs `f […]` identically — only a `;`/newline separates, never
whitespace. §6's "spacing disambiguates" premise is wrong; the table phase needs
a real disambiguator for `f[…]` call-sugar vs `[…]` literal. Harmless for index
(suffix-only, no competing meaning).

## Next Steps (resume here)

DONE so far: index moved to `@` (sole index sigil), `[` index REMOVED from the
parser, all `tst/` + `doc/` migrated, ppp via `t@#` / `t@+` implemented
(`06-09-ppp.md`). Suite GREEN. The `@`-index tip logic is fully local in
`parser_2_suf`'s `@` branch (no global; `parser_4_pre` untouched).

The ONE remaining move in this plan: table `@{}` -> `[]` (then block `{}`
becomes mono-purpose for free). It is now unblocked (`[` is free at the suffix
level). Steps, in order:

1. DECIDE the §6 blocker FIRST (design, no code): `f[…]` call-sugar vs a
   standalone `[…]` literal cannot be told apart by whitespace (`sep` ignores
   spaces). Options to pick from:
   a. drop `f[…]` call-sugar entirely (require `f([…])`); `[…]` is always a
      literal. Simplest, recommended.
   b. keep call-sugar via the adjacency gate (`TK0.sep==TK1.sep`) — but that
      only separates by `;`/newline, so `f [x]` (spaced) is still a call. Ugly.
   Also decide what happens to the two OTHER current `[` users:
   - dict-keys `@{[k]=v}` -> become `[k=v]` / `[[k]=v]` inside the new `[…]`
     table literal (see plan §3 `[x=1, y=2]`).
   - pools `[ts]` / `emit[t]` / `spawn [ts]` -> need a new spelling (the `[`
     is taken by literals). Pick one (e.g. keep `[ts]` as a special prefix, or
     move pools to another marker). THIS IS THE MAIN OPEN QUESTION.

2. lexer (`src/lexer.lua`): drop the `@{` token; make `[` / `]` plain symbols.

3. parser: `[…]` parses as the table/vector literal (replaces today's `@{…}`
   constructor in `prim.lua`); dict-keys + tag-prefix `:Pos [..]` per §3.
   Re-spell pools per the §1 decision. Add `[` to `check_call_arg` only if
   keeping call-sugar (option 1b).

4. coder (`src/coder.lua`): table constructor already emits plain Lua `{…}`
   (the `atm_table` wrapper was removed), so likely just the `[…]` parse maps
   to the same table node — minimal coder change.

5. tosource (`src/tosource.lua`): print tables as `[…]` (was `@{…}`).

6. MASS-migrate `@{…}` -> `[…]` across `src/`? NO (src is Lua). Across `tst/`
   and ALL `doc/` (manual, exs, guide) — big sweep. Watch the same blind spot:
   greps that exclude `@{`/`[` lines miss nested cases.

7. block `{}` mono-purpose: once tables leave `{}`, `{` after an expr is always
   a block; remove any block-vs-table disambiguation still in the parser.

Environment / how to run (cross-machine):
- Tests load `atmos.lang` from the INSTALLED tree, NOT `src/`. After editing
  `src/`, sync: `cp src/*.lua /x/lua-atmos/atmos/atmos/lang/` then
  `cd tst && lua5.4 all.lua`.
- Edit `doc/manual.md`, never `doc/manual-out.md` (auto-generated via
  `cd doc && lua5.4 manual.lua manual.md > manual-out.md`; leave regen to the
  doc build — do not commit/edit it by hand).
- `[` currently still serves dict-keys `@{[k]=v}` and pools `[ts]`/`emit[t]`;
  those are SEPARATE parsers from the (removed) index suffix.
