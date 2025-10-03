require "atmos.lang.global"
require "atmos.lang.aux"

local match = string.match

function err (tk, msg)
    error(FILE .. " : line " .. tk.lin .. " : near '" .. tk.str .."' : " .. msg, 0)
end

local function _lexer_ (str)
    local i = 1

    local function read ()
        local c = string.sub(str,i,i)
        if c == '\n' then
            LIN = LIN + 1
            SEP = SEP + 1
        elseif c == ';' then
            SEP = SEP + 1
        end
        i = i + 1
        return c
    end
    local function unread ()
        i = i - 1
        local c = string.sub(str,i,i)
        if c == '\n' then
            LIN = LIN - 1
            SEP = SEP - 1
        elseif c == ';' then
            SEP = SEP - 1
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
                    local lin,sep = LIN,SEP
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
                                err({str=s,lin=lin,sep=sep}, "unterminated comment")
                            end
                            s = read_while("", C';')
                        until #s>2 and #s>=#stk[#stk]
                    end
                end
            end

        -- @{, @clk
        elseif c == '@' then
            local c2 = read()
            if c2 == '{' then
                coroutine.yield { tag='sym', str=c..'{', lin=LIN,sep=SEP }
            else -- clock
                unread()
                local t = read_while('', M"[%w_:%.]")
                local h,min,s,ms = match(t, '^([^:%.]+):([^:%.]+):([^:%.]+)%.([^:%.]+)$')
                if not h then
                    h,min,s = match(t, '^([^:%.]+):([^:%.]+):([^:%.]+)$')
                    if not h then
                        min,s,ms = match(t, '^([^:%.]+):([^:%.]+)%.([^:%.]+)$')
                        if not min then
                            min,s = match(t, '^([^:%.]+):([^:%.]+)$')
                            if not min then
                                s,ms = match(t, '^([^:%.]+)%.([^:%.]+)$')
                                if not s then
                                    s = match(t, '^([^:%.]+)$')
                                    if not s then
                                        ms = match(t, '^%.([^:%.]+)$')
                                        if not ms then
                                            err({str='@',lin=LIN,sep=SEP}, "invalid clock")
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                coroutine.yield {
                    tag = 'clk',
                    str = t,
                    clk = {
                        h   = (h or 0),
                        min = (min or 0),
                        s   = (s or 0),
                        ms  = (ms or 0)
                    },
                    lin=LIN,sep=SEP,
                }
            end

        -- symbols:  {  (  ,  ;
        elseif contains(SYMS, c) then
            coroutine.yield { tag='sym', str=c, lin=LIN,sep=SEP }

        elseif c == '.' then
            local c2 = read()
            if c2 ~= '.' then
                unread()
                coroutine.yield { tag='sym', str='.', lin=LIN,sep=SEP }
            else
                local c3 = read()
                if c3 ~= '.' then
                    unread()
                    coroutine.yield { tag='sym', str='.', lin=LIN,sep=SEP }
                    coroutine.yield { tag='sym', str='.', lin=LIN,sep=SEP }
                else
                    coroutine.yield { tag='sym', str='...', lin=LIN }
                end
            end

        -- operators:  +  >=  #
        elseif contains(OPS.cs, c) then
            local op = read_while(c, function (c) return contains(OPS.cs,c) end)
            local cur = op
            while not contains(OPS.vs,cur) do
                if string.len(cur) == 0 then
                    err({str=op,lin=LIN,sep=SEP}, "invalid operator")
                end
                unread()
                cur = string.sub(cur, 1, -2)
            end
            if op=='~~' or op=='!~' then
                error("TODO : ~~ !~ : not implemented")
            end
            coroutine.yield { tag='op', str=cur, lin=LIN,sep=SEP }

        -- tags:  :X  :a:b:c
        elseif c == ':' then
            local c2 = read()
            if c2 == ':' then
                coroutine.yield { tag='sym', str='::', lin=LIN,sep=SEP }
            else
                unread()
                local tag = read_while(':', M"[%w_%.]")
                --[[
                local hier = {}
                for x in string.gmatch(tag, ":([^:]*)") do
                    hier[#hier+1] = x
                end
                ]]
                coroutine.yield { tag='tag', str=tag, lin=LIN,sep=SEP }
            end

        -- keywords:  await  if
        -- variables:  x  a_10
        elseif match(c, "[%a_]") then
            local id = read_while(c, M"[%w_]")
            if contains(KEYS, id) then
                coroutine.yield { tag='key', str=id, lin=LIN,sep=SEP }
            else
                coroutine.yield { tag='id', str=id, lin=LIN,sep=SEP }
            end

        -- numbers:  0xFF  10.1
        elseif match(c, "%d") then
            local num = read_while(c, M"[%w%.]")
            if string.find(num, '[PpEe]') then
                num = read_while(num, M"[%w%.%-%+]")
            end
            if not tonumber(num) then
                err({str=num,lin=LIN,sep=SEP}, "invalid number")
            else
                coroutine.yield { tag='num', str=num, lin=LIN,sep=SEP }
            end

        elseif c=='`' then
            local lin,sep = LIN,SEP
            local pre = read_while(c, C(c))
            local n1 = string.len(pre)
            local v = ''
            if n1 == 2 then
                v = ''
            elseif n1 == 1 then
                v = read_until(v, M("[\n"..c.."]"))
                if string.sub(str,i,i) == '\n' then
                    err({str=string.sub(str,i-1,i-1),lin=lin,sep=sep}, "unterminated native")
                end
                assert(c == read())
            else
                while true do
                    v = read_until(v, C(c))
                    if not v then
                        err({str=pre,lin=lin,sep=sep}, "unterminated native")
                    end
                    local pos = read_while('', C(c))
                    local n2 = string.len(pos)
                    if n1 == n2 then
                        break
                    end
                    v = v .. pos
                end
            end
            coroutine.yield { tag='nat', str=v, lin=lin,sep=sep }

        elseif c=='"' or c=="'" then
            local lin,sep = LIN,SEP
            local pre = read_while(c, C(c))
            local n1 = string.len(pre)
            local v = ''
            if n1 == 2 then
                v = ''
            elseif n1 == 1 then
                v = read_until(v, M("[\n"..c.."]"))
                if string.sub(str,i,i) == '\n' then
                    err({str=string.sub(str,i-1,i-1),lin=lin,sep=sep}, "unterminated string")
                end
                assert(c == read())
            else
                while true do
                    v = read_until(v, C(c))
                    if not v then
                        err({str=pre,lin=lin,sep=sep}, "unterminated string")
                    end
                    local pos = read_while('', C(c))
                    local n2 = string.len(pos)
                    if n1 == n2 then
                        break
                    end
                    v = v .. pos
                end
            end
            coroutine.yield { tag='str', str=v, lin=lin,sep=sep }

        -- eof
        elseif c == '\0' then
            coroutine.yield { tag='eof', str='<eof>', lin=LIN,sep=SEP }

        -- error
        else
            err({str=c,lin=LIN,sep=SEP}, "invalid character")
        end
    end
end

function lexer_init (file, str)
    str = str .. '\0'
    FILE = file
    LIN = 1
    local co = coroutine.create(_lexer_)
    LEX = function ()
        local ok, v = coroutine.resume(co, str)
        if not ok then
            error(v, 0)
        end
        return v
    end
end

function lexer_next ()
    TK0 = TK1
    TK1 = LEX()
end
