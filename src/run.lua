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

function atm_tag_is (t, a, b)
    local ist = (type(t) == 'table')
    if not ist then
        return false
    elseif not t.tag then
        return false
    elseif a then
        return (t.tag == a) or (t.tag == b)
    else
        return t.tag
    end
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
-- LOOP, FUNC, DO, BREAK, RETURN, ESCAPE
-------------------------------------------------------------------------------

function atm_loop (f, ...)
    return (function (ok, err, ...)
        if ok then
            return err, ...
        elseif err.up == 'loop' then
            return table.unpack(err)
        else
            error(err, 0)
        end
    end)(pcall(f, ...))
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

function atm_call (f, ...)
    if not atm_tag_is(f,'func') then
        return f(...)
    else
        return (function (ok, err, ...)
            if ok then
                return err, ...
            elseif err.up == 'func' then
                return table.unpack(err)
            else
                error(err, 0)
            end
        end)(pcall(f.func, ...))
    end
end

__atm_func = { __call=atm_call }

function atm_func (f)
    return setmetatable({ tag='func', func=f }, __atm_func)
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

function atm_break (...)
    return error({up='loop',...}, 0)
end

function atm_return (...)
    return error({up='func',...}, 0)
end

function escape (...)
    return error({up='do',...}, 0)
end

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
    elseif type(t)=='function' or atm_tag_is(t,'func') then
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
