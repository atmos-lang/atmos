require "global"
require "lexer"
require "parser"
require "coder"
function exec_file (file)
    local f = assert(io.open(file))
    local src = f:read('*a')
    return exec_string(file, src)
end

function exec_string (file, src)
    init()
    lexer_init(file, src)
    lexer_next()
    local ok, do_ = pcall(parser_main)
    if not ok then
        return do_
    end

    local f = assert(io.open(file..".lua", "w"))
    f:write([[
        require 'aux'
        require 'runtime'
        return atm_exec (
            "]] .. file .. [[",
            ]] .. string.format('%q', coder_stmts(do_.blk.es)) .. [[
        )
    ]])
    f:close()

    local exe = assert(io.popen("lua5.4 "..file..".lua 2>&1", "r"))
    return exe:read("a")
end

function do_file (file)
    local f = assert(io.open(file))
    local src = f:read('*a')
    return do_string(file, src)
end

function do_string (file, src)
    init()
    lexer_init(file, src)
    lexer_next()
    local ok, blk = pcall(parser_main)
    if not ok then
        return ok, blk
    end

    local f = assert(io.open(file..".lua", "w"))
    f:write([[
        require 'aux'
        require 'runtime'
        return atm_exec (
            "]] .. file .. [[",
            ]] .. string.format('%q', coder_stmts(blk.es)) .. [[
        )
    ]])
    f:close()

    return pcall(dofile, file..".lua")
end
