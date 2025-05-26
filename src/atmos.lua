require "exec"

local file = ...

local ok, err = do_file(file)
if not ok then
    io.stderr:write(err .. '\n')
end
