require "parser"

function parser_expr_prim_1 ()
    if accept_key("nil") then
        return { tag="nil", tk=TK0 }
    elseif accept_key("true") or accept_key("false") then
        return { tag="bool", tk=TK0 }
    elseif accept_tag("tag") then
        return { tag="tag", tk=TK0 }
    elseif accept_tag("num") then
        return { tag="num", tk=TK0 }
    elseif accept_tag("var") then
        return { tag="var", tk=TK0 }
    elseif accept_sym("(") then
        local e = parser_expr()
        accept_sym_err(")")
        return e
    else
        error("expected expression : have "..TK1.str)
    end
end

function parser_expr_suf_2 (pre)
    local e = pre or parser_expr_prim_1()
    local ok = check_tag("sym") and contains(OPS.sufs, TK1.str)
                -- TODO: same line
    if not ok then
        return e
    end

    local sym = accept_tag_err("sym")

    if sym.str == '(' then
        local args = parser_list(",", ")", function () return parser_expr() end)
        accept_sym_err(')')
        return { tag="call", f=e, args=args }
    else
        error("TODO")
    end
end

function parser_expr_pre_3 ()
    local ok = check_tag("op") and contains(OPS.unos, TK1.str)
    if not ok then
        return parser_expr_suf_2()
    end
    local op = accept_tag_err("op")
    local e = parser_expr_pre_3()
    return { tag="uno", op=op, e=e }
end

function parser_expr_bin_4 (pre)
    local e1 = pre or parser_expr_pre_3()
    local ok = check_tag("op") and contains(OPS.bins, TK1.str)
    if not ok then
        return e1
    end
    local op = accept_tag_err("op")
    if pre and pre.op.str ~= op.str then
        error("binary operation error : use parentheses to disambiguate")
    end
    local e2 = parser_expr_pre_3()
    return parser_expr_bin_4 { tag="bin", op=op, e1=e1, e2=e2 }
end

parser_expr = parser_expr_bin_4
