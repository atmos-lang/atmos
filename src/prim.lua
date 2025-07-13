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
            local cnd = parser()
            xf = {
                tag = 'func',
                pars = {
                    { tag='id', str="evt" }
                },
                blk = { tag='block', es={cnd} },
            }
        end
        return {
            tag = 'call',
            f = {
                tag = 'acc',
                tk = {tag='id',str='await',lin=lin}
            },
            es = {xe,xf},
        }
    end
end

local function spawn (lin, blk)
    return {
        tag = 'call',
        f = { tag='acc', tk={tag='id', str='spawn', lin=lin} },
        es = {
            { tag='bool', tk={str='true'} },    -- invisible=true
            { tag='func', pars={}, blk=blk },
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
        local ts = nil; do
            if accept('[') then
                ts = parser()
                accept_err(']')
            end
        end
        local call = parser_6_pip()
        if call.tag ~= 'call' then
            err(tk, "expected call")
        end
        table.insert(call.es, 1, {tag='bool',tk={str='false'}})
        table.insert(call.es, 2, call.f)

        local f; do
            if ts then
                table.insert(call.es, 1, ts)
                f = 'spawn_in'
            else
                f = 'spawn'
            end
        end

        local spw = {
            tag = 'call',
            f   = { tag='acc', tk={tag='id', str=f, lin=tk.lin} },
            es  = call.es,
        }
        local out = parser_7_out(spw)
        return out, spw
    end
end

local lits = { {'nil','true','false','...'}, {'tag','num','str','nat','clk'} }

function parser_1_prim ()
    local function check_(tag)
        return check(nil, tag)
    end

    -- literals: nil, true, false, ..., tag, str, nat, clock
    if any(lits[1],check) or any(lits[2],check_) then
        -- nil, true, false, ...
        if accept('nil') then
            return { tag='nil', tk=TK0 }
        elseif accept('true') or accept('false') then
            return { tag='bool', tk=TK0 }
        elseif accept('...') then
            return { tag='dots', tk=TK0 }
        -- 0xFF, 'xxx', `xxx`, :X
        elseif accept(nil,'num') then
            return { tag='num', tk=TK0 }
        elseif accept(nil,'str') then
            return { tag='str', tk=TK0 }
        elseif accept(nil,'nat') then
            return { tag='nat', tk=TK0 }
        elseif accept(nil,'tag') then
            return { tag='tag', tk=TK0 }
        elseif accept(nil,'clk') then
            return { tag='clk', tk=TK0 }
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

    -- emit, await, spawn, toggle
    elseif check('emit') or check('await') or check('spawn') or check('toggle') then
        -- emit [t] (...)
        -- emit [t] <- :X (...)
        if accept('emit') then
            local tk = TK0
            local to = nil
            local f  = nil
            if accept('[') then
                to = parser()
                accept_err(']')
                f = 'emit_in'
            else
                f = 'emit'
            end
            local cmd = { tag='acc', tk={tag='id',str=f,lin=TK0.lin} }
            local call = parser_6_pip(parser_5_bin(parser_4_pre(parser_3_met(parser_2_suf(cmd)))))
            if call.tag ~= 'call' then
                err(tk, "expected call")
            end
            if f == 'emit_in' then
                table.insert(call.es, 1, to)
            end
            return parser_7_out(call)
        -- await(...)
        elseif accept('await') then
            local tk = TK0
            if check(nil,'id') then
                local call = parser_6_pip()
                if call.tag ~= 'call' then
                    err(tk, "expected call")
                end
                return parser_7_out {
                    tag = 'call',
                    f   = { tag='acc', tk={tag='id', str='await', lin=tk.lin} },
                    es  = {
                        {
                            tag = 'call',
                            f   = { tag='acc', tk={tag='id', str='spawn', lin=tk.lin} },
                            es  = concat({call.f}, call.es),
                        }
                    },
                }
            else
                local cmd = { tag='acc', tk={tag='id',str='await',lin=tk.lin} }
                local call = parser_6_pip(parser_5_bin(parser_4_pre(parser_3_met(parser_2_suf(cmd)))))
                if call.tag ~= 'call' then
                    err(tk, "expected call")
                end
                return parser_7_out(call)
            end
        -- spawn {}, spawn T()
        elseif check('spawn') then
            local out,spw = parser_spawn()
            if spw.f.tk.str == 'spawn' then
                -- force "pin" if no "in" target
                out = {
                    tag = 'dcl',
                    tk  = {tag='key',str='pin'},
                    ids = { {tag='id',str='_'} },
                    set = out,
                }
            end
            return out
        elseif accept('toggle') then
            local tag = accept(nil, 'tag')
            if tag then
                local lin = TK0.lin
                local blk = parser_block()
                local id = "atm_" .. N()
                local loop = {
                    tag = 'loop',
                    ids = nil,
                    itr = nil,
                    blk = {
                        tag = 'block',
                        es = {
                            {
                                tag = 'call',
                                f = { tag='acc', tk={tag='id',str='await'} },
                                es = {
                                    { tag='tag', tk=tag },
                                    {
                                        tag = 'func',
                                        dots = false,
                                        pars = {
                                            { tag='id', str="evt" }
                                        },
                                        blk = {
                                            tag = 'block',
                                            es = {
                                                {
                                                    tag = 'uno',
                                                    op  = { tag='op', str='!' },
                                                    e = { tag='acc', tk={tag='id',str='evt'} },
                                                },
                                            },
                                        }
                                    },
                                },
                            },
                            {
                                tag = 'call',
                                f = { tag='acc', tk={tag='id',str='toggle'} },
                                es = {
                                    { tag='acc', tk={str=id} },
                                    { tag='bool', tk={str='false'} },
                                },
                            },
                            {
                                tag = 'call',
                                f = { tag='acc', tk={tag='id',str='await'} },
                                es = {
                                    { tag='tag', tk=tag },
                                    {
                                        tag = 'func',
                                        dots = false,
                                        pars = {
                                            { tag='id', str="evt" }
                                        },
                                        blk = {
                                            tag = 'block',
                                            es = {
                                                { tag='acc', tk={tag='id',str='evt'} },
                                            },
                                        }
                                    },
                                },
                            },
                            {
                                tag = 'call',
                                f = { tag='acc', tk={tag='id',str='toggle'} },
                                es = {
                                    { tag='acc', tk={str=id} },
                                    { tag='bool', tk={str='true'} },
                                },
                            },
                        },
                    },
                }
                return {
                    tag = 'do',
                    blk = {
                        tag = 'block',
                        es = {
                            {
                                tag = 'dcl',
                                tk  = { tag='key', str='pin' },
                                ids = { {tag='id', str=id} },
                                set = spawn(lin, blk),
                            },
                            spawn(lin, {
                                tag = 'block',
                                es = { loop },
                            }),
                            {
                                tag = 'call',
                                f = { tag='acc', tk={tag='id',str='await'} },
                                es = {
                                    { tag='acc', tk={str=id} },
                                },
                            }
                        },
                    }
                }
            else
                local tk = TK0
                local cmd = { tag='acc', tk={tag='id', str='toggle', lin=TK0.lin} }
                local call = parser_6_pip()
                if call.tag ~= 'call' then
                    err(tk, "expected call")
                end
                table.insert(call.es, 1, call.f)
                return parser_7_out({ tag='call', f=cmd, es=call.es })
            end
        else
            error "bug found"
        end

    -- func, return
    elseif check('func') or check('return') then
        if accept('func') then
            -- func () { ... }
            -- func f () { ... }
            -- func M.f () { ... }
            -- func o::f () { ... }
            if accept('(') then
                local dots, pars = parser_dots_pars()
                accept_err(')')
                local blk = parser_block()
                return { tag='func', dots=dots, pars=pars, blk=blk }
            else
                local id = accept_err(nil, 'id')

                local idxs = {}
                while accept('.') do
                    idxs[#idxs+1] = accept_err(nil, 'id')
                end

                local met = nil
                if accept('::') then
                    met = accept_err(nil, 'id')
                    idxs[#idxs+1] = met
                end

                accept_err('(')
                local dots, pars = parser_dots_pars()
                accept_err(')')

                if met then
                    table.insert(pars, 1, {tag='id',str="self"})
                end

                local dst = { tag='acc', tk=id }
                for _, idx in ipairs(idxs) do
                    dst = { tag='index', t=dst, idx={tag='str',tk=idx} }
                end

                local blk = parser_block()
                return {
                    tag  = 'set',
                    dsts = { dst },
                    src  = { tag='func', dots=dots, pars=pars, blk=blk }
                }
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
                if tk.str=='pin' and spw.f.tk.str=='spawn_in' then
                    err(tk1, "invalid spawn in : unexpected pin declaration")
                elseif tk.str~='pin' and spw.f.tk.str=='spawn' then
                    err(tk1, "invalid spawn : expected pin declaration")
                end
                set = out
            elseif accept('tasks') then
                if tk.str ~= 'pin' then
                    err(TK0, "invalid tasks : expected pin declaration")
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
        local dsts = parser_list(',', '=', function ()
            local tk = TK1
            local e = parser()
            if e.tag=='acc' or e.tag=='index' or e.tag=='nat' then
                -- ok
            else
                err(tk, "expected assignable expression")
            end
            return e
        end)
        accept_err('=')
        local src = parser()
        return { tag='set', dsts=dsts, src=src }

    -- do, defer, catch
    elseif check('do') or check('catch') or check('defer') then
        -- do :X {...}
        -- do(...)
        if accept('do') then
            if accept('(') then
                local e = parser()
                accept_err(')')
                return { tag='do', blk={tag='block',es={e}} }
            else
                local tag = accept(nil, 'tag')
                local blk = parser_block()
                return { tag='do', esc=tag, blk=blk }
            end
        -- catch
        elseif accept('catch') then
            local cnd = parser()
            local blk = parser_block()
            return { tag='catch', cnd=cnd, blk=blk }
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
                        cnd = 'else'
                    else
                        local cmp = parser()
                        cnd = {
                            tag = 'call',
                            f = { tag='acc', tk={str="_is_"} },
                            es = {
                                { tag='acc', tk={str="it"} },
                                cmp
                            },
                        }
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
            local n = N()
            local par = accept('(')
            local awt = parser_await(lin)
            if par then
                accept_err(')')
            end
            local lin = TK1.lin
            local es = parser_block()
            return {
                tag = 'do',
                blk = {
                    tag = 'block',
                    es = {
                        {
                            tag = 'dcl',
                            tk  = { tag='key', str='pin' },
                            ids = { {tag='id', str='atm_grd_'..n} },
                            set = spawn(lin,awt),
                        },
                        {
                            tag = 'dcl',
                            tk  = { tag='key', str='pin' },
                            ids = { {tag='id', str='atm_blk_'..n} },
                            set = spawn(lin,es),
                        },
                        {
                            tag = 'call',
                            f = { tag='acc', tk={tag='id',str='await'} },
                            es = {
                                { tag='tag', tk={str=':par_or'} },
                                { tag='nil', tk={tag='key',str='nil'} },
                                { tag='acc', tk={str='atm_grd_'..n} },
                                { tag='acc', tk={str='atm_blk_'..n} },
                            },
                        },
                    }
                }
            }
        else
            error "bug found"
        end
    else
        err(TK1, "expected expression")
    end
end
