coro   = coroutine.create
resume = coroutine.resume
yield  = coroutine.yield

local TASKS = {}

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
    local t = { tag='task', coro=coro(f) }
    TASKS[#TASKS+1] = t
    TASKS[t.coro] = t
    return t
end

function spawn (t, ...)
    if type(t) == 'function' then
        return spawn(task(t), ...)
    end
    assert(type(t)=='table' and t.coro, 'invalid spawn : expected task')
    assert(resume(t.coro, ...))
    return t
end

function await (e, cnd)
    local t = TASKS[coroutine.running()]
    t.await = { e=e, cnd=cnd }
    return yield()
end

function emit (...)
    for _, t in ipairs(TASKS) do
        assert(resume(t.coro, ...))
    end
end
