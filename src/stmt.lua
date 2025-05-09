require "parser"
require "expr"

function parser_stmt ()
    if false then
    elseif false then
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


