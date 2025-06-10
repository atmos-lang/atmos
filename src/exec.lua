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

function atm_loadstring (src, file)
    init()
    lexer_init(file, src)
    lexer_next()
    local ast = parser_main()
    local lua = coder_stmts(ast.blk.es)
    --io.stderr:write(lua)
    local f,msg1 = load(lua, file)
    if not f then
        local filex, lin, msg2 = string.match(msg1, '%[string "(.-)"%]:(%d+): (.-) at line %d+$')
        if not filex then
            filex, lin, msg2 = string.match(msg1, '%[string "(.-)"%]:(%d+): (.*)$')
        end
        assert(file == filex)
        return f, (file..' : line '..lin..' : '..msg2..'\n')
    end
    return function ()
        require 'runtime'
        local v, msg1 = pcall(f)
        --print(v, msg1)
        if not v then
            if type(msg1) == 'table' then
                if msg1.up == 'func' then
                    return table.unpack(msg1)
                elseif msg1.up == 'catch' then
                    assert(msg1.up)
                    error("uncaught throw : " .. stringify(msg1[1]), 0)
                else
                    error "bug found"
                end
            else
                assert(type(msg1) == 'string')
                local filex, lin, msg2 = string.match(msg1, '%[string "(.-)"%]:(%d+): (.*)$')
                --print(file, filex, lin, msg1)
                if file ~= filex then
                    error('internal error : ' .. msg1)
                end
                error(file..' : line '..lin..' : '..msg2, 0)
            end
            return nil
        end
        close(TASKS)
        return v
    end
end

function atm_dostring (src, file)
    assertn(0, atm_loadstring(src,file))()
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
