# Plan: Atmos with a C backend (new implementation, new repo)

## Context

A from-scratch reimplementation of Atmos that compiles to C.
No Lua: no VM, no interpreter, no Lua syntax, no Lua libraries.
The current implementation (this repo + lua-atmos) is the reference for
semantics, and its test suite becomes the spec (see Tests).

Goal: the simplest dynamic language that still supports Atmos'
structured, deterministic concurrency.

## Settled decisions

- **C backend only.**
    - Whole-program compilation to one C file, then `cc`.
    - No VM, no bytecode, no interpreter.
- **No `load`.**
    - No runtime evaluation of source.
    - Modules are resolved statically at compile time.
- **No metatables, no coroutines.**
    - Tasks are the only suspension mechanism.
- **Stackless tasks with shallow `await`.**
    - `await` is legal only lexically inside a task body: task prototypes,
      the main chunk, and transparent blocks inside them.
    - `await` inside a `func` body is a compile error.
    - Reusable waiting logic is a task awaited with `await T(...)`.
- **Reference counting plus numeric pin scopes, no GC.**
    - `pin` is extended to all dynamic values (see Memory).
    - A pinned value records the depth of its pin block and is freed,
      guaranteed, when that block ends.
    - A pinned value never escapes its pin block: every escape is
      checked at runtime and raises an error at the escape point.
    - No reference to a freed value is ever observable: no dead values,
      no liveness check on access.
    - Unpinned values are refcounted and may go anywhere.
    - Closures inherit the scope: a closure that captures pinned values
      is pinned at the deepest of their depths.
    - Leaks are accepted for cycles made only of unpinned values.
- **Inline frames for structured constructs.**
    - `par`, `watching`, `loop on`, `toggle on` need no allocation.
    - No more lowering to lambdas or Lua closures.
- **Non-local exits as status codes.**
    - Errors, `escape`, `break`, `return` all propagate as a returned
      status, never `setjmp`/`longjmp`.
- **Tables only, Lua-like.**
    - One mutable table type with array part and hash part.
    - No separate tuple type.
    - Hash part iterates in insertion order (determinism).
- **Native code is C.**
    - Native blocks emit C.
    - Native resources are boxed values with a finalizer.
    - `$x` inside a native block refers to the Atmos variable `x`.
- **Compiler written in C.**
    - One self-contained binary, no runtime dependency.
    - Self-hosting in Atmos may come later.
- **Numbers are a single `double`.**
    - `print`/`tostring` show integral values without decimals (`1`,
      not `1.0`), to keep current outputs.
- **Multiple values and varargs are kept.**
    - `catch`, `await`, `escape`, `par :all`, and `val a,b = ...` rely
      on them.
    - Implemented with a runtime value stack (see Calls).
- **Static globals.**
    - No dynamic global table.
    - Top-level declarations become static C variables.
    - An unknown identifier is a compile error.
    - `func f` without `val` declares a top-level variable.
- **All strings are interned in v1.**
    - Equality and table key hashing become pointer operations.
    - Revisit if concatenation-heavy code suffers.
- **Indexes are 1-based**, as today (manual, tests, `@#`, `@+`).
- **No string patterns in v1.**
    - Plain `find`, `sub`, `split` only.
- **No auto-pin of task arguments in v1.**
    - Unpinned arguments are already safe by refcount.
    - Auto-pin would only add a guaranteed free when the task ends and
      break cycles through the argument. Revisit later.

## Language delta (relative to current Atmos)

### Kept

- Literals: nil, booleans, numbers, strings, tags, clocks, natives.
- `val`, `var`, `pin`, `set`, `where`.
- Blocks, `do :X`, `escape`, `defer`, `test`.
- `if`, `ifs`, `match`, all four `loop` forms, `break`, `until`, `while`.
- `throw`, `catch` (with `true`, `false`, function, and `??` matching).
- All operators: `??` `!?` `#` `++` `?>` `!>` `===` `=!=` `=>=` `=<=`.
- Indexing: `t@(e)`, `t@1`, `t.x`, `t@#`, `t@+`.
- Calls with single constructor argument, pipes, parenthesis lists.
- `func`, lambdas (`\{ it }`), prototypes, `o::f()` as sugar for `o.f(o)`.
- `task`, `tasks(n)`, `spawn`, `spawn @ts`, transparent `spawn {}`.
- `await` (full pattern language), `emit @target`, `toggle`, `abort`,
  `pub`, `par`, `par :any`, `par :all`, `watching`.
