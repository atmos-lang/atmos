require "global"
require "lexer"
require "parser"
require "coder"

function atm_test (src, tst)
    PRINT = print
    local out = ""
    print = (tst and print) or (function (...)
        local t = {}
        for i=1, select('#',...) do
            t[#t+1] = tostring(select(i,...))
        end
        out = out .. join('\t', t) .. '\n'
    end)
    local ok, err = pcall(atm_dostring, src, "anon.atm")
    print = PRINT
    if ok then
        return out
    else
        return err
    end
end

function atm_searcher (name)
    local path = package.path:gsub('%?%.lua','?.atm'):gsub('init%.lua','init.atm')
    local f, err = package.searchpath(name, path)
    if not f then
        return f, err
    end
    return function(_,x) return assert(atm_loadfile(x))() end, f
end

package.searchers[#package.searchers+1] = atm_searcher

function atm_to_lua (file, src)
    init()
    lexer_init(file, src)
    lexer_next()
    local ast = parser_main()
    return coder_stmts(ast.blk.es)
end

function atm_loadstring (src, file)
    local lua = atm_to_lua(file, src)
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
        require "runtime"
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

function atm_loadfile (file)
    local f = assert(io.open(file))
    local src = f:read('*a')
    return atm_loadstring(src, file)
end

function atm_dostring (src, file)
    assertn(0, atm_loadstring(src,file))()
end

function atm_dofile (file)
    local f = assert(io.open(file))
    local src = f:read('*a')
    return atm_dostring(src, file)
end
