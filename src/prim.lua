local atmos = require "atmos"

local function spawn (lin, blk)
    return {
        tag = 'call',
        f = { tag='acc', tk={tag='id', str='spawn', lin=lin} },
        es = {
            { tag='bool', tk={str='true'} },    -- transparent=true
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
        -- spawn [...] T(...)
        local tk = TK0
        local ts = nil; do
            if accept('[') then
                ts = parser()
                accept_err(']')
            end
        end
        local call = parser_6_pip()
        if call.tag ~= 'call' then
            err(tk, "expected call syntax")
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

local lits = { {'nil','true','false','...'}, {'num','str','nat','clk'} }

function parser_1_prim ()
    local function check_(tag)
        return check(nil, tag)
    end

    -- literals: nil, true, false, ..., str, nat, clock
    -- (except tag)
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
        elseif accept(nil,'clk') then
            return { tag='clk', tk=TK0 }
        else
            error "bug found"
        end

    -- id: x, __v
    elseif accept(nil,'id') then
        return { tag='acc', tk=TK0 }

    -- tag
    elseif accept(nil,'tag') then
        local e = { tag='tag', tk=TK0 }
        if (check'(' or check'@{') and (TK0.sep == TK1.sep) then
            -- (:X) @{...}
            local t = parser_1_prim()
            local f = { tag='acc', tk={tag='id',str="atm_tag_do"} }
            return { tag='call', f=f, es={e,t} }
        else
            return e
        end

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
                err(tk, "expected call syntax")
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
                    err(tk, "expected call syntax")
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
                    err(tk, "expected call syntax")
                end
                return parser_7_out(call)
            end
        -- spawn {}, spawn T()
        elseif check('spawn') then
            local lin = TK1.lin
            local out,spw = parser_spawn()
            if spw.f.tk.str == 'spawn' then
                -- force "pin" if no "in" target
                out = {
                    tag = 'dcl',
                    tk  = {tag='key',str='pin',lin=lin},
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
                            lua = true,
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
                    err(tk, "expected call syntax")
                end
                table.insert(call.es, 1, call.f)
                return parser_7_out({ tag='call', f=cmd, es=call.es })
            end
        else
            error "bug found"
        end

    -- func, return
    elseif check('func') or check('\\') or check('return') then
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

        -- lambda: \{}
        elseif check('\\') then
            return parser_lambda()

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

        if accept('func') then
            local id = accept_err(nil, 'id')
            accept_err('(')
            local dots, pars = parser_dots_pars()
            accept_err(')')
            local blk = parser_block()
            local f = { tag='func', dots=dots, pars=pars, blk=blk }
            return { tag='dcl', tk=tk, ids={id}, set=f }
        end

        local ids = parser_ids('=')

        local beh = (#ids == 1) and accept('*')
        if beh then
            if tk.str ~= 'pin' then
                err(tk, "invalid stream variable : expected pin declaration")
            end
        end

        local set
        if accept('=') then
            if check('spawn') then
                local tk1 = TK1
                set = parser_spawn()
                local inv = set.es[1]
                if inv.tag=='bool' and inv.tk.str=="true" then
                    err(tk, "invalid assignment : unexpected transparent task")
                end
            elseif accept('tasks') then
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

        if not beh then
            return { tag='dcl', tk=tk, ids=ids, set=set }
        else
            --[[
                pin x* = S.from(@1)
                --
                var x
                spawn {
                    S.from(@1)::tap \{ set x=it }::emitter('x')::to()
                }
                --
                val _x = tasks()
                val x = @{}
                atm_behavior(_x, x, S.from(@1))
            ]]
            local id = ids[1]
            if set.tag == 'table' then
                return {
                    tag = 'stmts',
                    es = {
                        { tag='dcl',
                            tk  = { tag='pin', str="pin" },
                            ids = { {tag='id', str="_"..id.str} },
                            set = { tag='call',
                                f  = { tag='acc', tk={tag='id',str="tasks"} },
                                es = {},
                            },
                        },
                        { tag='dcl',
                            tk  = { tag='val', str="val" },
                            ids = { id },
                            set = { tag='table', es={} },
                        },
                        { tag='call',
                            f  = { tag='acc', tk={tag='id',str="atm_behavior"} },
                            es = {
                                { tag='str', tk={tag='str',str=id.str} },
                                { tag='acc', tk={tag='id',str="_"..id.str} },
                                { tag='acc', tk={tag='id',str=id.str} },
                                set, -- S.from(@1)
                            },
                        },
                    },
                }
            else
                return {
                    tag = 'stmts',
                    es = {
                        { tag='dcl', tk={tag='var',str="var"}, ids={id} },
                        spawn(tk.lin, {
                            tag = 'block',
                            es = {
                                { tag='call',
                                    f = { tag='met',
                                        met = { tag='id', str="to" },
                                        o = { tag='call',
                                            f = { tag='met',
                                                met = { tag='id', str="emitter" },
                                                o = { tag='call',
                                                    f = { tag='met', o=set, met={tag='id',str="tap"} },
                                                    es = {
                                                        { tag='func',
                                                            pars = { {tag='id',str="it"} },
                                                            blk = { tag='block',
                                                                es = {
                                                                    { tag='set',
                                                                        dsts = {
                                                                            { tag='acc',tk=ids[1] },
                                                                        },
                                                                        src = { tag='acc',tk={tag='id',str="it"} },
                                                                    },
                                                                },
                                                            },
                                                        },
                                                    },
                                                },
                                            },
                                            es = {
                                                { tag='str',tk=id },
                                            },
                                        },
                                    },
                                    es = {},
                                },
                            },
                        }),
                    },
                }
            end
        end

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
    elseif check('do') or check('test') or check('catch') or check('defer') then
        -- do :X {...}
        -- do(...)
        if accept('do') then
            if check(nil,'tag') or check('{') then
                local tag = accept(nil, 'tag')
                local blk = parser_block()
                return { tag='do', esc=tag, blk=blk }
            else
                local tk = TK0
                local cmd = { tag='acc', tk={tag='id',str='atm_id',lin=TK0.lin} }
                local call = parser_6_pip(parser_5_bin(parser_4_pre(parser_3_met(parser_2_suf(cmd)))))
                if call.tag ~= 'call' then
                    err(tk, "expected call syntax")
                end
                return call
            end
        -- test
        elseif accept('test') then
            local blk = parser_block()
            if not atmos.test then
                blk.es = {}
            end
            return { tag='do', blk=blk }
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
                local blk = parser_block()
                local t = { tag='func', lua=true, pars={}, blk=blk }
                cases[#cases+1] = { cnd, t }
                if accept('else') then
                    local blk = parser_block()
                    local f = { tag='func', lua=true, pars={}, blk=blk }
                    cases[#cases+1] = { 'else', f }
                end
            else
                accept_err('=>')
                if check('\\') then
                    local t = parser_lambda()
                    cases[#cases+1] = { cnd, t }
                    if accept('else') then
                        local blk = parser_block()
                        local f = { tag='func', lua=true, pars={}, blk=blk }
                        cases[#cases+1] = { 'else', f }
                    end
                else
                    local e = parser()
                    local t = { tag='func', lua=true, pars={}, blk={tag='block', es={e}} }
                    cases[#cases+1] = { cnd, t }
                    if accept('=>') then
                        local e = parser()
                        local f = { tag='func', lua=true, pars={}, blk={tag='block', es={e}} }
                        cases[#cases+1] = { 'else', f }
                    end
                end
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
                local f; do
                    if check('{') then
                        local blk = parser_block()
                        f = { tag='func', lua=true, pars={}, blk=blk }
                    elseif check('\\') then
                        f = parser_lambda()
                    else
                        local blk = {tag='block', es={parser()}}
                        f = { tag='func', lua=true, pars={}, blk=blk }
                    end
                end
                ts[#ts+1] = { cnd, f }
                if brk then
                    break
                end
            end
            accept_err('}')
            return { tag='ifs', cases=ts }
        -- match e { x => a ; y => b ; else => c }
        elseif accept('match') then
            local ts = {}
            local match = { n=N(), e=parser() }
            local tk = accept_err('{')
            while not check('}') do
                local brk = false
                local cnd; do
                    if accept('else') then
                        brk = true
                        cnd = {
                            tag = 'bin',
                            op = { str='||' },
                            e1 = { tag='acc', tk={str="atm_"..match.n} },
                            e2 = { tag='bool', tk={str="true"} },
                        }
                    elseif check('\\') then
                        local f = parser_lambda()
                        cnd = {
                            tag = 'call',
                            f = f,
                            es = {
                                { tag='acc', tk={str="atm_"..match.n} },
                            },
                        }
                    else
                        local cmp = parser()
                        cnd = {
                            tag = 'bin',
                            op = { str='&&' },
                            e1 = {
                                tag = 'call',
                                f = { tag='acc', tk={str="_is_"} },
                                es = {
                                    { tag='acc', tk={str="atm_"..match.n} },
                                    cmp
                                },
                            },
                            e2 = {
                                tag = 'bin',
                                op = { str='||' },
                                e1 = { tag='acc', tk={str="atm_"..match.n} },
                                e2 = { tag='bool', tk={str="true"} },
                            },
                        }
                    end
                end
                accept_err('=>')
                local f; do
                    if check('{') then
                        local blk = parser_block()
                        f = { tag='func', lua=true, pars={}, blk=blk }
                    elseif check('\\') then
                        f = parser_lambda()
                    else
                        local blk = { tag='block', es={parser()} }
                        f = { tag='func', lua=true, pars={}, blk=blk }
                    end
                end
                ts[#ts+1] = { cnd, f }
                if brk then
                    break
                end
            end
            accept_err('}')
            return { tag='ifs', match=match, cases=ts }
        else
            error "bug found"
        end

    -- loop
    elseif accept('loop') then
        local ids = check(nil,'id') and parser_ids('in') or nil
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
            local ids = {}
            local awt = parser_list(',', '{', parser)
            if accept('in') then
                ids = awt
                for i,v in ipairs(ids) do
                    if v.tag ~= 'acc' then
                        err(v.tk, "expected identifier")
                    end
                    ids[i] = v.tk
                end
                awt = parser_list(',', '{', parser)
            end
            local blk = parser_block()
            local cb = { tag='func', lua=true, pars=ids, blk=blk }
            return {
                tag = 'call',
                f = { tag='acc', tk={tag='id',str='every'} },
                es = concat(awt, {cb})
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
                    lua  = true,
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
                        tag  = 'func',
                        lua  = true,
                        pars = {},
                        blk  = blk,
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