- `X.tostring`, `X.print`, `X.copy`.

### Changed

- `await` is shallow (compile error inside `func`).
- `pin` applies to any dynamic value, not only tasks and pools.
- A pinned value cannot escape its pin block (runtime error).
    - Today a pinned task can be aliased outside its block and is then
      seen as `dead`; this becomes an error at the assignment.
- Returning a pinned value from its own pin block transfers ownership.
    - Today `func f () { pin t = spawn T() ; t }` returns a dead task;
      it now returns a live task that the caller must pin.
- Parameters are immutable, as the manual states.
    - Today `set` on a parameter is silently accepted.
- Native blocks contain C, not Lua.
- Globals are static (see Settled decisions).
- Deep ordering drops the metatable rule (rule 2).

### Dropped

- `load` and anything that evaluates source at runtime.
- Metatables, metamethods, `__call`/`__pairs` iteration, `__concat`.
- The `meta` await pattern (`__atmos`).
- Lua standard libraries (replaced by a small library, see Stdlib).
- `thread`, `async` (v1), functional streams (v1).
- String methods via metatable (`s::len()`).
- Types `thread` and `userdata` (replaced by the native box).

## Runtime

### Values

```c
typedef enum {
    A_NIL, A_BOOL, A_NUM, A_STR,
    A_TAB, A_FUNC, A_TASK, A_TASKS, A_NAT
} AType;

typedef struct {
    uint8_t type;
    union {
        int     b;
        double  n;
        AObj*   o;      // STR, TAB, FUNC, TASK, TASKS, NAT
    } u;
} AVal;
```

- 16-byte tagged union in v1. NaN-boxing is a later optimization.
- Tags are interned strings (`:x == 'x'` holds as today).
- `type(v)` returns the tag `:nil`, `:table`, `:xtask`, etc.

### Memory

```c
typedef struct {
    int32_t  rc;
    uint8_t  type;
    uint8_t  pinned;
    uint32_t depth;     // depth of the pin block, if pinned
} AObj;
```

#### Ownership convention

- Arguments are borrowed.
- Return values are owned (+1).
- Storing into a variable, frame slot, table, or closure takes a
  reference; overwriting releases the old one.
- All objects keep a refcount, pinned or not. For a pinned object it
  only matters after a transfer (see Exits).

#### Block depth

- Every block instance has a depth: its parent block's depth plus one.
- The main chunk's block has depth 1. Top-level variables live there.
- A function body is one deeper than the caller's current block.
- A task body is one deeper than the block it is attached to: the
  spawning block, or the block of its pool.
- Depths are stored in frames, so a resumed task keeps its own depths,
  whoever emitted.

#### Unpinned values

- Live by refcount and may be stored anywhere: emitted, thrown, put in
  top-level variables, in other tables, in `pub`.
- Can never reference a pinned value (see Stores), so everything
  reachable from them is refcounted too.
- Cycles made only of unpinned values leak (accepted).

#### Pin

- `pin x = e` pins the value of `e` in the current block.
    - The value must be unique (`rc == 1`), else
      `invalid pin : shared value`.
    - Pinning an already pinned value is an error.
    - Pinning the running task or an ancestor is an error.
    - An unassigned `spawn` is an implicit pin in the enclosing block.
    - Tasks and pools must be pinned: `val`/`var` of an unpinned task
      or pool is an error, as today.
- Sets `pinned = 1` and `depth` to the block depth.
- When the block ends, each pinned value is freed unconditionally:
    - task: aborted (defers run), then freed;
    - pool: all tasks aborted, then freed;
    - table: entries released, then freed;
    - function: captures released, then freed;
    - native: finalizer called, then freed.

#### Invariant

- Every reference to a pinned value lives in its pin block or in a
  block nested inside it, on the same chain of blocks.
- Hence freeing at the end of the pin block never leaves a reference
  behind. There are no dead values and no liveness check on access.
- Along a single chain, nesting equals depth order, so one integer
  comparison suffices.
- Every lateral channel (between parallel branches or tasks) is an
  escape, checked as below.

#### Stores

Storing a pinned value `v` with depth `p`:

