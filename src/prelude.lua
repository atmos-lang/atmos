coro   = coroutine.create
resume = coroutine.resume
status = coroutine.status

local TASKS = { tag='global', dns={} }

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

function task (f)
    local up = TASKS[coroutine.running()]
    local t = { tag='task', co=coro(f), tog=false, up=up, dns={}, ing=0,gc=false }
    TASKS[t.co] = t
    if up then
        up.dns[#up.dns+1] = t
    else
        TASKS.dns[#TASKS.dns+1] = t
    end
    return t
end

local function task_resume (t, e, ...)
    local ok = false
    if status(t.co) ~= 'suspended' then
        -- nothing to awake
    elseif t.await == nil then
        -- first awake
        ok = true
    elseif t.await.e == false then
        -- never awakes
    elseif t.await.e==true or t.await.e==e then
        if t.await.f==nil or t.await.f(e,...) then
            ok = true
        end
    end
    if ok then
        assert(resume(t.co, e, ...))
        if status(t.co) == 'dead' then
            if t.up then
                t.up.gc = true
            end
            emit(t.up, t)
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
    assert(task_resume(t, ...))
    return t
end

function yield (...)
    local co = coroutine.running()
    if TASKS[co] then
        error('invalid yield : unexpected task instance', 2)
    end
    return coroutine.yield(...)
end

function await (e, f)
    local t = TASKS[coroutine.running()]
    t.await = { e=e, f=f }
    return coroutine.yield()
end

function emit (to, ...)
    local function f (t, ...)
        -- ing++
        for _, dn in ipairs(t.dns) do
            f(dn, ...)
        end
        if t.tag == 'task' then
            assert(task_resume(t, ...))
        end
        -- ing--
        -- TODO: gc
    end
    if to == nil then
        f(TASKS, ...)
    elseif type(to)=='table' and (to.tag=='task' or to.tag=='tasks') then
        f(to, ...)
    else
        error('invalid emit : invalid target', 2)
    end
    return ...
end
