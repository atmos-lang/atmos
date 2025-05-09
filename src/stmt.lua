require "parser"
require "expr"

function parser_curly ()
    accept_err("sym","{")
    local ss = parser_list(null, "}", parser_stmt)
    accept_err("sym","}")
    return ss
end

function parser_stmt ()
    if false then
    elseif accept("key","val") or accept("key","var") then
        local id = accept_err("var")
        local set = accept("op","=") and parser_expr() or nil
        local dcl = { tag="dcl", tk=id, id=id }
        if set then
            error("TODO")
        else
            return dcl
        end
    elseif accept("key","do") then
        local tag = accept("tag")
        local ss  = parser_curly()
        return { tag="block", esc=tag, ss=ss }
    elseif accept("key","escape") then
        accept_err("sym",'(')
        local e = parser_expr()
        accept_err("sym",')')
        return { tag="escape", e=e }
    elseif accept("key","catch") then
        local tag = accept_err("tag")
        local ss  = parser_curly()
        return { tag="catch", esc=tag, blk={tag="block",ss=ss} }
    elseif accept("key","throw") then
        accept_err("sym",'(')
        local e = parser_expr()
        accept_err("sym",')')
        return { tag="throw", e=e }
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


