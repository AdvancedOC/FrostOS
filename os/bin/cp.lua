local args = ...
local thread = require("thread")

local flags = {
	recursive = false,
	copyHidden = false,
	ignoreLinks = false,
	verbose = false,
	overwrite = false,
}

local input
local outputs = {}

local i = 1
while args[i] do
	if args[i]:sub(1, 1) == "-" then
		local opts = args[i]:sub(2)
		for i=1,#opts do
			local opt = opts:sub(i, i)
			if opt == "r" then
				flags.recursive = true
			elseif opt == "f" then
				flags.copyHidden = true
			elseif opt == "l" then
				flags.ignoreLinks = true
			elseif opt == "v" then
				flags.verbose = true
			elseif opt == "o" then
				flags.overwrite = true
			else
				print("Unknown flag: " .. opt)
				return
			end
		end
	else
		if not input then
			input = args[i]
		else
			table.insert(outputs, args[i])
		end
	end
	i = i + 1
end

if not input then
	print("Error: No input file")
	return
end

if #outputs == 0 then
	print("Error: No output files")
	return
end

local function pjoin(p, child)
	if p == "/" then return "/" .. child end
	return p .. "/" .. child
end

function Copy(from, into)
	coroutine.yield()
	if flags.verbose then
		print("Copying from " .. from .. " to " .. into)
	end
	if io.isSymlink(from) then
		if flags.verbose then print("Dead symlink at ".. from .. ". Ignoring...") end
		return
	end
	if not io.exists(from) then
		print("Unable to find " .. from)
		return
	end

	if io.exists(into) then
		if flags.overwrite or ((io.isDirectory(from) or io.isMount(from)) and (io.isDirectory(into) or io.isMount(into))) then
			if io.isFile(from) and io.isDirectory(into) then
				if flags.verbose then
					print("Conflicting types for " .. from .. " and " .. into .. "...")
					print("Deleting " .. into .. "...")
				end
				-- If into is a directory, we're fucked
				local err = io.remove(into)
				if err then
					print("Error: " .. err)
					return
				end
			elseif (io.isDirectory(from) or io.isMount(from)) and (io.isFile(into) or io.isSymlink(into)) then
				if flags.verbose then
					print("Conflicting types for " .. from .. " and " .. into .. "...")
					print("Deleting " .. into .. "...")
				end
				local err = io.remove(into)
				if err then
					print("Error: " .. err)
					return
				end
			end
		else
			print("Unable to overwrite " .. into)
			return
		end
	end

	if io.isFile(from) then
		local input, err = io.open(from, "r")
		if not input then
			print("Unable to open " .. from .. ": " .. err)
			return
		end
		local out, err = io.open(into, "w")
		if not out then
			print("Unable to open " .. into .. ": " .. err)
			return
		end
		while true do
			local data = io.read(input, math.huge)
			if not data then break end
			io.write(out, data)
			coroutine.yield()
		end
		io.flush(out)
		io.close(input)
		io.close(out)
	elseif io.isDirectory(from) or io.isMount(from) then
		if not flags.recursive then
			print("Error: Unable to copy " .. from .. " (Use -r for recursive copying)")
			return
		end
		-- Welp, we better copy the directory!
		local sub = io.list(from)
		if not io.exists(into) then
			if flags.verbose then print("Making directory " .. into) end
			local err = io.mkdir(into)
			if err then print("Error: " .. err) return end
		end
		for _, child in ipairs(sub) do
			Copy(pjoin(from, child), pjoin(into, child))
		end
	end
end

for i=1,#outputs do
	Copy(input, outputs[i])
end