| Destination                                    | Rule     |
|------------------------------------------------|----------|
| local variable of a block at depth `d`         | `d >= p` |
| table pinned at depth `d`                      | `d >= p` |
| `pub` of a task pinned at depth `d`            | `d >= p` |
| `emit` payload, target root at depth `d`       | `d >= p` |
| `spawn` argument, task attached at depth `d`   | `d >= p` |
| captured `var` (heap box)                      | error    |
| unpinned table                                 | error    |
| `throw` payload                                | error    |

- A failed rule raises `invalid escape : pinned value` at the store.
- `emit` targets `:global`, `:parent`, and `n > 0` are always outer, so
  emitting a pinned value to them is an error.
- `emit @:task` is allowed only if `v` is pinned in the outermost block
  of the running task.
- A task that receives a pinned argument inherits its depth: it cannot
  be stored, returned, or pooled above `p`.
- A closure that captures pinned values inherits their scope (see
  Functions and closures).
- Unpinned task arguments are plain refcounted references. They are
  safe because unpinned values cannot reference pinned ones.
- `throw` is always an error because the pin block is unwound before
  the `catch` receives the value.

#### Exits

`return`, `escape`, `break`, a block's final value, and a task's result
carry a value `v` with depth `p` to a destination at depth `d`:

- **Alias (`p <= d`).** `v` stays pinned where it is.
- **Transfer (`p > d`).** The pin block of `v` is being exited.
    - `v` is unpinned and flows out as a fresh value.
    - Pinned values reachable from `v` with depth `> d` are unpinned
      too. The traversal only visits pinned objects, since unpinned
      ones cannot hold pinned ones.
    - The destination decides: `pin` again, or keep it refcounted.
      Tasks and pools must be pinned again.
    - Safe by the invariant: every other reference lived in the exited
      blocks and was released with them, so refcounts are exact.
- Today `func f () { pin t = spawn T() ; t }` returns a dead task.
  With transfer it behaves like `func f () { spawn T() }`.

#### Cycles

- Cycles through pinned values are freed when their pin block ends.
  Since unpinned values cannot reference pinned ones, such cycles are
  made only of pinned values.
- Cycles of unpinned values leak. The remedy is `pin`, and ASan finds
  them in tests.

### Strings and tags

- Immutable, refcounted, interned (weak intern table).
- Length stored; contents NUL-terminated for C interop.
- Tag hierarchy `??` is a dot-prefix test on the interned string.

### Tables

- Array part (`1..n`) plus insertion-ordered hash part.
- Hash: open addressing index into a dense entry array.
- Deletion leaves a tombstone, compacted on rehash.
- `#t` is the array border, as in Lua.
- Iteration: array part, then hash entries in insertion order.
- `tag` field is an ordinary string key.
- Runtime helpers: `++` on tables, `?>`, `===`, `=>=`, `X.copy`,
  `X.tostring`.

### Functions and closures

```c
typedef AStatus (*AFn) (AFunc* self, int argc, AVal* argv);

typedef struct {
    AObj  hdr;
    AFn   fn;
    int   ncap;
    AVal  caps[];
} AFunc;
```

- A captured `val` is copied into `caps`.
- **Scope inheritance.** A closure that captures pinned values is
  pinned at creation, at the deepest of their depths.
    - The closure is fresh, so the pin is always valid.
    - It is then subject to the Stores rules like any pinned value: it
      cannot go to an unpinned table, a captured `var`, a `throw`, or an
      outer variable.
    - On exits it follows the transfer rule: returning it from the pin
      block unpins it together with the captured pinned values.
    - Task prototypes written as literals follow the same rule.
- A closure that captures only unpinned values stays unpinned.
- A captured `var` lives in a refcounted box shared by all closures and
  the declaring frame.
- Stdlib and native functions use the same type, with `ncap == 0`.

### Calls and multiple values

- One global value stack, as in Lua.
- Caller pushes arguments, callee pushes results.
- The callee returns a status; the result count is in the context.
- On error, the stack is unwound to the frame base, releasing values.
- Nothing on the stack survives an `await`: task temporaries live in
  the task frame (see Compiler).

### Status and non-local exits

```c
typedef enum {
    A_OK, A_ERROR, A_ESCAPE, A_BREAK, A_RETURN, A_ABORT
} AStatus;
```

- The payload (thrown values, escape tag and values, ...) is kept in
  the runtime context.
