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

function check_key (key)
    return tk1.tag=="key" and tk1.str==key
end
function check_key_err (key)
    if not check_key(key) then
        error("expected '"..key.."' : have "..tk1.str)
    end
    return true
end
function accept_key (key)
    local ret = check_key(key)
    if ret then
        parser_lexer()
    end
    return ret
end
function accept_key_err (key)
    check_key_err(key)
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
