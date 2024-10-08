local args = ...
local process = require("process")

local top = 0
local kill = false

local i = 1
while args[i] do
	if args[i] == "-p" or args[i] == "--process" then
		local pattern = args[i+1]
		if tonumber(pattern) then
			top = tonumber(pattern) or 0
		else
			top = process.find(pattern)
			if not top then
				print("No process matching " .. pattern .. " could be found")
				return
			end
		end
		i = i + 2
	elseif args[i] == "-k" then
		kill = true
		i = i + 1
	else
		print("Error: Unknown argument " .. args[i])
		return
	end
end

function processTree(pid, indent)
	local prefix = string.rep(' ', indent)

	local info = process.info(pid)
	print(prefix .. info.name .. " (" .. info.pid .. ")")
	print(prefix .. "PWD: " .. info.cwd .. " Ring: " .. info.ring)

	if kill then
		local err = process.kill(pid)
		if err then print(prefix .. "Error: " .. err) end
	end

	for _, child in ipairs(info.children) do
		processTree(child, indent + 2)
		coroutine.yield()
	end
end

processTree(top, 0)
