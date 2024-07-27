local args = ...

local recursive = false
local dirs = {}

for i=1,#args do
	if args[i] == "-r" then
		recursive = true
	else
		table.insert(dirs, args[i])
	end
end

for i=1,#dirs do
	io.mkdir(dirs[i])
end
