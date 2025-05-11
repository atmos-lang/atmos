local _n_ = 0
function N ()
    _n_ = _n_ + 1
    return _n_
end

function coder_stmts (ss)
    return concat('\n', map(ss,coder_stmt)) .. "\n"
end

function coder_stmt (s)
    if false then
    elseif s.tag == 'dcl' then
        local cst = s.tk.str=='val' and " <const>" or ''
        local ids = concat(', ', map(s.ids,  function(id) return id.str end))
        local sets = s.sets and (' = '..concat(', ',map(s.sets,coder_expr))) or ''
        return 'local ' .. ids .. cst .. sets
    elseif s.tag == 'set' then
        return concat(',', map(s.dsts,coder_expr))..' = '..concat(',', map(s.srcs,coder_expr))
    elseif s.tag == 'block' then
        return "do\n" ..
            coder_stmts(s.ss) ..
            (s.esc and (":"..s.esc.str.."::\n") or "")..
        "end"
    elseif s.tag == 'defer' then
        local n = N()
        local def = "atm_"..n
        return [[
            local ]] .. def .. [[ <close> = setmetatable({}, {__close=
                function () ]]..
                    concat('\n', map(s.blk.ss,coder_stmt)) ..'\n' .. [[
                end
            })
        ]]
    elseif s.tag == 'escape' then
        return "goto " .. s.e.tk.str:sub(2)
    elseif s.tag == 'return' then
        return "return " .. coder_expr(s.e)
    elseif s.tag == 'if' then
        return "if " .. coder_expr(s.cnd) .. " then\n" ..
            concat('\n', map(s.t.ss,coder_stmt)) ..'\n' ..
        "else\n" ..
            concat('\n', map(s.f.ss,coder_stmt)) ..'\n' ..
        "end"
    elseif s.tag == 'loop' then
        local ids = concat(', ', map(s.ids or {{str="_"}}, function(id) return id.str end))
        local itr = s.itr and coder_expr(s.itr) or ''
        return "for " .. ids .. " in iter(" .. itr .. ") do\n" ..
            concat('\n', map(s.blk.ss,coder_stmt)) ..'\n' ..
        "end"
    elseif s.tag == 'break' then
        return "break"
    elseif s.tag == 'catch' then
        local n = N()
        local ok, esc = "atm_ok_"..n, "atm_esc_"..n
        return [[
            local ]]..ok..','..esc..[[ = pcall(
                function () ]]..
                    concat('\n', map(s.blk.ss,coder_stmt)) ..'\n' .. [[
                end
            )
            if not ]]..ok..' and '..esc..' ~= "'..s.esc.str..[[" then
                error(]]..esc..[[, 0)
            end
        ]]
    elseif s.tag == 'throw' then
        return "error(" .. coder_expr(s.e) .. ", 0)"
    elseif s.tag == 'expr' then
        return coder_expr(s.e)
    else
        return tostr_stmt(s)
    end
end

function coder_expr (e)
    if e.tag == 'tag' then
        return '"'..e.tk.str..'"'
    elseif e.tag == 'index' then
        return coder_expr(e.t) .. '[atm_idx(' .. coder_expr(e.idx) .. ')]'
    elseif e.tag == 'table' then
        local ps = concat(", ", map(e.ps, function (t)
            return '['..coder_expr(t.k)..'] = '..coder_expr(t.v)
        end))
        return '{' .. ps .. '}'
    elseif e.tag == 'call' then
        return coder_expr(e.f)..'('..concat(", ", map(e.args, coder_expr))..')'
    elseif e.tag == 'func' then
        local pars = concat(', ', map(e.pars, function (id) return id.str end))
        local ss = concat('\n', map(e.blk.ss,coder_stmt))
        return "function (" .. pars .. ")\n" ..
            ss ..'\n' ..
        "end"
    else
        return tostr_expr(e)
    end
end
