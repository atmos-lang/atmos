function parser_await (lin)
    local clk = accept(nil,'clk')
    if clk then
        local function f (v, mul)
            if tonumber(v) then
                return { tag='bin', op={str='*'}, e1={tag='num',tk={str=v}}, e2={tag='num',tk={str=tostring(mul)}} }
            else
                return { tag='bin', op={str='*'}, e1={tag='acc',tk={str=v}}, e2={tag='num',tk={str=tostring(mul)}} }
            end
        end
        local clk = clk.clk; do
            clk[1] = f(clk[1], 60*60*1000)
            clk[2] = f(clk[2], 60*1000)
            clk[3] = f(clk[3], 1000)
            clk[4] = f(clk[4], 1)
        end

        local vs = map(clk, f)
        local sum = {
            tag = 'bin',
            op  = {str='+'},
            e1  = clk[1],
            e2  = {
                tag = 'bin',
                op  = {str='+'},
                e1  = clk[2],
                e2  = {
                    tag = 'bin',
                    op  = {str='+'},
                    e1  = clk[3],
                    e2  = clk[4],
                },
            },
         }
        local f   = { tag='acc', tk={tag='id',str='await',lin=lin} }
        local tag = { tag='tag', tk={str=':clock'} }
        return { tag='call', f=f, args={tag,sum}, custom="await" }
    else
        local xe = parser()
        local xf = nil
        if accept(',') then
            --[[
                func (evt) {
                    return $xe
                }
            ]]
            local it = { tag='id', str="evt" }
            local cnd = parser()
            xf = { tag='func', pars={it}, blk={tag='block',es={cnd}} }
        end
        local f = { tag='acc', tk={tag='id',str='await',lin=lin} }
        return { tag='call', f=f, args={xe,xf}, custom="await" }
    end
end

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
        local call = parser()
        local ts; do
            if accept('in') then
                ts = parser()
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

