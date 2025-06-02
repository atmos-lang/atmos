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
        return { tag='call', f=f, args={tag,sum} }
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
        return { tag='call', f=f, args={xe,xf} }
    end
end

local function spawn (lin, es)
    local cmd = { tag='acc', tk={tag='id', str='spawn', lin=lin} }
    local ts = { tag='nil', tk={tag='key',str='nil'} }
    local f = { tag='func', pars={}, blk={tag='block',es=es} }
    return { tag='call', f=cmd, args={ts,f} }
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
        return { tag='call', f=cmd, args=call.args }
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

    -- table: @{...}
    elseif accept('@{') then
        local idx = 1
        local ps = parser_list(',', '}', function ()
            local key
            if accept('[') then
                key = parser()
                accept_err(']')
                accept_err('=')
                val = parser()
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
        accept_err('}')
        return { tag='table', ps=ps }

    -- vector: #{...}
    elseif accept('#{') then
        local ps = parser_list(',', '}', parser)
        accept_err('}')
        return { tag='vector', ps=ps }

    -- parens: (...)
    elseif accept('(') then
        local tk = TK0
        local es = parser_list(',', ')', parser)
        accept_err(')')
        if #es == 1 then
            return { tag='parens', tk=tk, e=es[1] }
        else
            return { tag='es', tk=tk, es=es }
        end

    -- coro, resume, yield
    elseif check('coro') or check('yield') or check('resume') then
        -- coro(f)
        if accept('coro') then
            local f = { tag='acc', tk={tag='id',str="coro",lin=TK0.lin} }
            accept_err('(')
            local e = parser()
            accept_err(')')
            return { tag='call', f=f, args={e} }
        -- resume co(...)
        elseif accept('resume') then
            local tk = TK0
            local cmd = { tag='acc', tk={tag='id', str='resume', lin=TK0.lin} }
            local call = parser()
            if call.tag ~= 'call' then
                err(tk, "expected call")
            end
            table.insert(call.args, 1, call.f)
            return { tag='call', f=cmd, args=call.args }
        -- yield(...)
        elseif accept('yield') then
            local f = { tag='acc', tk={tag='id',str=TK0.str,lin=TK0.lin} }
            accept_err('(')
            local args = parser_list(',', ')', parser)
            accept_err(')')
            return { tag='call', f=f, args=args }
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
            return { tag='call', f=f, args={e} }
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
            return { tag='call', f=f, args=args }
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
                spw = { tag='dcl', tk=pin, ids={id}, set=spw }
            end
            return spw
        else
            error "bug found"
        end

    -- func, return
    elseif check('func') or check('return') then
        if accept('func') then
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
                return { tag='dcl', tk={tag='key',str='var'}, ids={id}, set=f, custom='func' }
            end
        -- return(...)
        elseif accept('return') then
            accept_err('(')
            local es = parser_list(',', ')', parser)
            accept_err(')')
            return { tag='return', es=es }
        else
            error "bug found"
        end

    -- var x = 10
    elseif accept('val') or accept('var') or accept('pin') then
        local tk = TK0
        local ids = parser_ids('=')
        local set
        if accept('=') then
            if check('spawn') then
                local tk1 = TK1
                local spw = parser_spawn()
                if tk.str=='pin' and spw.args[1].tag~='nil' then
                    err(tk1, "invalid spawn in : unexpected pin declaraion")
                elseif tk.str~='pin' and spw.args[1].tag=='nil' then
                    err(tk1, "invalid spawn : expected pin declaraion")
                end
                set = spw
            elseif accept('tasks') then
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
                local ts = { tag='call', f=f, args={e} }
                set = ts

            else
                set = parser()
            end
        end
        return { tag='dcl', tk=tk, ids=ids, set=set }

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
        local src = parser()
        return { tag='set', dsts=dsts, src=src }

    -- do, escape, defer
    -- catch, throw
    elseif check('do') or check('escape') or check('catch') or check('throw') or check('defer') then
        local function tag_args (err)
            local args; do
                if check(nil,'tag') then
                    local tk = TK1
                    local e = parser()
                    if e.tag~='call' or e.f.tag~='acc' or e.f.tk.str~="atm_tag_do" then
                        err(tk, "invalid escape : expected tag constructor")
                    end
                    return { e }
                else
                    accept_err('(')
                    if err then
                        check_err(nil, 'tag')
                    end
                    local es = parser_list(',', ')', parser)
                    accept_err(')')
                    return es
                end
            end
        end
        -- do :X {...}
        if accept('do') then
            local tag = accept(nil, 'tag')
            local es = parser_curly()
            return { tag='block', esc=tag, es=es }
        -- catch
        elseif accept('catch') then
            local xe = parser()
            if not (xe.tag=='bool' or xe.tag=='tag') then
                err(tk, "invalid catch : expected tag")
            end
            local xf = nil
            if accept(',') then
                local it = { tag='id', str="err" }
                local e = parser()
                xf = { tag='func', pars={it}, blk={tag='block',es={e}} }
            end
            local es = parser_curly()
            return { tag='catch', cnd={e=xe,f=xf}, blk={tag='block',es=es} }
        -- escape :X()
        elseif accept('escape') then
            local args = tag_args(true)
            return { tag='escape', args=args }
        -- throw(err)
        elseif accept('throw') then
            local args = tag_args()
            return { tag='throw', args=args }
        -- defer {...}
        elseif accept('defer') then
            local es = parser_curly()
            return { tag='defer', blk={tag='block',es=es} }
        else
            error "bug found"
        end

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
            accept_err('(')
            local args = parser_list(',', ')', parser)
            accept_err(')')
            return { tag='break', args=args }
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

    -- every
    elseif check('every') or check('par') or check('par_and') or check('par_or') or check('watching') then
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
                ids={{tag='id',str='evt'}}, set=awt
            }
            table.insert(es, 1, dcl)
            return { tag='loop', ids=nil, itr=nil, blk={tag='block',es=es} }
        -- par
        elseif accept('par') then
            local sss = { { TK1.lin, parser_curly() } }
            while accept('with') do
                sss[#sss+1] = { TK1.lin, parser_curly() }
            end
            local es = map(sss, function (t) return spawn(t[1],t[2]) end)
            es[#es+1] = {
                tag = 'call',
                f = { tag='acc', tk={tag='id',str='await'} },
                args = {
                    { tag='bool', tk={str='false'} },
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
                    tag = 'dcl',
                    tk  = { tag='key', str='pin' },
                    ids = { {tag='id', str='atm_'..n..'_'..i} },
                    set = spawn(t[1],t[2]),
                }
            end
            local function f2 (t,i)
                return {
                    tag = 'call',
                    f = { tag='acc', tk={tag='id',str='await'} },
                    args = {
                        { tag='acc', tk={str='atm_'..n..'_'..i} },
                    },
                }
            end
            local function f3 (t,i)
                return {
                    k = { tag='num', tk={tag='num',str=tostring(i)} },
                    v = {
                        tag = 'index',
                        t   = { tag='acc', tk={str='atm_'..n..'_'..i} },
                        idx = { tag='str', tk={str="ret"} },
                    }
                }
            end
            local ss1 = map(sss,f1)
            local ss2 = map(sss,f2)
            local ss3 = {
                { tag='table', ps=map(sss,f3) },
            }
            return { tag='block', es=concat(ss1,ss2,ss3) }
        -- par_or
        elseif accept('par_or') then
            local n = N()
            local sss = { { TK1.lin, parser_curly() } }
            while accept('with') do
                sss[#sss+1] = { TK1.lin, parser_curly() }
            end
            local function f1 (t,i)
                return {
                    tag = 'dcl',
                    tk  = { tag='key', str='pin' },
                    ids = { {tag='id', str='atm_'..n..'_'..i} },
                    set = spawn(t[1],t[2]),
                }
            end
            local function f2 (_,i)
                return { tag='acc', tk={str="atm_"..n..'_'..i} }
            end
            local es = map(sss,f1)
            local tsks = map(sss,f2)
            local xe_xf = {
                { tag='tag', tk={str=':par_or'} },
                { tag='nil', tk={tag='key',str='nil'} },
            }
            local awt = {
                tag = 'call',
                f = { tag='acc', tk={tag='id',str='await'} },
                args = concat(xe_xf,tsks),
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
                tag = 'dcl',
                tk  = { tag='key', str='val' },
                ids = { {tag='id', str='_'} },
                set = spawn(lin,es),
            }
            return { tag='block', es={spw, awt} }

        else
            error "bug found"
        end
    else
        err(TK1, "expected expression")
    end
end
