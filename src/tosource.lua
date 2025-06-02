--[[
function tostr_stmt (e)
    if false then
    elseif e.tag == 'escape' then
        return "escape (" .. e.esc.str .. ', ' .. tosource(e.e) .. ')'
    elseif e.tag == 'expr' then
        return tosource(e.e)
    else
        print(e.tag)
        error("TODO")
    end
end
]]

function tosource (e)
    if e.tag=='nil' or e.tag=='bool' or e.tag=='tag' or e.tag=='num' or e.tag=='acc' or e.tag=='dots' then
        return e.tk.str
    elseif e.tag == 'str' then
        return '"' .. e.tk.str .. '"'
    elseif e.tag == 'nat' then
        return '`' .. e.tk.str .. '`'
    elseif e.tag == 'uno' then
        return e.op.str..tosource(e.e)
    elseif e.tag == 'bin' then
        return tosource(e.e1)..' '..e.op.str..' '..tosource(e.e2)
    elseif e.tag == 'index' then
        return tosource(e.t)..'['..tosource(e.idx)..']'
    elseif e.tag == 'table' then
        local ps = join(", ", map(e.ps, function (t)
            return '('..tosource(t.k)..','..tosource(t.v)..')'
        end))
        return '[' .. ps .. ']'
    elseif e.tag == 'es' then
        return '('..join(", ", map(e.es, tosource))..')'
    elseif e.tag == 'parens' then
        return '('..tosource(e.e)..')'
    elseif e.tag == 'call' then
        return tosource(e.f) .. '(' .. join(", ", map(e.args, tosource)) .. ')'
    elseif e.tag == 'met' then
        return tosource(e.o) .. '::' .. e.met.str .. '(' .. join(", ", map(e.args, tosource)) .. ')'
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
        local es = join('\n', map(e.blk.es,tostr_stmt))
        return "func (" .. pars .. dots .. ") {\n" ..
            es ..'\n' ..
        "}"
    elseif e.tag == 'return' then
        return "return(" .. join(',',map(e.es,tosource)) .. ")"

    elseif e.tag == 'dcl' then
        local f = function (se)
            if e.custom then
                return tostr_stmt(se)
            else
                return tosource(se)
            end
        end
        local ids = join(', ', map(e.ids,  function(id) return id.str end))
        local set = e.set and (' = '..f(e.set)) or ''
        return e.tk.str .. " " .. ids .. set
    elseif e.tag == 'set' then
        return "set " .. join(', ',map(e.dsts,tosource)) .. " = " .. tosource(e.src)
    elseif e.tag == 'block' then
        return "do " .. (e.esc and e.esc.str.." " or "") .. "{\n" ..
            join('\n', map(e.es,tostr_stmt)) ..'\n' ..
        "}"
    elseif e.tag == 'defer' then
        return "defer {\n" ..
            join('\n', map(e.blk.es,tostr_stmt)) ..'\n' ..
        "}"
    elseif e.tag == 'if' then
        return "if " .. tosource(e.cnd) .. " {\n" ..
            join('\n', map(e.t.es,tosource)) ..'\n' ..
        "} else {\n" ..
            join('\n', map(e.f.es,tosource)) ..'\n' ..
        "}"
    elseif e.tag == 'loop' then
        local ids = e.ids and (' '..join(', ', map(e.ids, function(id) return id.str end))) or ''
        local itr = e.itr and ' in '..tosource(e.itr) or ''
        return "loop" .. ids .. itr .. " {\n" ..
            join('\n', map(e.blk.es,tostr_stmt)) ..'\n' ..
        "}"
    elseif e.tag == 'break' then
        return "break"
    elseif e.tag == 'catch' then
        local esc = e.esc and (e.esc.str..' ') or ''
        local xf = e.cnd.f and (', '..tosource(e.cnd.f)) or ''
        return "catch " .. tosource(e.cnd.e) .. xf .. " {\n" ..
            join('\n', map(e.blk.es,tostr_stmt)) ..'\n' ..
        "}"
    elseif e.tag == 'throw' then
        return 'throw('..join(", ", map(e.args, tosource))..')'
    else
        print(e.tag)
        error("TODO")
    end
end

tostr_stmt = tosource
