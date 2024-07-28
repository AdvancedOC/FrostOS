local args = ...
local syscalls = require("syscalls")

local url = args[1]
local out = args[2]

if not url then
	error("No output file!")
	return
end

local response = syscalls.internet_download(url)
if not response then
	error("Unable to reach " .. url)
	return
end

if out then
	local outfile, err = io.open(out, "w")
	if not outfile then error("Unable to open " .. out .. ": " .. err) return end
	outfile:write(response)
	outfile:close()
else
	print(response)
end
