-- AWAIT PATTERNS
--
-- What await / watching / loop-on / toggle-with wait for:
--      :X [v] | @1 | T(...) | spawn T(...) | p&&p | p||p | !p
--      p until c | p while c | until c | while c
--      :any ts | :all ts
--
-- Rules:
--  - a WHOLE-pattern lone call SPAWNS a task and awaits its
--    termination; as an operand a call is a value, so a task must be
--    spawned explicitly (`p || spawn T()`); to await a call result,
--    use extra parens: await((f()))
--  - the pattern is EAGER (evaluated once, at await time);
--    until/while predicates are LAZY (re-evaluated per event)
--  - patterns parse with dedicated precedence levels:
--      1_prim : leaves (tags, clocks, values, until c, spawn T, (p))
--      2_pre  : !p
--      3_bin  : p&&p | p||p | p until c | p while c
--    level-3 combinators chain same-op only: mixing them requires
--    parentheses, mirroring parser_5_bin for expressions
--  - implicit spawn happens once, at the top of parser_await

-- builds the lua-atmos combinator table {tag=name, [1]=items[1], ...};
-- `pat` marks compiler-built patterns (vs verbatim value leaves)
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
    return { tag='table', pat=true, es=es }
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

-- level 1: leaf patterns.
-- a call stays a value here; implicit spawn is decided once, at the
-- top of parser_await, only when the whole pattern is a lone call.
-- a task operand must be spawned explicitly (`spawn T()`).
function parser_await_1_prim ()
    -- :any ts / :all ts
    if accept(':any','tag') or accept(':all','tag') then
        return { tag='table', pat=true, es={
            { k={tag='tag', tk={tag='tag', str=':tag'}},   v={tag='str', tk={tag='str', str='tasks'}} },
            { k={tag='tag', tk={tag='tag', str=':mode'}},  v={tag='str', tk={tag='str', str=TK0.str:sub(2)}} },
            { k={tag='tag', tk={tag='tag', str=':tasks'}}, v=parser() },
        } }

    -- bare predicate: until c / while c (any event until/while c)
    elseif accept('until') or accept('while') then
        return mk_tagged(TK0.str, parse_pred())

    -- explicit task spawn: spawn T(...)
    elseif accept('spawn') then
        local tk = TK0
        local call = parser_2_suf()
        if call.tag ~= 'call' then
            err(tk, "invalid spawn : expected call")
        end
        return mk_tagged('spawn', call.f, table.unpack(call.es))

    -- value leaf: an expression without pattern combinators
    else
        -- (p) grouping or (e) value escape
        local e1
        if accept('(') then
            local tk = TK0
            local e = parser_await_3_bin()
            accept_err(')')
            if e.pat then
                return e
            end
            e1 = { tag='parens', tk=tk, e=e }
        else
            e1 = parser_4_pre()
        end

        -- generic binary ops chain same-op only (as parser_5_bin),
        -- leaving &&/|| and until/while to level 3
        local op0 = nil
        while check(nil,'op') and contains(OPS.bins, TK1.str) and
              TK1.str~='&&' and TK1.str~='||' do
            local op = accept_err(nil,'op')
            if op0 and op0 ~= op.str then
                err(op, "operation error : use parentheses to disambiguate")
            end
            op0 = op.str
            e1 = { tag='bin', op=op, e1=e1, e2=parser_4_pre() }
        end

        return e1
    end
end

-- level 2: !p
function parser_await_2_pre ()
    local ok = (check(nil,'op') and TK1.str=='!')
    if ok then
        accept_err(nil,'op')
        return mk_tagged('not', parser_await_2_pre())
    else
        return parser_await_1_prim()
    end
end

-- level 3: p&&p | p||p | p until c | p while c.
-- same-op chaining only: mixing errs, mirroring parser_5_bin;
-- until/while accept no separator before them (as the suffix form)
function parser_await_3_bin ()
    local e1 = parser_await_2_pre()
    local op0 = nil
    while true do
        local op
        if check(nil,'op') and (TK1.str=='&&' or TK1.str=='||') then
            op = accept_err(nil,'op')
        elseif TK0.sep==TK1.sep and (check('until') or check('while')) then
            op = accept_err(TK1.str)
        else
            return e1
        end
        if op0 and op0~=op.str then
            err(op, "operation error : use parentheses to disambiguate")
        end
        op0 = op.str
        if op.str=='until' or op.str=='while' then
            e1 = mk_tagged(op.str, e1, parse_pred())
        else
            local name = (op.str=='&&') and 'and' or 'or'
            e1 = mk_tagged(name, e1, parser_await_2_pre())
        end
    end
end

-- Parses one await pattern with the full grammar (levels 1-3)
-- If full=false, check if AST is valid
function parser_await (full)
    local pat = parser_await_3_bin()

    -- special "bare" case:
    -- await T()
    if pat.tag=='call' and (pat.f.tag~='acc' or pat.f.tk.str~="atm_tag_do") then
        pat = mk_tagged('spawn', pat.f, table.unpack(pat.es))
    end

    -- special non-parens cases:
    -- await PAT:
    --  - await :X
    --  - await :X until f()
    -- check if :X is valid
    if not full then
        local e = pat
        local top = e.pat and e.es[1].v.tk.str
        if (top=='until' or top=='while') and #e.es==3 then
            -- await :X until f()
            -- extract :X to check below
            e = e.es[2].v
            top = e.pat and e.es[1].v.tk.str
        end
        local ok; do
            if e.pat then
                -- all parsed as `pat`, except these
                ok = (top~='and') and (top~='or') and (top~='not')
            else
                -- none parsed as expr, except these
                ok = contains({'tag','clk','str','nat','table','proto','call'}, e.tag)
            end
        end
        if not ok then
            err(TK1, "invalid await : unexpected expression")
        end
    end

    return pat
end
