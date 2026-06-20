# Plan: string escape sequences (issue #31)

## Problem

The lexer stores string content raw; the coder then runs `%q`, which
doubles every backslash:

```
"([^\r\n]+)"  --lexer-->  ( \ r \ n )  --coder %q-->  "([^\\r\\n]+)"
```

So `\n \r \t \xHH ...` all end up as literal letters, never decoded.

## Approach B: let Lua decode the escapes

Stop `%q`-ing single-line strings. Emit their raw bytes between the
original quotes and let **Lua's own lexer** interpret the escapes.
Keep `%q` for multi-line strings (they hold real newlines that cannot
sit inside a Lua `"..."`, and stay raw like Lua `[[ ]]`).

| string kind          | coder emits              | escapes decoded by |
|----------------------|--------------------------|--------------------|
| single `"..."`/`'...'` | `q .. str .. q`        | Lua                |
| multi `"""..."""`    | `string.format("%q", s)` | nobody (raw)       |

Wins: zero hand-written escape table — `\n \r \t \xHH \ddd \u{} \z`
all work for free.

Dropped (per discussion): `\"` escaped delimiter. Use `""" " """`.

## Where

| file            | place                  | change                          |
|-----------------|------------------------|---------------------------------|
| `src/lexer.lua` | `"`/`'` branch (220)   | tag token single vs multi + delim |
| `src/coder.lua` | str branch (60-62)     | branch: raw-emit vs `%q`        |

## Implementation

### lexer (`src/lexer.lua`, ~220-247)

String content stays raw (no change to reading). Add to the yielded
token:

- `multi = (n1 >= 3)` — or equivalently a `raw` flag
- `quo = c` — the original delimiter (`"` or `'`)

```
coroutine.yield { tag='str', str=v, multi=(n1>=3), quo=c, lin=lin, sep=sep }
```

### coder (`src/coder.lua:60-62`)

```
elseif e.tag == 'str' then
    if e.tk.multi then
        return L(e.tk) .. string.format("%q", e.tk.str)
    else
        return L(e.tk) .. e.tk.quo .. e.tk.str .. e.tk.quo
    end
```

## Edge cases

- single-line ending in lone `\` (`"\"`): emits broken Lua.
  Detect and `err "unterminated string"` (it is the dropped `\"` case).
- `'a"b'`: emitted with `'` delim, so inner `"` stays literal. OK.
- empty `""` (n1==2): single, emits `""`. OK.

## Affected existing expectations

- `tst/lexer.lua:163-171` assert raw `\n\z10`, `\d` token content —
  token gains `multi`/`quo` fields; string still stored raw, so the
  `str=` value is unchanged but the table comparison may need the new
  fields.

## Status

- [x] lexer: add `multi=(n1>=3)` + `quo=c` to str token (`lexer.lua:247`)
- [x] coder: branch raw-emit vs `%q` (`coder.lua:60`)
- [x] tests: `tst/exec.lua` `\n` decode + quote-via-multi-line
- [x] fix token-shape expectations: `tst/lexer.lua:167-172`, `tst/expr.lua:112/114/116`
- [ ] lone-trailing-`\` guard — deferred (errors in generated Lua, same
      unsupported case as `\"`; revisit if needed)
- [ ] doc/manual.md: document single-line escapes vs raw multi-line

## Verified (targeted compiles)

- `print("a\nb")`   -> `a` NL `b` NL          (\n decoded)
- `print("x\ty")`   -> tab decoded
- `print("\x41")`   -> `A`                     (hex via Lua, free)
- `print("""a\nb""")` -> literal `a\nb`        (multi-line stays raw)
- `print(trim(""" " """))` -> `"`             (supported quote form)
