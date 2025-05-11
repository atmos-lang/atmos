function exec_string (file, src)
    lexer_string(file, src)
    parser()
    local blk = parser_main()

    local f = assert(io.open(file..".lua", "w"))
    f:write("require 'prelude'\n")
    f:write(coder_stmts(blk.ss))
    f:close()

    local exe = assert(io.popen("lua5.4 "..file..".lua 2>&1", "r"))
    return exe:read("a")
end
