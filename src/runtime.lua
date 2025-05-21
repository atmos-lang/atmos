coro   = coroutine.create
resume = coroutine.resume

function atm_idx (idx)
    if type(idx) == 'number' then
        idx = idx + 1
    end
    return idx
end

function atm_catch (v, e, f)
    return (e==true or v==e) and (f==nil or f(v))
end

function atm_exec (file, src)
    local f, msg = load(src, file)
    --print(f, msg)

    if not f then
        local filex, lin, msg2 = string.match(msg, '%[string "(.-)"%]:(%d+): (.-) at line %d+$')
        if not filex then
            filex, lin, msg2 = string.match(msg, '%[string "(.-)"%]:(%d+): (.*)$')
        end
        --print('xxx', file, filex, lin, msg2)
        assert(file == filex)
        io.stderr:write(file..' : line '..lin..' : '..msg2..'\n')
        return nil
    end

    local v, msg = pcall(f)
    if not v then
--print('ERR', msg)
        local filex, lin, msg = string.match(msg, '%[string "(.-)"%]:(%d+): (.*)$')
        --print(file, filex, lin, msg)
        assert(file == filex)
        io.stderr:write(file..' : line '..lin..' : '..msg..'\n')
        return nil
    end

    return v
end

function atm_is (v, x)
    if v == x then
        return true
    end
    local tp = type(v)
    if tp == x then
        return true
    elseif type(x) == 'string' then
        local tag = (tp=='table' and v.tag) or tostring(v)
        return x == tag
        --return atm_sup(x, tag)
    end
    return false
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

function iter (t)
    local f
    if t == nil then
        f = function ()
            local i = 0
            while true do
                coroutine.yield(i)
                i = i + 1
            end
        end
    elseif type(t) == 'number' then
        f = function ()
            for i=0, t-1 do
                coroutine.yield(i)
            end
        end
    elseif type(t) == 'table' then
        if t.tag == 'tasks' then
            f = function ()
                t.ing = t.ing + 1
                for _,v in ipairs(t.dns) do
                    coroutine.yield(v)
                end
                t.ing = t.ing - 1
                atm_task_gc(t)
            end
        elseif t[1] ~= nil then
            f = function ()
                for i,v in ipairs(t) do
                    coroutine.yield(i-1,v)
                end
            end
        else
            f = function ()
                for k,v in pairs(t) do
                    coroutine.yield(k,v)
                end
            end
        end
    elseif type(t) == 'function' then
        f = t
    else
        error("TODO - iter(t)")
    end
    return coroutine.wrap(f)
end

-------------------------------------------------------------------------------

function status (t)
    if type(t)=='table' and t.tag=='task' then
        return coroutine.status(t.co)
    else
        return coroutine.status(t)
    end
end

local function close (t)
    for _,dn in ipairs(t.dns) do
        close(dn)
    end
    if t.tag == 'task' then
        if status(t.co) == 'normal' then
            -- cannot close now (emit continuation will raise error)
            t.status = 'aborted'
        else
            coroutine.close(t.co)
        end
    end
end

local meta = { __close=close }

local TASKS <close> = setmetatable({
    tag = 'tasks',
    max = nil,
    up  = nil,
    i   = nil,
    dns = {},
    ing = 0,
    gc  = false,
    cache = setmetatable({}, {__mode='k'}),
}, meta)

function atm_me ()
    local co = coroutine.running()
    return co and TASKS.cache[co]
end

