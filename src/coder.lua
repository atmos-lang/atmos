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
    elseif s.tag == "dcl" then
        local cst = s.tk.str=="val" and " <const>" or ''
        local set = s.set and (' = '..coder_expr(s.set)) or ''
        return 'local ' .. s.id.str .. cst .. set
    elseif s.tag == "set" then
        return coder_expr(s.dst)..' = '..coder_expr(s.src)
    elseif s.tag == "block" then
        return "do\n" ..
            coder_stmts(s.ss) ..
            (s.esc and (":"..s.esc.str.."::\n") or "")..
        "end"
    elseif s.tag == "escape" then
        return "goto " .. s.e.tk.str:sub(2)
    elseif s.tag == "catch" then
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
    elseif s.tag == "throw" then
        return "error(" .. coder_expr(s.e) .. ", 0)"
    elseif s.tag == "expr" then
        return coder_expr(s.e)
    else
        return tostr_stmt(s)
    end
end

function coder_expr (e)
    if e.tag == "tag" then
        return '"'..e.tk.str..'"'
    elseif e.tag == "call" then
        return coder_expr(e.f)..'('..concat(", ", map(e.args, coder_expr))..')'
    else
        return tostr_expr(e)
    end
end
