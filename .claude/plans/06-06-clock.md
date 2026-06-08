# Clock / Duration Redesign

## 1. Context

This plan is part of a larger sigil remap that makes every delimiter
mono-purpose and resolves the original block-vs-table ambiguity that
forced `@{ }` in the first place.

| Concept | Before    | After     | Freed because…                       |
| ------- | --------- | --------- | ------------------------------------ |
| table   | `@{…}`    | `[…]`     | `[ ]` freed by moving index to `@`   |
| block   | `{…}`     | `{…}`     | now mono-purpose → `if f {` is clear |
| index   | `t[…]`    | `t@(…)`   | `@` freed by moving clock off it     |
| clock   | `@5.100`  | units     | `@` no longer needed for clocks      |

The clock change is the keystone: `@`-indexing was only ever blocked by
clock literals (`@5` lexes as a clock), so moving clocks off `@`
unblocks `t@i` / `t@(i+1)`.

## 2. Problems With the Current `@h:m:s.ms`

Current format (`src/lexer.lua:102-142`) is a positional stopwatch
string `@[h:][min:]s[.ms]` where `.ms` is a literal millisecond count,
not a fraction.

| Source     | Means         | Reads like | Issue                         |
| ---------- | ------------- | ---------- | ----------------------------- |
| `@5`       | 5 s           | 5 of what? | unit is positional            |
| `@5.100`   | 5 s + 100 ms  | 5.1 s      | ok only by luck (3 digits)    |
| `@5.5`     | 5 s + 5 ms    | 5.5 s      | trailing zeros are meaningful |
| `@5.50`    | 5 s + 50 ms   | 5.5 s      | `.5` is 5 ms, not half a sec  |
| `@100`     | 100 s         | 100 ms?    | no `ms` form without `@.100`  |

Three structural defects, independent of the sigil:

1. Unit is positional — you count colons to know what `@30` means.
2. `.ms` is integer-magnitude, not fractional — `.5` = 5 ms,
   `.500` = 500 ms; trailing zeros carry meaning.
3. No range — hours is the ceiling, no day/week, no sub-ms floor.

## 3. Proposal A — Unit-Suffixed (Recommended)

Go-style suffixes, compound, descending, with real decimal fractions.

```
5s            ;; 5 seconds
300ms         ;; 300 milliseconds
1.5h          ;; 90 minutes (real fraction, no footgun)
2h30min       ;; compound, descending order
1h30min500ms  ;; chains freely
```

- Lexical rule: `(digits[.digits] unit)+`, units adjacent (no space),
  summed left to right.
- Fractions are real: `1.5h` = 90 min, `5.5s` = 5500 ms.
- Self-documenting, composable, extensible (add units later).

## 4. Options B / C

### Option B — Keep Colon, Fix the Fraction

```
$1:30      ;; 1 min 30 s
$1:30:00   ;; 1 h 30 min
$5.5       ;; 5.5 s (decimal = real fraction now)
```

Minimal change, but keeps positional load (`$30` = 30 what?) and still
has no days. Only a half-fix.

### Option C — Single-Unit Literals + Operator Compose

```
5s + 300ms   ;; explicit composition
1h + 30min
```

Simplest lexer (just `number+unit`), composition reuses Atmos `+`.
Cost: `2h30min` becomes `2h + 30min`.

### Comparison

| Axis           | A unit-suffix | B colon     | C single+op |
| -------------- | ------------- | ----------- | ----------- |
| readable unit  | explicit      | positional  | explicit    |
| fraction sane  | `1.5h`        | fixed       | yes         |
| compound       | `2h30min`     | `1:30`      | via `+`     |
| sigil needed   | optional      | yes         | optional    |
| lexer effort   | medium        | low         | lowest      |
| extensible     | yes           | no          | yes         |

## 5. Unit Alphabet Constraint

Lua number syntax reserves letters, and the Atmos number lexer reads
them greedily (see section 8). A unit must avoid any letter that is part
of number syntax, or it gets swallowed.

| Letters       | Role in numbers      | Usable as unit?           |
| ------------- | -------------------- | ------------------------- |
| `e` `E`       | decimal exponent     | no — `5e3` = 5000         |
| `x` `X`       | hex prefix `0x`      | no — ambiguous            |
| `p` `P`       | hex-float exponent   | no                        |
| `a b c d f`   | hex digits           | risky — `0xd` = 13        |

Proposed set:

| Unit  | Safe? | Note                              |
| ----- | ----- | --------------------------------- |
| `ms`  | yes   |                                   |
| `s`   | yes   |                                   |
| `min` | yes   | `m` spelled out to avoid clashes  |
| `h`   | yes   | `h` > `f`, not a hex digit        |
| `d`   | no    | hex digit — use `day` instead     |

