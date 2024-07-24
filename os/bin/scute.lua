local syscalls = require("syscalls")

-- unimplemented lol

local function isBackslashed(str, i)
	if str:sub(i - 1, i - 1) == "\\" then
		return not isBackslashed(str, i - 1)
	end
	return false
end

local function parseCommand(cmd)
	local args = {}
	local current = ""

	local i = 0
	while i < #cmd do
		i = i + 1

		local ch = string.sub(cmd, i, i)

		if ch == " " and not isBackslashed(cmd, i) then
			args[#args + 1] = current
			current = ""
		elseif ch == '"' and not isBackslashed(cmd,i) then
			i = i + 1
		 	while cmd:sub(i,i) ~= '"' or isBackslashed(cmd,i) do
				current = current .. cmd:sub(i,i)
		  		i = i + 1
			end
			i = i + 1
		else
			current = current .. cmd:sub(i,i)
		end
	end

	if #current > 0 then args[#args+1] = current end
end
