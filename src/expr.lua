Expr = {}   -- solves mutual require with stmt.lua

require "parser"
_ = Stmt or require "stmt"

function parser_expr_prim_1 ()
    -- nil
    if accept("key","nil") then
        return { tag="nil", tk=TK0 }

    -- true, false
    elseif accept("key","true") or accept("key","false") then
        return { tag="bool", tk=TK0 }

    -- :tag
    elseif accept("tag") then
        return { tag="tag", tk=TK0 }

    -- 10, 0xFF
    elseif accept("num") then
        return { tag="num", tk=TK0 }

    -- x, __v
    elseif accept("var") then
        return { tag="var", tk=TK0 }

    -- (...)
    elseif accept("sym","(") then
        local e = parser_expr()
        accept_err("sym",")")
        return e

    -- coro(f), task(T), tasks(n)
    elseif accept("key","coro") or accept("key","task") or accept("key","tasks") then
        local f = { tag="var", tk={tag="var", str=TK0.str, lin=TK0.lin} }
        accept_err("sym","(")
        local e = parser_expr()
        accept_err("sym",")")
        return { tag="call", f=f, args={e} }

    -- yield(...), emit(...)
    elseif accept("key","yield") or accept("key","emit") then
        local f = { tag="var", tk={tag="var", str=TK0.str, lin=TK0.lin} }
        accept_err("sym","(")
        local args = parser_list(",", ")", function () return parser_expr() end)
        accept_err("sym",")")
        return { tag="call", f=f, args=args }

    -- await(...)
    elseif accept("key","await") then
        local f = { tag="var", tk={tag="var", str="await", lin=TK0.lin} }
        accept_err("sym","(")
        local cnd = nil
        local e = parser_expr()
        if accept("sym",",") then
            local it = { tag="var", str="it", lin=TK0.lin }
            local e = parser_expr()
            local ret = { tag="return", e=e }
            cnd = { tag="func", pars={it}, blk={tag="block",ss={ret}} }
        end
        accept_err("sym",")")
        return { tag="call", f=f, args={e,cnd} }

    -- resume co(...), spawn T(...)
    elseif accept("key","resume") or accept("key","spawn") then
        local tk = TK0
        local cmd = { tag="var", tk={tag="var", str=TK0.str, lin=TK0.lin} }
        local call = parser_expr()
        if call.tag ~= "call" then
            err(tk, "expected call")
        end
        table.insert(call.args, 1, call.f)
        return { tag="call", f=cmd, args=call.args }

    -- func () { ... }
    elseif accept("key","func") then
        accept_err("sym","(")
        local pars = parser_list(",", ")", function () return accept_err("var") end)
        accept_err("sym",")")
        local ss = parser_curly()
        return { tag="func", pars=pars, blk={tag="block",ss=ss} }

    else
        err(TK1, "expected expression")
    end
end

function parser_expr_suf_2 (pre)
    local e = pre or parser_expr_prim_1()
    local ok = check("sym") and contains(OPS.sufs, TK1.str)
                -- TODO: same line
    if not ok then
        return e
    end

    local sym = accept_err("sym")

    local ret = nil
    if sym.str == '(' then
        local args = parser_list(",", ")", function () return parser_expr() end)
        accept_err("sym",')')
        ret = { tag="call", f=e, args=args }
    else
        error("TODO")
    end

    return parser_expr_suf_2(ret)
end

function parser_expr_pre_3 ()
    local ok = check("op") and contains(OPS.unos, TK1.str)
    if not ok then
        return parser_expr_suf_2()
    end
    local op = accept_err("op")
    local e = parser_expr_pre_3()
    return { tag="uno", op=op, e=e }
end

function parser_expr_bin_4 (pre)
    local e1 = pre or parser_expr_pre_3()
    local ok = check("op") and contains(OPS.bins, TK1.str)
    if not ok then
        return e1
    end
    local op = accept_err("op")
    if pre and pre.op.str ~= op.str then
        err(op, "binary operation error : use parentheses to disambiguate")
    end
    local e2 = parser_expr_pre_3()
    return parser_expr_bin_4 { tag="bin", op=op, e1=e1, e2=e2 }
end

parser_expr = parser_expr_bin_4
