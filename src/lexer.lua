require "global"
require "aux"

local fixs = { '{', '}', '(', ')', '[', ']', ',', '.', ':' }

local function _lexer_ (str)
    str = str .. '\0'
    local i = 1

    function read_while (pre, f)
        local str = pre
        local c = string.sub(str,i,i)
        i = i + 1
        while f(c) do
            assert(c ~= '\0')
            str = str .. c
            c = string.sub(str,i,i)
            i = i + 1
        end
        i = i - 1
        return str
    end

    while i <= #str do
        local c = string.sub(str,i,i)
        i = i + 1
        if c == ' ' then
        elseif c == ';' then
        elseif contains(fixs, c) then
            coroutine.yield({ tag="fix", str=c })
        elseif contains(OPS.cs, c) then
            local op = read_while(c, function (c) return contains(OPS.cs,c) end)
            coroutine.yield({ tag="op", str=op })
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

