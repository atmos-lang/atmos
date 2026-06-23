X = require "atmos.x"   -- global bc of threads/lanes

function atm_pin_chk_set (chk, pin, ...)
    local t = ...
    if X.is(t,'xtask') or X.is(t,'tasks') then
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

function atm_void ()
    -- do(...)
end

-------------------------------------------------------------------------------
-- TOSTRING : render values as atmos-lang tables (:X [...])
-------------------------------------------------------------------------------

-- override `atmos.x` generic tostring with atmos-lang surface syntax;
-- `X.print` picks this up since it calls `M.tostring` on the same table
function X.tostring (v)
    if type(v) ~= 'table' then
        return tostring(v)
    else
        local fst = true
        local vs = ""
        local t = {}
        for k,x in pairs(v) do
            assert(type(k)=='number' or type(k)=='string')
            if k ~= 'tag' then
                t[#t+1] = { k, x }
            end
        end
        table.sort(t, function (x, y)
            local n1, n2 = tonumber(x[1]), tonumber(y[1])
            if n1 and n2 then
                return (n1 < n2)
            else
                return (tostring(x[1]) < tostring(y[1]))
            end
        end)
        local i = 1
        for _,kx in ipairs(t) do
            local k,x = table.unpack(kx)
            if not fst then
                vs = vs .. ', '
            end
            if tonumber(k) == i then
                i = i + 1
                vs = vs .. X.tostring(x)
            else
                vs = vs .. k .. '=' .. X.tostring(x)
            end
            fst = false
        end
        local tag = v.tag and (':'..v.tag..' ') or ''
        return tag .. "[" .. vs .. "]"
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
