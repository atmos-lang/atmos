local atmos = require "atmos"
require "atmos.lang.await"

local function spawn (lin, blk)
    return {
        tag = 'call',
        f = { tag='acc', tk={tag='id', str='do_spawn', lin=lin} },
        es = {
            { tag='proto', sub='func', pars={}, blk=blk },
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
        -- spawn @ts T(...)  |  spawn @(e) T(...)
        local tk = TK0
        local ts = nil; do
            if accept('@') then
                ts = parser_at()
            end
        end
        local call = parser_6_pip()
        if call.tag ~= 'call' then
            err(tk, "expected call syntax")
        end

        table.insert(call.es, 1, call.f)
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
        if (check'(' or check'[') and (TK0.sep == TK1.sep) then
            -- (:X) [...]
            local t = parser_1_prim()
            local f = { tag='acc', tk={tag='id',str="atm_tag_do"} }
            return { tag='call', f=f, es={e,t} }
        else
            return e
        end

    -- table: [...]
    elseif accept('[') then
        local idx = 1
        local es = parser_list(',', ']', function ()
            local key, val
            -- computed key: @(e)=v  @id=v  @5=v  (mirrors t@(e) index)
            if accept('@') then
                key = parser_at()
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
        accept_err(']')
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
        -- emit @t (...)
        -- emit @t <- :X (...)
        if accept('emit') then
            local tk = TK0
            local to = nil
            local f  = nil
            if accept('@') then
                to = parser_at()
                f = 'emit_in'
            else
                f = 'emit'
            end
            local cmd = { tag='acc', tk={tag='id',str=f,lin=TK0.lin} }
            local call = parser_6_pip(parser_5_bin(parser_4_pre(parser_3_met(parser_2_suf(cmd)))))
            if call.tag ~= 'call' then
                err(tk, "expected call syntax")
            end
            if #call.es ~= 1 then
                err(tk, "expected single argument")
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
                -- await T(...) -> await(T, ...) : the runtime await sugar
                -- spawns a task prototype, so codegen need not emit spawn
                return parser_7_out {
                    tag = 'call',
                    f   = { tag='acc', tk={tag='id', str='await', lin=tk.lin} },
                    es  = concat({call.f}, call.es),
                }
            else
                local awt
                if accept('(') then
                    -- await(PAT) : full pattern (combinators + until/while)
                    awt = parser_await(')')
                    accept_err(')')
                else
                    -- await PAT : juxtaposition base is a single primary, so
                    -- `await :X || :Y` stays `(await :X) || :Y`; pool/until ok
                    awt = parser_await(nil, true)
                end
                return {
                    tag = 'call',
                    f   = { tag='acc', tk={tag='id', str='await', lin=tk.lin} },
                    es  = { awt },
                }
            end
        -- spawn {}, spawn T()
        elseif check('spawn') then
            local lin = TK1.lin
            local out,spw = parser_spawn()
            if spw.f.tk.str ~= 'spawn_in' then
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
            if accept('on') then
                local tag = accept_err(nil, 'tag')
                local filter = {}
                if accept('with') then -- optional filter pattern
                    filter = parser_list_1(',', '{', function () return parser_await('{') end)
                end
                local blk = parser_block()
                return {
                    tag = 'call',
                    f = { tag='acc', tk={tag='id',str='toggle'} },
                    es = concat(
                        { { tag='tag', tk=tag } },
                        filter,
                        { { tag='proto', sub='lua', pars={}, blk=blk } }
                    ),
                }
            else
                local tk = TK0
                local cmd = { tag='acc', tk={tag='id', str='toggle', lin=TK0.lin} }
                local call = parser_6_pip()
                if call.tag ~= 'call' then
                    err(tk, "expected call syntax")
                end
                table.insert(call.es, 1, call.f)
                -- optional trailing filter pattern (stops at first non-comma)
                local filter = {}
                if accept('with') then
                    filter = parser_list_1(',', function () return false end, function () return parser_await(function () return false end) end)
                end
                return parser_7_out({ tag='call', f=cmd, es=concat(call.es,filter) })
            end
        else
            error "bug found"
        end

    -- func, return
    elseif check('task') or check('func') or check('\\') or check('return') then
        if accept('task') or accept('func') then
            -- func () { ... }
            -- func f () { ... }
            -- func M.f () { ... }
            -- func o::f () { ... }
            local sub = TK0.str

            -- bare `task` = running instance ("me"): not a proto
            -- header when no same-line `(` or name follows
            if sub=='task' and not ((check('(') or check(nil,'id')) and TK0.sep==TK1.sep) then
                return { tag='call', f={tag='acc', tk={tag='id',str='xtask',lin=TK0.lin}}, es={} }
            end

            if accept('(') then
                local dots, pars = parser_dots_pars()
                accept_err(')')
                local blk = parser_block()
                return { tag='proto', sub=sub, dots=dots, pars=pars, blk=blk }
            else
                local id = accept_err(nil, 'id')

                local idxs = {}
                local met = nil
                while accept('.') do
                    idxs[#idxs+1] = accept_field_err()
                end
                if sub=='func' and accept('::') then
                    met = accept_field_err()
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
                    src  = { tag='proto', sub=sub, dots=dots, pars=pars, blk=blk }
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

        if tk.str=='val' and (accept('task') or accept('func')) then
            local sub = TK0.str
            local id = accept_err(nil, 'id')
            accept_err('(')
            local dots, pars = parser_dots_pars()
            accept_err(')')
            local blk = parser_block()
            local f = { tag='proto', sub=sub, dots=dots, pars=pars, blk=blk }
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
                if set.f.tk.str == 'do_spawn' then
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
                                                        { tag='proto', sub='func',
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
        local dsts = parser_list_1(',', '=', function ()
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
                local cmd = { tag='acc', tk={tag='id',str='atm_void',lin=TK0.lin} }
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
                local t = { tag='proto', sub='lua', pars={}, blk=blk }
                cases[#cases+1] = { cnd, t }
                if accept('else') then
                    local blk = parser_block()
                    local f = { tag='proto', sub='lua', pars={}, blk=blk }
                    cases[#cases+1] = { 'else', f }
                end
            else
                accept_err('=>')
                if check('\\') then
                    local t = parser_lambda()
                    cases[#cases+1] = { cnd, t }
                    if accept('else') then
                        local blk = parser_block()
                        local f = { tag='proto', sub='lua', pars={}, blk=blk }
                        cases[#cases+1] = { 'else', f }
                    end
                else
                    local e = parser()
                    local t = { tag='proto', sub='lua', pars={}, blk={tag='block', es={e}} }
                    cases[#cases+1] = { cnd, t }
                    if accept('=>') then
                        local e = parser()
                        local f = { tag='proto', sub='lua', pars={}, blk={tag='block', es={e}} }
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
                        f = { tag='proto', sub='lua', pars={}, blk=blk }
                    elseif check('\\') then
                        f = parser_lambda()
                    else
                        local blk = {tag='block', es={parser()}}
                        f = { tag='proto', sub='lua', pars={}, blk=blk }
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
                                f = { tag='acc', tk={str="X.is"} },
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
                        f = { tag='proto', sub='lua', pars={}, blk=blk }
                    elseif check('\\') then
                        f = parser_lambda()
                    else
                        local blk = { tag='block', es={parser()} }
                        f = { tag='proto', sub='lua', pars={}, blk=blk }
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
        local tk = TK0
        local ids = check(nil,'id') and parser_ids('in') or nil
        if accept('on') then
            -- loop { val IDS = await(PAT) ; BODY }
            local awt = parser_await('{')
            local blk = parser_block()
            local call = {
                tag = 'call',
                f   = { tag='acc', tk={tag='id', str='await', lin=tk.lin} },
                es  = { awt },
            }
            local bnd = (not ids) and call or {
                tag = 'dcl',
                tk  = {tag='key', str='val', lin=tk.lin},
                ids = ids,
                set = call
            }
            table.insert(blk.es, 1, bnd)
            return { tag='loop', ids=nil, itr=nil, blk=blk }
        else
            local itr = nil
            if accept('in') then
                itr = parser()
            end
            local blk = parser_block()
            return { tag='loop', ids=ids, itr=itr, blk=blk }
        end

    elseif accept('until') or accept('while') then
        return { tag='acc', tk={tag='id', str=TK0.str, lin=TK0.lin, sep=TK0.sep} }

    -- pars, watching
    elseif check('par') or check('watching') then
        -- par :all -> par_all (rejoin all); :any -> par_any (rejoin any)
        if accept('par') then
            local par = 'par'
            local tag = accept(nil, 'tag')
            if tag then
                par = tag.str
                if par == ':all' then
                    par = 'par_all'
                elseif par == ':any' then
                    par = 'par_any'
                else
                    err(tag, "invalid par : invalid tag")
                end
            end
            local fs = { parser_block() }
            while accept('with') do
                fs[#fs+1] = parser_block()
            end
            fs = map(fs, function (blk)
                return {
                    tag  = 'proto',
                    sub  = 'lua',
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
            local awt = parser_await('{')
            local blk = parser_block()
            return {
                tag = 'call',
                f = { tag='acc', tk={tag='id',str='watching'} },
                es = {
                    awt,
                    { tag='proto', sub='lua', pars={}, blk=blk },
                }
            }
        else
            error "bug found"
        end

    elseif accept('thread') then
        local blk = parser_block()
        return {
            tag = 'call',
            f = {
                tag = 'acc',
                tk  = { tag='id', str='thread', lin=TK0.lin },
            },
            es = {
                { tag='proto', sub='lua', pars={}, blk=blk },
            },
        }

    else
        err(TK1, "expected expression")
    end
end
