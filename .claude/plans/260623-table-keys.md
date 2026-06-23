# Plan: accept keywords as table keys

## Goal

Allow reserved words to appear as member names / table keys, so the
parser accepts `S.on`, `pico.set`, etc., instead of forcing the ugly
`S@('on')` index or an alias like `S.zon`.

The relaxation is enabled ONLY in name-only positions (right after
`.` / `::`, and as a literal key before `=`). A bare keyword used as
a variable or primary stays illegal.

## Motivation (consuming refactors)

Two public APIs currently collide with reserved words:

- `S.on` (streams): `on` is reserved (`loop on`, `toggle on`).
    - Temporarily aliased as `S.zon` (run.lua + call sites).
    - After this plan: drop the alias, restore `S.on`.
- `pico.set` (pico-lua): `set` is reserved (`set x = ...`).
    - After this plan: write `pico.set(...)` directly.

## Why it is safe (no ambiguity)

After an explicit `.` / `::` the grammar admits ONLY a name; no other
production competes.
A bare keyword with no leading `.` never continues a suffix (the
suffix gate is `same-sep | @ | . | ::`), so statement-leading
keywords (`loop`, `if`, ...) are unaffected.

Coverage is clean: all 30 hard keywords lex as `tag='key'`; the
contextual await words (`or and not any all until while`) are NOT in
`KEYS`, so they already lex as `id` and work as fields today.
Operators are symbolic, never alphabetic.
So a single `key`-accepting helper covers exactly the reserved set.

## Mechanism

Add a helper that accepts an `id` OR a `key` token as a name:

    local function accept_name ()
        local tk = check(nil,'id') or check_err(nil,'key')
        lexer_next()
        return tk
    end

Use it at every name-only site (read, method, def, literal key).

## Sites

| file            | line(s)  | place                  | today      |
|-----------------|----------|------------------------|------------|
| src/parser.lua  | 304      | `.id` read index       | id only    |
| src/parser.lua  | 310      | `::m` method call      | id only    |
| src/parser.lua  | 254      | `@id` index (optional) | id / num   |
| src/prim.lua    | 265, 268 | `func M.f` / `o::f` def | id only    |
| src/prim.lua    | 111      | table literal `[k=v]`  | acc (=id)  |

Apply all sites for consistency: patching only the read side lets you
read `S.on` but neither define `func S.on()` nor build `[on=1]`.

The table-literal key (prim.lua:111) needs its own branch: today only
a bare `acc` (identifier) followed by `=` becomes a key, and a keyword
is not an `acc`. The computed-key form `@('on')=v` is the existing
escape hatch and stays valid.

## Subtleties (none are ambiguities)

- `.` continues across separators (gate includes `TK1.str=='.'`), so
  `obj` newline `.on(...)` indexes -- already true for `.field`,
  keywords just inherit it.
- AST model: `.id` is stored as a `:id` tag node (same shape as event
  `:on`), so a keyword field and an event tag are indistinguishable at
  AST level -- already true for ordinary fields.
- `tosource.lua` emits `.id` from the tag node as a plain string;
  verify it round-trips keyword names without requoting.
- Strategic cost: `.kw` / `::kw` is permanently reserved for indexing,
  foreclosing any future postfix-keyword syntax (e.g. `expr.match {}`).
  `where` is already postfix but triggered by `expr where {}`, not
  `.where`, so no current conflict.
- Readability: `x.loop`, `t.do`, `e.if` read as control flow to a
  human; it is opt-in by the API author (`S.on` is the good case).

## Steps

1. [DONE] Helper `accept_field` in parser.lua (after `accept_err`):
   accepts `id`/`key`, but reports a missing `<id>` on error via
   `check_err(nil,'id')`.
2. [DONE] parser.lua: `.id` (304) and `::m` (310) use `accept_field`.
3. [SKIP] `@id` index relax -- left id/num only.
4. [DONE] prim.lua: `func M.f` / `o::f` def names (265, 268).
5. [WON'T DO] keyword-key branch in `[k=v]`. Ambiguous: a table
   literal has no leading `.`, so a leading keyword may be a key
   (`[on=v]`) or the start of a value (`[false]`, `[await x]`,
   `[spawn T()]`). The lexer has no 2-token lookahead to peek the
   `=`. Keyword keys keep using the `@(:on)=v` escape hatch.
6. [DONE] tosource.lua: confirmed -- no change needed. Keyword fields
   emit via the existing computed-key form (`S@(:on)`, `o::on`,
   `@(:on)=v`), so they round-trip like ordinary fields.

## Follow-up refactors (after this plan)

- Revert the `S.zon` hack: remove the run.lua alias and rename all
  `S.zon(` call sites back to `S.on(` (tst/streams.lua, tst/guide.atm,
  exs/rx.atm, exs/rx-behavior.atm, exs/clicks.atm, doc/guide.md).
- pico-lua: use `pico.set` (and any other keyword-named members)
  directly.
