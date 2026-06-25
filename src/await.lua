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

-- Rewrites &&/||/! inside await-pattern positions into the lua-atmos table
-- format {tag='or'|'and'|'not', ...}. Descends through parens and nested
-- &&/|| trees; stops at any other node (calls, lambdas, literals, tags).
local function await_ast_logical (e)
    if e.tag == 'parens' then
        return await_ast_logical(e.e)
    elseif (e.tag == 'bin') and (e.op.str=='&&' or e.op.str=='||') then
        local name = (e.op.str=='&&') and 'and' or 'or'
        return mk_tagged(name, await_ast_logical(e.e1), await_ast_logical(e.e2))
    elseif (e.tag == 'uno') and (e.op.str == '!') then
        return mk_tagged('not', await_ast_logical(e.e))
    else
        return e
    end
end

-- parses a single await pattern (pool prefix, combinators, until/while).
-- parser() errors on an empty slot. shared by await(...) / loop on / watching.
-- base0: true -> single primary (bare `await PAT`, so `await :X || :Y` stays
-- `(await :X) || :Y`); nil -> full expression.
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

-- bare: true -> single-primary base (bare `await PAT`); a trailing &&/|| is
-- then ambiguous and rejected. false/nil -> full-expression base.
-- One optional pair of parens wraps the whole pattern, so pool/until/while
-- become parenthesizable (matching await(...)). An opening `(` ends the
-- pattern; inside parens the base is a full expression.
function parser_await (bare)
    local par = accept('(')
    if par then
        bare = false
    end

    local pat

    -- pool prefix: :any ts / :all ts -> {tag='tasks', mode=, tasks=ts}
    local m = accept(':any', 'tag') or accept(':all', 'tag')
    if m then
        pat = { tag='table', es={
            { k={tag='tag', tk={tag='tag', str=':tag'}},   v={tag='str', tk={tag='str', str='tasks'}} },
            { k={tag='tag', tk={tag='tag', str=':mode'}},  v={tag='str', tk={tag='str', str=m.str:sub(2)}} },
            { k={tag='tag', tk={tag='tag', str=':tasks'}}, v=parser() },
        } }
    else
        -- await until f / await while f : no base pattern -> synchronous
        -- predicate; the function lands at awt[1], the runtime discriminator
        local k0 = accept('until') or accept('while')
        if k0 then
            pat = mk_tagged(k0.str, parse_pred())
        else
            -- base pattern + combinators &&/||/!
            local base
            if bare then
                base = parser_1_prim()
            else
                base = parser()
            end
            pat = await_ast_logical(base)

            -- optional until/while predicates (each non-func wrapped as \{ e })
            local k = accept('until') or accept('while')
            if k then
                pat = mk_tagged(k.str, pat, parse_pred())
            end

            -- bare `await :X || :Y` is ambiguous (pattern combinator vs
            -- logical-or on the await result): require parentheses
            if bare and (check('&&') or check('||')) then
                err(TK1, "use parentheses to disambiguate")
            end
        end
    end

    if par then
        accept_err(')')
    end
    return pat
end
