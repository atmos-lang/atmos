Stmt = {}   -- solves mutual require with expr.lua

require "parser"
_ = Expr or require "expr"

function parser_curly ()
    accept_err("sym","{")
    local ss = parser_list(null, "}", parser_stmt)
    accept_err("sym","}")
    return ss
end

function parser_stmt ()
    if false then

    -- var x = 10
    elseif accept("key","val") or accept("key","var") then
        local tk = TK0
        local id = accept_err("var")
        local set = accept("op","=") and parser_expr() or nil
        return { tag="dcl", tk=tk, id=id, set=set }

    -- set x = 10
    elseif accept("key","set") then
        local dst = parser_expr()
        accept_err("op", "=")
        local src = parser_expr()
        return { tag="set", dst=dst, src=src }

    -- do { ... }
    elseif accept("key","do") then
        local tag = accept("tag")
        local ss  = parser_curly()
        return { tag="block", esc=tag, ss=ss }

    -- escape(:X), return(10)
    elseif accept("key","escape") then
        accept_err("sym",'(')
        local e = parser_expr()
        accept_err("sym",')')
        return { tag="escape", e=e }
    elseif accept("key","return") then
        accept_err("sym",'(')
        local e = parser_expr()
        accept_err("sym",')')
        return { tag="return", e=e }

    -- catch, throw
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
