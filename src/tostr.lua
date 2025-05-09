function tostr_stmt (s)
    if false then
    elseif s.tag == "dcl" then
        return s.tk.str.." "..s.id.str
    elseif s.tag == "set" then
        return "set "..tostr_expr(s.src).." = "..tostr_expr(s.dst)
    elseif s.tag == "block" then
        return "do " .. (s.esc and s.esc.str.." " or "") .. "{\n" ..
            concat('\n', map(s.ss,tostr_stmt)) ..'\n' ..
        "}"
    elseif s.tag == "escape" then
        return "escape(" .. tostr_expr(s.e) .. ")"
    elseif s.tag == "catch" then
        return "catch " .. s.esc.str .. " {\n" ..
            concat('\n', map(s.blk.ss,tostr_stmt)) ..'\n' ..
        "}"
    elseif s.tag == "throw" then
        return "throw(" .. tostr_expr(s.e) .. ")"
    elseif s.tag == "expr" then
        return tostr_expr(s.e)
    else
        error("TODO")
    end
end

function tostr_expr (e)
    if e.tag == "uno" then
        return '('..e.op.str..tostr_expr(e.e)..')'
    elseif e.tag == "bin" then
        return '('..tostr_expr(e.e1)..' '..e.op.str..' '..tostr_expr(e.e2)..')'
    elseif e.tag == "call" then
        return tostr_expr(e.f)..'('..concat(", ", map(e.args, tostr_expr))..')'
    else
        return e.tk.str
    end
end
