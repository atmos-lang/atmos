function atm_pin_chk_set (chk, pin, ...)
    local t = ...
    if _is_(t,'task') or _is_(t,'tasks') then
        if pin then
            assertn(2, (not chk) or (not t.pin),
                "invalid assignment : expected unpinned value")
            t.pin = true
        else
            assertn(2, (not chk) or t.pin,
                "invalid assignment : expected pinned value")
        end
    end
    return ...
end

function atm_tag_do (tag, t)
    assertn(2, type(t)=='table', 'invalid tag operation : expected table', 2)
    t.tag = tag
    return t
end

-------------------------------------------------------------------------------

local function inext (t, i)
    i = i + 1
    if i < #t then
        return i, t[i]
    else
        return nil
    end
end

local meta_vector = {
    __ipairs = function (t)
        return inext, t, -1
    end,
    __index = function (t, i)
        local vs = rawget(t, 'vs')
        if i == '=' then
            return vs[#vs]
        elseif i == '-' then
            local v = vs[#vs]
            vs[#vs] = nil
            return v
        else
            assertn(2, type(i)=='number', "invalid index : expected number")
            assertn(2, i>=0 and i<#vs, "invalid index : out of bounds")
            return vs[i+1]
        end
    end,
    __newindex = function (t, i, v)
        local vs = rawget(t, 'vs')
        if i == '=' then
            vs[#vs] = v
        elseif i == '+' then
            vs[#vs+1] = v
        else
            assertn(2, type(i)=='number', "invalid index : expected number")
            if v == nil then
                assertn(2, i>=0 and i==#vs-1, "invalid pop : out of bounds")
            else
                assertn(2, i>=0 and i<=#vs, "invalid push : out of bounds")
            end
            vs[i+1] = v
        end
    end,
    __len = function (t)
        return #(rawget(t,'vs'))
    end,
}

function atm_vector (vs)
    local ret = {
        tag = 'vector',
        vs  = vs,
    }
    setmetatable(ret, meta_vector)
    return ret
end

function atm_cat (v1, v2)
    local t1 = type(v1)
    local t2 = type(v2)
    local m1 = getmetatable(v1)
    local m2 = getmetatable(v2)
    if t1 == 'string' then
        return v1 .. v2
    elseif m1 and m2 and m1.__ipairs and m2.__ipairs then
        local ret = atm_vector{}
        for _, x in m1.__ipairs(v1) do
            ret[#ret] = x
        end
        for _, x in m2.__ipairs(v2) do
            ret[#ret] = x
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
    if type(t) == 'table' then
        if t.tag == 'vector' then
            for i=0, #t-1 do
                if t[i] == v then
                    return true
                end
            end
            return false
        elseif t[v] ~= nil then
            return true
        end
    end
    for x,y in iter(t) do
        if x==v or y==v then
            return true
        end
    end
    return false
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

local function fi (N, i)
    i = i + 1
    if i == N then
        return nil
    end
    return i
end

function iter (t)
    local mt = getmetatable(t)
    if mt and mt.__ipairs then
        return mt.__ipairs(t)
    elseif mt and mt.__pairs then
        return mt.__pairs(t)
    elseif t == nil then
        return fi, nil, -1
    elseif type(t) == 'function' then
        return t
    elseif type(t) == 'number' then
        return fi, t, -1
    elseif type(t) == 'table' then
        return next, t, nil
    else
        error("TODO - iter(t)")
    end
end
