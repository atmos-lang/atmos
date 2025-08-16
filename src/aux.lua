function assertn (n, cnd, err)
    if n > 0 then
        n = n + 1
    end
    if not cnd then
        error(err, n)
    end
    return cnd
end

function assertfx(cur, exp)
    return assert(string.find(cur,exp), cur)
end

function assertx(cur, exp)
    return assert(cur == exp, cur)
end

function warnx(cur, exp)
    return warn(cur == exp, exp)
end

function warn (ok, msg)
    if not ok then
        msg = "WARNING: "..(msg or "<warning message>")
        io.stderr:write(msg..'\n')
    end
end

function totable (...)
    local t = {}
    local n = select('#',...) / 2
    assert((n*2) == select('#',...))
    for i=1, n do
        t[select(i,...)] = select(i+n,...)
    end
    return t
end

function trim (s)
    return (s:gsub("^%s*",""):gsub("\n%s*","\n"):gsub("%s*$",""))
end

function contains (t, v)
    for _,x in ipairs(t) do
        if x == v then
            return true
        end
    end
    return false
end

function xtostring (v)
    if type(v) ~= 'table' then
        return tostring(v)
    elseif v.tag == 'vector' then
        local vs = ""
        local fst = true
        for i=0, #v-1 do
            local x = v[i]
            if not fst then
                vs = vs .. ', '
            end
            vs = vs .. xtostring(x)
            fst = false
        end
        return "#{" .. vs .. "}"
    else
        local fst = true
        local vs = ""
        local t = {}
        for k,x in pairs(v) do
            assert(type(k)=='number' or type(k)=='string')
            --if k ~= 'tag' then
                t[#t+1] = { k, x }
            --end
        end
        table.sort(t, function (x, y) return (tostring(x[1]) < tostring(y[1])) end)
        local i = 1
        for _,kx in ipairs(t) do
            local k,x = table.unpack(kx)
            if not fst then
                vs = vs .. ', '
            end
            if tonumber(k) == i then
                i = i + 1
                vs = vs .. xtostring(x)
            else
                vs = vs .. k .. '=' .. xtostring(x)
            end
            fst = false
        end
        --local tag = v.tag and (':'..v.tag..' ') or ''
        return --[[tag ..]] "{" .. vs .. "}"
    end
end

function xprint (...)
    local ret = {}
    for i=1, select('#', ...) do
        ret[#ret+1] = xtostring(select(i, ...))
    end
    print(table.unpack(ret))
end

function any (t, f)
    for _, v in ipairs(t) do
        if f(v) then
            return true
        end
    end
    return false
end

function xcopy (v)
    if type(v) ~= 'table' then
        return v
    end
    local ret = {}
    for k,x in pairs(v) do
        ret[k] = xcopy(x)
    end
    return ret
end

function map (t, f)
    local ret = {}
    for i,v in ipairs(t) do
        ret[#ret+1] = f(v,i)
    end
    return ret
end

function join (sep, t)
    local ret = ""
    for i,v in ipairs(t) do
        if i > 1 then
            ret = ret .. sep
        end
        ret = ret .. v
    end
    return ret
end

function concat (t1, t2, ...)
    local ret = {}
    for _,v in ipairs(t1) do
        ret[#ret+1] = v
    end
    for _,v in ipairs(t2) do
        ret[#ret+1] = v
    end
    if ... then
        return concat(ret, ...)
    end
    return ret
end