- Within one C function, `break`/`escape`/`return` compile to `goto`
  through the cleanup chain.
- Across C functions (calls, transparent blocks) they propagate as a
  status, and each level runs its cleanup.
- Cleanup = run defers in reverse, release locals, free pins.
- `catch` tests the status and payload and stops propagation on match.
- Uncaught `A_ERROR` at the top prints the trace and exits.
- Traces: each frame records Atmos file and line before calls and
  awaits, producing the bidimensional trace (call stack plus task tree).

### Tasks

- **Prototype.** A `task` value is a closure whose `fn` is a resume
  function plus a frame size.
- **Instance.** An `xtask` is a heap object:

```c
typedef struct ATask {
    AObj    hdr;
    AResume resume;     // generated
    int     pc;         // resumption point
    uint8_t status;     // running, suspended, terminated
    uint8_t toggled;    // on/off
    struct ATask* up;   // owner
    ABlock* blks;       // active nested blocks with tasks
    APatt*  await;      // current await pattern
    AVal    pub;
    AVal    ret;
    // generated frame follows: params, locals, temporaries
} ATask;
```

- **Resume signature.**

```c
typedef enum { R_START, R_EVENT, R_EXIT, R_ABORT } AKind;
typedef AStatus (*AResume) (ATask* t, AKind k, AVal evt);
```

- `R_EVENT`: an emit matched the current await pattern.
- `R_EXIT`: a transparent child delivered a non-local exit; the task
  behaves as if it was raised at its current await point.
- `R_ABORT`: the task jumps to the cleanup chain of its current `pc`.
- **Transparent blocks** (`spawn {}`, `par` branches, `watching`,
  `toggle on`) are task objects embedded inline in the owner's frame.
    - No allocation.
    - An `up` pointer gives access to the owner's locals.
    - `return`/`break`/`throw`/`escape` cross to the owner with their
      values, matching `tst/throw.lua` (pre and pos cases).
    - They delegate `pub` and `emit` to the owner.
- **Main chunk** is a task (it may `await`).
- **Pools.** `tasks(n)` is a list of heap tasks with an optional limit.
    - `spawn @ts` fails with `nil` when full.
    - A task leaves its pool when it terminates; `#ts` counts live
      tasks.
- **Lifetime.** A task may terminate or be aborted before its pin block
  ends. This is a valid state, not a dead reference.
    - The frame (locals, nested blocks) is freed at termination.
    - The header (`status`, `pub`, `ret`) lives until the pin block
      ends, so `await t` and `t.pub` keep working.
    - Headers of pool tasks are refcounted by their aliases. All aliases
      live inside the pool's block, so a header is freed at the latest
      when that block ends.

### Scheduler

- **Spawn.** Allocate frame (or use inline slot), link into the
  enclosing block, resume with `R_START` until the first await.
- **Await.** Build the pattern once, eagerly (including spawned task
  arguments); `until`/`while` predicates stay closures, called on each
  candidate event.
    - Patterns: boolean, value (`??`), tagged table (`=>=`), clock,
      `:clock`, task, `T(...)`, `:any ts`, `:all ts`, `until`, `while`,
      `!`, `&&`, `||`.
    - `&&` keeps per-operand state inside the pattern.
- **Emit.** Traverse the task tree in the documented order:
    1. the active block of the task,
    2. its nested tasks in sequence,
    3. its single nested block,
    4. the task itself at its await point,
    5. the next sibling task.
- **Emit targets.** `:task` (default), `:parent`, `:global`, a task, or
  a level number.
- **Reentrancy.** A reaction may emit, or abort tasks not yet
  traversed.
    - The traversal holds a reference to the next task header and skips
      terminated tasks.
- **Deferred abort.** A reaction may abort a block whose code is still
  on the C stack (e.g. an outer `watching` aborts the emitter).
    - The abort only marks the block.
    - Cleanup and deallocation run when control returns to that code,
      which sees `A_ABORT` and unwinds.
    - Pinned values held in its temporaries stay valid until then.
- **Pinned payloads.** `emit` of a pinned value requires the target to
  live inside the value's pin block (see Memory, Stores).
- **Termination.** A finishing task stores `ret` and signals its owner,
  so `await t`, `await T()`, `:any ts`, `:all ts` match with `v,t[,ts]`.
- **Errors in reactions** propagate through `emit` to the emitter
  (`tst/tasks.lua` "catch 1").
