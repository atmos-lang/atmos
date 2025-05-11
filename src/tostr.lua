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
    elseif s.tag == "defer" then
        return "defer {\n" ..
            concat('\n', map(s.blk.ss,tostr_stmt)) ..'\n' ..
        "}"
    elseif s.tag == "escape" then
        return "escape(" .. tostr_expr(s.e) .. ")"
    elseif s.tag == "return" then
        return "return(" .. tostr_expr(s.e) .. ")"
    elseif s.tag == "if" then
        return "if " .. tostr_expr(s.cnd) .. " {\n" ..
            concat('\n', map(s.t.ss,tostr_stmt)) ..'\n' ..
        "} else {\n" ..
            concat('\n', map(s.f.ss,tostr_stmt)) ..'\n' ..
        "}"
    elseif s.tag == "loop" then
        return "loop {\n" ..
            concat('\n', map(s.blk.ss,tostr_stmt)) ..'\n' ..
        "}"
    elseif s.tag == "break" then
        return "break"
    elseif s.tag == "catch" then
        return "catch " .. s.esc.str .. " {\n" ..
            concat('\n', map(s.blk.ss,tostr_stmt)) ..'\n' ..
        "}"
    elseif s.tag == "throw" then
        return "throw(" .. tostr_expr(s.e) .. ")"
    elseif s.tag == "expr" then
        return tostr_expr(s.e)
    else
        print(s.tag)
        error("TODO")
    end
end

function tostr_expr (e)
    if e.tag=="nil" or e.tag=="bool" or e.tag=="tag" or e.tag=="num" or e.tag=="var" then
        return e.tk.str
    elseif e.tag == "str" then
        return '"' .. e.tk.str .. '"'
    elseif e.tag == "uno" then
        return '('..e.op.str..tostr_expr(e.e)..')'
    elseif e.tag == "bin" then
        return '('..tostr_expr(e.e1)..' '..e.op.str..' '..tostr_expr(e.e2)..')'
    elseif e.tag == "index" then
        return tostr_expr(e.t)..'['..tostr_expr(e.idx)..']'
    elseif e.tag == "table" then
        local ps = concat(", ", map(e.ps, function (t)
            return '('..tostr_expr(t.k)..','..tostr_expr(t.v)..')'
        end))
        return '[' .. ps .. ']'
    elseif e.tag == "call" then
        return tostr_expr(e.f)..'('..concat(", ", map(e.args, tostr_expr))..')'
    elseif e.tag == "func" then
        local pars = concat(', ', map(e.pars, function (id) return id.str end))
        local ss = concat('\n', map(e.blk.ss,tostr_stmt))
        return "func (" .. pars .. ") {\n" ..
            ss ..'\n' ..
        "}"
    elseif e.tag == "exec" then
        return e.tk.str .. "(" .. tostr_expr(e.e) .. ")"
    else
        print(e.tag)
        error("TODO")
    end
end
