-- builds the lua-atmos event-combinator table {tag=name, [1]=items[1], ...}
-- (items used verbatim).
local function mk_tagged (name, ...)
    local es = {
        { k = { tag='tag', tk={tag='tag', str=':tag'} },
          v = { tag='str', tk={tag='str', str=name} } },
    }
    for i=1, select('#',...) do
        local it = select(i, ...)
        es[#es+1] = {
            k = { tag='num', tk={tag='num', str=tostring(i)} },
            v = it,
        }
    end
    return { tag='table', es=es }
end

-- task-call promotion: a plain-id call in a promotion site becomes the
-- lua-atmos spawn carrier {tag='spawn', f, args...}; atm_* callees are
-- compiler-generated (e.g. :X [payload] -> atm_tag_do) and excluded
local function is_task_call (e)
    return e.tag=='call' and e.f.tag=='acc' and not string.match(e.f.tk.str, '^atm_')
end

-- Rewrites &&/||/! inside await-pattern positions into the lua-atmos table
-- format {tag='or'|'and'|'not', ...}. Descends through parens and nested
-- &&/|| trees; stops at any other node (calls, lambdas, literals, tags).
-- promote: task-call leaves become spawn carriers (watching / loop on);
-- off in value-await sites (await(PAT), spawn/toggle filters)
local function await_ast_logical (e, promote)
    if e.tag == 'parens' then
        return await_ast_logical(e.e, promote)
    elseif (e.tag == 'bin') and (e.op.str=='&&' or e.op.str=='||') then
        local name = (e.op.str=='&&') and 'and' or 'or'
        return mk_tagged(name, await_ast_logical(e.e1, promote), await_ast_logical(e.e2, promote))
    elseif (e.tag == 'uno') and (e.op.str == '!') then
        return mk_tagged('not', await_ast_logical(e.e, promote))
    elseif promote and is_task_call(e) then
        return mk_tagged('spawn', e.f, table.unpack(e.es))
    else
        return e
    end
end

-- parses a single await pattern (pool prefix, combinators, until/while).
-- parser() errors on an empty slot. shared by await(...) / loop on / watching.
-- base0: true -> single suffixed primary (bare `await PAT`, so `await T(...)`
-- eats the call but `await :X || :Y` stays `(await :X) || :Y`);
-- nil -> full expression.
-- parses a single predicate, wrapping a non-func expression as a
-- \it -> e function (proto). until/while take exactly ONE predicate;
-- combine conditions with && rather than a comma list, so a trailing
-- comma falls back to the enclosing list (toggle filters / patterns)

local function parse_pred ()
    -- TODO: we assume a simple-expr body (no await/etc)
    local e = parser()
    if e.tag == 'proto' then
        -- \{...}
        assert(e.sub == 'func')
        return e
    else
        -- x > 10
        return {
            tag='proto', sub='lua',
            pars = { {tag='id',str='it'} },
            blk  = {tag='block', es={e}},
        }
    end
end

function parser_await (stop, base0, promote)
    -- pool prefix: :any ts / :all ts -> {tag='tasks', mode=, tasks=ts}
    local m = accept(':any', 'tag') or accept(':all', 'tag')
    if m then
        return { tag='table', es={
            { k={tag='tag', tk={tag='tag', str=':tag'}},   v={tag='str', tk={tag='str', str='tasks'}} },
            { k={tag='tag', tk={tag='tag', str=':mode'}},  v={tag='str', tk={tag='str', str=m.str:sub(2)}} },
            { k={tag='tag', tk={tag='tag', str=':tasks'}}, v=parser() },
        } }
    end

    -- await until f / await while f : no base pattern -> synchronous
    -- predicate; the function lands at awt[1], the runtime discriminator
    local k0 = accept('until') or accept('while')
    if k0 then
        return mk_tagged(k0.str, parse_pred())
    end

    -- base pattern + combinators &&/||/!
    local base
    if base0 then
        base = parser_2_suf()
    else
        base = parser()
    end
    local pat = await_ast_logical(base, promote)

    -- optional until/while predicates (each non-func wrapped as \{ e })
    local k = accept('until') or accept('while')
    if not k then
        return pat
    end
    return mk_tagged(k.str, pat, parse_pred())
end
