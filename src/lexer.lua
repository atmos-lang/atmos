require "global"
require "aux"

local match = string.match

local syms = { '{', '}', '(', ')', '[', ']', ',', '.' }

function err (tk, msg)
    error(FILE .. " : line " .. tk.lin .. " : near '" .. tk.str .."' : " .. msg, 0)
end

local function _lexer_ (str)
    str = str .. '\0'
    local i = 1

    local function read ()
        local c = string.sub(str,i,i)
        if c == '\n' then
            LIN = LIN + 1
        end
        i = i + 1
        return c
    end
    local function unread ()
        i = i - 1
        local c = string.sub(str,i,i)
        if c == '\n' then
            LIN = LIN - 1
        end
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
                                err({str='<eof>',lin=LIN}, "unterminated comment")
                            end
                            s = read_while("", C';')
                        until #s>2 and #s>=#stk[#stk]
                    end
                end
            end

        -- symbols:  {  (  ,  ;
        elseif contains(syms, c) then
            coroutine.yield { tag='sym', str=c, lin=LIN }

        -- operators:  +  >=  #
        elseif contains(OPS.cs, c) then
            local op = read_while(c, function (c) return contains(OPS.cs,c) end)
            if not contains(OPS.vs,op) then
                err({str=op,lin=LIN}, "invalid operator")
            end
            if not (op=='~~' or op=='!~') then
                coroutine.yield { tag='op', str=op, lin=LIN }
            else
                local lin = LIN
                local pre = read_until('', '/')
                local reg = read_until('', '/')
                local sub; do
                    if pre == 's' then
                        sub = read_until('', '/')
                    end
                end
                local pos = read_while('', '%a')
                if not (pre and reg and sub and pos) then
                    err({str=TK0.str,lin=lin}, "invalid regex")
                end
                coroutine.yield { tag='op', str=op, pre=pre, reg=reg, sub=sub, pos=pos }
            end

        -- tags:  :X  :a:b:c
        elseif c == ':' then
            local tag = read_while(':', M"[%w_:]")
            --[[
            local hier = {}
            for x in string.gmatch(tag, ":([^:]*)") do
                hier[#hier+1] = x
            end
            ]]
            coroutine.yield { tag='tag', str=tag, lin=LIN }

        -- keywords:  await  if
        -- variables:  x  a_10
        elseif match(c, "[%a_]") then
            local id = read_while(c, M"[%w_]")
            if contains(KEYS, id) then
                coroutine.yield { tag='key', str=id, lin=LIN }
            else
                coroutine.yield { tag='id', str=id, lin=LIN }
            end

        -- numbers:  0xFF  10.1
        elseif match(c, "%d") then
            local num = read_while(c, M"[%w%.]")
            if string.find(num, '[PpEe]') then
                num = read_while(num, M"[%w%.%-%+]")
            end
            if not tonumber(num) then
                err({str=num,lin=LIN}, "invalid number")
            else
                coroutine.yield { tag='num', str=num, lin=LIN }
            end

        elseif c=='"' or c=="'" then
            local lin = LIN
            local pre = read_while(c, C(c))
            local n1 = string.len(pre)
            local v = ''
            if n1 == 2 then
                v = ''
            elseif n1 == 1 then
                v = read_until(v, M("[\n"..c.."]"))
                if string.sub(str,i,i) == '\n' then
                    err({str=string.sub(str,i-1,i-1),lin=lin}, "unterminated string")
                end
                assert(c == read())
            else
                while true do
                    v = read_until(v, C(c))
                    local pos = read_while('', C(c))
                    local n2 = string.len(pos)
                    if n1 == n2 then
                        break
                    end
                    v = v .. pos
                end
            end
            coroutine.yield { tag='str', str=v, lin=lin }

        -- eof
        elseif c == '\0' then
            coroutine.yield { tag='eof', str='<eof>', lin=LIN }

        -- error
        else
            err({str=c,lin=LIN}, "invalid character")
        end
    end
end

function lexer_string (file, str)
    FILE = file
    LIN = 1
    LEX = coroutine.wrap (
        function ()
            _lexer_(str, 1)
        end
    )
end

