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

function atm_in (v, t)
    if type(t)=='table' and t[v] then
        if t[v] then
            return true
        else
            for _,x in pairs(t) do
                if v == x then
                    return true
                end
            end
            return false
        end
    else
        for x in iter(t) do
            if x == v then
                return true
            end
        end
        return false
    end
end

-------------------------------------------------------------------------------
-- CATCH/THROW, LOOP/UNTIL/WHILE/BREAK, FUNC/RETURN, DO/ESCAPE
-------------------------------------------------------------------------------

function atm_loop (blk)
    return (function (ok, ...)
        if ok then
            return ...
        else
            -- atm-loop, ...
            return select(2, ...)
        end
    end)(catch('atm-loop', blk))
end

function atm_until (cnd, ...)
    if cnd then
        if ... then
            return atm_break(...)
        else
            return atm_break(cnd)
        end
    end
end

function atm_while (cnd, ...)
    if not cnd then
        return atm_break(...)
    end
end

function atm_func (f)
    return function (...)
        local args = { ... }
        return (function (ok, ...)
            if ok then
                return ...
            else
                -- atm-do, ...
                return select(2, ...)
            end
        end)(catch('atm-func', function () return f(table.unpack(args)) end))
    end
end


function atm_do (tag, blk)
    return (function (ok, ...)
        if ok then
            return ...
        else
            -- atm-do, tag, ...
            if select('#',...) == 2 then
                return select(2, ...)
            else
                return select(3, ...)
            end
        end
    end)(catch('atm-do', tag, blk))
end

function atm_break (...)
    return throw('atm-loop', ...)
end

function atm_return (...)
    return throw('atm-func', ...)
end

function escape (...)
    return throw('atm-do', ...)
end

-------------------------------------------------------------------------------
-- ITER
-------------------------------------------------------------------------------

local function inext (t, i)
    i = i + 1
    local v = t[i]
    if v then
        return i, v
    else
        return nil
    end
end

local function fi (N, i)
    i = i + 1
    if i == N then
        return nil
    end
    return i
end

function iter (t)
    if t == nil then
        return fi, nil, -1
    elseif type(t) == 'function' then
        return t
    elseif type(t) == 'number' then
        return fi, t, -1
    elseif _is_(t, 'tasks') then
        return getmetatable(t).__pairs(t)
    elseif _is_(t, 'vector') then
        return inext, t, -1
    elseif type(t) == 'table' then
        return next, t, nil
    else
        error("TODO - iter(t)")
    end
end

-------------------------------------------------------------------------------
-- CEU
-------------------------------------------------------------------------------

--[[
local function aux (skip_fake, t)
    if skip_fake and t.fake then
        return aux(skip_fake, t.up)
    else
        return t
    end
end

function atm_me (skip_fake)
    local th = coroutine.running()
    return th and TASKS.cache[th] and aux(skip_fake, TASKS.cache[th])
end
]]
