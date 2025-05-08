function contains (t, v)
    for _,x in ipairs(t) do
        if x == v then
            return true
        end
    end
    return false
end
