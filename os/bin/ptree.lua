local args = ...
local process = require("process")

local top = 0

function processTree(pid, indent)
	local prefix = string.rep(' ', indent)

	local info = process.info(pid)
	print(prefix .. info.name .. " (" .. info.pid .. ")")
	print(prefix .. "PWD: " .. info.cwd .. " Ring: " .. info.ring)

	for _, child in ipairs(info.children) do
		processTree(child, indent + 2)
	end
end

print(table.concat(process.all(), ' '))

processTree(top, 0)
