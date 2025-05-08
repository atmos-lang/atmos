function lexer_string (str)
    return coroutine.wrap (
        function ()
            for i=1, #str do
                local c = string.sub(str,i,i)
                coroutine.yield(c)
            end
        end
    )
end
