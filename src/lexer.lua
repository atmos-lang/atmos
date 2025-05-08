require "global"
require "aux"

local match = string.match

local fixs = { '{', '}', '(', ')', '[', ']', ',', '.' }

local function _lexer_ (str)
    str = str .. '\0'
    local i = 1

    function read ()
        local c = string.sub(str,i,i)
        i = i + 1
        return c
    end
    function unread ()
        local c = string.sub(str,i,i)
        i = i - 1
        return c
    end

    function read_while (pre, f)
        local ret = pre
        local c = read()
        while f(c) do
            assert(c ~= '\0')
            ret = ret .. c
            c = read()
        end
        unread()
        return ret
    end

    while i <= #str do
        local c = read()
        if c == ' ' then
        elseif c == ';' then
        elseif contains(fixs, c) then
            coroutine.yield({ tag="fix", str=c })
        elseif contains(OPS.cs, c) then
            local op = read_while(c, function (c) return contains(OPS.cs,c) end)
            if not contains(OPS.vs,op) then
                error("invalid operator : " .. op)
            end
            coroutine.yield({ tag="op", str=op })
        elseif match(c, "[%a_]") then
            local id = read_while(c, function (c) return match(c, "[%w_]") end)
            if contains(KEYS, id) then
                coroutine.yield({ tag="key", str=id })
            else
                coroutine.yield({ tag="id", str=id })
            end
        elseif c == '\0' then
            coroutine.yield({ tag="eof", str=c })
        else
            error(c)
        end
    end
end

function lexer_string (str)
    return coroutine.wrap (
        function ()
            _lexer_(str, 1)
        end
    )
end

