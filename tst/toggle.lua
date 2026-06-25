require "atmos.lang.exec"
require "atmos.lang.tosource"

-- These tests encode the POST-FIX behavior of toggle-filter patterns: the
-- `with` filter must route through `parser_await`, so `&&`/`||`/`!`
-- combinators and `:any`/`:all` pools lower to `{tag=...}` tables (like
-- `await` / `loop on` / `watching`), NOT Lua boolean operators.
-- They FAIL until the fix lands (TDD).

print '--- TOGGLE FILTER : PARSE ---'

do
    -- call form : && combinator
    local src = "toggle t(false) with :a && :b"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "toggle(t, false, [@(:tag)=\"and\", @(1)=:a, @(2)=:b])")

    -- call form : || combinator
    local src = "toggle t(false) with :a || :b"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "toggle(t, false, [@(:tag)=\"or\", @(1)=:a, @(2)=:b])")

    -- call form : ! combinator
    local src = "toggle t(false) with !:a"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "toggle(t, false, [@(:tag)=\"not\", @(1)=:a])")

    -- call form : pool prefix
    local src = "toggle t(false) with :any ts"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "toggle(t, false, [@(:tag)=\"tasks\", @(:mode)=\"any\", @(:tasks)=ts])")

    -- call form : combinator mixed with a plain tag in the list
    local src = "toggle t(false) with :a && :b, :c"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "toggle(t, false, [@(:tag)=\"and\", @(1)=:a, @(2)=:b], :c)")

    -- block form : combinator
    local src = "toggle on :X with :a || :b { }"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(trim(tosource(e)), trim [[
        toggle(:X, [@(:tag)="or", @(1)=:a, @(2)=:b], {
        })
    ]])
end

do
    -- a single-predicate `until`/`while` stops at the comma, so a
    -- trailing pattern joins the enclosing filter list (no swallowing)
    local src = "toggle t(false) with :a until c, :b"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "toggle(t, false, [@(:tag)=\"until\", @(1)=:a, @(2)=func (it) {\nc\n}], :b)")
end

-- a filter item may be wrapped in one optional pair of parens, so the
-- pattern-only syntax (pool :any/:all, until/while) is parenthesizable,
-- matching await(...). `(PAT)` == `PAT`. FAILS until the fix lands (TDD).

do
    local src = "toggle on :X with (:any ts) { }"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "toggle(:X, [@(:tag)=\"tasks\", @(:mode)=\"any\", @(:tasks)=ts], {\n\n})")
end

do
    local src = "toggle t(false) with (:a until c)"
    print("Testing...", src)
    init()
    lexer_init("anon", src)
    lexer_next()
    local e = parser()
    assert(check('<eof>'))
    assertx(tosource(e), "toggle(t, false, [@(:tag)=\"until\", @(1)=:a, @(2)=func (it) {\nc\n}])")
end

print '--- TOGGLE FILTER : EXEC ---'

do
    -- combinator filter passes multiple events while toggled off
    local src = [[
        val T = task () {
            spawn (task () { loop on :Draw  { print(:draw)  } }) ()
            spawn (task () { loop on :Click { print(:click) } }) ()
            loop on :Tick { print(:tick) }
        }
        pin t = spawn T()
        emit(:Tick)                            ;; on  -> tick
        toggle t (false) with :Draw || :Click  ;; off, both pass
        emit(:Draw)                            ;; passes -> draw
        emit(:Click)                           ;; passes -> click
        emit(:Tick)                            ;; gated
        toggle t (true)
        emit(:Tick)                            ;; on  -> tick
    ]]
    print("Testing...", "toggle filter combinator")
    local out = atm_test(src)
    assertx(out, "tick\ndraw\nclick\ntick\n")

    -- toggle a whole tasks pool: gate/un-gate all members
    local src = [[
        val T = task (v) {
            loop {
                await(true)
                print(v)
            }
        }
        pin ts = tasks()
        spawn @ts T(1)
        spawn @ts T(2)
        emit(:X)
        toggle ts(false)
        print("---")
        emit(:X)
        emit(:X)
        print("---")
        toggle ts(true)
        emit(:X)
    ]]
    print("Testing...", "toggle pool target")
    local out = atm_test(src)
    assertx(out, "1\n2\n---\n---\n1\n2\n")
end
