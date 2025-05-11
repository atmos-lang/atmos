Stmt = {}   -- solves mutual require with expr.lua

require "parser"
_ = Expr or require "expr"

function parser_curly ()
    accept_err('{')
    local ss = parser_list(null, '}', parser_stmt)
    accept_err('}')
    return ss
end

function parser_stmt ()
    if false then

    -- var x = 10
    elseif accept('val') or accept('var') then
        local tk = TK0
        local ids = parser_ids('=')
        local sets = accept('=') and parser_list(',', nil, parser_expr)
        return { tag='dcl', tk=tk, ids=ids, sets=sets }

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
        local pars = parser_ids(')')
        accept_err(')')
        local ss = parser_curly()
        local f = { tag='func', pars=pars, blk={tag='block',ss=ss} }
        return { tag='dcl', tk={tag='key',str='val'}, ids={id}, sets={f} }

    -- do { ... }, defer { ... }
    elseif accept('do') then
        local tag = accept(nil,'tag')
        local ss  = parser_curly()
        return { tag='block', esc=tag, ss=ss }
    elseif accept('defer') then
        local ss = parser_curly()
        return { tag='defer', blk={tag='block',ss=ss} }

    -- escape(:X), return(10)
    elseif accept('escape') then
        accept_err('(')
        local e = parser_expr()
        accept_err(')')
        return { tag='escape', e=e }
    elseif accept('return') then
        accept_err('(')
        local e = parser_expr()
        accept_err(')')
        return { tag='return', e=e }

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
        local tag = accept(nil,'tag')
        local ss  = parser_curly()
        return { tag='catch', esc=tag, blk={tag='block',ss=ss} }

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
