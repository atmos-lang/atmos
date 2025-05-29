Stmt = {}   -- solves mutual require with expr.lua

-- only_stmt: dcl, func, set, ...
    -- list of exprs, except last
-- only_expr: literals, index, parens, bins, mets
    -- middle of compund exprs
    -- last in list of exprs
-- both: call, if, ...

require "parser"
_ = Expr or require "expr"

local function spawn (lin, es)
    local cmd = { tag='acc', tk={tag='id', str='spawn', lin=lin} }
    local ts = { tag='nil', tk={tag='key',str='nil'} }
    local f = { tag='func', pars={}, blk={tag='block',es=es} }
    return { tag='call', f=cmd, args={ts,f}, custom="spawn" }
end

function parser_spawn ()
    accept_err('spawn')
    if check('{') then
        -- spawn { ... }
        return spawn(TK0.lin, parser_curly())
    else
        -- spawn T(...) [in ...]
        local tk = TK0
        local cmd = { tag='acc', tk={tag='id', str=TK0.str, lin=TK0.lin} }
        local call = parser_expr()
        local ts; do
            if accept('in') then
                ts = parser_expr()
            else
                ts = { tag='nil', tk={tag='key',str='nil'} }
            end
        end
        if call.tag ~= 'call' then
            err(tk, "expected call")
        end
        table.insert(call.args, 1, ts)
        table.insert(call.args, 2, call.f)
        return { tag='call', f=cmd, args=call.args, custom="spawn" }
    end
end

function parser_stmt ()
    if false then

    -- return(...)
    elseif accept('return') then
        accept_err('(')
        local es = parser_list(',', ')', parser_expr)
        accept_err(')')
        return { tag='return', es=es }

    -- par
    elseif accept('par') then
        local sss = { { TK1.lin, parser_curly() } }
        while accept('with') do
            sss[#sss+1] = { TK1.lin, parser_curly() }
        end
        local function f (t)
            return { tag='expr', e=spawn(t[1],t[2]) }
        end
        local es = map(sss,f)
        es[#es+1] = {
            tag = 'expr',
            e = {
                tag = 'call',
                f = { tag='acc', tk={tag='id',str='await'} },
                args = {
                    { tag='bool', tk={str='false'} },
                },
                custom = "await",
            },
        }
        return { tag='block', es=es }

    -- par_and
    elseif accept('par_and') then
        local n = N()
        local sss = { { TK1.lin, parser_curly() } }
        while accept('with') do
            sss[#sss+1] = { TK1.lin, parser_curly() }
        end
        local function f1 (t,i)
            return {
                tag  = 'dcl',
                tk   = { tag='key', str='pin' },
                ids  = { {tag='id', str='atm_'..n..'_'..i} },
                sets = { spawn(t[1],t[2]) },
            }
        end
        local function f2 (t,i)
            return {
                tag = 'expr',
                e = {
                    tag = 'call',
                    f = { tag='acc', tk={tag='id',str='await'} },
                    args = {
                        { tag='acc', tk={str='atm_'..n..'_'..i} },
                    },
                    custom = "await",
                },
            }
        end
        local ss1 = map(sss,f1)
        local ss2 = map(sss,f2)
        return { tag='block', es=concat(ss1,ss2) }

    -- par_or
    elseif accept('par_or') then
        local n = N()
        local sss = { { TK1.lin, parser_curly() } }
        while accept('with') do
            sss[#sss+1] = { TK1.lin, parser_curly() }
        end
        local function f1 (t,i)
            return {
                tag  = 'dcl',
                tk   = { tag='key', str='pin' },
                ids  = { {tag='id', str='atm_'..n..'_'..i} },
                sets = { spawn(t[1],t[2]) },
            }
        end
        local function f2 (i)
            if i > #sss then
                return { tag='bool', tk={str='false'} }
            else
                return {
                    tag = 'bin',
                    op  = {str = '||'},
                    e1  = {
                        tag = 'parens',
                        e = {
                            tag = 'bin',
                            op  = { str='==' },
                            e1  = { tag='acc', tk={str="evt"} },
                            e2  = { tag='acc', tk={str="atm_"..n..'_'..i} },
                        },
                    },
                    e2  = f2(i+1),
                }
            end
        end
        local es = map(sss,f1)
        local awt = {
            tag = 'expr',
            e = {
                tag = 'call',
                f = { tag='acc', tk={tag='id',str='await'} },
                args = {
                    { tag='bool', tk={str='true'} },
                    {
                        tag  = 'func',
                        pars = { {tag='id',str="evt"} },
                        blk  = {
                            tag = 'block',
                            es  = {
                                { tag='return', es={f2(1)} },
                            },
                        },
                    },
                },
                custom = "await",
            },
        }
        es[#es+1] = awt
        return { tag='block', es=es }

    -- watching
    elseif accept('watching') then
        local lin = TK0.lin
        local par = accept('(')
        local awt = parser_await(lin)
        if par then
            accept_err(')')
        end
        local lin = TK1.lin
        local es = parser_curly()
        local spw = {
            tag  = 'dcl',
            tk   = { tag='key', str='val' },
            ids  = { {tag='id', str='_'} },
            sets = { spawn(lin,es) },
        }
        return { tag='block', es={spw, {tag='expr',e=awt}} }

    -- call: f(), nat: `xxx`
    else
        local tk = TK1
        local e = parser_expr()
        if e.tag=='call' or e.tag=='nat' then
            return { tag='expr', e=e }
        else
            err(tk, "expected statement")
        end
    end
end
