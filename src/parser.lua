require "atmos.lang.prim"

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

-- field name: keyword or identifier
function accept_field_err ()
    return accept(nil,'key') or accept_err(nil,'id')
end

-------------------------------------------------------------------------------

function parser_list (sep, clo, one)
    assert(sep or clo)
    if clo == nil then
        clo = function () return false end
    elseif type(clo) == 'function' then
        -- ok
    else
        local x = clo
        clo = function () return check(x) end
    end
    local l = {}
    if clo() then
        return l
    end
    l[#l+1] = one(#l+1)
    while true do
        if clo() then
            return l
        end
        if sep then
            if check(sep) then
                accept_err(sep)
                if clo() then
                    return l
                end
            else
                return l
            end
        end
        --[[
        -- HACK-01: flatten "seq" into list
        if one == parser_stmt then
            local es = one()
            if es.tag == "seq" then
                for _,s in ipairs(es) do
                    l[#l+1] = s
                end
            else
                l[#l+1] = es
            end
        else
            l[#l+1] = one()
        end
        ]]
        l[#l+1] = one(#l+1)
    end
    return l
end

function parser_list_1 (sep, clo, one)
    local tk = TK0
    local ret = parser_list(sep, clo, one)
    if #ret == 0 then
        err(tk, "unexpected empty list")
    end
    return ret
end

function parser_ids (clo)
    return parser_list_1(",", clo, function () return accept_err(nil,'id') end)
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

function parser_stmts (clo)
    return parser_list(nil, clo,
        function (i)
            if i>1 and TK0.sep==TK1.sep then
                err(TK1, "sequence error : expected ';' or new line")
            end
            return parser()
        end
    )
end

function parser_lambda ()
    accept_err('\\')

    -- normal lambda: \(){}
    if not check(nil, 'op') then
        local dots = false
        local pars = {
            { tag='id', str="it" },
        }
        if accept('(') then
            dots, pars = parser_dots_pars()
            accept_err(')')
        elseif accept(nil,'id') then
            pars = { TK0 }
        end
        check_err('{')
        local blk = parser_block()
        return { tag='proto', sub='func', dots=dots, pars=pars, blk=blk }

    -- lambda operator: \- \++
    else
        local op = accept_err(nil, 'op')
        if contains(OPS.bins, op.str) then
            local a = { tag='id', str='a' }
            local b = { tag='id', str='b' }
            return {
                tag  = 'proto',
                sub  = 'func',
                dots = false,
                pars = { a, b },
                blk  = {
                    tag = 'block',
                    es  = {
                        {
                            tag = 'bin',
                            op  = op,
                            e1  = {
                                tag='acc', tk=a
                            },
                            e2  = {
                                tag='acc', tk=b
                            },
                        }
                    }
                }
            }
        elseif contains(OPS.unos, op.str) then
            local a = { tag='id', str='a' }
            return {
                tag  = 'proto',
                sub  = 'func',
                dots = false,
                pars = { a },
                blk  = {
                    tag = 'block',
                    es  = {
                        {
                            tag = 'uno',
                            op  = op,
                            e   = {
                                tag='acc', tk=a
                            },
                        }
                    }
                }
            }
        else
            err(op, "lambda error : invalid operator")
        end
    end
end

function parser_block ()
    accept_err('{')
    local es = parser_stmts('}')
    accept_err('}')
    return { tag='block', es=es }
end

function parser_main ()
    local es = parser_stmts('<eof>')
    accept_err('<eof>')
    return { tag='do', blk={tag='block',es=es} }
end

-------------------------------------------------------------------------------

-- 7_out : v where {...}
-- 6_pip : v --> f     f <-- v
-- 5_bin : a + b
-- 4_pre : -a
-- 3_met : v->f    f<-v
-- 2_suf : v@(0)   v.x    x::m()   f()
--         :X() :X[]
--         f[] f"" f``
-- 1_prim

local function is_prefix (e)
    return (
        e.tag == 'tag'    or
        e.tag == 'acc'    or
        e.tag == 'nat'    or
        e.tag == 'call'   or
        e.tag == 'met'    or
        e.tag == 'index'  or
        e.tag == 'parens'
    )
end

local function check_call_arg ()
    return check('[') or check('\\') or
           check(nil,'str') or check(nil,'tag') or
           check(nil,'nat') or check(nil,'clk')
end

-- @-qualifier (after '@' is consumed): @(e) | bare @num | @id | @:tag.
-- shared by index, table key, pool, emit-target.
-- ret==true : return false on no-match so the caller can continue
-- (used by index, which then handles the @# / @+ tip markers).
function parser_at (ret)
    if accept('(') then
        local e = parser()
        accept_err(')')
        return e
    elseif accept(nil,'tag') then
        return { tag='tag', tk=TK0 }
    elseif check(nil,'num') or check(nil,'id') then
        return parser_1_prim()
    elseif ret then
        return false
    else
        err(TK1, "expected name, number, tag, or '('")
    end
end

function parser_2_suf (pre)
    local no = check('emit') or check('spawn') or
               check('toggle') or check('thread')
    local e = pre or parser_1_prim()

    local ok = (not no) and is_prefix(e) and (
        TK0.sep==TK1.sep or TK1.str=='@' or TK1.str=='.' or TK1.str=='::'
    )
    if not ok then
        return e
    end

    local ret

    if accept('@') then
        local tk0 = TK0 -- @
        local idx = parser_at(true)         -- @(e) | @num | @id (or false)
        if not idx then
            if accept('#') then             -- t@#  (last item)
                idx = { tag='uno', op=TK0, e=e }
            elseif accept('+') then         -- t@+  (next item: #t+1)
                local len = { tag='op', str='#', lin=tk0.lin, sep=tk0.sep }
                local add = { tag='op', str='+', lin=tk0.lin, sep=tk0.sep }
                local one = { tag='num', tk={ tag='num', str='1' } }
                idx = {
                    tag = 'bin',
                    op  = add,
                    e1  = { tag='uno', op=len, e=e },
                    e2  = one,
                }
            else
                err(TK1, "expected name, number, or '('")
            end
        end
        ret = { tag='index', t=e, idx=idx }
    elseif accept('.') then
        -- (t) .id
        local id = accept_field_err()
        id = { tag='tag', str=':'..id.str }
        local idx = { tag='tag', tk=id }
        ret = { tag='index', t=e, idx=idx }
    elseif accept('::') then
        -- (o) ::m
        local id = accept_field_err()
        local _ = check_call_arg() or check_err('(')
        ret = { tag='met', o=e, met=id }
    elseif accept('(') then
        -- (f) (...)
        local es = parser_list(',', ')', parser)
        accept_err(')')
        ret = { tag='call', f=e, es=es }
    elseif check_call_arg() then
        local v = parser_1_prim()
        ret = { tag='call', f=e, es={v} }
    else
        -- nothing consumed, not a suffix
        return e
    end

    return parser_2_suf(ret)
end

local function pipe (f, e, pre)
    local out = f
    while f.tag == 'parens' do
        f = f.e
    end
    if f.tag == 'call' then
        if pre then
            table.insert(f.es, 1, e)
        else
            f.es[#f.es+1] = e
        end
        return out
    else
        return { tag='call', f=out, es={e} }
    end
end

function parser_3_met (pre)
    local e = pre or parser_2_suf()
    if accept('->') then
        return parser_3_met(pipe(parser_2_suf(), e, true))
    elseif accept('<-') then
        return pipe(e, parser_3_met(parser_2_suf()), false)
    else
        return e
    end
end

function parser_4_pre (pre)
    local ok = check(nil,'op') and contains(OPS.unos, TK1.str)
    if not ok then
        return parser_3_met(pre)
    end
    local op = accept_err(nil,'op')
    local e = parser_4_pre()
    return { tag='uno', op=op, e=e }
end

function parser_5_bin (pre)
    local e1 = pre or parser_4_pre()
    local ok = check(nil,'op') and contains(OPS.bins, TK1.str) --and (TK0.lin==TK1.lin)
    if not ok then
        return e1
    end
    local op = accept_err(nil,'op')
    if pre and pre.op.str~=op.str then
        err(op, "operation error : use parentheses to disambiguate")
    end
    local e2 = parser_4_pre()
    return parser_5_bin { tag='bin', op=op, e1=e1, e2=e2 }
end

function parser_6_pip (pre)
    local e = pre or parser_5_bin()
    local ok = true --(TK0.lin==TK1.lin)
    if not ok then
        return e
    end

    local op = check('-->') or check('<--')
    if pre and op and pre.op and pre.op.str~=op.str then
        err(op, "operation error : use parentheses to disambiguate")
    end

    local ret
    if accept('-->') then
        ret = pipe(parser_5_bin(), e, true)
    elseif accept('<--') then
        -- right to left
        local pre = parser_6_pip()
        if pre.op and pre.op.str == '-->' then
            err(pre.op, "operation error : use parentheses to disambiguate")
        end
        return pipe(e, pre, false)
    else
        -- nothing consumed, not an out
        return e
    end

    ret.op = op
    return parser_6_pip(ret)
end

function parser_7_out (pre)
    local e = pre or parser_6_pip()
    local ok = true --(TK0.lin==TK1.lin)
    if not ok then
        return e
    end

    local op = check('where')
    if pre and op and pre.op and pre.op.str~=op.str then
        err(op, "operation error : use parentheses to disambiguate")
    end

    local ret
    if accept('where') then
        accept_err("{")
        local ss = parser_list(nil, '}',
            function ()
                local ids = parser_ids('=')
                accept_err('=')
                local set = parser()
                return { tag='dcl', tk={str='val'}, ids=ids, set=set }
            end
        )
        accept_err("}")
        ss[#ss+1] = e
        ret = {
            tag = 'call',
            f = {
                tag = 'proto',
                sub = 'lua',
                pars = {},
                blk = {
                    tag = 'block',
                    es = ss,
                },
            },
            es = {}
        }
    else
        -- nothing consumed, not an out
        return e
    end

    ret.op = op
    return parser_7_out(ret)
end

function parser (...)
    -- regardless of ..., must pass nothing to out()
    return parser_7_out()
end
