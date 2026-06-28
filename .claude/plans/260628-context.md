# context

## Goal

Add a `context` statement that brackets a reactive block, running
per-reaction `:enter`/`:leave` code around it and once-only
`:init` (with `defer` = post) setup.

Compiles to the lua-atmos runtime primitive
`context(enter, leave, block)`.

Tracks issue #21 (Context primitive).

## Syntax

```
context {
    :init  { ... }   ;; once, at start  (defer = post, at end)
    :enter { ... }   ;; per reaction, before body
    :body  { ... }   ;; the reactive block          (required)
    :leave { ... }   ;; per reaction, after body
}
```

Rules:

- Body is a sequence of `:tag { block }` entries only (no free
  statements).
- Allowed tags: `:init :enter :body :leave`.
- All optional except `:body`.
- Tags may appear in any order.
- Unknown tag, duplicate tag, or missing `:body` -> compile error.

## Scope rule (decided)

The section `{ }` is a label delimiter, not a scope.
`:init` declarations are hoisted into the enclosing `do` scope, so
`:enter`/`:leave`/`:body` close over them.

`:enter` and `:leave` are separate functions, so they share
per-reaction data through a `var` declared in `:init` (not a
direct local).

## Desugar

```
context {
    :init  { val res = acquire(); var old; defer { release(res) } }
    :enter { set old = save() }
    :body  { every :draw { ... } }
    :leave { restore(old) }
}
```
becomes
```
do {
    val res = acquire()
    var old
    defer { release(res) }              ;; post (once)
    context(
        func () { set old = save() },   ;; enter (per reaction)
        func () { restore(old) },       ;; leave (per reaction)
        func () { every :draw { ... } } ;; block (body)
    )
}
```

Mapping:

| tag      | scale         | maps to                                |
| -------- | ------------- | -------------------------------------- |
| `:init`  | once          | `do` prologue; its `defer` = post      |
| `:enter` | per reaction  | `context` arg 1 (enter fn)             |
| `:leave` | per reaction  | `context` arg 2 (leave fn)             |
| `:body`  | reactive      | `context` arg 3 (block fn) (required)  |

Notes:

- Omitted `:enter`/`:leave` -> pass an empty/no-op function (or
  `nil`, per the runtime's accepted form).
- Omitted `:init` -> no prologue; `do` holds just the `context`
  call.

## Build approach

Parse in `prim.lua` and emit existing AST nodes (same style as
`watching`, which builds a `call` to a runtime helper):

- `do` node: `{ tag='do', blk={ tag='block', es={...} } }`.
- `:init` statements spliced first into `blk.es`.
- `context` call node:
  `{ tag='call', f=acc 'context', es={enter, leave, block} }`.
- each arg is a `{ tag='proto', sub='lua', pars={}, blk=... }`
  wrapping the matching section block (mirror `prim.lua:709-719`).

## Files

| file             | place                          | description                                              |
| ---------------- | ------------------------------ | -------------------------------------------------------- |
| `src/global.lua`  | keyword list (~33-36)          | add `context` keyword                                    |
| `src/prim.lua`    | statement dispatch (near `watching`, ~675) | parse `context`, collect `:tag {}` sections, build `do` + `context(...)` call |

## Prerequisite (external, not this worktree)

The runtime primitive `context(enter, leave, block)` does not exist
in lua-atmos yet.
It must be added to `/x/lua-atmos/atmos/atmos/run.lua` as
`M.context`, bracketing each reaction of `block`'s subtree with
`enter` before and `leave` after (hook around the `emit` dns loop,
`run.lua:691-701`).
This is a separate repo and outside the current worktree.

## Open decisions

- `:` overloading: `:enter` is also an event tag; accepted as a
  section label inside `context` only.
- Empty-section form: pass `nil` vs an empty `func` for omitted
  `:enter`/`:leave` (depends on the runtime signature).

## Pending

- [ ] Register `context` keyword in `src/global.lua`.
- [ ] Add `context` parser branch in `src/prim.lua`
      (section collection + validation + desugar to `context(...)`).
- [ ] Document `context` in `doc/manual.md`.
- [ ] (external) Implement `M.context` in lua-atmos `run.lua`.

## Won't do

- Pure-compiler desugar via `par :any` + `loop on true` (rejected
  in favor of the runtime primitive: simpler and brackets only the
  body's reactions, not every global emit).
- RAII form `context(enter, block)` with `leave = enter()`
  (chose the explicit `enter, leave, block` signature).
- Implicit `func`-body form from the issue #21 comment.
