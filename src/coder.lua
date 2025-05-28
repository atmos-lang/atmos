function N ()
    _n_ = _n_ + 1
    return _n_
end

local function L (tk)
    local ls = ''
    if tk and tk.lin then
        assert(tk.lin >= _l_)
        while tk.lin > _l_ do
            ls = ls .. '\n'
            _l_ = _l_ + 1
        end
    end
    return ls
end

function coder_stmts (ss)
    return join(' ; ', map(ss,coder_stmt)) .. " ; "
end

function coder_stmt (s)
    if false then
    elseif s.tag == 'dcl' then
        local mod = ''; do
            if s.tk.str == 'val' then
                mod = " <const>"
            elseif s.tk.str == 'pin' then
                mod = " <close>"
            end
        end
        if s.custom == 'block' then
            local id, blk = s.ids[1], s.sets[1]
            return coder_stmt(blk) .. [[ ; local ]] .. id.str .. mod .. ' = atm_'..blk.esc.str:sub(2)
        elseif s.custom == 'catch' then
            local n = _n_+1
            local ids = join(',', map(s.ids, function (id) return id.str end))
            local cat = coder_stmt(s.sets[1])
            return cat .. ' ; local ' .. ids .. ' = atm_ok_' .. n .. ', atm_esc_' .. n
        elseif s.custom == 'func' then
            local id, f = s.ids[1], s.sets[1]
            return 'local ' .. id.str .. ' ; ' .. id.str .. mod .. ' = ' .. coder_expr(f)
        else
            local ids = join(', ', map(s.ids,  function(id) return id.str end))
            local sets = s.sets and (' = '..join(', ',map(s.sets,coder_expr))) or ''
            return 'local ' .. ids .. mod .. sets
        end
    elseif s.tag == 'set' then
        return join(',', map(s.dsts,coder_expr))..' = '..join(',', map(s.srcs,coder_expr))
    elseif s.tag == 'block' then
        local str = s.esc and s.esc.str:sub(2)
        return (s.esc and ("local atm_"..str) or "") .. ' ' ..
            "do " ..
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
        return "return " .. join(',', map(s.es,coder_expr))
    elseif s.tag == 'if' then
        return "if " .. coder_expr(s.cnd) .. " then " ..
            coder_stmts(s.t.ss) ..
        "else " ..
            coder_stmts(s.f.ss) ..
        "end"
    elseif s.tag == 'loop' then
        local ids = join(', ', map(s.ids or {{str="_"}}, function(id) return id.str end))
        local itr = s.itr and coder_expr(s.itr) or ''
        return "for " .. ids .. " in iter(" .. itr .. ") do " ..
            coder_stmts(s.blk.ss) ..
        "end"
    elseif s.tag == 'break' then
        return "break"
    elseif s.tag == 'catch' then
        local n = N()
        local ok, esc = "atm_ok_"..n, "atm_esc_"..n
        local xe  = coder_expr(s.cnd.e)
        local xf  = s.cnd.f and coder_expr(s.cnd.f) or 'nil'
        local blk = coder_stmts(s.blk.ss)
        return [[
            local ]]..ok..','..esc..[[ = pcall(
                function () ]]..
                    blk .. [[
                end
            )
            if ]] .. ok .. " or atm_catch("..esc..','..xe..','..xf..[[) then
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
        return L(e.tk) .. '"' .. e.tk.str:sub(2) .. '"'
    elseif e.tag == 'acc' then
        if e.tk.str == 'pub' then
            return L(e.tk) .. "atm_me().pub"
        else
            return L(e.tk) .. tostr_expr(e)
        end
    elseif e.tag == 'nat' then
        return L(e.tk) .. e.tk.str
    elseif e.tag == 'index' then
        return '(' .. coder_expr(e.t) .. ")[atm_idx(" .. coder_expr(e.idx) .. ')]'
    elseif e.tag == 'table' then
        local ps = join(", ", map(e.ps, function (t)
            return '['..coder_expr(t.k)..'] = '..coder_expr(t.v)
        end))
        return '{' .. ps .. '}'
    elseif e.tag == 'uno' then
        return '('..(OPS.lua[e.op.str] or e.op.str)..' '..coder_expr(e.e)..')'
    elseif e.tag == 'bin' then
        if e.op.str == '++' then
            return "atm_cat(" .. coder_expr(e.e1) .. ',' .. coder_expr(e.e2) .. ')'
        elseif e.op.str == '??' then
            return "atm_is(" .. coder_expr(e.e1) .. ',' .. coder_expr(e.e2) .. ')'
        elseif e.op.str == '!?' then
            return "(not atm_is(" .. coder_expr(e.e1) .. ',' .. coder_expr(e.e2) .. '))'
        elseif e.op.str == '?>' then
            return "atm_in(" .. coder_expr(e.e1) .. ',' .. coder_expr(e.e2) .. ')'
        elseif e.op.str == '!>' then
            return "(not atm_in(" .. coder_expr(e.e1) .. ',' .. coder_expr(e.e2) .. '))'
        elseif e.op.str == '<?' then
            return "atm_in(" .. coder_expr(e.e2) .. ',' .. coder_expr(e.e1) .. ')'
        elseif e.op.str == '<!' then
            return "(not atm_in(" .. coder_expr(e.e2) .. ',' .. coder_expr(e.e1) .. '))'
        else
            return '('..coder_expr(e.e1)..' '..(L(e.op)..(OPS.lua[e.op.str] or e.op.str))..' '..coder_expr(e.e2)..')'
        end
    elseif e.tag == 'call' then
        return '('..coder_expr(e.f)..')('..join(", ", map(e.args, coder_expr))..')'
    elseif e.tag == 'func' then
        local pars = join(', ', map(e.pars, function (id) return id.str end))
        local dots = ''; do
            if e.dots then
                if #e.pars == 0 then
                    dots = '...'
                else
                    dots = ', ...'
                end
            end
        end
        return "function (" .. pars .. dots .. ") " ..
            coder_stmts(e.blk.ss) ..
        " end"
    elseif e.tag == 'parens' then
        return L(e.tk) .. '(' .. coder_expr(e.e) .. ')'
    else
        return L(e.tk) .. tostr_expr(e)
    end
end
