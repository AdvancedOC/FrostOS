local syscalls = require("syscalls")
local process = require("process")

local screens = syscalls.graphics_getScreens()

local gpucount = syscalls.graphics_gpuCount()

local w = 60
local h = 20

local truecount = math.min(#screens,gpucount) -- if you have more screens than gpus you can't, and you also don't need multiple gpus on a single screen

for i=1,truecount do
	syscalls.graphics_bind(screens[i],i) -- bind gpus to screens
	local sw, sh = syscalls.graphics_maxResolution(i)
	w = math.min(w, sw)
	h = math.min(h, sh)
end

screens = nil -- safe some RAM

for i = 1,truecount do
    syscalls.graphics_setResolution(w,h,i) -- if any of them don't support this i'll cry
end

local j = 0

local function clearScreens()
	j = 0
	for i = 1,truecount do
		syscalls.graphics_setBackground(0x000000,i)
		syscalls.graphics_setForeground(0xFFFFFF,i)
		syscalls.graphics_fill(1,1,w,h," ",i)
	end
end

syscalls.graphics_setForeground(0xFFFFFF)
syscalls.graphics_setBackground(0x000000)

clearScreens()
clearScreens = nil

local function addWarning(warning)
	j = j + 1
	if j > h then
		for i = 1, truecount do
			syscalls.graphics_copy(1,2,w,h-1,0,-1, i)
			syscalls.graphics_fill(1,1,w,1," ", i)
		end
	end
	for i = 1, truecount do
		syscalls.graphics_set(1, j, warning, i)
	end
end
addWarning("OS finished booting, running login")

if syscalls.computer_dangerouslyLowRAM() then
	addWarning("Warning: OS running in MEMORY-CONSERVATIVE mode")
end

if not syscalls.data_sha256 or not syscalls.data_encode64 or not syscalls.data_decode64 then
	-- No data card... can't do anything right now
	addWarning("Error: No data card driver found.")
	while true do
		coroutine.yield()
	end
end

local users = {}

-- TODO: Parse users

-- TODO: if no users, ask to create admin

-- TODO: Login

local extraStuff = {
	HOME = "/home",
}

repeat
	Events.process(0.01)
	coroutine.yield()
until syscalls.computer_freeMemory() > 8*1024

local env = "/os/bin/bterm.lua"

log("Spawning environment process")
local term, err = process.spawn("Environment " .. env, nil, extraStuff, extraStuff.HOME, 2)
if not term then log("Error: " .. err) addWarning("Error: " .. err) end

log("Running environment " .. env)
local ok, err = process.exec(term, env)

if not ok then log("Error: " .. err) addWarning("Error: " .. err) end

if syscalls.computer_dangerouslyLowRAM() then process.exit() end

while true do
	if process.status(term) == "dead" then
		return
	end
	coroutine.yield()
end
