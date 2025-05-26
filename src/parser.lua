function parser ()
    TK0 = TK1
    TK1 = LEX()
end

function check (str, tag)
    return (tag==nil or TK1.tag==tag) and (str==nil or TK1.str==str) and TK1 or nil
end
function check_no_err (str, tag)
    local tk = check(str, tag)
    if tk then
        err(TK1, "unexpected "..((str and "'"..str.."'") or (tag and '<'..tag..'>')))
    end
    return tk
end
function check_err (str, tag)
    local tk = check(str, tag)
    if not tk then
        err(TK1, "expected "..((str and "'"..str.."'") or (tag and '<'..tag..'>')))
    end
    return tk
end
function accept (str, tag)
    local tk = check(str, tag)
    if tk then
        parser()
    end
    return tk
end
function accept_err (str, tag)
    local tk = check_err(str, tag)
    parser()
    return tk
end

function parser_list (sep, clo, f)
    assert(sep or clo)
    local l = {}
    if clo and check(clo) then
        return l
    end
    l[#l+1] = f()
    while true do
        if clo and check(clo) then
            return l
        end
        if sep then
            if check(sep) then
                accept_err(sep)
                if clo and check(clo) then
                    return l
                end
            else
                return l
            end
        end
        --[[
        -- HACK-01: flatten "seq" into list
        if f == parser_stmt then
            local ss = f()
            if ss.tag == "seq" then
                for _,s in ipairs(ss) do
                    l[#l+1] = s
                end
            else
                l[#l+1] = ss
            end
        else
            l[#l+1] = f()
        end
        ]]
        l[#l+1] = f()
    end
    return l
end

function parser_ids (clo)
    return parser_list(",", clo, function () return accept_err(nil,'id') end)
end

function parser_dots_pars ()
    if accept('...') then
        return true, {}
    else
        local l = {}
        if check(')') then
            return false, l
        end
        l[#l+1] = accept_err(nil,'id')
        while not check(')') do
            accept_err(sep)
            if accept('...') then
                return true, l
            end
            l[#l+1] = accept(nil,'id')
        end
        return false, l
    end
end
