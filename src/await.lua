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

-- task-call promotion: a call in pattern position becomes the lua-atmos
-- spawn carrier {tag='spawn', f, args...}. Any callee promotes (the
-- callee value evaluates eagerly; the runtime discriminates), except
-- atm_tag_do, the one compiler-generated call inside pattern
-- expressions (:X [payload])
local function is_task_call (e)
    return e.tag=='call' and (e.f.tag~='acc' or e.f.tk.str~="atm_tag_do")
end

-- Rewrites &&/||/! inside await-pattern positions into the lua-atmos table
-- format {tag='or'|'and'|'not', ...}. Descends through parens and nested
-- &&/|| trees; stops at any other node (lambdas, literals, tags).
-- Task-call leaves always promote to the spawn carrier; grouping parens
-- directly wrapping a call are the value escape: `await((f()))` calls f
-- and awaits its result, while `(a || b)` stays combinator grouping.
local function await_ast_logical (e)
    if e.tag == 'parens' then
        if is_task_call(e.e) then
            return e.e
        end
        return await_ast_logical(e.e)
    elseif (e.tag == 'bin') and (e.op.str=='&&' or e.op.str=='||') then
        local name = (e.op.str=='&&') and 'and' or 'or'
        return mk_tagged(name, await_ast_logical(e.e1), await_ast_logical(e.e2))
    elseif (e.tag == 'uno') and (e.op.str == '!') then
        return mk_tagged('not', await_ast_logical(e.e))
    elseif is_task_call(e) then
        return mk_tagged('spawn', e.f, table.unpack(e.es))
    else
        return e
    end
end

-- parses a single await pattern (pool prefix, combinators, until/while).
-- shared by await / toggle-with / loop on / watching.
-- stop: nil -> juxtaposed (bare `await PAT`): a single suffixed primary, so
-- `await T(...)` eats the call but `await :X || :Y` stays `(await :X) || :Y`;
-- the base must be a call-arg token or parse into a call (bare values like
-- `await x` are invalid: values require await's argument parens).
-- non-nil -> delimited by the given token (not consumed): full expression,
-- combinators licensed since the pattern region is closed.
-- pattern position always promotes task-calls to the spawn carrier; the
-- value escape is grouping parens around the call: `await((f()))`.
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

function parser_await (stop)
    -- PRE shortcuts
    do
        -- :any ts / :all ts
        local pool = accept(':any','tag') or accept(':all','tag')
        if pool then
            return { tag='table', es={
                { k={tag='tag', tk={tag='tag', str=':tag'}},   v={tag='str', tk={tag='str', str='tasks'}} },
                { k={tag='tag', tk={tag='tag', str=':mode'}},  v={tag='str', tk={tag='str', str=pool.str:sub(2)}} },
                { k={tag='tag', tk={tag='tag', str=':tasks'}}, v=parser() },
            } }
        end

        -- await until f / await while f
        local pred = accept('until') or accept('while')
        if pred then
            return mk_tagged(pred.str, parse_pred())
        end
    end

    -- base pattern + combinators &&/||/!
    local base
    if stop == nil then
        local ok = check_call_arg()
        base = parser_2_suf()
        if not (ok or is_task_call(base)) then
            err(TK1, "invalid await : unexpected expression")
        end
    else
        base = parser()
    end
    local pat = await_ast_logical(base)

    -- optional until/while predicates (each non-func wrapped as \{ e })
    local pred = accept('until') or accept('while')
    if pred then
        return mk_tagged(pred.str, pat, parse_pred())
    else
        return pat
    end
end
