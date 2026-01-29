require "atmos.lang.tosource"

local function L (tk)
    local ls = ''
    if tk and tk.lin then
        if tk.lin < _l_ then
            return ls
                -- TODO: workaround
                    -- where (tasks.lua, "every-where")
                    -- (exec.lua, "func 2c")
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
    return e.tag=='dcl' or e.tag=='set' or e.tag=='defer' or (
        e.tag=='call' and e.f.tag=='acc' and (
            -- prevents tail call b/c of error messasges
            e.f.tk.str=='throw' or e.f.tk.str=='spawn_in' or
            e.f.tk.str=='emit' or e.f.tk.str=='emit_in'
        )
    )
end

function coder_stmts (es, noret)
    local function f (e, i)
        if noret or i<#es or is_stmt(e) then
            return "; " .. coder(e)
        else
            return "; return " .. coder(e)
        end
    end
    return join('', map(es,f))
end

function coder_args (es)
    return join(", ", map(es,coder))
end

function coder_tag (tag)
    return L(tag) .. '"' .. tag.str:sub(2) .. '"'
end

local ids = { 'break', 'until', 'while', 'return' }

function coder (e)
    if e.tag == 'tag' then
        return coder_tag(e.tk)
    elseif e.tag == 'acc' then
        if e.tk.str == 'pub' then
            --return L(e.tk) .. "(function() print(debug.traceback());return assert(atm_me(true), 'TODO') end)().pub"
            return L(e.tk) .. "assert(task(),'invalid pub : expected enclosing task').pub"
        elseif contains(ids, e.tk.str) then
            return L(e.tk) .. "atm_"..e.tk.str
        else
            return L(e.tk) .. tosource(e)
        end
    elseif e.tag == 'str' then
        return L(e.tk) .. "trim(" .. string.format("%q", e.tk.str) .. ")"
    elseif e.tag == 'nat' then
        return L(e.tk) .. e.tk.str
    elseif e.tag == 'clk' then
        local t = e.tk.clk
        return L(e.tk) .. "clock {" ..
            'h='..t.h..',' .. 'min='..t.min..',' .. 's='..t.s..',' .. 'ms='..t.ms ..
        " }"
    elseif e.tag == 'index' then
        return coder(e.t) ..'['..coder(e.idx) .. ']'
    elseif e.tag == 'table' then
        local es = join(", ", map(e.es, function (t)
            return '['..coder(t.k)..'] = '..coder(t.v)
        end))
        return "atm_table{ " .. es .. "}"
    elseif e.tag == 'uno' then
        return '('..(OPS.lua[e.op.str] or e.op.str)..' '..coder(e.e)..')'
    elseif e.tag == 'bin' then
        if false then
        elseif e.op.str == '===' then
            return "atm_equal(" .. coder(e.e1) .. ',' .. coder(e.e2) .. ')'
        elseif e.op.str == '=!=' then
            return "(not atm_equal(" .. coder(e.e1) .. ',' .. coder(e.e2) .. '))'
        elseif e.op.str == '++' then
            return "atm_cat(" .. coder(e.e1) .. ',' .. coder(e.e2) .. ')'
        elseif e.op.str == '??' then
            return "atm_is(" .. coder(e.e1) .. ',' .. coder(e.e2) .. ')'
        elseif e.op.str == '!?' then
            return "(not atm_is(" .. coder(e.e1) .. ',' .. coder(e.e2) .. '))'
        elseif e.op.str == '?>' then
            return "atm_in(" .. coder(e.e1) .. ',' .. coder(e.e2) .. ')'
        elseif e.op.str == '!>' then
            return "(not atm_in(" .. coder(e.e1) .. ',' .. coder(e.e2) .. '))'
        else
            return '('..coder(e.e1)..' '..(L(e.op)..(OPS.lua[e.op.str] or e.op.str))..' '..coder(e.e2)..')'
        end
    elseif e.tag == 'call' then
        return coder(e.f) .. '(' .. coder_args(e.es) .. ')'
    elseif e.tag == 'met' then
        return coder(e.o) .. ':' .. e.met.str
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
        local f = (
            "function (" .. pars .. dots .. ") " ..
                coder(e.blk) ..
            " end"
        )
        if e.lua then
            f = '(' .. f .. ')'
        else
            f = "atm_func(" .. f .. ")"
        end
        return f
    elseif e.tag == 'parens' then
        local s = coder(e.e)
        if e.e.tag == 'es' then
            s = "(function () return " .. s .. " end)()"
        end
        return L(e.tk) .. '(' .. s .. ')'
    elseif e.tag == 'es' then
        return coder_args(e.es)

    elseif e.tag == 'dcl' then
        local mod = ''; do
            if e.tk.str == 'val' then
                mod = " <const>"
            elseif e.tk.str == 'pin' then
                mod = " <close>"
            end
        end
        local ids = join(", ", map(e.ids,  function(id) return id.str end))
        local out = L(e.tk) .. 'local ' .. ids .. mod
        if not e.set then
            return out
        elseif e.tk.str == 'pin' then
            local chk = (e.ids[1].str == '_') and "false" or "true"
            return out .. " = atm_pin_chk_set(" .. chk .. ", true, "..coder(e.set)..')'
        else
            return out .. " = atm_pin_chk_set(true, false, "..coder(e.set)..')'
        end
    elseif e.tag == 'set' then
        return coder_args(e.dsts) .. ' = atm_pin_chk_set(true, false, ' .. coder(e.src) .. ')'
    elseif e.tag == 'do' then
        if e.esc then
            return (
                "atm_do(" .. coder_tag(e.esc) .. ',' ..
                    "function () " .. coder(e.blk) .. " end" ..
                ")"
            )
        else
            return "(function () " .. coder(e.blk) .. " end)()"
        end
    elseif e.tag == 'stmts' then
        return coder_stmts(e.es, true)
    elseif e.tag == 'block' then
        return coder_stmts(e.es)
    elseif e.tag == 'defer' then
        local n = N()
        local def = "atm_"..n
        return
            "local " .. def .. " <close> = setmetatable({}, {__close=" ..
                "function () " ..
                    coder_stmts(e.blk.es,true) ..
                " end" ..
            "})"
    elseif e.tag == 'ifs' then
        local function f (case)
            local cnd,e = table.unpack(case)
            local n = "atm_" .. N()
            if cnd == 'else' then
                cnd = "true"
            else
                cnd = coder(cnd)
            end
            return "local " .. n .. "=" .. cnd .. " ; if " .. n .. " then return (" .. coder(e) .. ")(" .. n .. ") end"
        end
        if e.match then
            return (
                "(function (atm_" .. e.match.n .. ") " ..
                    join(' ', map(e.cases,f)) ..
                " end)(" .. coder(e.match.e) .. ")"
            )
        else
            return (
                "(function () " ..
                    join(' ', map(e.cases,f)) ..
                " end)()"
            )
        end
    elseif e.tag == 'loop' then
        local ids = join(', ', map(e.ids or {{str="_"}}, function(id) return id.str end))
        local itr = e.itr and coder(e.itr) or ''
        return (
            "atm_loop(" ..
                "function () " ..
                    "for " .. ids .. " in iter(" .. itr .. ") do " ..
                        coder_stmts(e.blk.es,true) ..
                    " end" ..
                " end" ..
            ")"
        )
    elseif e.tag == 'catch' then
        local xe = coder(e.cnd)
        return (
            "catch(" .. xe .. ',' ..
                "function () " .. coder(e.blk) .. " end" ..
            ")"
        )

    else
        --print(e.tag)
        return L(e.tk) .. tosource(e)
    end
end
