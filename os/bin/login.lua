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
gpucount = nil

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

local function credentialsMatch(name, password)
	local user = users[name]
	if not user then return false, 3 end
	local passhash = syscalls.data_encode64(syscalls.data_sha256(password))
	return user.passhash == passhash, user.ring
end

local function plogin(proc, user, guess)
	if not users[user] then return false, "Bad user" end
	local ok, ring = credentialsMatch(user, guess)
	if ok then
		proc.ring = ring
		return true, ring
	else
		return false, "Bad credentials"
	end
end

local function phasuser(proc, user)
	return users[user] ~= nil
end

local function puser(proc)
	proc.ring = 3 -- Bring back to userland
end

table.insert(Kernel.AllDrivers, function(proc)
	proc:defineSyscall("plogin", plogin)
	proc:defineSyscall("puser", puser)
end)

-- TODO: Parse users

do
	local usertabfile = io.open("os/etc/usertab", "r")
	if not usertabfile then error("No user tables! What now?") end -- TODO: make empty usertab

	local usertab = usertabfile:read("a")
	usertabfile:close()

	local lines = string.split(usertab,"\n")
	local buf = {}
	local segments = {}
	for i = 1,#lines do
		local line = lines[i]

		local k = 1
		while k <= #line do
			local char = line:sub(k,k)

			if char == '"' then
				k = k + 1
				local strstart = k
				while line:sub(k,k) ~= '"' and line:sub(k,k) ~= "" do
					k = k + 1
				end

				buf[#buf+1] = line:sub(strstart,k-1) -- k-1 because we're on the "
			elseif char == " " then
				segments[#segments+1] = table.concat(buf)
				table.clear(buf)
			else
				local start = k
				while line:sub(k,k) ~= '"' and line:sub(k,k) ~= " " do
					k = k + 1
				end

				k = k - 1 -- DO NOT skip the character after the bit of shit
				buf[#buf+1] = line:sub(start,k)
			end

			k = k + 1
		end

		if #buf > 0 then segments[#segments+1] = table.concat(buf) table.clear(buf) end

		if #segments < 3 then
			log(tostring(segments[1]) .. " " .. tostring(segments[2]) .. " " .. tostring(segments[3]))
			error("Invalid user in usertab! What now?") -- TODO: make it not die completely
		end

		local name = segments[1]
		local password = segments[2]
		local ring = tonumber(segments[3])

		if not ring then error("Ring is not a number for user " .. name .. "! What now?") end -- maybe default to 3?

		users[name] = {passhash = password, ring = ring}

		log("Loaded user " .. name)

		table.clear(segments)
	end
end

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
