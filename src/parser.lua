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

function parser_expr_prim_1 ()
    if accept_tag("var") then
        return { tag="var", tk=tk0 }
    elseif accept_sym("(") then
        local e = parser_expr()
        accept_sym_err(")")
        return e
    else
        error("expected expression : have "..tk1.str)
    end
end

parser_expr = parser_expr_prim_1
