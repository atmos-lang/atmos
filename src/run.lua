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
-- CORO
-------------------------------------------------------------------------------

resume = coroutine.resume
coro   = coroutine.create

-------------------------------------------------------------------------------
-- ITER
-------------------------------------------------------------------------------

function inext (t, i)
    i = i + 1
    local v = t[i]
    if v then
        return i, v
    else
        return nil
    end
end

function iter (t)
    if t == nil then
        return coroutine.wrap(function ()
            local i = 0
            while true do
                coroutine.yield(i)
                i = i + 1
            end
        end)
    elseif type(t) == 'function' then
        return t
    elseif type(t) == 'number' then
        return coroutine.wrap(function ()
            for i=0, t-1 do
                coroutine.yield(i)
            end
        end)
    elseif type(t) == 'table' then
        if t.tag == 'tasks' then
            local co = coroutine.create (
                function ()
                    t.ing = t.ing + 1
                    local _ <close> = setmetatable({}, {
                        __close = function()
                            t.ing = t.ing - 1
                            atm_task_gc(t)
                        end
                    })
                    for _,v in ipairs(t.dns) do
                        coroutine.yield(v)
                    end
                end
            )
            local wr = (
                function ()
                    return (function (ok, ...)
                        if not ok then
                            error(..., 0)
                        end
                        return ...
                    end)(coroutine.resume(co))
                end
            )
            local close = setmetatable({}, {__close=function() coroutine.close(co) end})
            return wr, co, nil, close
        elseif t.tag == 'vector' then
            return inext, t, -1
        else
            return next, t, nil
        end
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

function yield (...)
    --assertn(2, not atm_me(), 'invalid yield : unexpected enclosing task instance')
    return coroutine.yield(...)
end


