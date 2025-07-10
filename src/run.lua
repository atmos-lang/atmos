function atm_is (v, x)
    if v == x then
        return true
    end
    local tp = type(v)
    if tp == x then
        return true
    elseif tp=='string' and type(x)=='string' then
        return (string.find(v, '^'..x) == 1)
    elseif tp=='table' and type(x)=='string' then
        return (string.find(v.tag or '', '^'..x) == 1)
    end
    return false
end

function atm_tag_do (tag, t)
    assertn(2, type(t)=='table', 'invalid tag operation : expected table', 2)
    t.tag = tag
    return t
end

-------------------------------------------------------------------------------

atm_vector = {
    __len = function (t)
        return rawlen(t) + (t[0]~=nil and 1 or 0)
    end
}

function atm_cat (v1, v2)
    local t1 = type(v1)
    local t2 = type(v2)
    assertn(2, t1==t2, 'invalid ++ : incompatible types', 2)
    if t1 == 'string' then
        return v1 .. v2
    elseif t1 ~= 'table' then
        error('invalid ++ : unsupported type', 2)
    elseif t2 ~= 'table' then
        error('invalid ++ : unsupported type', 2)
    elseif v1.tag=='vector' and v2.tag=='vector' then
        local ret = setmetatable({ tag='vector' }, atm_vector)
        for i=1, #v1 do
            ret[#ret] = v1[i-1]
        end
        for i=1, #v2 do
            ret[#ret] = v2[i-1]
        end
        return ret
    else
        local ret = {}
        for k,x in pairs(v1) do
            ret[k] = x
        end
        for k,x in pairs(v2) do
            ret[k] = x
        end
        return ret
    end
end

-------------------------------------------------------------------------------

function escape (...)
    return error({up='do',...}, 0)
end

function atm_do (xt, blk, ...)
    return (function (ok, err, ...)
        if ok then
            return err, ...
        elseif err.up == 'do' then
            if atm_is(err[1],xt) then
                return table.unpack(err, (#err==1 and 1) or 2)
            else
                error(err, 0)
            end
        else
            error(err, 0)
        end
    end)(pcall(blk, ...))
end
