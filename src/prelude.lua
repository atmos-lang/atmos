coro   = coroutine.create
resume = coroutine.resume
yield  = coroutine.yield

local TASKS = {}

function task (f)
    local t = { tag="task", coro=coro(f) }
    TASKS[#TASKS+1] = t
    TASKS[t.coro] = t
    return t
end

function spawn (t, ...)
    if type(t) == "function" then
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
