coro   = coroutine.create
resume = coroutine.resume
status = coroutine.status

local TASKS = { tag='tasks', dns={} }

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
        --print('err', msg)
        local filex, lin, msg = string.match(msg, '%[string "(.-)"%]:(%d+): (.*)$')
        --print(file, filex, lin, msg)
        assert(file == filex)
        io.stderr:write(file..' : line '..lin..' : '..msg..'\n')
        return nil
    end

    atm_task_close(TASKS)

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

function atm_me ()
    local co = coroutine.running()
    return co and TASKS[co]
end

local meta = { __close=nil }

function task (f)
    local up = atm_me()
    local t = {
        tag = 'task',
        co  = coro(f),
        up  = up,
        dns = {},
        status = nil, -- aborted, toggled
        ing = 0,
        gc  = false,
        [':pub'] = nil,
    }
    setmetatable(t, meta)
    TASKS[t.co] = t
    if up then
        up.dns[#up.dns+1] = t
    else
        TASKS.dns[#TASKS.dns+1] = t
    end
    return t
end

function atm_task_close (t)
    for _,dn in ipairs(t.dns) do
        atm_task_close(dn)
    end
    if t.tag == 'task' then
        if status(t.co) == 'normal' then
            -- cannot close now (emit continuation will raise error)
            t.status = 'aborted'
        else
            coroutine.close(t.co)
        end
    end
    -- TODO: remove from up (or up traverses dead dns)
end
meta.__close = atm_task_close

local function atm_task_resume (t, a, b, ...)
    -- a=:X, b={...}, choose b on t.await.f(b) and resume(t,b)
    local awk = false
    if status(t.co) ~= 'suspended' then
        -- nothing to awake
    elseif t.await == nil then
        -- first awake
        awk = true
    elseif t.await.e == false then
        -- never awakes
    elseif t.await.e==true or t.await.e==a then
        if t.await.f==nil or t.await.f(b or a, a,...) then
            awk = true
        end
    end
    if awk then
        local ok, err = resume(t.co, b or a, a, ...)
        if ok then
            -- no error: continue normally
        elseif err == 'atm_aborted' then
            -- callee aborted from outside: continue normally
            coroutine.close(t.co)
        else
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
            if t.up then
                t.up.gc = true
            end
            --if t.status ~= 'aborted' then
                emit(t.up, ':task', t)
            --end
        end
    end
    return true
end

function spawn (t, ...)
    if type(t) == 'function' then
        return spawn(task(t), ...)
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
    assert(atm_task_resume(t, ...))
    return t
end

function yield (...)
    if atm_me() then
        error('invalid yield : unexpected enclosing task instance', 2)
    end
    return coroutine.yield(...)
end

local function _aux_ (a, b, ...)
    if a == 'atm_error' then
        error(b, 0)
    else
        return a, b, ...
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

function emit (to, ...)
    local me = atm_me()

    local function f (t, ...)
        -- ing++
        local ok, err = true, nil
        for _, dn in ipairs(t.dns) do
            --f(dn, ...)
            ok, err = pcall(f, dn, ...)
            if not ok then
                break
            end
        end
        if t.tag == 'task' then
            if ok then
                assert(atm_task_resume(t, ...))
            else
                assert(resume(t.co, 'atm_error', err))
            end
        end
        -- ing--
        -- TODO: gc
    end

    if to == nil then
        to = 0
    elseif to == ":task" then
        to = 0
    elseif to == ":parent" then
        to = 1
    end

    if to == ":global" then
        to = TASKS
    elseif type(to) == 'number' then
        local n = tonumber(to)
        to = me or TASKS
        while n > 0 do
            to = to.up
            if to == nil then
                error('invalid emit : invalid target', 2)
            end
            n = n - 1
        end
    elseif type(to)=='table' and (to.tag=='task' or to.tag=='tasks') then
        to = to
    else
        error('invalid emit : invalid target', 2)
    end

    f(to, ...)

    if me and me.status=='aborted' then
        error('atm_aborted', 0)
    end

    return ...
end
