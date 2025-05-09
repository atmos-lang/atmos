function stmts_code (ss)
    return concat('\n', map(ss,stmt_code)) .. "\n"
end

function stmt_code (s)
    if false then
    elseif s.tag == "block" then
        return "do\n" ..
            stmts_code(s.ss) ..
            (s.esc and (":"..s.esc.str.."::\n") or "")..
        "end"
    elseif s.tag == "escape" then
        return "goto " .. s.e.tk.str:sub(2)
    elseif s.tag == "expr" then
        return expr_code(s.e)
    else
        return stmt_tostr(s)
    end
end

function expr_code (e)
    if e.tag == "tag" then
        return '"'..e.tk.str..'"'
    elseif e.tag == "call" then
        return expr_code(e.f)..'('..concat(", ", map(e.args, expr_code))..')'
    else
        return expr_tostr(e)
    end
end
