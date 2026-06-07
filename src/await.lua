-- builds the lua-atmos event-combinator table {tag=name, [1]=items[1], ...}
-- (items used verbatim).
local function mk_tagged (name, items)
    local es = {
        { k = { tag='tag', tk={tag='tag', str=':tag'} },
          v = { tag='str', tk={tag='str', str=name} } },
    }
    for i, it in ipairs(items) do
        es[#es+1] = {
            k = { tag='num', tk={tag='num', str=tostring(i)} },
            v = it,
        }
    end
    return { tag='table', es=es }
end

-- Rewrites &&/||/! inside await-pattern positions into the lua-atmos table
-- format {tag='or'|'and'|'not', ...}. Descends through parens and nested
-- &&/|| trees; stops at any other node (calls, lambdas, literals, tags).
local function await_ast_logical (e)
    if e.tag == 'parens' then
        return await_ast_logical(e.e)
    elseif (e.tag == 'bin') and (e.op.str=='&&' or e.op.str=='||') then
        local name = (e.op.str=='&&') and 'and' or 'or'
        return mk_tagged(name, { await_ast_logical(e.e1), await_ast_logical(e.e2) })
    elseif (e.tag == 'uno') and (e.op.str == '!') then
        return mk_tagged('not', { await_ast_logical(e.e) })
    else
        return e
    end
end

-- parses a single await pattern (pool prefix, combinators, until/while).
-- parser() errors on an empty slot. shared by await(...) / every / watching.
-- prim=true uses a single primary as base (bare `await PAT` juxtaposition),
-- so `await :X || :Y` stays `(await :X) || :Y`; default uses the full expr.
function parser_await (stop, prim)
    -- pool prefix: :any ts / :all ts -> {tag='tasks', mode=, tasks=ts}
    local m = accept(':any', 'tag') or accept(':all', 'tag')
    if m then
        return { tag='table', es={
            { k={tag='tag', tk={tag='tag', str=':tag'}},   v={tag='str', tk={tag='str', str='tasks'}} },
            { k={tag='tag', tk={tag='tag', str=':mode'}},  v={tag='str', tk={tag='str', str=m.str:sub(2)}} },
            { k={tag='tag', tk={tag='tag', str=':tasks'}}, v=parser() },
        } }
    end

    -- base pattern + combinators &&/||/!
    local base = prim and parser_1_prim or parser
    local pat = await_ast_logical(base())

    -- optional until/while predicates (each non-func wrapped as \{ e })
    local k = accept('until') or accept('while')
    if not k then
        return pat
    end
    local preds = parser_list_1(',', stop, parser)
    local fs = map(preds, function (e)
        if e.tag == 'func' then
            return e
        end
        return { tag='func', lua=true, pars={{tag='id',str='it'}}, blk={tag='block', es={e}} }
    end)
    return mk_tagged(k.str, concat({pat}, fs))
end
