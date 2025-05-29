--[[
function tostr_stmt (e)
    if false then
    elseif e.tag == 'escape' then
        return "escape (" .. e.esc.str .. ', ' .. tostr_expr(e.e) .. ')'
    elseif e.tag == 'return' then
        return "return(" .. join(',',map(e.es,tostr_expr)) .. ")"
    elseif e.tag == 'expr' then
        return tostr_expr(e.e)
    else
        print(e.tag)
        error("TODO")
    end
end
]]

function tostr_expr (e)
    if e.tag=='nil' or e.tag=='bool' or e.tag=='tag' or e.tag=='num' or e.tag=='acc' or e.tag=='dots' then
        return e.tk.str
    elseif e.tag == 'str' then
        return '"' .. e.tk.str .. '"'
    elseif e.tag == 'nat' then
        return '`' .. e.tk.str .. '`'
    elseif e.tag == 'uno' then
        return e.op.str..tostr_expr(e.e)
    elseif e.tag == 'bin' then
        return tostr_expr(e.e1)..' '..e.op.str..' '..tostr_expr(e.e2)
    elseif e.tag == 'index' then
        return tostr_expr(e.t)..'['..tostr_expr(e.idx)..']'
    elseif e.tag == 'table' then
        local ps = join(", ", map(e.ps, function (t)
            return '('..tostr_expr(t.k)..','..tostr_expr(t.v)..')'
        end))
        return '[' .. ps .. ']'
    elseif e.tag == 'parens' then
        return '('..tostr_expr(e.e)..')'
    elseif e.tag == 'call' then
        return tostr_expr(e.f)..'('..join(", ", map(e.args, tostr_expr))..')'
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

    elseif e.tag == 'dcl' then
        local f = function (se)
            if e.custom then
                return tostr_stmt(se)
            else
                return tostr_expr(se)
            end
        end
        local ids = join(', ', map(e.ids,  function(id) return id.str end))
        local sets = e.sets and (' = '..join(', ',map(e.sets,f))) or ''
        return e.tk.str .. " " .. ids .. sets
    elseif e.tag == 'set' then
        return "set "..join(', ',map(e.dsts,tostr_expr)).." = "..join(', ',map(e.srcs,tostr_expr))
    elseif e.tag == 'block' then
        return "do " .. (e.esc and e.esc.str.." " or "") .. "{\n" ..
            join('\n', map(e.es,tostr_stmt)) ..'\n' ..
        "}"
    elseif e.tag == 'defer' then
        return "defer {\n" ..
            join('\n', map(e.blk.es,tostr_stmt)) ..'\n' ..
        "}"
    elseif e.tag == 'if' then
        return "if " .. tostr_expr(e.cnd) .. " {\n" ..
            join('\n', map(e.t.es,tostr_expr)) ..'\n' ..
        "} else {\n" ..
            join('\n', map(e.f.es,tostr_expr)) ..'\n' ..
        "}"
    elseif e.tag == 'loop' then
        local ids = e.ids and (' '..join(', ', map(e.ids, function(id) return id.str end))) or ''
        local itr = e.itr and ' in '..tostr_expr(e.itr) or ''
        return "loop" .. ids .. itr .. " {\n" ..
            join('\n', map(e.blk.es,tostr_stmt)) ..'\n' ..
        "}"
    elseif e.tag == 'break' then
        return "break"
    elseif e.tag == 'catch' then
        local esc = e.esc and (e.esc.str..' ') or ''
        local xf = e.cnd.f and (', '..tostr_expr(e.cnd.f)) or ''
        return "catch " .. tostr_expr(e.cnd.e) .. xf .. " {\n" ..
            join('\n', map(e.blk.es,tostr_stmt)) ..'\n' ..
        "}"
    else
        print(e.tag)
        error("TODO")
    end
end

tostr_stmt = tostr_expr
