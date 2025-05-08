function expr_tocode (e)
    if e.tag == "uno" then
        return '('..e.op.str..expr_tocode(e.e)..')'
    elseif e.tag == "bin" then
        return '('..expr_tocode(e.e1)..' '..e.op.str..' '..expr_tocode(e.e2)..')'
    else
        return e.tk.str
    end
end
