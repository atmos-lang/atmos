tk0 = nil
tk1 = nil
tks = nil

require "accept"

function parser_lexer (f)
    if f then
        tks = f
    end
    tk0 = tk1
    tk1 = tks()
end

function parser_expr_prim_1 ()
    if accept_key("nil") then
        return { tag="nil", tk=tk0 }
    elseif accept_key("true") or accept_key("false") then
        return { tag="bool", tk=tk0 }
    elseif accept_tag("num") then
        return { tag="num", tk=tk0 }
    elseif accept_tag("var") then
        return { tag="var", tk=tk0 }
    elseif accept_sym("(") then
        local e = parser_expr()
        accept_sym_err(")")
        return e
    else
        error("expected expression : have "..tk1.str)
    end
end

function parser_expr_bin_2 (pre)
    local e1 = pre or parser_expr_prim_1()
    local ok = check_tag("op") and contains(OPS.bins, tk1.str)
    if not ok then
        return e1
    end
    accept_tag_err("op")
    local op = tk0
    if pre and pre.op.str ~= op.str then
        error("binary operation error : use parentheses to disambiguate")
    end
    local e2 = parser_expr_prim_1()
    return parser_expr_bin_2 { tag="bin", op=op, e1=e1, e2=e2 }
end

parser_expr = parser_expr_bin_2
