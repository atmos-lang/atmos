resume = coroutine.resume

function coro (f)
    if atm_tag_is(f,'func') then
        return { tag='coro', th=coroutine.create(f.func) }
    else
        return coroutine.create(f)
    end
end

function resume (co, ...)
    if atm_tag_is(co,'coro') then
        return (function (ok, err, ...)
            if ok then
                return ok, err, ...
            elseif err.up == 'func' then
                return true, table.unpack(err)
            else

--[[
        local dbg = debug.getinfo(co.co,1)
        local x = {
            file = dbg.short_src,
            line = dbg.currentline,
        }
        dump(x)
]]

                return false, err, ...
            end
        end)(coroutine.resume(co.th, ...))
    else
        return coroutine.resume(co, ...)
    end
end

function atm_tag_is (t, a, b)
    return type(t)=='table' and t.tag and (t.tag==a or t.tag==b)
end

function atm_tag_do (tag, t)
    if type(t) ~= 'table' then
        error('invalid tag operation : expected table', 2)
    end
    t.tag = tag
    return t
end

function atm_idx (idx)
    if type(idx) == 'number' then
        idx = idx + 1
    end
    return idx
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

function atm_catch (xe, xf, blk, ...)
    return (function (ok, err, ...)
        if ok then
            return true, err, ...
        elseif err.up == 'catch' then
            if (xe==true or atm_is(err[1],xe)) and (xf==nil or atm_call(xf,table.unpack(err))) then
                return false, table.unpack(err)
            else
                error(err, 0)
            end
        else
            error(err, 0)
        end
    end)(pcall(blk, ...))
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

function atm_exec (file, src)
    local f, msg = load(src, file)

    if not f then
        local filex, lin, msg2 = string.match(msg, '%[string "(.-)"%]:(%d+): (.-) at line %d+$')
        if not filex then
            filex, lin, msg2 = string.match(msg, '%[string "(.-)"%]:(%d+): (.*)$')
        end
        assert(file == filex)
        io.stderr:write(file..' : line '..lin..' : '..msg2..'\n')
        return nil
    end

    local v, msg = pcall(f)
    --print(v, msg)
    if not v then
        if type(msg) == 'table' then
            if msg.up == 'func' then
                return table.unpack(msg)
            elseif msg.up == 'catch' then
                assert(msg.up)
                io.stderr:write("uncaught throw : " .. stringify(msg[1]) .. '\n')
            else
                error "bug found"
            end
        else
            assert(type(msg) == 'string')
            local filex, lin, msg2 = string.match(msg, '%[string "(.-)"%]:(%d+): (.*)$')
            --print(file, filex, lin, msg)
            if file ~= filex then
                error('internal error : ' .. msg)
            end
            io.stderr:write(file..' : line '..lin..' : '..msg2..'\n')
        end
        return nil
    end
    close(TASKS)

    return v
end

function atm_is (v, x)
    if v == x then
        return true
    end
    local tp = type(v)
    if tp == x then
        return true
    elseif tp=='table' and type(x)=='string' then
        return (string.find(v.tag or '', '^'..x) == 1)
    end
    return false
end

function atm_cat (v1, v2)
    local t1 = type(v1)
    local t2 = type(v2)
    if t1 ~= t2 then
        error('invalid ++ : incompatible types', 2)
    end
    if t1 == 'string' then
        return v1 .. v2
    elseif t1 == 'table' then
        local ret = {}
        for k,v in pairs(v1) do
            ret[k] = v
        end
        local n1 = #v1
        for k,v in pairs(v2) do
            if type(k) == 'number' then
                ret[n1+k] = v
            end
        end
        return ret
    else
        error('invalid ++ : unsupported type', 2)
    end
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
    elseif atm_tag_is(t,'func') then
        f = function (...)
            return atm_call(t, ...)
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
    else
        error("TODO - iter(t)")
    end
    return coroutine.wrap(f)
end

-------------------------------------------------------------------------------

