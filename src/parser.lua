local tk0, tk1
local tks

function parser_lexer (f)
    if f then
        tks = f
    end
    tk0 = tk1
    tk1 = tks()
end

function check_sym (sym)
    return tk1.tag=="sym" and tk1.str==sym
end
function check_sym_err (sym)
    if not check_sym(sym) then
        error("expected '"..sym.."' : have "..tk1.str)
    end
    return true
end
function accept_sym (sym)
    local ret = check_sym(sym)
    if ret then
        parser_lexer()
    end
    return ret
end
function accept_sym_err (sym)
    check_sym_err(sym)
    parser_lexer()
    return true
end

function check_tag (tag)
    return tk1.tag == tag
end
function check_tag_err (tag)
    if not check_tag(tag) then
        error("expected "..tag.." : have "..tk1.str)
    end
    return true
end
function accept_tag (tag)
    local ret = check_tag(tag)
    if ret then
        parser_lexer()
    end
    return ret
end
function accept_tag_err (tag)
    check_tag_err(tag)
    parser_lexer()
    return true
end

function parser_expr_prim_1 ()
    if accept_tag("num") then
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