function parser_1_prim ()
    local lits = { {'nil','true','false','...'}, {'tag','num','str','nat'} }
    local function check_(tag)
        return check(nil, tag)
    end

    -- literals: nil, true, false, ..., tag, str, nat
    if any(lits[1],check) or any(lits[2],check_) then
        -- nil, true, false, ...
        if accept('nil') then
            return { tag='nil', tk=TK0 }
        elseif accept('true') or accept('false') then
            return { tag='bool', tk=TK0 }
        elseif accept('...') then
            return { tag='dots', tk=TK0 }

        -- :tag, 0xFF, 'xxx'
        elseif accept(nil,'tag') then
            return { tag='tag', tk=TK0 }
        elseif accept(nil,'num') then
            return { tag='num', tk=TK0 }
        elseif accept(nil,'str') then
            return { tag='str', tk=TK0 }
        elseif accept(nil,'nat') then
            return { tag='nat', tk=TK0 }

        else
            error "bug found"
        end

    -- id: x, __v
    elseif accept(nil,'id') then
        return { tag='acc', tk=TK0 }

    -- table: [...]
    elseif accept('[') then
        local idx = 1
        local ps = parser_list(',', ']', function ()
            local key
            if accept('(') then
                key = parser()
                accept_err(',')
                val = parser()
                accept_err(')')
            else
                local e = parser()
                if e.tag=='acc' and accept('=') then
                    local id = { tag='tag', str=':'..e.tk.str }
                    key = { tag='tag', tk=id }
                    val = parser()
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

    -- parens: (...)
    elseif accept('(') then
        local tk = TK0
        local e = parser()
        accept_err(')')
        return { tag='parens', tk=tk, e=e }

    -- coro, resume, yield
    elseif check('coro') or check('yield') or check('resume') then
        -- coro(f)
        if accept('coro') then
            local f = { tag='acc', tk={tag='id',str="coro",lin=TK0.lin} }
            accept_err('(')
            local e = parser()
            accept_err(')')
            return { tag='call', f=f, args={e}, custom="coro" }
        -- resume co(...)
        elseif accept('resume') then
            local tk = TK0
            local cmd = { tag='acc', tk={tag='id', str='resume', lin=TK0.lin} }
            local call = parser()
            if call.tag ~= 'call' then
                err(tk, "expected call")
            end
            table.insert(call.args, 1, call.f)
            return { tag='call', f=cmd, args=call.args, custom="resume" }
        -- yield(...)
        elseif accept('yield') then
            local f = { tag='acc', tk={tag='id',str=TK0.str,lin=TK0.lin} }
            accept_err('(')
            local args = parser_list(',', ')', parser)
            accept_err(')')
            return { tag='call', f=f, args=args, custom="yield" }
        else
            error "bug found"
        end

    -- task, emit, await, spawn
    elseif check('task') or check('emit') or check('await') or check('spawn') then
        -- task(T)
        if accept('task') then
            local f = { tag='acc', tk={tag='id',str="task",lin=TK0.lin} }
            accept_err('(')
            local e = parser()
            accept_err(')')
            return { tag='call', f=f, args={e}, custom="task" }
        -- emit(...) in t
        elseif accept('emit') then
            local f = { tag='acc', tk={tag='id',str=TK0.str,lin=TK0.lin} }
            accept_err('(')
            local args = parser_list(',', ')', parser)
            accept_err(')')
            local to; do
                if accept('in') then
                    to = parser()
                else
                    to = { tag='nil', tk={tag='key',str='nil',lin=TK0.lin} }
                end
            end
            table.insert(args, 1, to)
            return { tag='call', f=f, args=args, custom="emit" }
        -- await(...)
        elseif accept('await') then
            local lin = TK0.lin
            accept_err('(')
            local awt = parser_await(lin)
            accept_err(')')
            return awt
        -- spawn {}, spawn T()
        elseif check('spawn') then
            local spw = parser_spawn()
            if spw.args[1].tag == 'nil' then
                -- force "pin" if no "in" target
                local pin = {tag='key',str='pin'}
                local id = { tag='id',str='_' }
                spw = { tag='dcl', tk=pin, ids={id}, sets={spw} }
            end
            return spw
        else
            error "bug found"
        end

    -- func
    elseif accept('func') then
        -- func () { ... }
        -- func f () { ... }
        if accept('(') then
            local dots, pars = parser_dots_pars()
            accept_err(')')
            local es = parser_curly()
            return { tag='func', dots=dots, pars=pars, blk={tag='block',es=es} }
        else
            local id = accept_err(nil,'id')
            accept_err('(')
            local dots, pars = parser_dots_pars()
            accept_err(')')
            local es = parser_curly()
            local f = { tag='func', dots=dots, pars=pars, blk={tag='block',es=es} }
            return { tag='dcl', tk={tag='key',str='var'}, ids={id}, sets={f}, custom='func' }
        end

    -- var x = 10
    elseif accept('val') or accept('var') or accept('pin') then
        local tk = TK0
        local ids = parser_ids('=')
        local sets
        local custom
        if accept('=') then
            if check('spawn') then
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
                custom = 'tasks'
                if tk.str ~= 'pin' then
                    err(TK0, "invalid tasks : expected pin declaraion")
                end
                local f = { tag='acc', tk={tag='id',str="tasks",lin=TK0.lin} }
                accept_err('(')
                local e
                if not check(')') then
                    e = parser()
                end
                accept_err(')')
                local ts = { tag='call', f=f, args={e}, custom="tasks" }
                sets = { ts }

            else
                sets = parser_list(',', nil, parser)
            end
        end
        return { tag='dcl', tk=tk, ids=ids, sets=sets, custom=custom }

    -- set x = 10
    elseif accept('set') then
        local dsts = parser_list(',', '=', function ()
            local tk = TK1
            local e = parser()
            if e.tag=='acc' or e.tag=='index' then
                -- ok
            else
                err(tk, "expected assignable expression")
            end
            return e
        end)
        accept_err('=')
        local srcs = parser_list(',', nil, parser)
        return { tag='set', dsts=dsts, srcs=srcs }

    -- do { ... }, defer { ... }
    elseif accept('do') then
        local es = parser_curly()
        return { tag='block', es=es }
    elseif accept('defer') then
        local es = parser_curly()
        return { tag='defer', blk={tag='block',es=es} }

    -- if, ifs
    elseif check('if') or check('ifs') then
        -- if x {...} else {...}
        -- if x => y => z
        if accept('if') then
            local cnd = parser()
            local t, f
            if check('{') then
                t = parser_curly()
                if accept('else') then
                    f = parser_curly()
                else
                    f = {}
                end
            else
                accept_err('=>')
                t = { parser() }
                accept_err('=>')
                f = { parser() }
            end
            return { tag='if', cnd=cnd, t={tag='block',es=t}, f={tag='block',es=f} }
        -- ifs { x => a ; y => b ; else => c }
        elseif accept('ifs') then
            local t = {}
            local tk = accept_err('{')
            while not check('}') do
                local brk = false
                local cnd; do
                    if accept('else') then
                        brk = true
                        cnd = { tag='bool', tk={str='true'} }
                    else
                        cnd = parser()
                    end
                end
                accept_err('=>')
                local es; do
                    if check('{') then
                        es = parser_curly()
                    else
                        es = { parser() }
                    end
                end
                t[#t+1] = { cnd, es }
                if brk then
                    break
                end
            end
            accept_err('}')
            if #t == 0 then
                err(tk, "invalid ifs : expected case")
            end
            local function F (i)
                local cnd, es = table.unpack(t[i])
                local f; do
                    if i < #t then
                        f = { tag='block', es={F(i+1)} }
                    else
                        f = { tag='block', es={} }
                    end
                end
                return { tag='if', cnd=cnd, t={tag='block',es=es}, f=f }
            end
            return F(1)
        else
            error "bug found"
        end

    -- loop, break, until, while
    elseif check('loop') or check('break') or check('until') or check('while') then
        -- loop
        if accept('loop') then
            local ids = check(nil,'id') and parser_ids('=') or nil
            local itr = nil
            if accept('in') then
                itr = parser()
            end
            local es = parser_curly()
            return { tag='loop', ids=ids, itr=itr, blk={tag='block',es=es} }
        -- break
        elseif accept('break') then
            return { tag='break' }
        -- until, while
        elseif accept('until') or accept('while') then
            local whi = (TK0.str == 'while')
            local cnd = parser()
            local t = { tag='block', es={{tag='break'}} }
            local f = { tag='block', es={} }
            if whi then
                t, f = f, t
            end
            return { tag='if', cnd=cnd, t=t, f=f }
        else
            error "bug found"
        end

    -- catch, throw
    elseif check('catch') or check('throw') then
        -- catch
        if accept('catch') then
            local xe = parser()
            local xf = nil
            if accept(',') then
                local it = { tag='id', str="err" }
                local e = parser()
                xf = { tag='func', pars={it}, blk={tag='block',es={e}} }
            end
            local es = parser_curly()
            return { tag='catch', cnd={e=xe,f=xf}, blk={tag='block',es=es} }
        -- throw(err)
        elseif accept('throw') then
            local f = { tag='acc', tk={tag='id', str="error", lin=TK0.lin} }
            local e; do
                if check(nil,'tag') then
                    local tk = TK1
                    e = parser()
                    if e.tag~='call' or e.f.tag~='acc' or e.f.tk.str~="atm_tag" then
                        err(tk, "invalid throw : expected tag constructor")
                    end
                else
                    accept_err('(')
                    if check(')') then
                        e = { tag='nil', tk={tag='key',str='nil',lin=TK0.lin} }
                    else
                        e = parser()
                    end
                    accept_err(')')
                end
            end
            return { tag='call', f=f, args={e, {tag='num',tk={str="0"}}}, custom="throw" }
        else
            error "bug found"
        end

    -- every
    elseif check('every') then
        -- every { ... }
        if accept('every') then
            local lin = TK0.lin
            local par = accept('(')
            local awt = parser_await(lin)
            if par then
                accept_err(')')
            end
            local es = parser_curly()
            local dcl = {
                tag='dcl', tk={tag='key',str='val'},
                ids={{tag='id',str='evt'}}, sets={awt}
            }
            table.insert(es, 1, dcl)
            return { tag='loop', ids=nil, itr=nil, blk={tag='block',es=es} }
        else
            error "bug found"
        end

    else
        err(TK1, "expected expression")
    end
end
