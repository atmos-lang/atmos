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

function atm_id ()
end

-------------------------------------------------------------------------------

local meta_table = {
    __index = function (t, i)
        if i == '=' then
            return t[#t]
        elseif i == '-' then
            local v = t[#t]
            t[#t] = nil
            return v
        else
            return nil
        end
    end,
    __newindex = function (t, i, v)
        if i == '=' then
            t[#t] = v
        elseif i == '+' then
            t[#t+1] = v
        else
            rawset(t, i, v)
        end
    end,
}

function atm_table (t)
    return setmetatable(t, meta_table)
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
    if i>N then
        return nil
    end
    return i
end

function iter (t, ...)
    local mt = getmetatable(t)
    if mt and mt.__pairs then
        return mt.__pairs(t)
    elseif mt and mt.__call then
        return t
    elseif t == nil then
        return fi, math.maxinteger-1, 0
    elseif type(t) == 'function' then
        return t
    elseif type(t) == 'number' then
        local fr, to
        if ... then
            fr, to = t-1, ...
        else
            fr, to = 0, t
        end
        return fi, to, fr
    elseif type(t) == 'table' then
        -- TODO: xnext
        return coroutine.wrap(function()
            for i=1, #t do
                coroutine.yield(i, t[i])
            end
            for k,v in pairs(t) do
                if type(k)~='number' or k<=0 or k>#t then
                    coroutine.yield(k,v)
                end
            end
        end)
    else
        error("TODO - iter(t)")
    end
end
