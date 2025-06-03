require "prim"

-------------------------------------------------------------------------------

function check (str, tag)
    return (tag==nil or TK1.tag==tag) and (str==nil or TK1.str==str) and TK1 or nil
end
function check_no_err (str, tag)
    local tk = check(str, tag)
    if tk then
        err(TK1, "unexpected "..((str and "'"..str.."'") or (tag and '<'..tag..'>')))
    end
    return tk
end
function check_err (str, tag)
    local tk = check(str, tag)
    if not tk then
        err(TK1, "expected "..((str and "'"..str.."'") or (tag and '<'..tag..'>')))
    end
    return tk
end
function accept (str, tag)
    local tk = check(str, tag)
    if tk then
        lexer_next()
    end
    return tk
end
function accept_err (str, tag)
    local tk = check_err(str, tag)
    lexer_next()
    return tk
end

-------------------------------------------------------------------------------

function parser_list (sep, clo, f)
    assert(sep or clo)
    local l = {}
    if clo and check(clo) then
        return l
    end
    l[#l+1] = f()
    while true do
        if clo and check(clo) then
            return l
        end
        if sep then
            if check(sep) then
                accept_err(sep)
                if clo and check(clo) then
                    return l
                end
            else
                return l
            end
        end
        --[[
        -- HACK-01: flatten "seq" into list
        if f == parser_stmt then
            local es = f()
            if es.tag == "seq" then
                for _,s in ipairs(es) do
                    l[#l+1] = s
                end
            else
                l[#l+1] = es
            end
        else
            l[#l+1] = f()
        end
        ]]
        l[#l+1] = f()
    end
    return l
end

function parser_ids (clo)
    return parser_list(",", clo, function () return accept_err(nil,'id') end)
end

function parser_dots_pars ()
    if accept('...') then
        return true, {}
    else
        local l = {}
        if check(')') then
            return false, l
        end
        l[#l+1] = accept_err(nil,'id')
        while not check(')') do
            accept_err(sep)
            if accept('...') then
                return true, l
            end
            l[#l+1] = accept(nil,'id')
        end
        return false, l
    end
end

function parser_block ()
    accept_err('{')
    local es = parser_list(nil, '}', parser)
    accept_err('}')
    return { tag='block', es=es }
end

function parser_main ()
    local es = parser_list(nil, '<eof>', parser)
    accept_err('<eof>')
    return { tag='do', blk={tag='block',es=es} }
end

-------------------------------------------------------------------------------

-- 6_out : v --> f     f <-- v    v where {...}    v thus {...}
-- 5_bin : a + b
-- 4_pre : -a    :T [...]
-- 3_met : v->f    f<-v
-- 2_suf : v[0]    v.x    v.1    v.(:T).x    f()    x::m()
-- 1_prim

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

function parser_2_suf (pre)
    local e = pre or parser_1_prim()
    local ok = (TK0.lin==TK1.lin) and is_prefix(e)
    if not ok then
        return e
    end

    local ret
    if e.tag=='tag' and (check'(' or check'@{' or check'#{') then
        local t = parser()
        local f = { tag='acc', tk={tag='id',str="atm_tag_do"} }
        ret = { tag='call', f=f, args={e,t} }
    elseif accept('(') then
        local args = parser_list(',', ')', parser)
        accept_err(')')
        ret = { tag='call', f=e, args=args }
    elseif check('@{') or check('#{') or check(nil,'str') then
        local v = parser_1_prim()
        ret = { tag='call', f=e, args={v} }
    elseif accept('[') then
        local idx = parser()
        accept_err(']')
        ret = { tag='index', t=e, idx=idx }
    elseif accept('.') then
        local id = accept_err(nil,'id')
        id = { tag='tag', str=':'..id.str }
        local idx = { tag='tag', tk=id }
        ret = { tag='index', t=e, idx=idx }
    elseif accept('::') then
        local id = accept_err(nil,'id')
        accept_err('(')
        local args = parser_list(',', ')', parser)
        accept_err(')')
        table.insert(args, 1, copy(e))
        local f = {
            tag = 'index',
            t   = e,
            idx = { tag='str', tk=id },
        }
        ret = { tag='call', f=f, args=args }
    else
        -- nothing consumed, not a suffix
        return e
    end

    return parser_2_suf(ret)
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

function parser_3_met (pre)
    local e = pre or parser_2_suf()
    if accept('->') then
        return parser_3_met(method(parser_2_suf(), e, true))
    elseif accept('<-') then
        return method(e, parser_3_met(parser_2_suf()), false)
    else
        return e
    end
end

function parser_4_pre ()
    local ok = check(nil,'op') and contains(OPS.unos, TK1.str)
    if not ok then
        return parser_3_met()
    end
    local op = accept_err(nil,'op')
    local e = parser_4_pre()
    return { tag='uno', op=op, e=e }
end

function parser_5_bin (pre)
    local e1 = pre or parser_4_pre()
    local ok = check(nil,'op') and contains(OPS.bins, TK1.str)
    if not ok then
        return e1
    end
    local op = accept_err(nil,'op')
    if pre and pre.op.str ~= op.str then
        err(op, "binary operation error : use parentheses to disambiguate")
    end
    local e2 = parser_4_pre()
    return parser_5_bin { tag='bin', op=op, e1=e1, e2=e2 }
end

function parser_6_out (pre)
    local e = pre or parser_5_bin()
    local ok = (TK0.lin==TK1.lin)
    if not ok then
        return e
    end

    local ret
    if accept('where') then
        accept_err("{")
        local ss = parser_list(nil, '}',
            function ()
                local id = accept(nil, 'id')
                accept_err('=')
                local set = parser()
                return { tag='dcl', tk={str='val'}, ids={id}, set=set }
            end
        )
        accept_err("}")
        ss[#ss+1] = e
        ret = {
            tag = 'parens',
            e = {
                tag = 'call',
                f = {
                    tag = 'func',
                    pars = {},
                    blk = {
                        tag = 'block',
                        es = ss,
                    },
                },
                args = {}
            },
        }
    else
        -- nothing consumed, not an out
        return e
    end

    return parser_6_out(ret)
end

parser = parser_6_out
