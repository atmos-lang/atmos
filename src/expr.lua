Expr = {}   -- solves mutual require with stmt.lua

require "parser"
_ = Stmt or require "stmt"

function parser_expr_prim_1 ()
    -- nil
    if accept("nil") then
        return { tag="nil", tk=TK0 }

    -- true, false
    elseif accept("true") or accept("false") then
        return { tag="bool", tk=TK0 }

    -- :tag
    elseif accept(nil,"tag") then
        return { tag="tag", tk=TK0 }

    -- 10, 0xFF
    elseif accept(nil,"num") then
        return { tag="num", tk=TK0 }

    -- x, __v
    elseif accept(nil,"var") then
        return { tag="var", tk=TK0 }

    -- (...)
    elseif accept("(") then
        local e = parser_expr()
        accept_err(")")
        return e

    -- [ ... ]
    elseif accept("[") then
        local idx = 1
        local ps = parser_list(",", "]", function ()
            local key
            if accept("(") then
                key = parser_expr()
                accept_err(",")
                val = parser_expr()
                accept_err(")")
            elseif accept(nil,"var") then
                local id = TK0
                if accept("=") then
                    key = { tag="str", tk=id }
                    val = parser_expr()
                else
                    key = { tag="num", tk={tag="num",str=tostring(idx)} }
                    idx = idx + 1
                    val = { tag="var", tk=id }
                end
            else
                key = { tag="num", tk={tag="num",str=tostring(idx)} }
                idx = idx + 1
                val = parser_expr()
            end
            return { k=key, v=val }
        end)
        accept_err("]")
        return { tag="table", ps=ps }

    -- coro(f), task(T), tasks(n)
    elseif accept("coro") or accept("task") or accept("tasks") then
        local f = { tag="var", tk={tag="var", str=TK0.str} }
        accept_err("(")
        local e = parser_expr()
        accept_err(")")
        return { tag="call", f=f, args={e} }

    -- yield(...), emit(...)
    elseif accept("yield") or accept("emit") then
        local f = { tag="var", tk={tag="var", str=TK0.str} }
        accept_err("(")
        local args = parser_list(",", ")", parser_expr)
        accept_err(")")
        return { tag="call", f=f, args=args }

    -- await(...)
    elseif accept("await") then
        local f = { tag="var", tk={tag="var", str="await"} }
        accept_err("(")
        local e = parser_expr()
        local cnd = nil
        if accept(",") then
            local it = { tag="var", str="it" }
            local e = parser_expr()
            local ret = { tag="return", e=e }
            cnd = { tag="func", pars={it}, blk={tag="block",ss={ret}} }
        end
        accept_err(")")
        return { tag="call", f=f, args={e,cnd} }

    -- resume co(...), spawn T(...)
    elseif accept("resume") or accept("spawn") then
        local tk = TK0
        local cmd = { tag="var", tk={tag="var", str=TK0.str} }
        local call = parser_expr()
        if call.tag ~= "call" then
            err(tk, "expected call")
        end
        table.insert(call.args, 1, call.f)
        return { tag="call", f=cmd, args=call.args }

    -- func () { ... }
    elseif accept("func") then
        accept_err("(")
        local pars = parser_list(",", ")", function () return accept_err(nil,"var") end)
        accept_err(")")
        local ss = parser_curly()
        return { tag="func", pars=pars, blk={tag="block",ss=ss} }

    else
        err(TK1, "expected expression")
    end
end

function parser_expr_suf_2 (pre)
    local e = pre or parser_expr_prim_1()
    local ok = check(nil,"sym") and contains(OPS.sufs, TK1.str)
                -- TODO: same line
    if not ok then
        return e
    end

    local sym = accept_err(nil,"sym")

    local ret = nil
    if sym.str == '(' then
        local args = parser_list(",", ")", parser_expr)
        accept_err(')')
        ret = { tag="call", f=e, args=args }
    else
        error("TODO")
    end

    return parser_expr_suf_2(ret)
end

function parser_expr_pre_3 ()
    local ok = check(nil,"op") and contains(OPS.unos, TK1.str)
    if not ok then
        return parser_expr_suf_2()
    end
    local op = accept_err(nil,"op")
    local e = parser_expr_pre_3()
    return { tag="uno", op=op, e=e }
end

function parser_expr_bin_4 (pre)
    local e1 = pre or parser_expr_pre_3()
    local ok = check(nil,"op") and contains(OPS.bins, TK1.str)
    if not ok then
        return e1
    end
    local op = accept_err(nil,"op")
    if pre and pre.op.str ~= op.str then
        err(op, "binary operation error : use parentheses to disambiguate")
    end
    local e2 = parser_expr_pre_3()
    return parser_expr_bin_4 { tag="bin", op=op, e1=e1, e2=e2 }
end

parser_expr = parser_expr_bin_4
