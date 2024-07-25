local syscalls = require("syscalls")
local process = require("process")

local screens = syscalls.graphics_getScreens()

local gpucount = syscalls.graphics_gpuCount()

local truecount = math.min(#screens,gpucount) -- if you have more screens than gpus you can't, and you also don't need multiple gpus on a single screen

for i = 1,truecount do
    syscalls.graphics_bind(screens[i],i) -- bind gpus to screens

    syscalls.graphics_setResolution(30,10,i) -- if any of them don't support this i'll cry
end

syscalls.graphics_setForeground(0xFFFFFF)
syscalls.graphics_setBackground(0x000000)

if not syscalls.data_sha256 then
	-- No data card... can't do anything right now
	syscalls.graphics_set(1,1,"No datacard available")
	while true do
		coroutine.yield()
	end
end

local users = {}

-- TODO: Parse users

-- TODO: if no users, ask to create user

-- TODO: Login

local extraStuff = {
	HOME = "/home",
}

local env = "/os/bin/bterm.lua"

local term = process.spawn("Environment", nil, process.envsWith(extraStuff), extraStuff.HOME, 2)

local ok, err = process.exec(term, env)

if not ok then error(err) end

while true do
	if process.status(term) == "dead" then
		return
	end
	coroutine.yield()
end
