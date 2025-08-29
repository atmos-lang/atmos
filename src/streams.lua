local S = require "streams"

function S.fr_vector (t)
    local i = 0
    local f = function ()
        if i < #t then
            local v = t[i]
            i = i + 1
            return v
        end
    end
    return setmetatable({f=f}, S.mt)
end

function S.to_vector (s)
    return S.to_acc(s, atm_vector{}, function(a,x) a[#a]=x ; return a end)
end

return S
