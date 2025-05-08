require "global"
require "aux"

local match = string.match

local syms = { '{', '}', '(', ')', '[', ']', ',', '.' }

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

        -- spaces
        if match(c, "%s") then
            -- ignore

        -- comments
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

        -- symbols:  {  (  ,  ;
        elseif contains(syms, c) then
            coroutine.yield { tag="sym", str=c }

        -- operators:  +  >=  #
        elseif contains(OPS.cs, c) then
            local op = read_while(c, function (c) return contains(OPS.cs,c) end)
            if not contains(OPS.vs,op) then
                error("invalid operator : " .. op)
            end
            coroutine.yield { tag="op", str=op }

        -- tags:  :X  :a:b:c
        elseif c == ':' then
            local tag = read_while(":", M"[%w_:]")
            local hier = {}
            for x in string.gmatch(tag, ":([^:]*)") do
                hier[#hier+1] = x
            end
            coroutine.yield { tag="tag", str=tag, hier=hier }

        -- keywords:  await  if
        -- variables:  x  a_10
        elseif match(c, "[%a_]") then
            local id = read_while(c, M"[%w_]")
            if contains(KEYS, id) then
                coroutine.yield { tag="key", str=id }
            else
                coroutine.yield { tag="var", str=id }
            end

        -- numbers:  0xFF  10.1
        elseif match(c, "%d") then
            local num = read_while(c, M"[%w]")
            if not tonumber(num) then
                error("invalid number : " .. num)
            else
                coroutine.yield { tag="num", str=num }
            end

        -- eof
        elseif c == '\0' then
            coroutine.yield { tag="eof", str=c }

        -- error
        else
            error("invalid character : " .. c)
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