- **Toggle.** `toggled = 0` skips the subtree in traversal, except
  events matching the `with` patterns.
    - `toggle on :T` reacts to `emit(:T [bool])`.
- **Abort.** Resume with `R_ABORT`, depth-first, defers in reverse.
- **Clocks.** Replicate the current synchronous timers semantics
  (`.claude/plans/done/261019-timers.md`):
    - `await(dur)` returns `late`;
    - `await :clock` returns `dt, late`;
    - one piece per timer expiry.

### Natives

- Native blocks are C expressions or statements.
- `$x` refers to an Atmos variable.
- A C API header gives macros to read and build values:
  `A_NUM(v)`, `A_STR(v)`, `a_num(d)`, `a_str(s)`, `a_tab()`, ...
- Native box:

```c
typedef struct {
    AObj   hdr;
    void*  ptr;
    void (*fin) (void*);
} ANat;
```

- The C wrapper attaches `fin` at creation (e.g. `fopen` with
  `fclose`). The user never declares finalizers.
- `fin` runs on last release or when its pin block ends, exactly
  once.

### Driver and environments

```c
void    atm_init  (int argc, char** argv);
AStatus atm_main  (void);           // run main until all suspended
AStatus atm_emit  (AVal evt);       // external event, global target
AStatus atm_step  (uint32_t ms);    // advance clock
int     atm_alive (void);           // tasks still pending?
void    atm_quit  (void);
```

- The default `main()` runs the main chunk, then sleeps until the next
  timer deadline and steps, until no task is pending.
- Environments (SDL, stdin, sockets) are separate C modules that call
  `atm_emit`/`atm_step` from their own loops.

### Stdlib (v1)

- **base:** `print`, `type`, `tostring`, `tonumber`, `assert`, `next`.
- **math:** `floor`, `ceil`, `abs`, `min`, `max`, `sqrt`, `sin`, `cos`,
  `random`, `randomseed`, `huge`, `pi`.
- **string:** `sub`, `find` (plain), `split`, `byte`, `char`, `upper`,
  `lower`, `rep`, `format` (`%d %s %f %g %x %%`).
- **vector:** `insert`, `remove`, `sort` (with comparator), `join`.
- **io:** `write`, `read` (line), `open`/`close`/`lines` as native box.
- **os:** `time`, `clock`, `exit`, `getenv`.
- **X:** `tostring`, `print`, `copy`.
- **atmos:** `status(t)`.

## Compiler

### Pipeline

```
.atm -> lexer -> parser -> resolver -> checker -> lowering -> coder -> .c
```

- CLI: `atmos f.atm [args]` compiles, builds, and runs.
- Flags: `-c` emit C only, `-o out` build only, `-t` enable `test`.
- `#line` directives map C diagnostics and debuggers to `.atm` lines.

### Passes

1. **Lexer.** Same lexicon as the manual; native blocks hold C text.
2. **Parser.** Recursive descent, 7 precedence levels, as the manual.
3. **Resolver.**
    - Scopes, `val`/`var`/`pin`, static globals.
    - Captures: copy `val`, box captured `var`.
    - Tags interned at compile time.
4. **Checker.**
    - `await` only inside task bodies.
    - `set` only on `var`, indexes, natives.
    - `pin` rules that are static.
5. **Lowering.**
    - `watching P {B}` to `par :any { await P } with {B}`.
    - `loop on P` to `loop { await P ... }`.
    - `until`/`while` to `if`/`break`.
    - Task bodies to A-normal form: every temporary that may be live
      across an `await` gets a frame slot (v1: all task temporaries).
6. **Coder.**
    - One C function per `func`; captures in `AFunc.caps`.
    - One resume function per task prototype and per transparent block.
    - One frame struct per task prototype, with inline frames for its
      transparent blocks.
    - Each block emits a cleanup label; each await site knows its
      cleanup chain, used for `R_ABORT` and `R_EXIT`.

### Codegen sketch

```
task T (n) {
    var i = 0
    loop on :X {
        set i = i + n
    }
}
```

