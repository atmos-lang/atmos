-- LUA_PATH="/x/atmos/src/?.lua;" lua5.4 lexer.lua

require "lexer"

-- SYMBOLS

do
    local tks = lexer_string("{ } ( ; < {{ > ( = ) ) # - , ][ #[ ## / * + .")
    assert(tks().str == "{")
    assert(tks().str == "}")
    assert(tks().str == "(")
    assert(tks().str == "<")
    assert(tks().str == "{")
    assert(tks().str == "{")
    assert(tks().str == ">")
    assert(tks().str == "(")
    assert(tks().str == "=")
    assert(tks().str == ")")
    assert(tks().str == ")")
    assert(tks().str == "#")
    assert(tks().str == "-")
    assert(tks().str == ",")
    assert(tks().str == "]")
    assert(tks().str == "[")
    assert(tks().str == "#")
    assert(tks().str == "[")
    assert(tks().str == "#")
    assert(tks().str == "#")
    assert(tks().str == "/")
    assert(tks().str == "*")
    assert(tks().str == "+")
    assert(tks().str == ".")
    assert(tks().tag == "eof")
    assert(tks() == nil)
end
