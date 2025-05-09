function stmt_tocode (s)
    if false then
    elseif s.tag == "block" then
        return "do " .. (s.esc and s.esc.str.." " or "") .. "{\n" ..
            concat('\n', map(s.ss,stmt_tocode)) ..
        "}"
    elseif s.tag == "expr" then
        return expr_tocode(s.e)
    else
        error("TODO")
    end
end

function expr_tocode (e)
    if e.tag == "uno" then
        return '('..e.op.str..expr_tocode(e.e)..')'
    elseif e.tag == "bin" then
        return '('..expr_tocode(e.e1)..' '..e.op.str..' '..expr_tocode(e.e2)..')'
    elseif e.tag == "call" then
        return expr_tocode(e.f)..'('..concat(map(e.args, expr_tocode),", ")..')'
    else
        return e.tk.str
    end
end
