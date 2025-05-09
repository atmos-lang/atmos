function exec_string (file, src)
    lexer_string(file, src)
    parser()
    local ss = parser_list(null, "<eof>", parser_stmt)

    local f = assert(io.open(file..".lua", "w"))
    f:write(stmts_code(ss))
    f:close()

    local exe = assert(io.popen("lua5.4 "..file..".lua", "r"))
    return exe:read("a")
end
