require "global"
require "aux"

local match = string.match

local fixs = { '{', '}', '(', ')', '[', ']', ',', '.' }

local function _lexer_ (str)
    str = str .. '\0'
    local i = 1

    local function read ()
        local c = string.sub(str,i,i)
        i = i + 1
        return c
    end
    local function unread (n)
        n = n or 1
        local c = string.sub(str,i,i)
        i = i - n
        return c
    end

    local function read_while (pre, f)
        local ret = pre
        local c = read()
        while f(c) do
            if c == '\0' then
                return nil
            end
            ret = ret .. c
            c = read()
        end
        unread()
        return ret
    end
    local function read_until (pre, f)
        return read_while(pre, function (c) return not f(c) end)
    end
    local function C (x)
        return function (c)
            return (x == c)
        end
    end
    local function M (m)
        return function (c)
            return match(c, m)
        end
    end

    while i <= #str do
        local c = read()
        if match(c, "%s") then
        elseif c == ';' then
            local c2 = read()
            if c2 ~= ';' then
                unread()
            else
                local s = read_while(";;", C';')
                if s == ";;" then
                    read_until(s, M"[\n\0]")
                else
                    local stk = {}
                    while true do
                        if stk[#stk] == s then
                            stk[#stk] = nil
                            if #stk == 0 then
                                break
                            end
                        else
                            stk[#stk+1] = s
                        end
                        repeat
                            if not read_until("", C';') then
                                error("unterminated comment")
                            end
                            s = read_while("", C';')
                        until #s>2 and #s>=#stk[#stk]
                    end
                end
            end
        elseif contains(fixs, c) then
            coroutine.yield({ tag="fix", str=c })
        elseif contains(OPS.cs, c) then
            local op = read_while(c, function (c) return contains(OPS.cs,c) end)
            if not contains(OPS.vs,op) then
                error("invalid operator : " .. op)
            end
            coroutine.yield({ tag="op", str=op })
        elseif match(c, "[%a_]") then
            local id = read_while(c, M"[%w_]")
            if contains(KEYS, id) then
                coroutine.yield({ tag="key", str=id })
            else
                coroutine.yield({ tag="var", str=id })
            end
        elseif match(c, "%d") then
            local num = read_while(c, M"[%w]")
            if not tonumber(num) then
                error("invalid number : " .. num)
            else
                coroutine.yield({ tag="num", str=num })
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

