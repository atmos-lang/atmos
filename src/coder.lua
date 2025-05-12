function N ()
    _n_ = _n_ + 1
    return _n_
end

local function L (tk)
    local ls = ''
    if tk and tk.lin then
        --assert(tk.lin >= _l_)
        while tk.lin > _l_ do
            ls = ls .. '\n'
            _l_ = _l_ + 1
        end
    end
    return ls
end

function coder_stmts (ss)
    return concat(' ; ', map(ss,coder_stmt)) .. " ; "
end

function coder_stmt (s)
    if false then
    elseif s.tag == 'dcl' then
        local cst = s.tk.str=='val' and " <const>" or ''
        local ids = concat(', ', map(s.ids,  function(id) return id.str end))
        local sets = s.sets and (' = '..concat(', ',map(s.sets,coder_expr))) or ''
        if s.sets and #s.sets==1 and s.sets[1].tag=='func' then
            return 'local ' .. ids .. ' ; ' .. ids .. sets
        else
            return 'local ' .. ids .. cst .. sets
        end
    elseif s.tag == 'set' then
        return concat(',', map(s.dsts,coder_expr))..' = '..concat(',', map(s.srcs,coder_expr))
    elseif s.tag == 'block' then
        local str = s.esc and s.esc.str:sub(2)
        return "do " ..
            (s.esc and ("local atm_"..str) or "") .. ' ' ..
            coder_stmts(s.ss) .. ' ' ..
            (s.esc and ("::"..str.."::") or "") .. ' ' ..
        "end"
    elseif s.tag == 'defer' then
        local n = N()
        local def = "atm_"..n
        return [[
            local ]] .. def .. [[ <close> = setmetatable({}, {__close=
                function () ]]..
                    coder_stmts(s.blk.ss) .. [[
                end
            })
        ]]
    elseif s.tag == 'escape' then
        local str = s.esc.str:sub(2)
        return L(s.esc) .. [[
            atm_]] .. str .. ' = ' .. coder_expr(s.e) .. [[
            goto ]] .. str
    elseif s.tag == 'return' then
        return "return " .. concat(',', map(s.es,coder_expr))
    elseif s.tag == 'if' then
        return "if " .. coder_expr(s.cnd) .. " then " ..
            coder_stmts(s.t.ss) ..
        "else " ..
            coder_stmts(s.f.ss) ..
        "end"
    elseif s.tag == 'loop' then
        local ids = concat(', ', map(s.ids or {{str="_"}}, function(id) return id.str end))
        local itr = s.itr and coder_expr(s.itr) or ''
        return "for " .. ids .. " in iter(" .. itr .. ") do " ..
            coder_stmts(s.blk.ss) ..
        "end"
    elseif s.tag == 'break' then
        return "break"
    elseif s.tag == 'catch' then
        local n = N()
        local ok, esc = "atm_ok_"..n, "atm_esc_"..n
        local cnd = s.esc and (esc..' ~= "'..s.esc.str..'"') or "false"
        return [[
            local ]]..ok..','..esc..[[ = pcall(
                function () ]]..
                    coder_stmts(s.blk.ss) .. [[
                end
            )
            if ]] .. ok .. " or atm_catch("..esc..','..coder_expr(s.cnd.e)..','..(s.cnd.f and coder_expr(s.cnd.f) or 'nil')..[[) then
                -- ok
            else
                error(]]..esc..[[, 0)
            end
        ]]
    elseif s.tag == 'expr' then
        return coder_expr(s.e)
    else
        return tostr_stmt(s)
    end
end

function coder_expr (e)
    if e.tag == 'tag' then
        return L(e.tk)..'"'..e.tk.str..'"'
    elseif e.tag == 'index' then
        return '(' .. coder_expr(e.t) .. ")[atm_idx(" .. coder_expr(e.idx) .. ')]'
    elseif e.tag == 'table' then
        local ps = concat(", ", map(e.ps, function (t)
            return '['..coder_expr(t.k)..'] = '..coder_expr(t.v)
        end))
        return '{' .. ps .. '}'
    elseif e.tag == 'bin' then
        return '('..tostr_expr(e.e1)..' '..(L(e.op)..(OPS.lua[e.op.str] or e.op.str))..' '..tostr_expr(e.e2)..')'
    elseif e.tag == 'call' then
        return '('..coder_expr(e.f)..')('..concat(", ", map(e.args, coder_expr))..')'
    elseif e.tag == 'func' then
        local pars = concat(', ', map(e.pars, function (id) return id.str end))
        return "function (" .. pars .. ") " ..
            coder_stmts(e.blk.ss) ..
        " end"
    else
        return L(e.tk)..tostr_expr(e)
    end
end
