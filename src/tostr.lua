function tostr_stmt (s)
    if false then
    elseif s.tag == 'dcl' then
        local f = function (se)
            if s.custom then
                return tostr_stmt(se)
            else
                return tostr_expr(se)
            end
        end
        local ids = concat(', ', map(s.ids,  function(id) return id.str end))
        local sets = s.sets and (' = '..concat(', ',map(s.sets,f))) or ''
        return s.tk.str .. " " .. ids .. sets
    elseif s.tag == 'set' then
        return "set "..concat(', ',map(s.dsts,tostr_expr)).." = "..concat(', ',map(s.srcs,tostr_expr))
    elseif s.tag == 'block' then
        return "do " .. (s.esc and s.esc.str.." " or "") .. "{\n" ..
            concat('\n', map(s.ss,tostr_stmt)) ..'\n' ..
        "}"
    elseif s.tag == 'defer' then
        return "defer {\n" ..
            concat('\n', map(s.blk.ss,tostr_stmt)) ..'\n' ..
        "}"
    elseif s.tag == 'escape' then
        return "escape (" .. s.esc.str .. ', ' .. tostr_expr(s.e) .. ')'
    elseif s.tag == 'return' then
        return "return(" .. concat(',',map(s.es,tostr_expr)) .. ")"
    elseif s.tag == 'if' then
        return "if " .. tostr_expr(s.cnd) .. " {\n" ..
            concat('\n', map(s.t.ss,tostr_stmt)) ..'\n' ..
        "} else {\n" ..
            concat('\n', map(s.f.ss,tostr_stmt)) ..'\n' ..
        "}"
    elseif s.tag == 'loop' then
        local ids = s.ids and (' '..concat(', ', map(s.ids, function(id) return id.str end))) or ''
        local itr = s.itr and ' in '..tostr_expr(s.itr) or ''
        return "loop" .. ids .. itr .. " {\n" ..
            concat('\n', map(s.blk.ss,tostr_stmt)) ..'\n' ..
        "}"
    elseif s.tag == 'break' then
        return "break"
    elseif s.tag == 'catch' then
        local esc = s.esc and (s.esc.str..' ') or ''
        local xf = s.cnd.f and (', '..tostr_expr(s.cnd.f)) or ''
        return "catch " .. tostr_expr(s.cnd.e) .. xf .. " {\n" ..
            concat('\n', map(s.blk.ss,tostr_stmt)) ..'\n' ..
        "}"
    elseif s.tag == 'expr' then
        return tostr_expr(s.e)
    else
        print(s.tag)
        error("TODO")
    end
end

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
        local ps = concat(", ", map(e.ps, function (t)
            return '('..tostr_expr(t.k)..','..tostr_expr(t.v)..')'
        end))
        return '[' .. ps .. ']'
    elseif e.tag == 'call' then
        return tostr_expr(e.f)..'('..concat(", ", map(e.args, tostr_expr))..')'
    elseif e.tag == 'func' then
        local pars = concat(', ', map(e.pars, function (id) return id.str end))
        local dots = ''; do
            if e.dots then
                if #e.pars == 0 then
                    dots = '...'
                else
                    dots = ', ...'
                end
            end
        end
        local ss = concat('\n', map(e.blk.ss,tostr_stmt))
        return "func (" .. pars .. dots .. ") {\n" ..
            ss ..'\n' ..
        "}"
    elseif e.tag == 'exec' then
        return e.tk.str .. "(" .. tostr_expr(e.e) .. ")"
    elseif e.tag == 'parens' then
        return '('..tostr_expr(e.e)..')'
    else
        print(e.tag)
        error("TODO")
    end
end