Decision: units = `ms s min h day` (avoid bare `m`, drop `d`).

### Name Length — As Short As Is Unambiguous

Keep unit names short; spell out only where a single letter is
ambiguous or collides. Common units stay terse for the hot path
(`await 5s`), rare units get a few cheap extra chars.

| Unit   | Form  | Why this length                  |
| ------ | ----- | -------------------------------- |
| milli  | `ms`  | bare `m` clashes (minute/meter)  |
| second | `s`   | safe, conventional               |
| minute | `min` | `m` ambiguous → spell it         |
| hour   | `h`   | safe (`h` > hex `f`)             |
| day    | `day` | `d` is a hex digit → spell it    |

Long names (`seconds`, `sec`, `hours`) are rejected for v1:

- Verbose on the hot path — `await 5seconds` vs `await 5s`.
- Plurals get messy — `1second` vs `2seconds`.
- They tend to contain `e`, which the number lexer treats as an
  exponent (`lexer.lua:210`, `[PpEe]`): `5sec` greedy-reads as if `e`
  starts an exponent. Short `e`-free names sidestep this entirely.

A long alias can be added later non-breakingly; default stays short.

## 6. Value Type — Normalize to Integer Milliseconds

Today a clock is roughly `@{h,min,s,ms}` (a table). Normalize instead to
a plain integer count of milliseconds.

- `5s` → `5000`, `300ms` → `300`, so `5s + 300ms` → `5300` via `+`.
- `await 5s` and `await 5000` become the same thing — one fewer concept.
- Cost: lose the structured `{h,min,…}` breakdown (rarely read).

This decision also enables variable durations (section 7).

## 7. Variables — Use `x * 1unit`, Not `(x)h`

Unit-suffixed literals are a lexical feature: the unit is glued to a
number token at lex time. A variable is not a number token, so:

- `xh`   → identifier `xh` (lexer reads `[%w_]` greedily).
- `(x)h` → `(x)` then identifier `h` — two separate things.

Making `(x)h` mean "x hours" would require units to be postfix operators
on any expression, which collides with identifiers (`h`, `s` could not
be variable names; `xh` vs `x h` turns whitespace-sensitive). Rejected.

Because units normalize to numbers (section 6), variable durations are
just multiplication — no new syntax, no reserved identifiers:

```
5h            ;; literal  → lexical unit suffix
x * 1h        ;; variable → 1h is 3600000, multiply
(x+1) * 1s    ;; any expression
```

This matches Go (`time.Duration(n) * time.Hour`).

| Need              | Syntax    | Mechanism                  |
| ----------------- | --------- | -------------------------- |
| literal duration  | `5h`      | lexical unit suffix        |
| variable duration | `x * 1h`  | arithmetic on ms number    |

## 8. Lexer / Parser Change Points

### Number lexer reads letters greedily (the blocker)

`src/lexer.lua:208-216`:

```lua
elseif match(c, "%d") then
    local num = read_while(c, M"[%w%.]")    -- grabs all alnum + dots
    if string.find(num, '[PpEe]') then
        num = read_while(num, M"[%w%.%-%+]")
    end
    if not tonumber(num) then
        err(..., "invalid number")
```

It consumes every `[%w.]` after the first digit, then validates with
`tonumber`. So `5s` currently lexes as the single token `"5s"` and fails
→ "invalid number". Lua's own lexer behaves the same (number touching a
letter is a malformed-number error).

Change: after reading the numeric part, peel a trailing known unit
(`ms|s|min|h|day`) into a duration token (or a chain of them); only the
remaining non-unit letters are an error.

### Other change points

| File / place               | Change                                       |
| -------------------------- | -------------------------------------------- |
| `lexer.lua:208-216`        | split unit suffix off the greedy number read |
| `lexer.lua:102-142`        | remove `@`-clock branch; `@` → plain symbol  |
| `lexer.lua` symbols        | add `@` as a one-char index symbol           |
| number → duration emit     | normalize unit chain to integer ms           |
| parser suffix (2_suf)      | add `@(…)` / `@id` index suffix              |
| coder                      | emit index access; emit ms integers          |

## 9. Sigil Decision

The only reason clocks needed `@` was to distinguish `@5` from the
number `5`. Explicit units do that for free — `5s` is self-evidently a
duration. So the sigil is optional:

- No sigil: `await 5s` — units self-delimit (recommended).
- Optional marker `$5s` if a visual cue is wanted.

Dropping the sigil leaves `@` cleanly available for indexing, completing
the remap in section 1.

## 10. Runtime Impact (lua-atmos)

Since a clock literal collapses to an integer number of milliseconds
(section 6), the `clock` runtime type disappears, and the change
propagates downstream to lua-atmos.

