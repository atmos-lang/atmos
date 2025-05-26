Stmt = {}   -- solves mutual require with expr.lua

require "parser"
_ = Expr or require "expr"

function parser_curly ()
    accept_err('{')
    local ss = parser_list(null, '}', parser_stmt)
    accept_err('}')
    return ss
end

function parser_spawn ()
    accept_err('spawn')
    if check('{') then
        -- spawn { ... }
        local cmd = { tag='acc', tk={tag='id', str='spawn', lin=TK0.lin} }
        local ts = { tag='nil', tk={tag='key',str='nil'} }
        local ss = parser_curly()
        local f = { tag='func', pars={}, blk={tag='block',ss=ss} }
        return { tag='call', f=cmd, args={ts,f}, custom="spawn" }
    else
        -- spawn T(...)
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

    -- var x = 10
    elseif accept('val') or accept('var') or accept('pin') then
        local tk = TK0
        local ids = parser_ids('=')
        local sets
        local custom
        if accept('=') then
            if check('do') then
                local tk = TK1
                local blk = parser_stmt()
                if blk.esc == nil then
                    err(tk, "expected tagged block")
                end
                custom = 'block'
                sets = { blk }
            elseif check('catch') then
                local cat = parser_stmt()
                custom = 'catch'
                sets = { cat }
            elseif check('spawn') then
                local tk1 = TK1
                local spw = parser_spawn()
                custom = 'spawn'
                if tk.str=='pin' and spw.args[1].tag~='nil' then
                    err(tk1, "invalid spawn in : unexpected pin declaraion")
                elseif tk.str~='pin' and spw.args[1].tag=='nil' then
                    err(tk1, "invalid spawn : expected pin declaraion")
                end
                sets = { spw }
            elseif accept('tasks') then
                -- tasks(n)
                custom = 'tasks'
                if tk.str ~= 'pin' then
                    err(TK0, "invalid tasks : expected pin declaraion")
                end
                local f = { tag='acc', tk={tag='id',str="tasks",lin=TK0.lin} }
                accept_err('(')
                local e
                if not check(')') then
                    e = parser_expr()
                end
                accept_err(')')
                local ts = { tag='call', f=f, args={e}, custom="tasks" }
                sets = { ts }

            else
                sets = parser_list(',', nil, parser_expr)
            end
        end
        return { tag='dcl', tk=tk, ids=ids, sets=sets, custom=custom }

    -- set x = 10
    elseif accept('set') then
        local dsts = parser_list(',', '=', function ()
            local tk = TK1
            local e = parser_expr()
            if e.tag=='acc' or e.tag=='index' then
                -- ok
            else
                err(tk, "expected assignable expression")
            end
            return e
        end)
        accept_err('=')
        local srcs = parser_list(',', nil, parser_expr)
        return { tag='set', dsts=dsts, srcs=srcs }

    -- func () { ... }
    elseif accept('func') then
        local id = accept_err(nil,'id')
        accept_err('(')
        local dots, pars = parser_dots_pars()
        accept_err(')')
        local ss = parser_curly()
        local f = { tag='func', dots=dots, pars=pars, blk={tag='block',ss=ss} }
        return { tag='dcl', tk={tag='key',str='var'}, ids={id}, sets={f}, custom='func' }

    -- do { ... }, defer { ... }
    elseif accept('do') then
        local tag = accept(nil,'tag')
        local ss  = parser_curly()
        return { tag='block', esc=tag, ss=ss }
    elseif accept('defer') then
        local ss = parser_curly()
        return { tag='defer', blk={tag='block',ss=ss} }

    -- escape(:X)
    elseif accept('escape') then
        accept_err('(')
        local tag = check_err(nil, 'tag')
        local e = parser_expr()
        if accept(',') then
            e = parser_expr()
        end
        accept_err(')')
        return { tag='escape', esc=tag, e=e }

    -- return(...)
    elseif accept('return') then
        accept_err('(')
        local es = parser_list(',', ')', parser_expr)
        accept_err(')')
        return { tag='return', es=es }

    -- if-else
    elseif accept('if') then
        local cnd = parser_expr()
        local t = parser_curly()
        local f; do
            if accept('else') then
                f = parser_curly()
            else
                f = {}
            end
        end
        return { tag='if', cnd=cnd, t={tag='block',ss=t}, f={tag='block',ss=f} }

    -- loop
    elseif accept('loop') then
        local ids = check(nil,'id') and parser_ids('=') or nil
        local itr = nil
        if accept('in') then
            itr = parser_expr()
        end
        local ss = parser_curly()
        return { tag='loop', ids=ids, itr=itr, blk={tag='block',ss=ss} }

    -- break, until, while
    elseif accept('break') then
        return { tag='break' }
    elseif accept('until') or accept('while') then
        local whi = (TK0.str == 'while')
        local cnd = parser_expr()
        local t = { tag='block', ss={{tag='break'}} }
        local f = { tag='block', ss={} }
        if whi then
            t, f = f, t
        end
        return { tag='if', cnd=cnd, t=t, f=f }

    -- catch
    elseif accept('catch') then
        local xe = parser_expr()
        local xf = nil
        if accept(',') then
            local it = { tag='id', str="it" }
            local e = parser_expr()
            local ret = { tag='return', es={e} }
            xf = { tag='func', pars={it}, blk={tag='block',ss={ret}} }
        end
        local ss = parser_curly()
        return { tag='catch', cnd={e=xe,f=xf}, blk={tag='block',ss=ss} }

    elseif check('spawn') then
        local spw = parser_spawn()
        if spw.args[1].tag == 'nil' then
            local pin = {tag='key',str='pin'}
            local id = { tag='id',str='_' }
            return { tag='dcl', tk=pin, ids={id}, sets={spw} }
        else
            return { tag='expr', e=spw }
        end

    -- call: f()
    else
        local tk = TK1
        local e = parser_expr()
        if e.tag == 'call' then
            return { tag='expr', e=e }
        else
            err(tk, "expected statement")
        end
    end
end

function parser_main ()
    local ss = parser_list(null, '<eof>', parser_stmt)
    accept_err('<eof>')
    return { tag='block', ss=ss }
end
