# task-dot -- dotted task declarations `task T.Task`

## Goal

Support dotted names in `task` prototype declarations, mirroring
`func` -- but NOT the `::` method form, which stays func-only:

```
task M.T (v) { ... }        ;; OK: set M@("T") = task (v) {...}
task o::f (v) { ... }       ;; ERROR (:: is func-only)
```

Split out of `260706-task-self.md` (bare `task` = "me", complete).

## Build approach

`src/prim.lua` proto branch (~263): hoist the dot-loop out of the
func-only guard; keep `::` guarded:

```lua
local idxs = {}
local met = nil
while accept('.') do
    idxs[#idxs+1] = accept_field_err()
end
if sub == 'func' and accept('::') then
    met = accept_field_err()
    idxs[#idxs+1] = met
end
```

`task o::f` then fails naturally at `accept_err('(')` with
"near '::' : expected '('" -- no explicit error needed.

Note: the `val task` form (`prim.lua:312`) keeps plain-id only
(dotted names make no sense as locals).

## Files

| file             | place               | description                                    |
| ---------------- | ------------------- | ---------------------------------------------- |
| `src/prim.lua`   | proto branch (~263) | allow `.` chains for `task`; `::` func-only    |
| `tst/stmt.lua`   | after `func M.o::f` | `task M.T (v) {}` tosource; `task o::f` error  |
| `tst/tasks.lua`  | new behavior test   | `val M = []` ; `task M.T` ; `spawn M.T(10)`    |
| `doc/manual.md`  | Prototypes (~1196)  | grammar: dotted = func/task, `::` = func-only  |
| `doc/manual.md`  | appendix (~2648)    | mark `[::´ ID]` func-only in the comment       |
| `HISTORY.md`     | v0.8 Additions      | dotted `task` declarations bullet              |

## Tests

Parse (`stmt.lua`):
- `task M.T (v) {}` -> tosource `set M@("T") = task (v) {\n}`
- `task o::f (v) {}` -> parse error "near '::' : expected '('"

Behavior (`tasks.lua`):
```
val M = []
task M.T (v) { print(v) }
spawn M.T(10)               ;; --> 10
```

## Docs

- `doc/manual.md` Prototypes grammar:
  ```
  Proto : [`val´] (`func´|`task`) ID `(´ ID* [`...´] `)´ Block
        | (`func´|`task`) ID {`.´ ID} `(´ ID* [`...´] `)´ Block
        | `func´ ID {`.´ ID} `::´ ID `(´ ID* [`...´] `)´ Block
  ```
  plus prose: dotted assigns to a table field (func/task);
  `::` declares a method with implicit `self` (func only).
- Appendix (~2648): `(func|task) ID {.ID} [::ID]` -- annotate
  `::` as func-only.
- NEVER regen `doc/manual-out.md` (user handles it).

## Progress

- [x] `src/prim.lua` dot-loop hoist (2026-07-07)
- [x] `tst/stmt.lua` parse tests: `task M.T` tosource,
      `task o::f` error (2026-07-07)
- [x] `tst/tasks.lua` behavior test 4b: dotted decl + spawn
      (2026-07-07)
- [x] `doc/manual.md`: Prototypes grammar split in 3 formats +
      prose; appendix comment "(`::´ func only)" (2026-07-07)
- [x] `HISTORY.md` v0.8 bullet (2026-07-07)
- [ ] run test suite (user)

## Won't do

- `task o::f` methods (`::` stays func-only).
- Dotted names in the `val task` local form.
