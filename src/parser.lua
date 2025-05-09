function parser ()
    TK0 = TK1
    TK1 = LEX()
end

function check (tag, str)
    return (tag==nil or TK1.tag==tag) and (str==nil or TK1.str==str) and TK1 or nil
end
function check_err (tag, str)
    local tk = check(tag, str)
    if not tk then
        err(TK1, "expected "..((str and "'"..str.."'") or (tag and '<'..tag..'>')))
    end
    return tk
end
function accept (tag, str)
    local tk = check(tag, str)
    if tk then
        parser()
    end
    return tk
end
function accept_err (tag, str)
    local tk = check_err(tag, str)
    parser()
    return tk
end

function parser_list (sep, clo, f)
    local l = {}
    if check(nil,clo) then
        return l
    end
    l[#l+1] = f()
    while true do
        if check(nil,clo) then
            return l
        end
        if sep then
            local x = accept_err(nil, sep)
            if check(nil,clo) then
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
