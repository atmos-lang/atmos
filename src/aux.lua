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
