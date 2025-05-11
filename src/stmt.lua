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
        local ids = parser_list(',', '=', function ()
            return accept_err(nil,"id")
        end)
        local sets = accept("=") and parser_list(',', nil, parser_expr)
        return { tag="dcl", tk=tk, ids=ids, sets=sets }

    -- set x = 10
    elseif accept("set") then
        local dsts = parser_list(',', '=', function ()
            local tk = TK1
            local e = parser_expr()
            if e.tag=="acc" or e.tag=="index" then
                -- ok
            else
                err(tk, "expected assignable expression")
            end
            return e
        end)
        accept_err("=")
        local srcs = parser_list(',', nil, parser_expr)
        return { tag="set", dsts=dsts, srcs=srcs }

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

    -- if-else
    elseif accept("if") then
        local cnd = parser_expr()
        local t = parser_curly()
        local f; do
            if accept("else") then
                f = parser_curly()
            else
                f = {}
            end
        end
        return { tag="if", cnd=cnd, t={tag="block",ss=t}, f={tag="block",ss=f} }

    -- loop
    elseif accept("loop") then
        local ss = parser_curly()
        return { tag="loop", blk={tag="block",ss=ss} }
    -- break
    elseif accept("break") then
        return { tag="break" }

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
