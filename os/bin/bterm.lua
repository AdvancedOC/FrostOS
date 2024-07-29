local syscalls = require("syscalls")

local version = "beta 0.0.1"

local screens = syscalls.graphics_getScreens()

local gpucount = syscalls.graphics_gpuCount()

local w = math.huge
local h = math.huge

local truecount = math.min(#screens,gpucount) -- if you have more screens than gpus you can't, and you also don't need multiple gpus on a single screen

for i = 1,truecount do
	syscalls.graphics_bind(screens[i],i) -- bind gpus to screens
end

for i=1,gpucount do
	local sw, sh = syscalls.graphics_maxResolution(i)
	w = math.min(w, sw)
	h = math.min(h, sh)
end

screens = nil
gpucount = nil

for i = 1,truecount do
	syscalls.graphics_setResolution(w,h,i) -- if any of them don't support this i'll cry
end


local empt = " " -- only allocating one constant space string because maybe that'll do something

local function clearScreens()
	for i = 1,truecount do
		syscalls.graphics_setBackground(0x000000,i)
		syscalls.graphics_setForeground(0xFFFFFF,i)
		syscalls.graphics_fill(1,1,w,h,empt,i)
	end
end

-- because we are linux 2 we put the same terminal on every screen
clearScreens()

-- stdout/stdin partially written by Atomical because Blendi partially gave up
local cx, cy = 1, 1

local function moveToFixScreen()
	if cx > w then
		cx = 1
		cy = cy + 1
	end
	if cy > h then
		local off = cy - h
		for i = 1, truecount do
			syscalls.graphics_copy(1, 1+off,w,h-off,0,-off,i)
			syscalls.graphics_fill(1, h-off+1, w, off, ' ')
		end
		cy = h
		cx = 1
	end
	if cy <= 0 then
		cy = 1
	end
	if cx <= 0 then
		cx = 1
	end
end

local inEscape = false
local escapeBuffer = ""
local escapeRet
local inputChar

local function doEscape()
	if escapeBuffer:sub(1, 2) == "MR" then
		local parts = string.split(escapeBuffer:sub(3), ';')
		local ox = tonumber(parts[1])
		local oy = tonumber(parts[2])
		if ox == nil or oy == nil then return end -- Bad escape
		cx = cx + ox
		cy = cy + oy
		moveToFixScreen()
		return
	end
	if escapeBuffer:sub(1, 1) == "M" then
		local parts = string.split(escapeBuffer:sub(2), ";")

		local x,y = tonumber(parts[1]),tonumber(parts[2])

		if not x or not y then return end

		x = math.min(math.max(x,1),w)
		y = math.min(math.max(y,1),h)

		cx = x
		cy = y
		return
	end
	if escapeBuffer == "C" then
		cx = 1
		cy = 1
		clearScreens()
		return
	end
	if escapeBuffer:sub(1, 1) == "C" then
		local y = tonumber(escapeBuffer:sub(2))
		if y == nil then return end -- bad escape
		y = math.min(math.max(y,1),h)
		for i=1,truecount do
			syscalls.graphics_setBackground(0x000000,i)
			syscalls.graphics_setForeground(0xFFFFFF,i)
			syscalls.graphics_fill(1, y, w, 1, ' ', i)
		end
		return
	end
	if escapeBuffer == "FR" then
		for i=1,truecount do
			syscalls.graphics_setForeground(0xFFFFFF, i)
		end
		return
	end
	if escapeBuffer == "BR" then
		for i=1,truecount do
			syscalls.graphics_setBackground(0x000000, i)
		end
		return
	end
	if escapeBuffer:sub(1, 1) == "F" then
		local color = escapeBuffer:sub(2)
		local channels = string.split(color, ';')
		local red, green, blue = table.unpack(channels)
		red, green, blue = tonumber(red), tonumber(green), tonumber(blue)
		if not red or not green or not blue then return end -- Bad escape
		local colorCode = red * 256 * 256 + green * 256 + blue
		for i=1,truecount do
			syscalls.graphics_setForeground(colorCode, i)
		end
		return
	end
	if escapeBuffer:sub(1, 1) == "B" then
		local color = escapeBuffer:sub(2)
		local channels = string.split(color, ';')
		local red, green, blue = table.unpack(channels)
		red, green, blue = tonumber(red), tonumber(green), tonumber(blue)
		if not red or not green or not blue then return end -- Bad escape
		local colorCode = red * 256 * 256 + green * 256 + blue
		for i=1,truecount do
			syscalls.graphics_setBackground(colorCode, i)
		end
		return
	end
	if escapeBuffer == "P" then
		inputChar = nil
		return
	end
	if escapeBuffer:sub(1, 1) == "P" then
		inputChar = escapeBuffer:sub(2)
		return
	end
	if escapeBuffer == "W" then
		escapeRet = tostring(w)
		return
	end
	if escapeBuffer == "H" then
		escapeRet = tostring(h)
		return
	end
	if escapeBuffer:sub(1, 1) == "G" then
		local parts = string.split(escapeBuffer:sub(2), ";")

		local x,y = tonumber(parts[1]),tonumber(parts[2])

		if not x or not y then return end

		if x < 1 or y < 1 or x > w or y > h then escapeRet = " " return end

		escapeRet = (syscalls.graphics_get(x, y, 1))
		return
	end
	if escapeBuffer:sub(1, 1) == "S" then
		local parts = string.split(escapeBuffer:sub(2), ";")

		local x,y = tonumber(parts[1]),tonumber(parts[2])

		if not x or not y then return end

		local sx,sy = 1,1
		local wid,hei = w,h

		if x >= 0 then
			wid = wid - x
		else
			sx = sx - x
			wid = wid + x
		end

		if y >= 0 then
			hei = hei - y
		else
			sy = sy - y
			hei = hei + y
		end

		syscalls.graphics_copy(sx,sy,wid,hei,x,y)

		return
	end
end

local inputBuffer = ""
local function writeChar(char)
	moveToFixScreen()

	-- For evil hack
	if char == "" then return end

	if inEscape then
		if char == "\x1B" then
			inEscape = false
			doEscape()
			escapeBuffer = ""
		else
			escapeBuffer = escapeBuffer .. char
		end

	 	return
	end

	if char == "\n" then
		cy = cy + 1
		cx = 1
	elseif char == "\t" then
		cx = cx + 4
	elseif char == "\r" then
		cx = 1
	elseif char == "\x1B" then
		inEscape = true
	else
		if not syscalls.keyboard_isControlCharacter(char) then
			for i = 1, truecount do
				syscalls.graphics_set(cx, cy, char)
			end
		end
		cx = cx + 1
	end
end

function writeOutput(memory)
	for i=1,#memory do
		writeChar(memory:sub(i, i))
	end
end

local function bufToRender()
	if not inputChar then return inputBuffer end
	local b = ""
	for i=1,#inputBuffer do
		if inputBuffer:sub(i, i) == "\n" then
			b = b .. "\n"
		else
			b = b .. inputChar
		end
	end
	return b
end

local function readLine()
	moveToFixScreen()
	while true do
		if syscalls.keyboard_isKeyPressed("back") then
			inputBuffer = inputBuffer:sub(1, -2)
			for i=1,truecount do
				syscalls.graphics_set(cx + #inputBuffer, cy, empt, i)
			end
		elseif syscalls.keyboard_isKeyPressed("delete") then
			for i=1,truecount do
				syscalls.graphics_set(cx, cy, string.rep(empt, #inputBuffer), i)
			end
			inputBuffer = ""
		elseif syscalls.keyboard_isKeyPressed("enter") then
			inputBuffer = inputBuffer .. '\n'
		else
			inputBuffer = inputBuffer .. syscalls.keyboard_getText()
		end

		if string.contains(inputBuffer, '\n') then
			writeOutput(bufToRender())
			return
		end
		for i=1,truecount do
			syscalls.graphics_set(cx, cy, bufToRender(), i)
		end
		coroutine.yield()
	end
end

local function readInput(amount)
	if inputBuffer == nil then
		-- Somehow, stdin closed.
		return nil
	end
	if inputBuffer == "" then
		readLine()
	end

	local chunk = inputBuffer:sub(1, amount)
	inputBuffer = inputBuffer:sub(amount+1)
	return chunk
end
io.stdout = io.stream(writeOutput, function()
	local res = escapeRet
	escapeRet = nil
	return res
end, "rw")
io.stdout.buflimit = 0

io.stdin = io.stream(function() return end, readInput, "r")

print("Welcome to BTerm version " .. version)
-- print(tostring(syscalls.computer_totalMemory()/1024/1024) .. "MiB of RAM installed

-- local function attemptToForceCollect()
-- 	for i = 1,20 do
-- 		local deadline = syscalls.computer_uptime() + 0.001
-- 		repeat coroutine.yield() until syscalls.computer_uptime() >= deadline
-- 	end
-- end

local process = require("process")

local function awaitRam()
	repeat
		Events.process(0.01)
		coroutine.yield()
	until syscalls.computer_freeMemory() > 20*1024
end

-- syscalls.computer_gc(8*1024,20)
awaitRam()

local env = process.getenvs()

env.AUTH = tonumber(env.AUTH) or 3 -- being careful

if env.AUTH == 0 then
	print("Be careful! You're running at ring 0, which means you have the permissions to do anything.")
end

local shell = "/usr/bin/sh.lua" -- symlink to the actual shell, usually scute

local shellProc = process.spawn("Shell " .. shell, {
	[0] = io.stdout.fd,
	[1] = io.stdin.fd,
	[2] = io.stdout.fd, -- (TODO:) stderr
}, nil, "/home", math.min(env.AUTH,2))

local ok, err = process.exec(shellProc, shell, {[0] = shell, "-r", tostring(env.AUTH)})
if not ok then print("Error: " .. err) end

while true do
	if process.status(shellProc) == "dead" then
		print("Shell died! Restarting...")
		awaitRam()
		shellProc = process.spawn("Shell " .. shell, {
			[0] = io.stdout.fd,
			[1] = io.stdin.fd,
			[2] = io.stdout.fd, -- (TODO:) stderr
		}, nil, "/home")
		local ok, err = process.exec(shellProc, shell)
		if not ok then
			print("Error: " .. err)
		end
	end

	if Events.inQueue("screen_resized") then
		local _ = Events.pull("screen_resized",0.01)

		local minw,minh = math.huge,math.huge

		for i = 1,truecount do
			local ww,hh = syscalls.graphics_getResolution(i)

			minw = math.min(minw,ww)
			minh = math.min(minh,hh)
		end

		w = minw
		h = minh
	end

	coroutine.yield()
end
