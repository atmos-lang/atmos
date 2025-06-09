require "global"
require "lexer"
require "parser"
require "coder"

function atm_searcher (name)
    local path = package.path:gsub('%?%.lua','?.atm'):gsub('init%.lua','init.atm')
    local f, err = package.searchpath(name, path)
    if not f then
        return f, err
    end
    return atm_loadfile, f
end

function atm_load (src, file)
    init()
    lexer_init(file, src)
    lexer_next()
    local main = parser_main()
    local lua = [[
        local atm_as_lua = function () ]] .. coder_stmts(main.blk.es) .. [[ end
        require 'aux'
        require 'runtime'
        return atm_exec(file, main)
            "]] .. file .. [[",
            ]] .. string.format('%q', coder_stmts(main.blk.es)) .. [[
        )
    ]]

    return load(src, file)
end

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
    local main = parser_main()

    local f = assert(io.open(file..".lua", "w"))
    f:write([[
        require 'aux'
        require 'runtime'
        return atm_exec (
            "]] .. file .. [[",
            ]] .. string.format('%q', coder_stmts(main.blk.es)) .. [[
        )
    ]])
    f:close()

    return dofile(file..".lua")
end
