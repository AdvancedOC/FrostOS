local args = ...

if #args == 0 then
	while true do
		local line = io.stdin:read("l")
		if line == nil then return end
		print(line)
		coroutine.yield()
	end
end

local silent = false
local chunksize = 128
for _, arg in ipairs(args) do
    if arg == "-s" then
        silent = true
    elseif arg == "-i" then
	    while true do
			local line = io.stdin:read("l")
			if line == nil then break end
			print(line)
			coroutine.yield()
		end
    else
        local f, err = io.open(arg, "r")
        if not f then print("Error: Unable to open " .. err) return end
        repeat
        	local chunk = f:read(chunksize)
        	io.write(io.stdout, chunk)
        until not chunk
    end
end

if silent then io.flush(io.stdout) else io.write('\n') end
