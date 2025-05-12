function exec_string (file, src)
    init()
    lexer_string(file, src)
    parser()
    local blk = parser_main()

    local f = assert(io.open(file..".lua", "w"))
    f:write([[
        require 'aux'
        require 'prelude'
        local f, msg = load (]] ..
            string.format('%q', coder_stmts(blk.ss))
            ..', "'..file..[["
        )

        if not f then
            local filex, lin, msg2 = string.match(msg, '%[string "(.-)"%]:(%d+): (.-) at line %d+$')
            if not filex then
                filex, lin, msg2 = string.match(msg, '%[string "(.-)"%]:(%d+): (.*)$')
            end
            --print("]]..file..[[", filex, lin, msg2)
            assert("]]..file..[[" == filex)
            io.stderr:write("]]..file..[["..' : line '..lin..' : '..msg2..'\n')
            return nil
        end

        local v, msg = pcall(f)
        if not v then
            local filex, lin, msg = string.match(msg, '%[string "(.-)"%]:(%d+): (.*)$')
            --print(file, filex, lin, msg)
            assert("]]..file..[[" == filex)
            io.stderr:write("]]..file..[["..' : line '..lin..' : '..msg..'\n')
            return nil
        end
        return v
    ]])
    f:close()

    local exe = assert(io.popen("lua5.4 "..file..".lua 2>&1", "r"))
    return exe:read("a")
end
