local args = ...
local syscalls = require("syscalls")
local term = require("term")

local repository = "https://raw.githubusercontent.com/Blendi-Goose/FrostOS"
local branch = args[1] or "main"

local url = repository .. "/" .. branch

local function downloadFile(url)
	local connection = syscalls.internet_request(url)
	if not connection then
		error("Unable to connect to " .. url)
	end
	connection.finishConnect()
	local buf = ""
	while true do
		local data = connection.read(math.huge)
		if not data then break end
		buf = buf .. data
	end
	connection.close()
	return buf
end

-- No way to do delta updates btw
local structure = string.split(downloadFile(url .. "/os_toinstall"), '\n')

for _, line in ipairs(structure) do
	if string.startswith(line, "directory") then
		local dir = line:sub(11)
		if io.isFile(dir) then
			print("File will be replaced with directory: " .. dir)
			io.write("Proceed? [y/N] ")
			local ans = io.read("l")
			if ans:lower():sub(1, 1) == "y" then
				io.remove(dir)
			else
				print("Aborting, system partially updated")
				return
			end
		end
		if not io.exists(dir) then
			local err = io.mkdir(dir)
			if err then error("Failed to create " .. dir .. ": " .. err) end
		end
	elseif string.startswith(line, "file") then
		local file = line:sub(6)
		-- Files start with / cuz why not
		local contents = downloadFile(url .. file)
		local f, err = io.open(file, "w")
		if not f then error("Unable to open " .. file .. ": " .. err) end
		f:write(contents)
		f:flush()
		f:close()
	end
end