```c
typedef struct {
    ATask t;
    AVal  n;
    AVal  i;
} T_Frame;

static AStatus T_resume (ATask* t, AKind k, AVal evt) {
    T_Frame* f = (T_Frame*) t;
    if (k == R_ABORT) {
        goto CLEANUP;
    }
    switch (t->pc) {
        case 0: break;
        case 1: goto AWAIT_1;
    }
    a_set(&f->i, a_num(0));
    while (1) {
        a_await(t, a_patt_val(TAG_X));
        t->pc = 1;
        return A_OK;            // suspended
    AWAIT_1:
        a_set(&f->i, a_add(f->i, f->n));
    }
CLEANUP:
    a_rel(&f->i);
    a_rel(&f->n);
    return (k == R_ABORT) ? A_ABORT : A_OK;
}
```

## Tests

- **Golden suite from the current repo.**
    - Write a one-time extractor in this repo that dumps every
      `atm_test(src)` case and its expected output from `tst/*.lua` into
      `tst/cases/NNNN-name.atm` plus `.out`.
    - Tag each case with the features it uses, so cases using dropped
      features (Lua natives, metatables, streams, threads, deep await)
      are moved to `tst/dropped/` or rewritten.
- **Runner.** Compile each case, run, diff stdout and error output.
- **Sanitizers from day one.** Build tests with `-fsanitize=address`.
    - Leak checking on by default.
    - Cases with intended unpinned cycles opt out explicitly.
- **Unit tests** for the runtime in C: tables, strings, refcounts,
  pin and free, transfer, scheduler order.
- **Escape checks.** One case per row of the Stores table and per exit
  kind, each in an allowed and a rejected variant, including parallel
  branches and captured variables.
- **Behavior changes.** Golden cases that observe `dead` aliases or dead
  returns (pin and return cases in `tst/tasks.lua`) are rewritten to
  expect the new escape errors or transfers.

## Repo layout

```
src/        compiler (lexer, parser, resolver, checker, lower, coder)
rt/         runtime (values, mem, str, tab, func, task, sched, std)
rt/atmos.h  public C API for natives and environments
env/        environments (default loop, SDL, ...)
tst/cases/  golden tests (.atm + .out)
tst/rt/     runtime unit tests
doc/        manual (rewritten from the current one)
exs/        examples
```

## Milestones

- [ ] M0 skeleton: build system, `AVal`, `print`, compile `print(1+2)`.
- [ ] M1 expressions: numbers, strings, tags, tables, all operators,
      indexing, `if`/`ifs`/`match`, non-event loops, `where`, pipes,
      `val`/`var`/`set`, static globals.
- [ ] M2 functions: closures, boxes, multiple values, varargs, `return`,
      lambdas, method sugar.
- [ ] M3 control and errors: blocks, `defer`, `escape`, `break`,
      `until`, `while`, `throw`, `catch`, traces with `#line`.
- [ ] M4 tasks core: prototypes, `spawn`, `await` on values and tags,
      default and `:global` emit, main as task, `pin` for tasks,
      `abort`, `pub`, `status`.
- [ ] M5 structured: transparent blocks, `par`, `par :any`, `par :all`,
      `watching`, `loop on`, exit crossing, `await T()`, `await t`.
- [ ] M6 pools and targets: `tasks(n)`, `spawn @ts`, `:any ts`,
      `:all ts`, emit targets, `toggle` (both forms, `with`).
- [ ] M7 time: clock awaits, `:clock`, timers, default driver loop.
- [ ] M8 memory: `pin` for all values, block depths, store checks,
      transfer on exits, deferred abort of blocks on the C stack.
- [ ] M9 natives and stdlib: C natives, `$x`, native box, stdlib v1, X.
- [ ] M10 parity: golden suite green, `exs/` ported, manual rewritten.

## Risks

- **Emit reentrancy.** Aborts during traversal are the main source of
  use-after-free bugs inside the runtime. Covered by deferred abort,
  refcounted task headers, and ASan.
- **Escape-check completeness.** A missed channel breaks the invariant
  silently. Every channel in the Stores table gets dedicated tests.
- **Escape-check cost.** Each store of a pinned value compares two
  integers. Cheap, but on hot paths; static elision later.
- **Refcount bugs in generated code.** Keep the ownership convention
  strict and centralize it in a few coder helpers.
- **Semantic drift.** The golden suite is the spec; any intended change
  must update the case and the manual together.
- **Big single C file.** Compile time grows with programs; acceptable
  for v1, separate compilation later.
- **Stdlib scope creep.** Hold v1 to the list above; add on demand.
