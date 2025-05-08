tk0 = nil
tk1 = nil
tks = nil

function parser (f)
    if f then
        tks = f
    end
    tk0 = tk1
    tk1 = tks()
end

function check_str (str)
    return tk1.str==str and tk1
end
function check_str_err (str)
    if not check_str(str) then
        error("expected '"..str.."' : have "..tk1.str)
    end
    return true
end
function accept_str (str)
    local ret = check_str(str)
    if ret then
        parser()
    end
    return ret
end
function accept_str_err (str)
    local tk = check_str_err(str)
    parser()
    return tk
end

function check_sym (sym)
    return tk1.tag=="sym" and tk1.str==sym and tk1
end
function check_sym_err (sym)
    local tk = check_sym(sym)
    if not tk then
        error("expected '"..sym.."' : have "..tk1.str)
    end
    return tk
end
function accept_sym (sym)
    local tk = check_sym(sym)
    if tk then
        parser()
    end
    return tk
end
function accept_sym_err (sym)
    local tk = check_sym_err(sym)
    parser()
    return tk
end

function check_key (key)
    return tk1.tag=="key" and tk1.str==key and tk1
end
function check_key_err (key)
    local tk = check_key(key)
    if not tk then
        error("expected '"..key.."' : have "..tk1.str)
    end
    return tk
end
function accept_key (key)
    local tk = check_key(key)
    if tk then
        parser()
    end
    return tk
end
function accept_key_err (key)
    local tk = check_key_err(key)
    parser()
    return tk
end

function check_tag (tag)
    return tk1.tag==tag and tk1
end
function check_tag_err (tag)
    local tk = check_tag(tag)
    if not tk then
        error("expected "..tag.." : have "..tk1.str)
    end
    return tk
end
function accept_tag (tag)
    local tk = check_tag(tag)
    if tk then
        parser()
    end
    return tk
end
function accept_tag_err (tag)
    local tk = check_tag_err(tag)
    parser()
    return tk
end

function parser_list (sep, clo, f)
    local l = {}
    if check_str(clo) then
        return l
    end
    l[#l+1] = f()
    while true do
        if check_str(clo) then
            return l
        end
        if sep then
            accept_str_err(sep)
            if check_str(clo) then
                return l
            end
        end
        l[#l+1] = f()
    end
    return l
end
