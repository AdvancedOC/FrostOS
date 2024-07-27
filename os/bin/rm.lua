local args = ...

local recursive = false
local verbose = false

local inputs  = {}

for i=1,#args do
	local arg = args[i]
	if arg:sub(1, 1) == "-" then
		local opts = arg:sub(2)
		for i=1,#opts do
			local o = opts:sub(i, i)
			if o == "r" then
				recursive = true
			elseif o == "v" then
				verbose = false
			else
				print("Unknown option: " .. o)
				return
			end
		end
	else
		table.insert(inputs, arg)
	end
end

function Remove(path)
	if verbose then print("Deleting " .. path .. "...") end
	if io.islink(path) then
		if verbose then
			print("Is symlink, ignoring...")
		end
		return
	end
	if io.isFile(path) then
		local err = io.remove(path)
		if err then print("Error: " .. err) return end
	end
	if io.isDirectory(path) or io.isMount(path) then
		if not recursive then
			print("Error: Unable to delete " .. path .. ": is a directory")
		else
			local items = io.list(path)
			for _, file in ipairs(items) do
				if path == "/" then
					Remove("/" .. file)
				else
					Remove(path .. "/" .. file)
				end
			end
			if io.isDirectory(path) then
				print("Deleting " .. path .. "...")
				io.remove(path)
			end
		end
	end
end

for i=1,#inputs do
	Remove(inputs[i])
end
