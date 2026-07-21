-- AWAIT PATTERNS
--
-- await / watching / loop-on / toggle-with take one of three tiers,
-- one per delimiter:
--      bare    : await P      -- one primary (a call spawns) + optional
--                                until (c) / while (c)
--      value   : await(E)     -- a plain value expression (a call is a
--                                value, not a spawn)
--      pattern : await<PAT>   -- the combinator grammar (below)
--
-- Rules:
--  - inside a pattern (bare or <>), a bare call SPAWNS a task and
--    awaits its termination (operand or not); to await a call's value,
--    drop to a `(f())` value leaf
--  - the pattern is EAGER (evaluated once, at await time);
--    until/while predicates are LAZY (re-evaluated per event)
--  - <PAT> parses with dedicated precedence levels:
--      1_prim : leaves -- :any/:all, until (c), (E) value, <P> group,
--               a primary (call -> spawn)
--      2_pre  : !p
--      3_bin  : p&&p | p||p | p until (c) | p while (c)
--    level-3 combinators chain same-op only: mixing them requires
--    parentheses, mirroring parser_5_bin for expressions
--  - inside <>, values are parenthesized (predicate `until (c)`, value
--    leaf `(E)`); a sub-pattern regroups with a nested <P>

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
    -- explicit count: a `nil` argument makes `#` an unreliable border,
    -- so the runtime unpacks with `awt.n` instead
    es[#es+1] = {
        k = { tag='tag', tk={tag='tag', str=':n'} },
        v = { tag='num', tk={tag='num', str=tostring(select('#',...))} },
    }
    return { tag='table', pat=true, es=es }
end


-- until/while predicate: `(E)` -- a \{} function, or an expression
-- wrapped as \it -> e. The parens are mandatory and bound the inner
-- parser so it cannot eat a closing pattern `>`.
local function parser_pred ()
    accept_err('(')
    -- TODO: we assume a simple-expr body (no await/etc)
    local e = parser()
    accept_err(')')
    if e.tag == 'proto' then
        -- (\{...})
        assert(e.sub == 'func')
        return e
    else
        -- (x > 10)
        return {
            tag='proto', sub='lua',
            pars = { {tag='id',str='it'} },
            blk  = {tag='block', es={e}},
        }
    end
end

local parser_await_3_bin

-- level 1: leaf patterns.
-- in pattern mode a bare call SPAWNS (operand or not); to await a
-- call's value, switch to a `(E)` value leaf. value operators also
-- live in `(E)`. a nested `<P>` regroups a sub-pattern.
local function parser_await_1_prim ()
    -- :any ts / :all ts -- tasks arg is a bounded primary so it does
    -- not eat a closing `>`; a computed pool needs `:any (E)`
    if accept(':any','tag') or accept(':all','tag') then
        return { tag='table', pat=true, es={
            { k={tag='tag', tk={tag='tag', str=':tag'}},   v={tag='str', tk={tag='str', str='tasks'}} },
            { k={tag='tag', tk={tag='tag', str=':mode'}},  v={tag='str', tk={tag='str', str=TK0.str:sub(2)}} },
            { k={tag='tag', tk={tag='tag', str=':tasks'}}, v=parser_2_suf() },
        } }

    -- bare predicate: until (c) / while (c)
    elseif accept('until') or accept('while') then
        return mk_tagged(TK0.str, parser_pred())

    -- nested pattern group: <p>
    elseif accept('<') then
        local p = parser_await_3_bin()
        accept_err('>')
        return p

    -- value leaf: (E) -- a value expression (tier 2)
    elseif accept('(') then
        local tk = TK0
        local e = parser()
        accept_err(')')
        return { tag='parens', tk=tk, e=e }

    -- bare primary; a lone call spawns (atm_tag_do `:X [v]` is not
    -- a task, so it stays a value leaf)
    else
        local e = parser_2_suf()
        if e.tag=='call' and (e.f.tag~='acc' or e.f.tk.str~="atm_tag_do") then
            return mk_tagged('spawn', e.f, table.unpack(e.es))
        end
        return e
    end
end

-- level 2: !p
local function parser_await_2_pre ()
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
parser_await_3_bin = function ()
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
            e1 = mk_tagged(op.str, e1, parser_pred())
        else
            local name = (op.str=='&&') and 'and' or 'or'
            e1 = mk_tagged(name, e1, parser_await_2_pre())
        end
    end
end

-- Parses one await pattern in one of three tiers:
--   value : await(E)     -> a plain value expression (no spawn)
--   patt  : await<PAT>   -> the pattern cascade (levels 1-3)
--   bare  : await P      -> a single primary/spawn (+ optional
--                           until/while); combinators need <PAT>
function parser_await ()
    -- tier 2: value -- await(E)
    if accept('(') then
        local e = parser()
        accept_err(')')
        return e
    end

    -- tier 3: pattern -- await<PAT> ; tier 1: bare -- await P.
    -- calls already spawn in the leaf, so nothing to do here
    local patt = accept('<')
    local pat = parser_await_3_bin()
    if patt then
        accept_err('>')
    end

    -- bare form: reject combinators and loose values (use <PAT> / (E))
    if not patt then
        local e = pat
        local top = e.pat and e.es[1].v.tk.str
        if (top=='until' or top=='while') and #e.es==3 then
            -- await P until c : validate the base P below
            e = e.es[2].v
            top = e.pat and e.es[1].v.tk.str
        end
        local ok; do
            if e.pat then
                ok = (top~='and') and (top~='or') and (top~='not')
            else
                ok = contains({'tag','clk','str','nat','bool','table','proto','call'}, e.tag)
            end
        end
        if not ok then
            err(TK1, "invalid await : unexpected expression")
        end
    end

    return pat
end
