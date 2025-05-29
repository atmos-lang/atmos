function N ()
    _n_ = _n_ + 1
    return _n_
end

local function L (tk)
    local ls = ''
    if tk and tk.lin then
        if tk.lin < _l_ then
            return ls           -- TODO: workaround for watching
        end
        assert(tk.lin >= _l_)
        while tk.lin > _l_ do
            ls = ls .. '\n'
            _l_ = _l_ + 1
        end
    end
    return ls
end

local function is_stmt (e)
    return e.tag=='dcl' or e.tag=='set'
end

function coder_exprs (es)
    local function f (e, i)
        if i<#es or is_stmt(e) then
            return coder(e)
        else
            return "return "..coder(e)
        end
    end
    return join(' ; ', map(es,f)) .. " ; "
end

function coder_stmt (e)
    if false then
    elseif e.tag == 'dcl' then
        local mod = ''; do
            if e.tk.str == 'val' then
                mod = " <const>"
            elseif e.tk.str == 'pin' then
                mod = " <close>"
            end
        end
        if e.custom == 'block' then
            local id, blk = e.ids[1], e.sets[1]
            return coder(blk) .. [[ ; local ]] .. id.str .. mod .. ' = atm_'..blk.esc.str:sub(2)
        elseif e.custom == 'catch' then
            local n = _n_+1
            local ids = join(',', map(e.ids, function (id) return id.str end))
            local cat = coder(e.sets[1])
            return cat .. ' ; local ' .. ids .. ' = atm_ok_' .. n .. ', atm_esc_' .. n
        elseif e.custom == 'func' then
            local id, f = e.ids[1], e.sets[1]
            return 'local ' .. id.str .. ' ; ' .. id.str .. mod .. ' = ' .. coder(f)
        else
            local ids = join(', ', map(e.ids,  function(id) return id.str end))
            local sets = e.sets and (' = '..join(', ',map(e.sets,coder))) or ''
            return 'local ' .. ids .. mod .. sets
        end
    elseif e.tag == 'set' then
        return join(',', map(e.dsts,coder))..' = '..join(',', map(e.srcs,coder))
    elseif e.tag == 'return' then
        return "return " .. join(',', map(e.es,coder))
    elseif e.tag == 'if' then
        return "if " .. coder(e.cnd) .. " then " ..
            coder_exprs(e.t.es) ..
        "else " ..
            coder_exprs(e.f.es) ..
        "end"
    elseif e.tag == 'loop' then
        local ids = join(', ', map(e.ids or {{str="_"}}, function(id) return id.str end))
        local itr = e.itr and coder(e.itr) or ''
        return "for " .. ids .. " in iter(" .. itr .. ") do " ..
            coder_exprs(e.blk.es) ..
        "end"
    elseif e.tag == 'break' then
        return "break"
    else
        error(e.tag)
    end
end

function coder (e)
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
        return '(' .. coder(e.t) .. ")[atm_idx(" .. coder(e.idx) .. ')]'
    elseif e.tag == 'table' then
        local ps = join(", ", map(e.ps, function (t)
            return '['..coder(t.k)..'] = '..coder(t.v)
        end))
        return '{' .. ps .. '}'
    elseif e.tag == 'uno' then
        return '('..(OPS.lua[e.op.str] or e.op.str)..' '..coder(e.e)..')'
    elseif e.tag == 'bin' then
        if e.op.str == '++' then
            return "atm_cat(" .. coder(e.e1) .. ',' .. coder(e.e2) .. ')'
        elseif e.op.str == '??' then
            return "atm_is(" .. coder(e.e1) .. ',' .. coder(e.e2) .. ')'
        elseif e.op.str == '!?' then
            return "(not atm_is(" .. coder(e.e1) .. ',' .. coder(e.e2) .. '))'
        elseif e.op.str == '?>' then
            return "atm_in(" .. coder(e.e1) .. ',' .. coder(e.e2) .. ')'
        elseif e.op.str == '!>' then
            return "(not atm_in(" .. coder(e.e1) .. ',' .. coder(e.e2) .. '))'
        elseif e.op.str == '<?' then
            return "atm_in(" .. coder(e.e2) .. ',' .. coder(e.e1) .. ')'
        elseif e.op.str == '<!' then
            return "(not atm_in(" .. coder(e.e2) .. ',' .. coder(e.e1) .. '))'
        else
            return '('..coder(e.e1)..' '..(L(e.op)..(OPS.lua[e.op.str] or e.op.str))..' '..coder(e.e2)..')'
        end
    elseif e.tag == 'call' then
        return '('..coder(e.f)..')('..join(", ", map(e.args, coder))..')'
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
            coder_exprs(e.blk.es) ..
        " end"
    elseif e.tag == 'parens' then
        return L(e.tk) .. '(' .. coder(e.e) .. ')'

    elseif e.tag == 'dcl' then
        local mod = ''; do
            if e.tk.str == 'val' then
                mod = " <const>"
            elseif e.tk.str == 'pin' then
                mod = " <close>"
            end
        end
        local ids = join(', ', map(e.ids,  function(id) return id.str end))
        local sets = e.sets and (' = '..join(', ',map(e.sets,coder))) or ''
        return 'local ' .. ids .. mod .. sets
    elseif e.tag == 'block' then
        return "do " .. coder_exprs(e.es) .. " end"
    elseif e.tag == 'defer' then
        local n = N()
        local def = "atm_"..n
        return
            "local " .. def .. " <close> = setmetatable({}, {__close=" ..
                "function () " ..
                    coder_exprs(e.blk.es) ..
                " end" ..
            "})"
    elseif e.tag == 'catch' then
        local n = N()
        local ok, esc = "atm_ok_"..n, "atm_esc_"..n
        local xe  = coder(e.cnd.e)
        local xf  = e.cnd.f and coder(e.cnd.f) or 'nil'
        local blk = coder_exprs(e.blk.es)
        return
            "local " .. ok .. ',' .. esc .. " = pcall(" ..
                "function () " ..
                    blk ..
                " end" ..
            ") ; " ..
            "if " .. ok .. " or atm_catch("..esc..','..xe..','..xf..") then else "..
                "error(" .. esc .. ", 0)" ..
            " end"
    else
print(e.tag)
        return L(e.tk) .. tostr_expr(e)
    end
end
