local args = ...
local syscalls = require("syscalls")
local term = require("term")
local process = require("process")

-- TODO: figure out how to change user
local user = "admin"
local cmd = args[1]
local cargs = {}
for i=1,#args do
	cargs[i-1] = args[i]
end

if not cmd then
	print("No command")
	return
end

local function spawnProcess(ring)
	local child = process.spawn("DOAS (" .. user .. "): " .. cmd, nil, nil, nil, ring)
	local ok, err = process.exec(child, "/usr/bin/sh.lua", {[0] = "/usr/bin/sh", "-r", tostring(ring), "-c", cmd, table.unpack(cargs)})
	if not ok then
		error("Error: " .. err)
	end
	process.join(child)
end

local unsecured, ring = syscalls.plogin(user, "")
if unsecured then
	spawnProcess(ring)
	process.exit()
	return
end

while true do
	io.write("Password: ")
	local guess = term.readPassword()
	local ok, ring = syscalls.plogin(user, guess)
	if ok then
		spawnProcess(ring)
		process.exit()
		return
	else
		print("Sorry, wrong password. Try again.")
	end
	coroutine.yield()
end
