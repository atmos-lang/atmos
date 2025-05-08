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
            assert(type(k) == "string")
            t[#t+1] = { k, x }
        end
        table.sort(t, function (x, y) return (x[1] <= y[1]) end)
        for _,kx in ipairs(t) do
            local k,x = table.unpack(kx)
            if not fst then
                vs = vs .. ', '
            end
            vs = vs .. k .. '=' .. xtostring(x)
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
