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

        local es = map(clk, f)
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
        return { tag='call', f=f, es={tag,sum} }
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
        return { tag='call', f=f, es={xe,xf} }
    end
end

local function spawn (lin, blk)
    return {
        tag = 'call',
        f = { tag='acc', tk={tag='id', str='spawn', lin=lin} },
        es = {
            { tag='nil', tk={tag='key',str='nil'} },
            { tag='func', pars={}, blk=blk },
            { tag='bool', tk={str='true'} },    -- fake=true
        },
    }
end

function parser_spawn ()
    accept_err('spawn')
    if check('{') then
        -- spawn { ... }
        local spw = spawn(TK0.lin, parser_block())
        return spw, spw
    else
        -- spawn T(...) [in ...]
        local tk = TK0
        local cmd = { tag='acc', tk={tag='id', str='spawn', lin=TK0.lin} }
        local ts; do
            if accept('[') then
                ts = parser()
                accept_err(']')
            else
                ts = { tag='nil', tk={tag='key',str='nil'} }
            end
        end
        local call = parser_6_pip()
        if call.tag ~= 'call' then
            err(tk, "expected call")
        end
        table.insert(call.es, 1, ts)
        table.insert(call.es, 2, call.f)
        table.insert(call.es, 3, {tag='bool',tk={str='false'}})
        local spw = { tag='call', f=cmd, es=call.es }
        local out = parser_7_out(spw)
        return out, spw
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
        local es = parser_list(',', '}', function ()
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
        return { tag='table', es=es }

    -- vector: #{...}
    elseif accept('#{') then
        local es = parser_list(',', '}', parser)
        accept_err('}')
        return { tag='vector', es=es }

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

    -- resume co(...)
    elseif accept('resume') then
        local tk = TK0
        local cmd = { tag='acc', tk={tag='id', str='resume', lin=TK0.lin} }
        local call = parser_6_pip()
        if call.tag ~= 'call' then
            err(tk, "expected call")
        end
        table.insert(call.es, 1, call.f)
        return parser_7_out({ tag='call', f=cmd, es=call.es })

    -- emit, await, spawn
    elseif check('emit') or check('await') or check('spawn') then
        -- emit [t] (...)
        -- emit [t] <- :X (...)
        if accept('emit') then
            local tk = TK0
            local cmd = { tag='acc', tk={tag='id',str='emit',lin=TK0.lin} }
            local to; do
                if accept('[') then
                    to = parser()
                    accept_err(']')
                else
                    to = { tag='nil', tk={tag='key',str='nil',lin=TK0.lin} }
                end
            end
            --local call = parser_4_pre(parser_3_met(parser_2_suf(cmd)))
            local call = parser_6_pip(parser_5_bin(parser_4_pre(parser_3_met(parser_2_suf(cmd)))))
            if call.tag ~= 'call' then
                err(tk, "expected call")
            end
            table.insert(call.es, 1, to)
            return parser_7_out(call)
        -- await(...)
        elseif accept('await') then
            local lin = TK0.lin
            accept_err('(')
            local awt = parser_await(lin)
            accept_err(')')
            return awt
        -- spawn {}, spawn T()
        elseif check('spawn') then
            local out,spw = parser_spawn()
            if spw.es[1].tag == 'nil' then
                -- force "pin" if no "in" target
                local pin = {tag='key',str='pin'}
                local id = { tag='id',str='_' }
                out = { tag='dcl', tk=pin, ids={id}, set=out }
            end
            return out
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
                local blk = parser_block()
                return { tag='func', dots=dots, pars=pars, blk=blk }
            else
                local id = accept_err(nil,'id')
                accept_err('(')
                local dots, pars = parser_dots_pars()
                accept_err(')')
                local blk = parser_block()
                local f = { tag='func', dots=dots, pars=pars, blk=blk }
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
                local out,spw = parser_spawn()
                if tk.str=='pin' and spw.es[1].tag~='nil' then
                    err(tk1, "invalid spawn in : unexpected pin declaraion")
                elseif tk.str~='pin' and spw.es[1].tag=='nil' then
                    err(tk1, "invalid spawn : expected pin declaraion")
                end
                set = out
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
                local ts = { tag='call', f=f, es={e} }
                set = ts

            else
                set = parser()
            end
        end
        return { tag='dcl', tk=tk, ids=ids, set=set }

    -- set x = 10
    elseif accept('set') then
        local has_idx = false
        local dsts = parser_list(',', '=', function ()
            local tk = TK1
            local e = parser()
            if e.tag=='acc' or e.tag=='index' or e.tag=='nat' then
                -- ok
                if e.tag == 'index' then
                    has_idx = true
                end
            else
                err(tk, "expected assignable expression")
            end
            return e
        end)
        accept_err('=')
        if has_idx and #dsts>1 then
            err(TK0, "invalid set : multiple assignment with index is not supported")
        end
        local src = parser()
        return { tag='set', dsts=dsts, src=src }

    -- do, defer, catch
    elseif check('do') or check('catch') or check('defer') then
        -- do :X {...}
        if accept('do') then
            local tag = accept(nil, 'tag')
            local blk = parser_block()
            return { tag='do', esc=tag, blk=blk }
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
            local blk = parser_block()
            return { tag='catch', cnd={e=xe,f=xf}, blk=blk }
        -- defer {...}
        elseif accept('defer') then
            local blk = parser_block()
            return { tag='defer', blk=blk }
        else
            error "bug found"
        end

    -- if, ifs, match
    elseif check('if') or check('ifs') or check('match') then
        -- if x {...} else {...}
        -- if x => y => z
        if accept('if') then
            local cnd = parser()
            local cases = {}
            if check('{') then
                cases[#cases+1] = { cnd, parser_block() }
                if accept('else') then
                    cases[#cases+1] = { 'else', parser_block() }
                end
            else
                accept_err('=>')
                cases[#cases+1] = { cnd, {tag='block', es={parser()}} }
                accept_err('=>')
                cases[#cases+1] = { 'else', {tag='block', es={parser()}} }
            end
            return { tag='ifs', cases=cases }
        -- ifs { x => a ; y => b ; else => c }
        elseif accept('ifs') then
            local ts = {}
            local tk = accept_err('{')
            while not check('}') do
                local brk = false
                local cnd; do
                    if accept('else') then
                        brk = true
                        cnd = 'else'
                    else
                        cnd = parser()
                    end
                end
                accept_err('=>')
                local es; do
                    if check('{') then
                        es = parser_block()
                    else
                        es = { tag='block', es={parser()} }
                    end
                end
                ts[#ts+1] = { cnd, es }
                if brk then
                    break
                end
            end
            accept_err('}')
            return { tag='ifs', cases=ts }
        -- match e { x => a ; y => b ; else => c }
        elseif accept('match') then
            local ts = {}
            local head = parser()
            local tk = accept_err('{')
            while not check('}') do
                local brk = false
                local cnd; do
                    if accept('else') then
                        brk = true
                        cmp = 'else'
                    else
                        cmp = parser()
                    end
                end
                accept_err('=>')
                local es; do
                    if check('{') then
                        es = parser_block()
                    else
                        es = { tag='block', es={parser()} }
                    end
                end
                local cnd = {
                    tag = 'call',
                    f = { tag='acc', tk={str="atm_is"} },
                    es = {
                        { tag='acc', tk={str="it"} },
                        cmp
                    },
                }
                ts[#ts+1] = { cnd, es }
                if brk then
                    break
                end
            end
            accept_err('}')
            return { tag='ifs', head=head, cases=ts }
        else
            error "bug found"
        end

    -- loop
    elseif accept('loop') then
        local ids = check(nil,'id') and parser_ids('=') or nil
        local itr = nil
        if accept('in') then
            itr = parser()
        end
        local blk = parser_block()
        return { tag='loop', ids=ids, itr=itr, blk=blk }

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
            local blk = parser_block()
            local dcl = {
                tag='dcl', tk={tag='key',str='val'},
                ids={{tag='id',str='evt'}}, set=awt
            }
            table.insert(blk.es, 1, dcl)
            return { tag='loop', ids=nil, itr=nil, blk=blk }
        -- par
        elseif accept('par') then
            local sss = { { TK1.lin, parser_block() } }
            while accept('with') do
                sss[#sss+1] = { TK1.lin, parser_block() }
            end
            local es = map(sss, function (t) return spawn(t[1],t[2]) end)
            es[#es+1] = {
                tag = 'call',
                f = { tag='acc', tk={tag='id',str='await'} },
                es = {
                    { tag='bool', tk={str='false'} },
                },
            }
            return { tag='do', blk={tag='block',es=es} }
        -- par_and
        elseif accept('par_and') then
            local n = N()
            local sss = { { TK1.lin, parser_block() } }
            while accept('with') do
                sss[#sss+1] = { TK1.lin, parser_block() }
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
                    es = {
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
                { tag='table', es=map(sss,f3) },
            }
            return { tag='do', blk={tag='block', es=concat(ss1,ss2,ss3)} }
        -- par_or
        elseif accept('par_or') then
            local n = N()
            local sss = { { TK1.lin, parser_block() } }
            while accept('with') do
                sss[#sss+1] = { TK1.lin, parser_block() }
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
                es = concat(xe_xf,tsks),
            }
            es[#es+1] = awt
            return { tag='do', blk={tag='block', es=es} }
        -- watching
        elseif accept('watching') then
            local lin = TK0.lin
            local par = accept('(')
            local awt = parser_await(lin)
            if par then
                accept_err(')')
            end
            local lin = TK1.lin
            local es = parser_block()
            local spw = {
                tag = 'dcl',
                tk  = { tag='key', str='pin' },
                ids = { {tag='id', str='_'} },
                set = spawn(lin,es),
            }
            return { tag='do', blk={tag='block', es={spw, awt}} }

        else
            error "bug found"
        end
    else
        err(TK1, "expected expression")
    end
end
