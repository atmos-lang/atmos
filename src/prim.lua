require "parser"

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
        local xe = parser_expr()
        local xf = nil
        if accept(',') then
            --[[
                func (evt) {
                    return $xe
                }
            ]]
            local it = { tag='id', str="evt" }
            local cnd = parser_expr()
            local ret = { tag='return', es={cnd} }
            xf = { tag='func', pars={it}, blk={tag='block',ss={ret}} }
        end
        local f = { tag='acc', tk={tag='id',str='await',lin=lin} }
        return { tag='call', f=f, args={xe,xf}, custom="await" }
    end
end

function parser_expr_1_prim ()
    -- nil
    if accept('nil') then
        return { tag='nil', tk=TK0 }

    -- true, false
    elseif accept('true') or accept('false') then
        return { tag='bool', tk=TK0 }

    -- :tag
    elseif accept(nil,'tag') then
        return { tag='tag', tk=TK0 }

    -- 10, 0xFF
    elseif accept(nil,'num') then
        return { tag='num', tk=TK0 }

    -- 'xxx', """xxx"""
    elseif accept(nil,'str') then
        return { tag='str', tk=TK0 }

    -- `xxx`, ```xxx```
    elseif accept(nil,'nat') then
        return { tag='nat', tk=TK0 }

    -- ...
    elseif accept('...') then
        return { tag='dots', tk=TK0 }

    -- x, __v
    elseif accept(nil,'id') then
        return { tag='acc', tk=TK0 }

    -- (...)
    elseif accept('(') then
        local tk = TK0
        local e = parser_expr()
        accept_err(')')
        return { tag='parens', tk=tk, e=e }

    -- [ ... ]
    elseif accept('[') then
        local idx = 1
        local ps = parser_list(',', ']', function ()
            local key
            if accept('(') then
                key = parser_expr()
                accept_err(',')
                val = parser_expr()
                accept_err(')')
            else
                local e = parser_expr()
                if e.tag=='acc' and accept('=') then
                    local id = { tag='tag', str=':'..e.tk.str }
                    key = { tag='tag', tk=id }
                    val = parser_expr()
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

    -- coro(f)
    elseif accept('coro') then
        local f = { tag='acc', tk={tag='id',str="coro",lin=TK0.lin} }
        accept_err('(')
        local e = parser_expr()
        accept_err(')')
        return { tag='call', f=f, args={e}, custom="coro" }

    -- task(T)
    elseif accept('task') then
        local f = { tag='acc', tk={tag='id',str="task",lin=TK0.lin} }
        accept_err('(')
        local e = parser_expr()
        accept_err(')')
        return { tag='call', f=f, args={e}, custom="task" }

    -- yield(...)
    elseif accept('yield') then
        local f = { tag='acc', tk={tag='id',str=TK0.str,lin=TK0.lin} }
        accept_err('(')
        local args = parser_list(',', ')', parser_expr)
        accept_err(')')
        return { tag='call', f=f, args=args, custom="yield" }

    -- emit(...) in t
    elseif accept('emit') then
        local f = { tag='acc', tk={tag='id',str=TK0.str,lin=TK0.lin} }
        accept_err('(')
        local args = parser_list(',', ')', parser_expr)
        accept_err(')')
        local to; do
            if accept('in') then
                to = parser_expr()
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

    -- resume co(...)
    elseif accept('resume') then
        local tk = TK0
        local cmd = { tag='acc', tk={tag='id', str='resume', lin=TK0.lin} }
        local call = parser_expr()
        if call.tag ~= 'call' then
            err(tk, "expected call")
        end
        table.insert(call.args, 1, call.f)
        return { tag='call', f=cmd, args=call.args, custom="resume" }

    -- throw(err)
    elseif accept('throw') then
        local f = { tag='acc', tk={tag='id', str="error", lin=TK0.lin} }
        accept_err('(')
        local e; do
            if check(')') then
                e = { tag='nil', tk={tag='key',str='nil',lin=TK0.lin} }
            else
                e = parser_expr()
            end
        end
        accept_err(')')
        return { tag='call', f=f, args={e, {tag='num',tk={str="0"}}}, custom="throw" }

    -- func () { ... }
    elseif accept('func') then
        accept_err('(')
        local dots, pars = parser_dots_pars()
        accept_err(')')
        local ss = parser_curly()
        return { tag='func', dots=dots, pars=pars, blk={tag='block',ss=ss} }

    -- if x => y => z
    elseif accept('if') then
        local cnd = parser_expr()
        accept_err('=>')
        local t = parser_expr()
        accept_err('=>')
        local f = parser_expr()
        return { tag='bin', op={str='or'}, e1={tag='parens', e={tag='bin',op={str='and'},e1=cnd,e2=t}}, e2=f }

    -- ifs { x => a ; y => b ; else => c }
    elseif accept('ifs') then
        local t = {}
        accept_err('{')
        while not check('}') do
            local brk = false
            local cnd; do
                if accept('else') then
                    brk = true
                    cnd = { tag='bool', tk={str='true'} }
                else
                    cnd = parser_expr()
                end
            end
            accept_err('=>')
            local e = parser_expr()
            t[#t+1] = { cnd, e }
            if brk then
                break
            end
        end
        accept_err('}')
        local function F (i)
            local cnd, e = table.unpack(t[i])
            local f = (i < #t) and F(i+1) or {tag='nil',tk={str='nil'}}
            return { tag='bin', op={str='or'}, e1={tag='parens', e={tag='bin',op={str='and'},e1=cnd,e2=e}}, e2={tag='parens', e=f} }
        end
        return F(1)

    else
        err(TK1, "expected expression")
    end
end
