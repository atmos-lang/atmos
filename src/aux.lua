function trim (s)
    local spc = string.match(s, "^(%s*)")
    return s:gsub("^"..spc,""):gsub("\n"..spc,"\n"):gsub("%s*$","")
end

function catch (f, ...)
    local ok, msg = pcall(f, ...)
    if not ok then
        msg = string.match(msg, '.-:%d+: (.*)$')
    end
    return ok, msg
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
    if type(v) ~= "table" then
        return tostring(v)
    else
        local fst = true
        local vs = ""
        local t = {}
        for k,x in pairs(v) do
            assert(type(k)=="number" or type(k)=="string")
            t[#t+1] = { k, x }
        end
        table.sort(t, function (x, y) return (x[1] < y[1]) end)
        for _,kx in ipairs(t) do
            local k,x = table.unpack(kx)
            if not fst then
                vs = vs .. ', '
            end
            if type(k) == 'number' then
                vs = vs .. xtostring(x)
            else
                vs = vs .. k .. '=' .. xtostring(x)
            end
            fst = false
        end
        return "{ " .. vs .. " }"
    end
end

function xdump (...)
    local ret = {}
    for i=1, select("#", ...) do
        ret[#ret+1] = xtostring(select(i, ...))
    end
    print(table.unpack(ret))
    return table.unpack(ret)
end

function map (t, f)
    local ret = {}
    for _,v in ipairs(t) do
        ret[#ret+1] = f(v)
    end
    return ret
end

function concat (t, sep)
    local ret = ""
    for i,v in ipairs(t) do
        if i > 1 then
            ret = ret .. sep
        end
        ret = ret .. v
    end
    return ret
end
