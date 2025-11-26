require "atmos.lang.global"
require "atmos.lang.lexer"
require "atmos.lang.parser"
require "atmos.lang.coder"

function atm_test (src, tst)
    local out = ""
    PRINT = print
    print = (tst and print) or (function (...)
        local t = {}
        for i=1, select('#',...) do
            t[#t+1] = tostring(select(i,...))
        end
        out = out .. join('\t', t) .. '\n'
    end)
    local f, err = atm_loadstring(src, "anon.atm")
    if not f then
        print = PRINT
        return err
    end
    atmos = require "atmos"
    X = require "atmos.x"
    require "atmos.lang.run"
    local ok, err = pcall(atmos.call,f)
    print = PRINT
    if ok then
        return out
    else
        return out .. err
    end
end

function atm_searcher (name)
    local path = package.path:gsub('%?%.lua','?.atm'):gsub('init%.lua','init.atm')
    local f, err = package.searchpath(name, path)
    if not f then
        return f, err
    end
    return function(_,x)
        return assert(atm_loadfile(x))()
    end, f
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
    local ok,lua = pcall(atm_to_lua, file, src)
    if not ok then
        return ok,lua
    end
--io.stderr:write('\n'..lua..'\n\n')
    local f,msg1 = load(lua, file)
    if not f then
        local filex, lin, msg2 = string.match(msg1, '%[string "(.-)"%]:(%d+): (.-) at line %d+$')
        if not filex then
            filex, lin, msg2 = string.match(msg1, '%[string "(.-)"%]:(%d+): (.*)$')
        end
        assert(file == filex)
        return f, (file..' : line '..lin..' : '..msg2..'\n')
    end
    return f
end

function atm_loadfile (file)
    local f = assert(io.open(file))
    -- enclose with func (atm_func) b/c of return (throw)
    -- func { \0 ... \n }:
    --  - 1st \0 means no \n b/c of lexer lines
    --  - 2nd \n prevents ";; }" in last line
    local src = "(func (...) { " .. f:read('*a') .. "\n})(...)"
    --local src = f:read('*a')
     return atm_loadstring(src, file)
end

function atm_dostring (src, file)
    return assertn(0, atm_loadstring(src,file))()
end

function atm_dofile (file)
    local f = assert(io.open(file))
    local src = f:read('*a')
    return atm_dostring(src, file)
end
