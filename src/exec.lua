function exec_string (file, src)
    lexer_string(file, src)
    parser()
    local blk = parser_main()

    local f = assert(io.open(file..".lua", "w"))
    f:write([[
        require 'prelude'
        local ok,msg = pcall(function () ]]..
            coder_stmts(blk.ss)..[[
        end)
        if not ok then
            local f, lin, msg = string.match(msg, "(.-)%.lua:(%d+): (.*)$")
            --print(f, lin, msg)
            io.stderr:write(f..' : line '..lin..' : '..msg..'\n')
        end
    ]])
    f:close()

    local exe = assert(io.popen("lua5.4 "..file..".lua 2>&1", "r"))
    return exe:read("a")
end
