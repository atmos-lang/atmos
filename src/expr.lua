Expr = {}   -- solves mutual require with stmt.lua

require "parser"
_ = Stmt or require "stmt"

function parser_expr_prim_1 ()
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

    -- x, __v
    elseif accept(nil,'id') then
        return { tag='acc', tk=TK0 }

    -- (...)
    elseif accept('(') then
        local e = parser_expr()
        accept_err(')')
        return e

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
            elseif accept(nil,'id') then
                local id = TK0
                if accept('=') then
                    id.str = ':'..id.str
                    key = { tag='tag', tk=id }
                    val = parser_expr()
                else
                    key = { tag='num', tk={tag='num',str=tostring(idx)} }
                    idx = idx + 1
                    val = { tag='acc', tk=id }
                end
            else
                key = { tag='num', tk={tag='num',str=tostring(idx)} }
                idx = idx + 1
                val = parser_expr()
            end
            return { k=key, v=val }
        end)
        accept_err(']')
        return { tag='table', ps=ps }

    -- coro(f), task(T), tasks(n)
    elseif accept('coro') or accept('task') or accept('tasks') then
        local f = { tag='acc', tk={tag='id',str=TK0.str,lin=TK0.lin} }
        accept_err('(')
        local e = parser_expr()
        accept_err(')')
        return { tag='call', f=f, args={e} }

    -- yield(...), emit(...)
    elseif accept('yield') or accept('emit') then
        local f = { tag='acc', tk={tag='id',str=TK0.str,lin=TK0.lin} }
        accept_err('(')
        local args = parser_list(',', ')', parser_expr)
        accept_err(')')
        return { tag='call', f=f, args=args }

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
        return { tag='call', f=f, args={xe,xf} }

    -- resume co(...), spawn T(...)
    elseif accept('resume') or accept('spawn') then
        local tk = TK0
        local cmd = { tag='acc', tk={tag='id', str=TK0.str, lin=TK0.lin} }
        local call = parser_expr()
        if call.tag ~= 'call' then
            err(tk, "expected call")
        end
        table.insert(call.args, 1, call.f)
        return { tag='call', f=cmd, args=call.args }

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
        return { tag='call', f=f, args={e, {tag='num',tk={str="0"}}} }

    -- func () { ... }
    elseif accept('func') then
        accept_err('(')
        local pars = parser_ids(')')
        accept_err(')')
        local ss = parser_curly()
        return { tag='func', pars=pars, blk={tag='block',ss=ss} }

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
        e.tag == 'call'  or
        e.tag == 'acc'   or
        e.tag == 'index' or
        TK0.str == ')'
    )
end

function parser_expr_suf_2 (pre)
    local e = pre or parser_expr_prim_1()
    local ok = check(nil,'sym') and contains(OPS.sufs, TK1.str)
                -- TODO: same line
    if not ok then
        return e
    end

    if not is_prefix(e) then
        local op; do
            if TK1.str == '(' then
                op = "call"
            elseif TK1.str == '[' then
                op = "index"
            elseif TK1.str == '.' then
                op = "field"
            else
                error("TODO")
            end
        end
        err(TK1, op.." error : expected prefix expression")
    end

    local sym = accept('~~') or accept('!~') or accept_err(nil,'sym')

    local ret = nil
    if sym.str == '(' then
        local args = parser_list(',', ')', parser_expr)
        accept_err(')')
        ret = { tag='call', f=e, args=args }
    elseif sym.str == '[' then
        local idx = parser_expr()
        accept_err(']')
        ret = { tag='index', t=e, idx=idx }
    elseif sym.str == '.' then
        local id = accept_err(nil,'id')
        id.str = ':'..id.str
        local idx = { tag='tag', tk=id }
        ret = { tag='index', t=e, idx=idx }
    elseif sym.str=='~~' or sym.str=='!~' then
        error("TODO - regex")
    else
        error("TODO")
    end

    return parser_expr_suf_2(ret)
end

function parser_expr_pre_3 ()
    local ok = check(nil,'op') and contains(OPS.unos, TK1.str)
    if not ok then
        return parser_expr_suf_2()
    end
    local op = accept_err(nil,'op')
    local e = parser_expr_pre_3()
    return { tag='uno', op=op, e=e }
end

function parser_expr_bin_4 (pre)
    local e1 = pre or parser_expr_pre_3()
    local ok = check(nil,'op') and contains(OPS.bins, TK1.str)
    if not ok then
        return e1
    end
    local op = accept_err(nil,'op')
    if pre and pre.op.str ~= op.str then
        err(op, "binary operation error : use parentheses to disambiguate")
    end
    local e2 = parser_expr_pre_3()
    return parser_expr_bin_4 { tag='bin', op=op, e1=e1, e2=e2 }
end

parser_expr = parser_expr_bin_4
