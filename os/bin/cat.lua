local args = ...

local silent = false

for _, arg in ipairs(args) do
    if arg == "-s" then
        silent = true
    else
        local f, err = io.open(arg, "r")
        if not f then print("Error: Unable to open " .. err) return end
        local chunksize = 128
        repeat
        	local chunk = f:read(chunksize)
        	io.write(io.stdout, chunk)
        until not chunk
    end
end

if silent then io.flush(io.stdout) else io.write('\n') end
