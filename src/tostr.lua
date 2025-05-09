function stmt_tostr (s)
    if false then
    elseif s.tag == "block" then
        return "do " .. (s.esc and s.esc.str.." " or "") .. "{\n" ..
            concat('\n', map(s.ss,stmt_tostr)) ..'\n' ..
        "}"
    elseif s.tag == "expr" then
        return expr_tostr(s.e)
    else
        error("TODO")
    end
end

function expr_tostr (e)
    if e.tag == "uno" then
        return '('..e.op.str..expr_tostr(e.e)..')'
    elseif e.tag == "bin" then
        return '('..expr_tostr(e.e1)..' '..e.op.str..' '..expr_tostr(e.e2)..')'
    elseif e.tag == "call" then
        return expr_tostr(e.f)..'('..concat(", ", map(e.args, expr_tostr))..')'
    else
        return e.tk.str
    end
end
