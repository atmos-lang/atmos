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
