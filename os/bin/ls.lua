local args = ...

local inputs = {}
local showType = false
local showSize = false
local recursive = false
local showHidden = false
local colored = false
local allowed = {
	file = true,
	directory = true,
	sym = true,
	mount = true,
}

local i = 1
while args[i] do
	local arg = args[i]
	if arg:sub(1, 1) == "-" then
		local options = arg:sub(2)
		for i=1,#options do
			local o = options:sub(i, i)
			if o == "r" then
				recursive = true
			elseif o == "i" then
				showType = true
			elseif o == "s" then
				showSize = true
			elseif o == "h" then
				showType = true
				showSize = true
			elseif o == "f" then
				showHidden = true
			elseif o == "c" then
				colored = true
			elseif o == "F" then
				allowed.file = false
			elseif o == "D" then
				allowed.directory = false
			elseif o == "S" then
				allowed.sym = false
			elseif o == "M" then
				allowed.mount = false
			else
				print("Error: Unknown option " .. o)
				return
			end
		end
		i = i + 1
	else
		table.insert(inputs, arg)
		i = i + 1
	end
end

local function round(val)
	return math.floor(val * 10 + 0.5) / 10
end

local function formatSize(size)
	local scale = 1024
	local units = {'B', 'KB', 'MB', 'GB', 'TB'}
	local unit = 1

	while size >= scale and units[unit+1] do
		size = size / scale
		unit = unit + 1
	end

	return round(size) .. units[unit]
end

local colors = {
	file = {0, 135, 113},
	directory = {0, 223, 223},
	mount = {0, 255, 15},
	symlink = {255, 0, 0},
}

local term = require("term")

function ListPath(name, path, indent, root)
	if name:sub(1, 1) == "." and not showHidden then return end
	local prefix = string.rep(" ", indent)
	local kind = io.type(path)
	if colored then
		term.setForeground(table.unpack(colors[kind] or {255, 255, 255}))
	end
	io.write(io.stdout, prefix, name)
	if showSize then
		local size = io.size(path)
		if size then
			io.write(io.stdout, " ", formatSize(size))
		end
	end
	if showType then
		io.write(io.stdout, " ", kind)
	end
	io.write(io.stdout, '\n')
	io.flush(io.stdout)

	if ((kind ~= "directory" and kind ~= "mount") or not recursive) and not root then return end

	local children, err = io.list(path)
	if not children then
		print("Error: " .. err)
		return
	end

	local files = {}

	for i=1,#children do
		if children[i]:sub(#children[i], #children[i]) == "/" then
			children[i] = children[i]:sub(1, -2)
		end
		if path == "/" then
			files[i] = "/" .. children[i]
		else
			files[i] = path .. "/" .. children[i]
		end
	end

	for i=1,#children do
		ListPath(children[i], files[i], indent + 2)
	end
end

for i=1,#inputs do
	ListPath(inputs[i], inputs[i], 0, true)
end

if #inputs == 0 then
	local items, err = io.list('.')
	if not items then error(err) end
	for i=1,#items do
		ListPath(items[i], items[i], 0, false)
	end
end
