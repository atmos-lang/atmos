function tosource_stmts (e)
    return join('\n', map(e.es,tosource)) ..'\n'
end

function tosource_block (e)
    return '{\n' .. tosource_stmts(e) .. '}'
end

function tosource_args (es)
    return join(', ', map(es,tosource))
end

function tosource (e, lbd)
    if e.tag=='nil' or e.tag=='bool' or e.tag=='tag' or e.tag=='num' or e.tag=='acc' or e.tag=='dots' then
        return e.tk.str
    elseif e.tag == 'str' then
        return '"' .. e.tk.str .. '"'
    elseif e.tag == 'nat' then
        return '`' .. e.tk.str .. '`'
    elseif e.tag == 'clk' then
        local t = e.tk.clk
        return '@' .. t.h .. ':' .. t.min .. ':' .. t.s .. '.' .. t.ms
    elseif e.tag == 'uno' then
        return '(' .. e.op.str .. tosource(e.e) .. ')'
    elseif e.tag == 'bin' then
        return '('..tosource(e.e1)..' '..e.op.str..' '..tosource(e.e2)..')'
    elseif e.tag == 'index' then
        return tosource(e.t)..'['..tosource(e.idx)..']'
    elseif e.tag == 'table' then
        local es = join(", ", map(e.es, function (t)
            return '['..tosource(t.k)..']='..tosource(t.v)
        end))
        return '@{' .. es .. '}'
    elseif e.tag == 'es' then
        return '(' .. tosource_args(e.es) .. ')'
    elseif e.tag == 'parens' then
        local e = tosource(e.e)
        if e:sub(1,1)=='(' and e:sub(#e,#e)==')' then
            return e
        else
            return '(' .. e .. ')'
        end
    elseif e.tag == 'call' then
        return tosource(e.f) .. '(' .. tosource_args(e.es) .. ')'
    elseif e.tag == 'met' then
        return tosource(e.o) .. '::' .. e.met.str
    elseif e.tag == 'func' then
        local pars = join(', ', map(e.pars, function (id) return id.str end))
        local dots = ''; do
            if e.dots then
                if #e.pars == 0 then
                    dots = '...'
                else
                    dots = ', ...'
                end
            end
        end
        if lbd then
            if #pars>0 then
                return "\\(" .. pars .. dots .. ")" .. tosource_block(e.blk)
            else
                return tosource_block(e.blk)
            end
        else
            return "func (" .. pars .. dots .. ") " .. tosource_block(e.blk)
        end

    elseif e.tag == 'dcl' then
        local ids = join(', ', map(e.ids,  function(id) return id.str end))
        local set = e.set and (' = '..tosource(e.set)) or ''
        return e.tk.str .. " " .. ids .. set
    elseif e.tag == 'set' then
        return "set " .. tosource_args(e.dsts) .. " = " .. tosource(e.src)
    elseif e.tag == 'stmts' then
        return tosource_stmts(e)
    elseif e.tag == 'block' then
        return tosource_block(e)
    elseif e.tag == 'do' then
        return "do " .. (e.esc and e.esc.str.." " or "") .. tosource(e.blk)
    elseif e.tag == 'defer' then
        return "defer " .. tosource_block(e.blk)
    elseif e.tag == 'ifs' then
        local function f (t,i)
            local cnd, x = table.unpack(t)
            if cnd ~= "else" then
                cnd = tosource(cnd)
            end
            return cnd .. " => " .. tosource(x,true) .. '\n'
        end
        local head = "ifs"
        if e.match then
            head = "match " .. tosource(e.match.e)
        end
        return head .. " {\n" .. join('',map(e.cases,f)) .. "}"
    elseif e.tag == 'loop' then
        local ids = e.ids and (' '..join(', ', map(e.ids, function(id) return id.str end))) or ''
        local itr = e.itr and (' in '..tosource(e.itr)) or ''
        return "loop" .. ids .. itr .. ' ' .. tosource_block(e.blk)
    elseif e.tag == 'catch' then
        return "catch " .. tosource(e.cnd) .. " " .. tosource_block(e.blk)
    else
        print(e.tag)
        error("TODO")
    end
end
