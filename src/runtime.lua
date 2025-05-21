coro   = coroutine.create
resume = coroutine.resume

function status (t)
    if type(t)=='table' and t.tag=='task' then
        return coroutine.status(t.co)
    else
        return coroutine.status(t)
    end
end

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

function iter (v)
    local f
    if v == nil then
        f = function ()
            local i = 0
            while true do
                coroutine.yield(i)
                i = i + 1
            end
        end
    elseif type(v) == 'number' then
        f = function ()
            for i=0, v-1 do
                coroutine.yield(i)
            end
        end
    elseif type(v) == 'table' then
        if v[1] ~= nil then
            f = function ()
                for i,v in ipairs(v) do
                    coroutine.yield(i-1,v)
                end
            end
        else
            f = function ()
                for k,v in pairs(v) do
                    coroutine.yield(k,v)
                end
            end
        end
    elseif type(v) == 'function' then
        f = v
    else
        error("TODO - iter(v)")
    end
    return coroutine.wrap(f)
end

-------------------------------------------------------------------------------

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

function tasks (max)
    local ts = {
        tag = 'tasks',
        max = max,
        dns = {},
        ing = 0,
        gc  = false,
    }
    setmetatable(ts, meta)
    return ts
end

local TASKS <close> = tasks()

function atm_me ()
    local co = coroutine.running()
    return co and TASKS[co]
end


function atm_pin (up, t)
    assert(t.up == nil)
    if t.co and status(t.co)=='dead' then
        return t
    end
    up = up or atm_me() or TASKS
    up.dns[#up.dns+1] = t
    t.up = up
    return t
end

function task (ts, f)
    local up = ts or atm_me()
    if ts and ts.max and #ts.dns>=ts.max then
        return nil
    end
    local t = {
        tag = 'task',
        co  = coro(f),
        up  = nil,
        dns = {},
        status = nil, -- aborted, toggled
        ing = 0,
        gc  = false,
        pub = nil,
        ret = nil,
    }
    TASKS[t.co] = t
    setmetatable(t, meta)
    if ts then
        atm_pin(ts, t)
    end
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
        if t.up then
            t.up.gc = true
        end
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

function spawn (ts, t, ...)
    if type(t) == 'function' then
        t = task(ts, t)
        if t == nil then
            return nil
        else
            return spawn(ts, t, ...)
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

    if t.gc and t.ing==0 then
        for i=#t.dns, 1, -1 do
            atm_task_rem(t.dns[i], i)
        end
    end

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

function atm_task_rem (t, i)
    assert(i and t.up.ing==0 and t.tag=='task' and status(t.co)=='dead')
    TASKS[t.co] = nil
    table.remove(t.up.dns, i)
end

function emit (to, ...)
    local me = atm_me()

    femit(fto(me,to), ...)

    if me and me.status=='aborted' then
        error('atm_aborted', 0)
    end

    return ...
end
