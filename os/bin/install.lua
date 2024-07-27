local args = ...
local term = require("term")
local process = require("process")
local syscalls = require("syscalls")

function SetupUsers(outdir)
	local usertab = io.open(outdir .. "/os/etc/usertab", "w")
	local users = {}

	print("Create Administrator user")
	io.write('Username: ')
	io.flush()
	local name = io.read("l")
	local password
	while true do
		io.write('Password: ')
		io.flush()
		password = term.readPassword()
		io.write('Password (again): ')
		io.flush()
		local password2 = term.readPassword()
		if password == password2 then break end
		print("Sorry, passwords do not match, try again")
	end

	table.insert(users, {name = name, password = password})

	while true do
		print("Create another user")
		io.write('Name (empty to cancel): ')
		io.flush()
		local name = io.read("l")
		if #name == 0 then break end
		local password
		while true do
			io.write('Password: ')
			io.flush()
			password = term.readPassword()
			io.write('Password (again): ')
			io.flush()
			local password2 = term.readPassword()
			if password == password2 then break end
			print("Sorry, passwords do not match, try again")
		end
		table.insert(users, {name = name, password = password})
	end

	print("Writing user login information in " .. outdir .. "/os/etc/usertab")

	for i=1,#users do
		local user = users[i]
		local passhash = syscalls.data_encode64(syscalls.data_sha256(user.password))
		local ring = 3
		if i == 1 then
			ring = 0
		end
		io.write(usertab, '"', user.name, '" "', passhash, '" ', tostring(ring), '\n')
	end
	io.flush(usertab)
	io.close(usertab)

end

function InstallOS()
	local mountPoints = io.list("/mnt")

	print("All disks:")
	for i=1,#mountPoints do
		print(tostring(i) .. ") " .. mountPoints[i])
	end
	io.write("Input mountpoint: ")
	io.flush()
	local input = io.read("l")
	local disk
	if tonumber(input) then
		disk = mountPoints[tonumber(input)]
		if not disk then
			print("Invalid response.")
			return
		end
	else
		for i=1,#mountPoints do
			if mountPoints[i] == input then
				disk = input
			end
		end
		if not disk then
			print("No mountpoint named " .. disk .. " could be found")
		end
	end

	print("Computing Operating System structure...")
	local structureBuffer = io.memory("", "rw")
	local structureProc = process.spawn("Install: Find OS structure", {[0] = structureBuffer.fd})
	local ok, err = process.exec(structureProc, "/os/bin/structure.lua", {"/", "-i", "/.git", "-i", "/tmp", "-i", "/mnt", "-i", "/os/etc", "-i", "/installers"})
	if not ok then print("Error: " .. err) return end
	process.join(structureProc)
	io.seek(structureBuffer, "set", 0)
	local outdir = "/mnt/" .. disk
	while true do
		local line = io.read(structureBuffer, "l")
		if line == nil then break end
		if string.startswith(line, "directory") then
			local dirpath = line:sub(11)
			print("Creating directory " .. outdir .. dirpath)
			io.mkdir(outdir .. dirpath)
		elseif string.startswith(line, "file") then
			local filepath = line:sub(6)
			local copyProc = process.spawn("Install: Copy " .. filepath)
			local ok, err = process.exec(copyProc, "/os/bin/cp.lua", {filepath, outdir .. filepath, "-v"})
			if not ok then print("Error: " .. err) return end
			process.join(copyProc)
			process.kill(copyProc) -- To free up the resources
		end
		coroutine.yield()
	end

	SetupUsers(outdir)
end

if #args == 0 then
	InstallOS()
end
io.flush(io.stdout)
