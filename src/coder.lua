function coder_stmts (ss)
    return concat('\n', map(ss,coder_stmt)) .. "\n"
end

function coder_stmt (s)
    if false then
    elseif s.tag == "block" then
        return "do\n" ..
            coder_stmts(s.ss) ..
            (s.esc and (":"..s.esc.str.."::\n") or "")..
        "end"
    elseif s.tag == "escape" then
        return "goto " .. s.e.tk.str:sub(2)
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
