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
    elseif accept_key("val") or accept_key("var") then
        local id = accept_enu_err("var")
        local set = accept_op("=") and parser_expr() or nil
        local dcl = { tag="dcl", tk=id, id=id }
        if set then
            error("TODO")
        else
            return dcl
        end

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
