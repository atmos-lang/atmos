Expr = {}   -- solves mutual require with stmt.lua

require "parser"
_ = Stmt or require "stmt"

function parser_expr_1_prim ()
    -- nil
    if accept('nil') then
        return { tag='nil', tk=TK0 }

    -- true, false
    elseif accept('true') or accept('false') then
        return { tag='bool', tk=TK0 }

    -- :tag
    elseif accept(nil,'tag') then
        return { tag='tag', tk=TK0 }

    -- 10, 0xFF
    elseif accept(nil,'num') then
        return { tag='num', tk=TK0 }

    -- 'xxx', """xxx"""
    elseif accept(nil,'str') then
        return { tag='str', tk=TK0 }

    -- ...
    elseif accept('...') then
        return { tag='dots', tk=TK0 }

    -- x, __v
    elseif accept(nil,'id') then
        return { tag='acc', tk=TK0 }

    -- (...)
    elseif accept('(') then
        local tk = TK0
        local e = parser_expr()
        accept_err(')')
        return { tag='parens', tk=tk, e=e }

    -- [ ... ]
    elseif accept('[') then
        local idx = 1
        local ps = parser_list(',', ']', function ()
            local key
            if accept('(') then
                key = parser_expr()
                accept_err(',')
                val = parser_expr()
                accept_err(')')
            else
                local e = parser_expr()
                if e.tag=='acc' and accept('=') then
                    local id = { tag='tag', str=':'..e.tk.str }
                    key = { tag='tag', tk=id }
                    val = parser_expr()
                else
                    key = { tag='num', tk={tag='num',str=tostring(idx)} }
                    idx = idx + 1
                    val = e
                end
            end
            return { k=key, v=val }
        end)
        accept_err(']')
        return { tag='table', ps=ps }

    -- coro(f)
    elseif accept('coro') then
        local f = { tag='acc', tk={tag='id',str="coro",lin=TK0.lin} }
        accept_err('(')
        local e = parser_expr()
        accept_err(')')
        return { tag='call', f=f, args={e}, custom="coro" }

    -- task(T)
    elseif accept('task') then
        local f = { tag='acc', tk={tag='id',str="task",lin=TK0.lin} }
        accept_err('(')
        local e = parser_expr()
        accept_err(')')
        return { tag='call', f=f, args={e}, custom="task" }

    -- yield(...)
    elseif accept('yield') then
        local f = { tag='acc', tk={tag='id',str=TK0.str,lin=TK0.lin} }
        accept_err('(')
        local args = parser_list(',', ')', parser_expr)
        accept_err(')')
        return { tag='call', f=f, args=args, custom="yield" }

    -- emit(...) in t
    elseif accept('emit') then
        local f = { tag='acc', tk={tag='id',str=TK0.str,lin=TK0.lin} }
        accept_err('(')
        local args = parser_list(',', ')', parser_expr)
        accept_err(')')
        local to; do
            if accept('in') then
                to = parser_expr()
            else
                to = { tag='nil', tk={tag='key',str='nil',lin=TK0.lin} }
            end
        end
        table.insert(args, 1, to)
        return { tag='call', f=f, args=args, custom="emit" }

    -- await(...)
    elseif accept('await') then
        local f = { tag='acc', tk={tag='id',str='await',lin=TK0.lin} }
        accept_err('(')
        local xe = parser_expr()
        local xf = nil
        if accept(',') then
            local it = { tag='id', str="it" }
            local xe = parser_expr()
            local ret = { tag='return', es={xe} }
            xf = { tag='func', pars={it}, blk={tag='block',ss={ret}} }
        end
        accept_err(')')
        return { tag='call', f=f, args={xe,xf}, custom="await" }

    -- resume co(...)
    elseif accept('resume') then
        local tk = TK0
        local cmd = { tag='acc', tk={tag='id', str='resume', lin=TK0.lin} }
        local call = parser_expr()
        if call.tag ~= 'call' then
            err(tk, "expected call")
        end
        table.insert(call.args, 1, call.f)
        return { tag='call', f=cmd, args=call.args, custom="resume" }

    -- throw(err)
    elseif accept('throw') then
        local f = { tag='acc', tk={tag='id', str="error", lin=TK0.lin} }
        accept_err('(')
        local e; do
            if check(')') then
                e = { tag='nil', tk={tag='key',str='nil',lin=TK0.lin} }
            else
                e = parser_expr()
            end
        end
        accept_err(')')
        return { tag='call', f=f, args={e, {tag='num',tk={str="0"}}}, custom="throw" }

    -- func () { ... }
    elseif accept('func') then
        accept_err('(')
        local dots, pars = parser_dots_pars()
        accept_err(')')
        local ss = parser_curly()
        return { tag='func', dots=dots, pars=pars, blk={tag='block',ss=ss} }

    -- if x => y => z
    elseif accept('if') then
        local cnd = parser_expr()
        accept_err('=>')
        local t = parser_expr()
        accept_err('=>')
        local f = parser_expr()
        return { tag='bin', op={str='or'}, e1={tag='bin',op={str='and'},e1=cnd,e2=t}, e2=f }

    else
        err(TK1, "expected expression")
    end
