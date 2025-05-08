dofile "../src/lexer.lua"

for x in lexer_string("abc") do
    print(x)
end

-- SYMBOLS

do
    local tks = lexer_string("{ } ( ; < {{ > ( = ) ) # - , ][ #[ ## / * + .")
    assert(tks().str == "{")
    assert(tks().str == "}")
    assert(tks().str == "(")
    assert(tks().str == "<")
    assert(tks().str == "{{")
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
    assert(tks().str == "#[")
    assert(tks().str == "##")
    assert(tks().str == "/")
    assert(tks().str == "*")
    assert(tks().str == "+")
    assert(tks().str == ".")
    assert(tks().tag == "eof")
    assert(tks() == nil)
end
