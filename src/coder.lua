require "tosource"

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
            return L(e.tk) .. "atm_me(true).pub"
        elseif contains(ids, e.tk.str) then
            return L(e.tk) .. "atm_"..e.tk.str
        else
            return L(e.tk) .. tosource(e)
        end
    elseif e.tag == 'nat' then
        return L(e.tk) .. e.tk.str
    elseif e.tag == 'index' then
        return '(' .. coder(e.t) .. ")[atm_idx(" .. coder(e.t) ..','..coder(e.idx) .. ')]'
    elseif e.tag == 'table' then
        local es = join(", ", map(e.es, function (t)
            return '['..coder(t.k)..'] = '..coder(t.v)
        end))
        return '{' .. es .. '}'
    elseif e.tag == 'vector' then
        local es = coder_args(e.es)
        return "{ tag='vector', " .. es .. '}'
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
        return (
            "atm_func(" ..
                "function (" .. pars .. dots .. ") " ..
                    coder(e.blk) ..
                " end" ..
            ")"
        )
    elseif e.tag == 'parens' then
        return L(e.tk) .. '(' .. coder(e.e) .. ')'
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
        if e.custom == 'func' then
            local id = e.ids[1]
            return 'local ' .. id.str .. ' ; ' .. id.str .. mod .. ' = ' .. coder(e.set)
        else
            local ids = join(', ', map(e.ids,  function(id) return id.str end))
            local set = e.set and (' = '..coder(e.set)) or ''
            return 'local ' .. ids .. mod .. set
        end
    elseif e.tag == 'set' then
        return coder_args(e.dsts) .. ' = ' .. coder(e.src)
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
            if cnd == 'else' then
                cnd = "true"
            else
                cnd = coder(cnd)
            end
            return " elseif " .. cnd .. " then " .. coder(e)
        end
        local head = ""
        if e.head then
            head = coder(e.head)
        end
        return (
            "(function (it) " ..
                "if false then " ..
                    join(' ', map(e.cases,f)) ..
                " end" ..
            " end)(" .. head .. ")"
        )
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
        local xe  = coder(e.cnd.e)
        local xf  = e.cnd.f and coder(e.cnd.f) or 'nil'
        return (
            "atm_catch(" .. xe .. ',' .. xf .. ',' ..
                "function () " .. coder(e.blk) .. " end" ..
            ")"
        )

    else
        --print(e.tag)
        return L(e.tk) .. tosource(e)
    end
end
