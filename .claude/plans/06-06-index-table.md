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
[x = 1, y = 2]     ;; dict, string keys      (was @{x=1,y=2})
[@(k) = v]         ;; computed key, mirrors t@(k)   (was @{[k]=v})
[@5 = v]           ;; key by literal/var, mirrors t@5
[1, x = 2]         ;; mixed    (positional + keyed)
[]                 ;; empty table
[ [1,2], [] ]      ;; nested tables, positional (no key collision)
:Pos [x=1, y=2]    ;; tagged table (tag prefix unchanged)
```

Computed keys move onto `@` (like indexing, §4), so a `[` INSIDE a table is
ALWAYS a nested table, never a key — the dict-key/nested ambiguity is gone.
`[@(k)=v]` mirrors `set t@(k)=v` exactly.

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

## 6. Call-Sugar vs Literal — by Position (Not Spacing)

`[…]` inherits `@{…}`'s existing rule EXACTLY: a table LITERAL in prim
position, CALL-SUGAR in suffix position. The split is by position, never
by whitespace (`sep` counts only `;`/newline, `lexer.lua:15-20`):

| Code      | Parse                              |
| --------- | ---------------------------------- |
| `x = [1]` | literal (prim)                     |
| `f[1]`    | call `f([1])` (suffix call-sugar)  |
| `f [1]`   | also `f([1])` — spaces are ignored |

Identical to today's `@{…}` (`f@{}` calls, `x=@{}` is a literal), so
`@{`->`[` PRESERVES behavior with NO new disambiguation. Two adjacent
expressions still require a `;`/newline (sequence rule), so `f` then a
separate `[…]` literal on one line is a sequence error regardless —
exactly as with `@{` today. (`t[1]` = renamed `t@{1}` = `t([1])`, a call,
not an index — indexing is on `@`.)

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
      (next/append) — see `done/06-09-ppp.md`. The earlier operandless-`#`-in-parens
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
  `done/06-09-ppp.md` (implemented, tests pass).
- [DONE] table `@{}` -> `[]` — FULL SUITE GREEN (user-confirmed). Done layer
  by layer (each layer's own test green, downstream red until reached):
    - [DONE] LEXER: `src/lexer.lua` drops the `@{` combiner; `@` folded into
      `SYMS` (`src/global.lua`). `tst/lexer.lua` updated. (`[`/`]` already syms.)
    - [DONE] PARSER: `[…]` is the table literal in `prim.lua`; computed keys
      use `@(k)=v` (mirrors index §4) so `[` inside is ALWAYS a nested table —
      no dict-key ambiguity. `check_call_arg` uses `[` (`f[…]` call-sugar).
      `tosource` prints `[…]` with bare `@k=v` for number/identifier keys and
      parens `@(k)=v` for tag/string/expr (matches index §4). `tst/expr.lua` + `tst/stmt.lua`
      migrated (source + tosource expecteds; `X.tostring` AST dumps untouched).
      EXPECTED: lexer/expr/stmt GREEN; exec/tasks/streams/await/thread RED.
    - [DONE] CODER/EXEC layer: `coder.lua`/`run.lua` NO change (table node
      unchanged -> identical Lua -> identical runtime). Migrated Atmos SOURCE
      `@{`->`[` (+ computed keys `[k]=`->`@(k)=`) in `exec`/`tasks`/`streams`/
      `await`/`thread` + `guide.atm` via a stack-based converter (handles
      nesting, func-block braces, pools). X.print OUTPUT assertions kept as
      `@{…}` (option A — `x.lua` renderer lives in lua-atmos, not migrated).
      tosource-expecteds (streams) -> `[…]`. Nested `@{@{}}`->`[[]]` forced
      some `local src = [[…]]` to bump to `[=[…]=]` (Lua long-string clash).
      Pools `[ts]`/`emit[t]` were later re-spelled to the `@`-qualifier (DONE,
      see §1 below) — `spawn @ts` / `emit @(:t)`.
    - [DONE] doc/: `manual.md` structural (nav, symbols `[ ]`/`@`, Lua-subtlety
      rationale, Table grammar `[ Key_Val* ]` with `@(k)=v` keys, User Types) +
      all code-fence examples; `exs/*.atm` + `guide.md` via converter. Prose
      inline `@{` hand-fixed (6). `manual-out.md` left to the doc build.
      CAVEAT: output-illustration comments (`;; --> [1, 2, 30]`, `xprint`
      results in exs) now show `[…]` but `X.print` still prints `@{…}` until the
      lua-atmos `x.lua` fix above — forward-looking, accurate once that lands.
    - [TODO] FIX `@{…}` OUTPUTS (downstream/cross-repo): runtime table dumps
      still print `@{…}` because `X.print`'s renderer lives in lua-atmos
      (`atmos/x.lua`), NOT in this worktree. Once that renderer moves to `[…]`
      (+ keys `@(k)=v`):
        - lua-atmos `x.lua`: table render `@{`->`[`, `}`->`]`, keys to `@(k)=`.
        - here: flip the kept-as-`@{…}` OUTPUT assertions to `[…]` —
          `tst/exec.lua` (~16) + `tst/tasks.lua` (`@{20}`/`@{30=30}` etc, the
          `assertx(trim(out), [[…]])` blocks). These were LEFT as `@{…}` under
          option A; grep `assertx(out|trim(out)` for `@{`.
      Until then `@{…}` in those output strings is INTENTIONAL, not a miss.
- [TODO] block `{}` mono-purpose (falls out of the table move).

Note (§6 fact): `sep` counts only `;` and `\n` (`lexer.lua:15-20`), NOT spaces,
so `t@i`/`t @ i` and `f[…]`/`f […]` parse identically. This needs NO
disambiguator: call-sugar vs literal is decided by POSITION (suffix vs prim),
exactly as `@{…}` already is — `@{`->`[` is a behavior-preserving rename. (An
earlier draft wrongly called for a "real disambiguator"; there is none to add.)

## Next Steps (resume here)

DONE so far: index moved to `@` (sole index sigil), `[` index REMOVED from the
parser, all `tst/` + `doc/` migrated, ppp via `t@#` / `t@+` implemented
(`done/06-09-ppp.md`). Suite GREEN. The `@`-index tip logic is fully local in
`parser_2_suf`'s `@` branch (no global; `parser_4_pre` untouched).

The ONE remaining move in this plan: table `@{}` -> `[]` (then block `{}`
becomes mono-purpose for free). It is now unblocked (`[` is free at the suffix
level). Steps, in order:

1. [RESOLVED] No §6 blocker — `@{`->`[` is a behavior-preserving RENAME.
   Call-sugar vs literal is positional (suffix vs prim), exactly as `@{…}`
   already is (see §6); there is NOTHING to disambiguate. So:
   - call-sugar KEPT: `f[…]` = renamed `f@{…}` (add `[` to `check_call_arg`).
   - literal KEPT: `x = [...]` = renamed `x = @{...}`.
   The two OTHER current `[` users:
   - dict computed-keys `@{[k]=v}` -> become `[@(k)=v]` (keys move onto `@`,
     mirroring index §4). So `[` inside a table is ALWAYS a nested table —
     the dict-key/nested ambiguity is dissolved, no lookahead needed. String
     keys stay `[x=v]`. [RESOLVED]
   - pools / emit-target `[ts]` / `emit[t]` / `spawn [ts]` -> [DONE, IMPLEMENTED]
     re-spelled with the `@`-qualifier — SAME micro-syntax as index & table
     keys (`@(e)` parens, bare `@num`/`@id`). Supersedes option D (`in …,`).

     ```
     spawn @ts T()            ;; pool          (was spawn [ts] T())
     spawn @(e) T()           ;; pool, expr
     spawn @ts { ... }        ;; pool + block task
     emit  @(:global) (:e)    ;; target scope  (was emit [:global] (:e))
     emit  @t (:e)            ;; target task
     emit  @(nil) (:e)        ;; keyword target needs parens

     spawn T()  /  emit (:e)  ;; no qualifier — unchanged
     ```

     - `@` now unifies ALL four sites: index `t@i`/`t@(e)`, table key
       `[@i=v]`/`[@(e)=v]`, pool `spawn @ts`, target `emit @(:t)`. Bare for
       num/id; parens for tag/`nil`/`false`/expr (the `check num or check_err
       id` guard, identical to the table-key branch).
     - Self-delimiting: `@<prim>` / `@(e)` is one unit, so the payload follows
       with no comma and no keyword. `src/prim.lua` spawn (~25) + emit (~154).
     - Why over option D `in …,`: terser, no comma, no `in` keyword reuse, one
       micro-syntax across all `@` sites. (`in …,` cost: comma wart + reused
       keyword; the `@` "at pool/target" reading is a slight semantic stretch
       but the consistency wins.)
     - DONE: parser (`prim.lua`), all `tst/` call sites (114), unified via
       `parser_at(ret)` (one `@`-helper for index/key/pool/target), clearer
       error ("expected name, number, or '('"). Suite GREEN.
     - DONE: docs — SYNTAX grammar (Spawn/Emit rules + the two inline rules:
       `[`@´ (`(´Expr`)´|NUM|ID)]`), Task-Ops examples, `exs/` (exp-25-spawn,
       exp-27-emit, exp-11-length/concatenation, val-07-tasks) + `guide.md`.
     - [TODO] DOC CLEANUP: the `@`-qualifier `(`(´Expr`)´|NUM|ID)` is now
       inlined in 4+ grammar spots (Index, Table `Key_Val`, Spawn, Emit, both
       in their sections and in the big SYNTAX block). Verify if manual.md can
       define it ONCE as a shared production `At` and reference it everywhere —
       mirroring the parser's `parser_at` unification. (Index also adds the
       tip `#`/`+`; check the SYNTAX block's flat `Expr : …` style allows a
       named sub-production cleanly, like `Key_Val`/`Case` already do.)

2. lexer (`src/lexer.lua`): drop the `@{` token; make `[` / `]` plain symbols.

3. parser: `[…]` parses as the table/vector literal (replaces today's `@{…}`
   constructor in `prim.lua`); dict-keys + tag-prefix `:Pos [..]` per §3.
   Re-spell pools per the §1 decision (`@`-qualifier). Add `[` to
   `check_call_arg` (keeps `f[…]` call-sugar = renamed `f@{…}`).

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