function status (t)
    if atm_tag_is(t,'task') then
        return coroutine.status(t.co.th)
    elseif atm_tag_is(t,'coro') then
        return coroutine.status(t.th)
    else
        return coroutine.status(t)
    end
end

function close (t)
    for _,dn in ipairs(t.dns) do
        close(dn)
    end
    if t.tag == 'task' then
        if status(t) == 'normal' then
            -- cannot close now (emit continuation will raise error)
            t.status = 'aborted'
        else
            coroutine.close(t.co.th)
        end
    end
end

TASKS = {
    tag = 'tasks',
    max = nil,
    up  = nil,
    i   = nil,
    dns = {},
    ing = 0,
    gc  = false,
    cache = setmetatable({}, {__mode='k'}),
}

function atm_me ()
    local th = coroutine.running()
    return th and TASKS.cache[th]
end

local meta = { __close=close }

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
    TASKS.cache[t.co.th] = t
    setmetatable(t, meta)
    return t
end

local function atm_task_resume_result (t, ok, err)
    if ok then
        -- no error: continue normally
    elseif err == 'atm_aborted' then
        -- callee aborted from outside: continue normally
        coroutine.close(t.co.th)   -- needs close b/c t.co is in error state
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

    if status(t) == 'dead' then
        t.ret = err
        t.up.gc = true
        --if t.status ~= 'aborted' then
            emit(t.up, t)
        --end
    end
end

local function atm_task_awake_check (t, a, b)
    if status(t) ~= 'suspended' then
        -- nothing to awake
        return false
    elseif t.await.e == false then
        -- never awakes
        return false
    elseif t.await.e==true or atm_is(a,t.await.e) then
        if t.await.f==nil or atm_call(t.await.f, b or a) then
            -- a=:X, b={...}, choose b
            return true
        else
            return false
        end
    end
end

function spawn (up, t, ...)
    if atm_tag_is(t,'func') then
        t = task(t)
        if t == nil then
            return nil
        else
            return spawn(up, t, ...)
        end
    end
    if atm_tag_is(t,'task') and t.co.th then
        -- ok
    else
        error('invalid spawn : expected task prototype', 2)
    end

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

--[[
        local dbg = debug.getinfo(2)
        local x = {
            file = dbg.short_src,
            line = dbg.currentline,
        }
        dump(x)
]]

function yield (...)
    if atm_me() then
        error('invalid yield : unexpected enclosing task instance', 2)
    end
    return coroutine.yield(...)
end

local function _aux_ (err, a, b, ...)
    a = (atm_tag_is(a,'task') and a.ret) or a
    if err then
        error(a, 0)
    elseif b then
        return a, b, ...
    else
        return a    -- avoids repetition of a/b or a/nil
    end
end

function await (e, f, ...)
    local t = atm_me()
    if not t then
        error('invalid await : expected enclosing task instance', 2)
    end
    local tsk = atm_tag_is(e, 'task')
    if tsk and status(e)=='dead' then
        return e.ret
    elseif e == 'clock' then
        local ms = f
        f = function (v)
            ms = ms - v
            return (ms <= 0)
        end
    elseif e == 'par_or' then
        local tsks = { ... }
        e = true
        f = function ()
            for _,tsk in ipairs(tsks) do
                if status(tsk) == 'dead' then
                    return tsk
                end
            end
            return false
        end
        local tsk = f()
        if tsk then
            return tsk.ret
        end
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
    elseif atm_tag_is(to,'task','tasks') then
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
            if s.tag=='task' and status(s)=='dead' then
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
            --[[
            if dn.status == 'aborted' then
                assert(err=='atm_aborted' and status(t)=='dead')
                close(dn)
            end
            ]]
            break
        end
    end
    t.ing = t.ing - 1

    atm_task_gc(t)

    if t.tag == 'task' then
        if not ok then
            if status(t) ~= 'dead' then
                local ok, err = resume(t.co, 'atm_error', err)
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
