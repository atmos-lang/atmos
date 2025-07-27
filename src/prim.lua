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

        local f; do
            if ts then
                table.insert(call.es, 1, ts)
                f = 'spawn_in'
            else
                table.insert(call.es, 1, {tag='bool',tk={str='false'}})
                f = 'spawn'
            end
        end
        table.insert(call.es, 2, call.f)

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
                local blk = parser_block()
                return {
                    tag = 'call',
                    f = { tag='acc', tk={tag='id',str='toggle'} },
                    es = {
                        { tag='tag', tk=tag },
                        {
                            tag = 'func',
                            pars = {},
                            blk = blk,
                        },
                    },
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

    -- every, pars, watching
    elseif check('every') or check('par') or check('par_and') or check('par_or') or check('watching') then
        -- every { ... }
        if accept('every') then
            local awt = parser()
            local blk = parser_block()
            return {
                tag = 'call',
                f = { tag='acc', tk={tag='id',str='every'} },
                es = {
                    awt,
                    {
                        tag  = 'func',
                        pars = {
                            { tag='id', str="_" },
                            { tag='id', str="it" },
                        },
                        blk  = blk,
                    },
                },
            }
        -- par
        elseif accept('par') or accept('par_and') or accept('par_or') then
            local par = TK0.str
            local fs = { parser_block() }
            while accept('with') do
                fs[#fs+1] = parser_block()
            end
            fs = map(fs, function (blk)
                return {
                    tag  = 'func',
                    pars = {},
                    blk  = blk,
                }
            end)
            return {
                tag = 'call',
                f = { tag='acc', tk={tag='id',str=par} },
                es = fs,
            }
        -- watching
        elseif accept('watching') then
            local awt = parser_list(',', '{', parser)
            local blk = parser_block()
            return {
                tag = 'call',
                f = { tag='acc', tk={tag='id',str='watching'} },
                es = concat(awt, {
                    {
                        tag = 'func',
                        pars = {},
                        blk = blk,
                    }
                })
            }
        else
            error "bug found"
        end
    else
        err(TK1, "expected expression")
    end
end