### Current coupling

```
Atmos  @5
  └─ coder.lua:67  →  clock { h=0, min=0, s=5, ms=0 }
                          └─ lua-atmos: first-class `clock` type
                                await(clock) = wait until it expires
```

`clock` is today a real value type (`doc/manual.md:531,637`): own
constructor, its own `?? :clock` test, and the scheduler dispatches on
it for timers. A bare `number` is not special.

### Required changes

| Concern         | Now                    | After                         |
| --------------- | ---------------------- | ----------------------------- |
| constructor     | `clock{…}`             | none — `5000` literal         |
| timer dispatch  | `await(clock)` expires | `await(number)` = relative ms |
| type test       | `x ?? :clock`          | `x ?? :number`                |
| value-type list | `…, clock`             | `clock` removed               |
| coder emit      | `clock{…}`             | summed ms integer             |

### Design note — the unused `await` slot

`await` currently accepts a clock, a condition-lambda, or a tag-event,
but never a bare number (`doc/manual.md:2110,2138,2139,2156`). So the
number slot in `await` is unused today. Making `await(number)` mean
"wait N ms" fills an empty slot — low collision risk. The runtime adds
one branch: if the reaction value is a number, schedule a relative timer
of that many milliseconds.

### Scope

lua-atmos is a separate repo — this is a downstream task there, not part
of this compiler change. The Atmos side is trivial: `coder.lua:65-69`
stops emitting `clock{…}` and emits the ms integer; the `clk` AST node
collapses into a plain `num`.

## Implementation Status (compiler side)

Decisions (this session):

- Scope    : clock literals + drop `@` sigil (keep `@{` tables; no index yet).
- Syntax   : unit-suffix (Proposal A) — `5s`, `300ms`, `2h30min`.
- Emit     : constant exprs, e.g. `(5*_s_ + 30*_min_)` (NOT raw integers).
- Units    : `us ms s min h day` (full set; `us` included).
- Base unit: MICROSECONDS, not ms. Runtime (`lua-atmos/atmos/init.lua`)
             defines `_us_=1, _ms_, _s_, _min_, _h_, _day_` and dropped the
             `clock` type. This supersedes plan §6 ("integer milliseconds").

Done:

- [DONE] `src/lexer.lua` : `lexer_dur(s)` parses `(digits[.digits]unit)+`.
- [DONE] `src/lexer.lua` : number branch emits `clk` token w/ `comps` (or
         falls back to `invalid number`).
- [DONE] `src/lexer.lua` : `@` branch drops clock; keeps `@{`; bare `@` ->
         `err "unexpected '@'"`.
- [DONE] `src/coder.lua` : `clk` emits `(n*_unit_ + ...)` constant expr.
- [DONE] `src/tosource.lua` : `clk` prints raw source (`e.tk.str`).
- No parser change: `clk` AST tag kept; only payload changed
  (`clk{h,min,s,ms}` -> `comps[{n,u}]`).

Pending:

- [DONE] migrate `@`-clock call sites -> unit-suffix in `tst/` (incl. guide.atm,
  `clock@{}` constructor removed, `?? :clock`->`:number`, var dur `@.ms`->
  `(ms * 1ms)`). Verified via parse+codegen probes.
- [DONE] lexer/expr clock tests rewritten to unit-suffix.
- [TODO] migrate `doc/manual.md`, `doc/guide.md`, `doc/exs/` (docs, not run by
  `all.lua`).
- [TODO] runtime `await(number)` = relative µs (lua-atmos, downstream).

Runtime API notes (already done in lua-atmos, for migration reference):

- `await {clock}` -> `await (us)` + `_ts_` (commit f11d2e5). Base unit µs.
- Periodic-timer stream: `S.from(clk)` REMOVED -> `S.fr_await(dt)` where `dt`
  is a µs duration (commit 9471433). So `S.from(@1)` -> `S.fr_await(1s)`.
  Plain `S.from(n[,m])` stays a numeric range/counter.
- `x ?? :clock` -> `x ?? :number`. `clock` value-type/constructor removed.

## Open Questions

- Keep an optional `$` marker, or go fully sigil-free?
  - DECIDED: sigil-free (`@` reserved; bare `@` errors).
- Allow `day` (and later `week`), or cap at `h`?
  - DECIDED: `us ms s min h day` (full set, no week yet).
- Any need for sub-ms (`us`)? Constrained by the unit alphabet.
  - DECIDED: yes, `us` included (runtime base unit).
- Compound order: enforce descending, or accept any order and sum?
  - DECIDED: enforce strict descending order (`day h min s ms us`), no
    repeats. Parser does one anchored `match` per unit in that order; any
    leftover text -> "invalid number". So `30min2h` and `5s5s` are errors.
