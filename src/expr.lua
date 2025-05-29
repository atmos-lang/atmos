Expr = {}   -- solves mutual require with stmt.lua

_ = Parser or require "parser"

-- expr_6_out : v --> f     f <-- v    v where {...}    v thus {...}
-- expr_5_bin : a + b
-- expr_4_pre : -a    :T [...]
-- expr_3_met : v->f    f<-v
-- expr_2_suf : v[0]    v.x    v.1    v.(:T).x    f()
-- expr_1_prim

local function is_prefix (e)
    return (
        e.tag == 'tag'    or
        e.tag == 'acc'    or
        e.tag == 'nat'    or
        e.tag == 'call'   or
        e.tag == 'index'  or
        e.tag == 'parens'
    )
end

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

function parser_expr_3_met (pre)
    local e = pre or parser_expr_2_suf()
    if accept('->') then
        return parser_expr_3_met(method(parser_expr_2_suf(), e, true))
    elseif accept('<-') then
        return method(e, parser_expr_3_met(parser_expr_2_suf()), false)
    else
        return e
    end
end

function parser_expr_4_pre ()
    local ok = check(nil,'op') and contains(OPS.unos, TK1.str)
    if not ok then
        return parser_expr_3_met()
    end
    local op = accept_err(nil,'op')
    local e = parser_expr_4_pre()
    return { tag='uno', op=op, e=e }
end

function parser_expr_5_bin (pre)
    local e1 = pre or parser_expr_4_pre()
    local ok = check(nil,'op') and contains(OPS.bins, TK1.str)
    if not ok then
        return e1
    end
    local op = accept_err(nil,'op')
    if pre and pre.op.str ~= op.str then
        err(op, "binary operation error : use parentheses to disambiguate")
    end
    local e2 = parser_expr_4_pre()
    return parser_expr_5_bin { tag='bin', op=op, e1=e1, e2=e2 }
end
