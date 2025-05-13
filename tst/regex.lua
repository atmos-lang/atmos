-- LUA_PATH="/x/atmos/src/?.lua;" lua5.4 regex.lua

require "lexer"
require "expr"

-- LEX

do
    local src = "~~ !~"
    print("Testing...", src)
    lexer_string("anon", src)
    assert(LEX().str == '~~')
    assert(LEX().str == '!~')

    local src = "/xyz/"
    print("Testing...", src)
    lexer_string("anon", src)
    assert(LEX().str == '~~')
    assert(LEX().str == '!~')
end

-- EXPR

do
    local src = "x ~~ b"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local ok, msg = pcall(parser_expr)
print(msg)
    assert(not ok and msg=="line 1 : near 'b' : expected '/'")

    local src = "x ~~ /y/"
    print("Testing...", src)
    init()
    lexer_string("anon", src)
    parser()
    local e = parser_expr()
    assert(check('<eof>'))
    assert(stringify(e) == "{ e1={ tag=acc, tk={ lin=1, str=a, tag=id } }, e2={ tag=num, tk={ lin=1, str=10, tag=num } }, op={ lin=1, str=+, tag=op }, tag=bin }")

end
