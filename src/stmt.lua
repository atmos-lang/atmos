Stmt = {}   -- solves mutual require with expr.lua

require "parser"
_ = Expr or require "expr"

function parser_curly ()
    accept_err("{")
    local ss = parser_list(null, "}", parser_stmt)
    accept_err("}")
    return ss
end

function parser_stmt ()
    if false then

    -- var x = 10
    elseif accept("val") or accept("var") then
        local tk = TK0
        local id = accept_err(nil,"var")
        local set = accept("=") and parser_expr() or nil
        return { tag="dcl", tk=tk, id=id, set=set }

    -- set x = 10
    elseif accept("set") then
        local dst = parser_expr()
        accept_err("=")
        local src = parser_expr()
        return { tag="set", dst=dst, src=src }

    -- do { ... }, defer { ... }
    elseif accept("do") then
        local tag = accept(nil,"tag")
        local ss  = parser_curly()
        return { tag="block", esc=tag, ss=ss }
    elseif accept("defer") then
        local ss = parser_curly()
        return { tag="defer", blk={tag="block",ss=ss} }

    -- escape(:X), return(10)
    elseif accept("escape") then
        accept_err('(')
        local e = parser_expr()
        accept_err(')')
        return { tag="escape", e=e }
    elseif accept("return") then
        accept_err('(')
        local e = parser_expr()
        accept_err(')')
        return { tag="return", e=e }

    -- catch, throw
    elseif accept("catch") then
        local tag = accept_err(nil,"tag")
        local ss  = parser_curly()
        return { tag="catch", esc=tag, blk={tag="block",ss=ss} }
    elseif accept("throw") then
        accept_err('(')
        local e = parser_expr()
        accept_err(')')
        return { tag="throw", e=e }

    -- call: f()
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

function parser_main ()
    local ss = parser_list(null, "<eof>", parser_stmt)
    accept_err("<eof>")
    return { tag="block", ss=ss }
end
