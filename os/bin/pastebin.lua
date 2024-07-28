local args = ...
local syscalls = require("syscalls")

local pastebin = "https://pastebin.com/raw/"

if args[1] == "run" then
	local path = args[2]

	print("Downloading file...")
	local filedata,err = syscalls.internet_download(pastebin .. path)
	if not filedata then error("Couldn't download file: " .. tostring(err)) end

	local temppath = "/tmp/" .. path

	print("Writing into " .. temppath .. "...")
	local filehandle = io.open(temppath, "w")

	if not filehandle then error("Can't open " .. temppath .. " for writing.") end

	filehandle:write(filedata)
	filehandle:close()

	print("Spawning process...")
	local process = require("process")
	local child = process.spawn("pastebin run: " .. path)

	print("Running file...")
	local ok, procerr = process.exec(child, temppath)
	if not ok then
		error("Error: " .. procerr)
	end
	process.join(child)
elseif args[1] == "get" then
	local pastebinpath = args[2]
	local filepath = args[3]

	local filedata,err = syscalls.internet_download(pastebin .. pastebinpath)
	if not filedata then error("Couldn't download file: " .. tostring(err)) end

	if filepath then
		local handle = io.open(filepath,"w")
		if not handle then error("Could not open " .. filepath .. " for writing.") end

		handle:write(filedata)
		handle:close()

		print("Successfully wrote the pastebin data to " .. filepath)
	else
		io.write(io.stdout, filedata)
		io.flush()
	end
end