function tasks (max)
    local n = max and tonumber(max) or nil
    if max and (not n) then
        error('invalid tasks limit : expected number', 2)
    end
    local up = atm_me() or TASKS
    local ts = {
        tag = 'tasks',
        max = n,
        up  = up,
        i   = #up.dns+1,
        dns = {},
        ing = 0,
        gc  = false,
    }
    up.dns[#up.dns+1] = ts
    setmetatable(ts, meta)
    return ts
end

function task (f)
    local t = {
        tag = 'task',
        co  = coro(f),
        i   = nil,
        up  = nil,
        dns = {},
        status = nil, -- aborted, toggled
        ing = 0,
        gc  = false,
        pub = nil,
        ret = nil,
    }
    TASKS.cache[t.co] = t
    setmetatable(t, meta)
    return t
end

local function atm_task_resume_result (t, ok, err)
--print('res', ok, err)
--  print(debug.traceback())
    if ok then
        -- no error: continue normally
    elseif err == 'atm_aborted' then
        -- callee aborted from outside: continue normally
        coroutine.close(t.co)   -- needs close b/c t.co is in error state
    else
--print'up'
        error(err, 0)
    end

--[[
    assert(resume(t.co, e, ...))
    local ok, err = resume(t.co, e, ...)
    if not ok then
        -- TODO: close
        return ok, {t=t,o=err}
    end
]]

    if status(t.co) == 'dead' then
        t.ret = err
        t.up.gc = true
        --if t.status ~= 'aborted' then
            emit(t.up, 'task', t)
        --end
    end
end

local function atm_task_awake_check (t, a, b)
    if status(t.co) ~= 'suspended' then
        -- nothing to awake
        return false
    elseif t.await.e == false then
        -- never awakes
        return false
    elseif t.await.e==true or t.await.e==a then
        if t.await.f==nil or t.await.f(b or a) then
            -- a=:X, b={...}, choose b
            return true
        else
            return false
        end
    end
end

function spawn (up, t, ...)
    if type(t) == 'function' then
        t = task(t)
        if t == nil then
            return nil
        else
            return spawn(up, t, ...)
        end
    end
    if type(t)=='table' and t.co then
        -- ok
    else
        error('invalid spawn : expected task prototype', 2)
    end
--[[
    local dbg = debug.getinfo(2)
    t.stk = {
        file = dbg.short_src,
        line = dbg.currentline,
    }
    local ok, t_o = atm_task_resume(t, ...)
    if not ok then
        return ok, t_o
    end
]]

    up = up or atm_me() or TASKS
    if up.max and #up.dns>=up.max then
        return nil
    end
    up.dns[#up.dns+1] = t
    t.i = #up.dns
    t.up = assert(t.up==nil and up)

    atm_task_resume_result(t, resume(t.co, ...))
    return t
end

-------------------------------------------------------------------------------
-- AWAIT
-------------------------------------------------------------------------------

function yield (...)
    if atm_me() then
        error('invalid yield : unexpected enclosing task instance', 2)
    end
    return coroutine.yield(...)
end

local function _aux_ (err, a, b, ...)
    if err then
        error(a, 0)
    elseif b then
        return a, b, ...
    else
        return a    -- avoids repetition of a/b or a/nil
    end
end

function await (e, f)
    local t = atm_me()
    if not t then
        error('invalid await : expected enclosing task instance', 2)
    end
    t.await = { e=e, f=f }
    return _aux_(coroutine.yield())
end

-------------------------------------------------------------------------------
-- EMIT
-------------------------------------------------------------------------------

local function fto (me, to)
    if to == nil then
        to = 0
    elseif to == 'task' then
        to = 0
    elseif to == 'parent' then
        to = 1
    end

    if to == 'global' then
        to = TASKS
    elseif type(to) == 'number' then
        local n = tonumber(to)
        to = me or TASKS
        while n > 0 do
            to = to.up
            if to == nil then
                error('invalid emit : invalid target', 3)
            end
            n = n - 1
        end
    elseif type(to)=='table' and (to.tag=='task' or to.tag=='tasks') then
        to = to
    else
        error('invalid emit : invalid target', 3)
    end

    return to
end

function atm_task_gc (t)
    if t.gc and t.ing==0 then
        for i=#t.dns, 1, -1 do
            local s = t.dns[i]
            if s.tag=='task' and status(s.co)=='dead' then
                table.remove(t.dns, s.i)
            end
        end
    end
end

local function femit (t, a, b, ...)
    local ok, err = true, nil

    t.ing = t.ing + 1
    for _, dn in ipairs(t.dns) do
        --f(dn, ...)
        ok, err = pcall(femit, dn, a, b, ...)
        if not ok then
            break
        end
    end
    t.ing = t.ing - 1

    atm_task_gc(t)

    if t.tag == 'task' then
        if not ok then
            if status(t.co) ~= 'dead' then
                local ok, err = resume(t.co, 'atm_error', err)
--print('x', ok, err)
                if not ok then
                    error(err, 0)
                end
            end
        else
            if atm_task_awake_check(t,a,b) then
                -- a=:X, b={...}, choose b on resume(t,b)
                atm_task_resume_result(t, resume(t.co, nil, b or a, b and a or nil, ...))
            end
        end
    else
        assert(t.tag == 'tasks')
        if not ok then
            error(err, 0)
        end
    end
end

function emit (to, ...)
    local me = atm_me()

    femit(fto(me,to), ...)

    if me and me.status=='aborted' then
        error('atm_aborted', 0)
    end

    return ...
end
