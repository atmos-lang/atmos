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

function any (t, f)
    for _, v in ipairs(t) do
        if f(v) then
            return true
        end
    end
    return false
end

function atm_equal (v1, v2)
    if v1 == v2 then
        return true
    end

    local t1 = type(v1)
    local t2 = type(v2)
    if t1 ~= t2 then
        return false
    end

    local mt1 = getmetatable(v1)
    local mt2 = getmetatable(v2)
    if mt1 ~= mt2 then
        return false
    end

    if t1 == 'table' then
        for k1,x1 in pairs(v1) do
            local x2 = v2[k1]
            if not atm_equal(x1,x2) then
                return false
            end
        end
        for k2,x2 in pairs(v2) do
            local x1 = v1[k2]
            if not atm_equal(x2,x1) then
                return false
            end
        end
        return true
    end

    return false
end

function atm_is (v1, v2)
    return atm_equal(v1,v2) or _is_(v1,v2)
end

function atm_cat (v1, v2)
    local ok, v = pcall(function()
        return v1 .. v2
    end)
    if ok then
        return v
    end

    local ret = {}
    for k,x in iter(v1) do
        ret[k] = x
    end
    local n = 1
    for k,x in iter(v2) do
        if k == n then
            ret[#ret+1] = x
            n = n + 1
        else
            ret[k] = x
        end
    end
    return ret
end

function atm_in (v, t)
    for x,y in iter(t) do
        if (x==v and type(x)~='number') or (y == v) then
            return true
        end
    end
    return false
end

local function T (id, tab, k, s)
    s
    :tap(function(v)
        tab[k] = v
    end)
    :emitter(2, id..'.'..k)
    :to()
end

function atm_behavior (id, tsks, tab, ss)
    for k,s in pairs(ss) do
        spawn_in(tsks, T, id, tab, k, s)
    end
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
