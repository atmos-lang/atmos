require "parser"
require "expr"

function parser_curly ()
    accept_sym_err("{")
    local ss = parser_list(null, "}", parser_stmt)
    accept_sym_err("}")
    return ss
end

function parser_stmt ()
    if false then
    elseif accept_key("do") then
        local tag = accept_tag("tag")
        local ss  = parser_curly()
        return { tag="block", esc=tag, ss=ss }
    elseif accept_key("escape") then
        accept_sym_err('(')
        local e = parser_expr()
        accept_sym_err(')')
        return { tag="escape", e=e }
    else
        local tk = TK1
        local e = parser_expr()
        if e.tag == "call" then
            return { tag="expr", e=e }
        else
            err(tk, "expected statement")
        end
    end
end


