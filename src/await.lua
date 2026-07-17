-- AWAIT PATTERNS
--
-- What await / watching / loop-on / toggle-with wait for:
--      :X [v] | @1 | T(...) | p&&p | p||p | !p
--      PAT until c | PAT while c | until c | while c
--      :any ts | :all ts
--
-- Rules:
--  - a call in a pattern SPAWNS a task and awaits its termination;
--    to await a call result, use extra parens: await((f()))
--  - the pattern is EAGER (evaluated once, at await time);
--    until/while predicates are LAZY (re-evaluated per event)

-- builds the lua-atmos combinator table {tag=name, [1]=items[1], ...}
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

-- a call to spawn: any callee counts (the runtime discriminates),
-- except atm_tag_do, which the compiler generates for `:X [v]`
local function is_task_call (e)
    return e.tag=='call' and (e.f.tag~='acc' or e.f.tk.str~="atm_tag_do")
end

-- rewrites a pattern expression into the lua-atmos table format:
--      p&&p / p||p / !p  ->  {tag='and'|'or'|'not', ...}
--      T(...)            ->  {tag='spawn', T, ...}
--      (f())             ->  f() verbatim (value escape)
--      anything else     ->  verbatim (tags, clocks, literals)
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

-- until/while predicate: a \{} function, or an expression wrapped as
-- \it -> e. Exactly ONE predicate: combine conditions with &&, since
-- a comma belongs to the enclosing list (toggle filters)
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

-- parses one await pattern.
-- stop=nil : bare `await PAT` -> single suffixed primary, so combinators
-- bind outside (`await :X || :Y` = `(await :X) || :Y`); the base must
-- start as a call-arg token or parse into a call -- bare values need
-- parens (`await(x)`).
-- stop~=nil : pattern delimited by the token (not consumed) -> full
-- expression, combinators allowed.
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

    -- optional until/while suffix (no separator in between)
    local pred = TK0.sep==TK1.sep and (accept('until') or accept('while'))
    if pred then
        return mk_tagged(pred.str, pat, parse_pred())
    else
        return pat
    end
end
