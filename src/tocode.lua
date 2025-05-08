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
