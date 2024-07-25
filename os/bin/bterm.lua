-- this'll be a terminal at some point... i think

local syscalls = require("syscalls")

local version = "beta 0.0.1"

local screens = syscalls.graphics_getScreens()

local gpucount = syscalls.graphics_gpuCount()

local truecount = math.min(#screens,gpucount) -- if you have more screens than gpus you can't, and you also don't need multiple gpus on a single screen

for i = 1,truecount do
    syscalls.graphics_bind(screens[i],i) -- bind gpus to screens

    syscalls.graphics_setResolution(60,20,i) -- if any of them don't support this i'll cry
end

local h = 20
local w = 60

local empt = " " -- only allocating one constant space string because maybe that'll do something

-- because we are linux 2 we put the same terminal on every screen
for i = 1,truecount do
    local w,h = syscalls.graphics_getResolution(i)
    syscalls.graphics_setBackground(0x000000,i)
    syscalls.graphics_setForeground(0xFFFFFF,i)
    syscalls.graphics_fill(1,1,w,h,empt,i)
end

-- stdout/stdin partially written by Atomical because Blendi partially gave up
local cx, cy = 1, 1
local inputBuffer = "" -- TODO: handle input
local function writeChar(char)
    if cx > w then
        cx = 1
        cy = cy + 1
    end
    if cy > h then
        local off = cy - h
        for i = 1, truecount do
            syscalls.graphics_copy(1, 1+off,w,h-off,0,-off,i)
            syscalls.graphics_fill(1, h, w, 1, ' ')
        end
        cy = h
        cx = 1
    end

    -- TODO: somehow handle the nighmareish state machine
    -- That will be terminal escape codes

    if char == "\n" then
        cy = cy + 1
        cx = 1
    elseif char == "\t" then
        cx = cx + 4
    else
        if not syscalls.keyboard_isControlCharacter(char) then
            for i = 1, truecount do
                syscalls.graphics_set(cx, cy, char)
            end
        end
        cx = cx + 1
    end
end

local function writeOutput(memory)
    for i=1,#memory do
        writeChar(memory:sub(i, i))
    end
end

local function readLine()
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
            writeOutput(inputBuffer)
            return
        end
        for i=1,truecount do
            syscalls.graphics_set(cx, cy, inputBuffer, i)
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

io.stdout = io.stream(writeOutput, function() return nil end, "w")
io.stdout.buflimit = 0

io.stdin = io.stream(function() return end, readInput, "r")

print("Welcome to BTerm version " .. version)
print(tostring(syscalls.computer_totalMemory()/1024/1024) .. "MiB of RAM installed")

local process = require("process")

local shell = "/os/bin/scute.lua"

local shellProc = process.spawn("Shell " .. shell, {
    [0] = io.stdout.fd,
    [1] = io.stdin.fd,
    [2] = io.stdout.fd, -- (TODO:) stderr
}, nil, "/home")

local ok, err = process.exec(shellProc, shell)
if not ok then error(err) end

while true do
    if process.status(shellProc) == "dead" then
        print("Shell died")
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

-- while true do
--     -- io.write(io.stdout, "> ")
--     -- local line = io.read(io.stdin, "l")
--     -- print(line)

--     coroutine.yield()
-- end