end

local function is_prefix (e)
    return (
        e.tag == 'tag'    or
        e.tag == 'acc'    or
        e.tag == 'call'   or
        e.tag == 'index'  or
        e.tag == 'parens'
    )
end


-- expr_5_out : v --> f     f <-- v    v where {...}    v thus {...}
-- expr_4_bin : a + b
-- expr_3_pre : -a    :T [...]
-- expr_X_met : v->f    f<-v
-- expr_2_suf : v[0]    v.x    v.1    v.(:T).x    f()
-- expr_1_prim

function parser_expr_2_suf (pre)
    local e = pre or parser_expr_1_prim()
    local ok = (TK0.lin==TK1.lin) and is_prefix(e)
    if not ok then
        return e
    end

    local ret = nil
    if e.tag=='tag' and (check'(' or check'[') then
        local t = parser_expr()
        local f = { tag='acc', tk={tag='id',str="atm_tag"} }
        ret = { tag='call', f=f, args={e,t} }
    elseif accept('(') then
        local args = parser_list(',', ')', parser_expr)
        accept_err(')')
        ret = { tag='call', f=e, args=args }
--[[
    elseif check('[') or check(nil,'str') then
        local v = parser_expr_prim_1()
        ret = { tag='call', f=e, args={v} }
]]
    elseif accept('[') then
        local idx = parser_expr()
        accept_err(']')
        ret = { tag='index', t=e, idx=idx }
    elseif accept('.') then
        local id = accept_err(nil,'id')
        id = { tag='tag', str=':'..id.str }
        local idx = { tag='tag', tk=id }
        ret = { tag='index', t=e, idx=idx }
    else
        -- nothing consumed, not a suffix
        return e
    end

    return parser_expr_2_suf(ret)
end

local function method (f, e, pre)
    if f.tag == 'call' then
        if pre then
            table.insert(f.args, 1, e)
        else
            f.args[#f.args+1] = e
        end
        return f
    else
        return { tag='call', f=f, args={e} }
    end
end

function parser_expr_X_met (pre)
    local e = pre or parser_expr_2_suf()
    if accept('->') then
        return parser_expr_X_met(method(parser_expr_2_suf(), e, true))
    elseif accept('<-') then
        return method(e, parser_expr_X_met(parser_expr_2_suf()), false)
    else
        return e
    end
end

function parser_expr_3_pre ()
    local ok = check(nil,'op') and contains(OPS.unos, TK1.str)
    if not ok then
        return parser_expr_X_met()
    end
    local op = accept_err(nil,'op')
    local e = parser_expr_3_pre()
    return { tag='uno', op=op, e=e }
end

function parser_expr_bin_4 (pre)
    local e1 = pre or parser_expr_3_pre()
    local ok = check(nil,'op') and contains(OPS.bins, TK1.str)
    if not ok then
        return e1
    end
    local op = accept_err(nil,'op')
    if pre and pre.op.str ~= op.str then
        err(op, "binary operation error : use parentheses to disambiguate")
    end
    local e2 = parser_expr_3_pre()
    return parser_expr_bin_4 { tag='bin', op=op, e1=e1, e2=e2 }
end

parser_expr = parser_expr_bin_4
