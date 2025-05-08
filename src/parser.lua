local tk0, tk1
local tks

function parser_lexer (f)
    if f then
        tks = f
    end
    tk0 = tk1
    tk1 = tks()
end

function check_tag (tag)
    return tk1.tag == tag
end

function accept_tag (tag)
    local ret = check_tag(tag)
    if ret then
        parser_lexer()
    end
    return ret
end

function parser_expr ()
    if accept_tag("var") then
        return { tag="var", tk=tk0 }
    else
        error("expected expression : have "..tk1.str)
    end
end
