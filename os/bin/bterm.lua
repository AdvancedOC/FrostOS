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

-- because we are linux 2 we put the same terminal on every screen
for i = 1,truecount do
    local w,h = syscalls.graphics_getResolution(i)
    syscalls.graphics_setBackground(0x000000,i)
    syscalls.graphics_setForeground(0xFFFFFF,i)
    syscalls.graphics_fill(1,1,w,h," ",i)
end

local lines = {}

local function addLine(line)
    if #lines >= h then
        table.remove(lines,1)

        for i = 1,truecount do
            syscalls.graphics_copy(1,2,w,h-1,0,-1,i) -- this is way faster than redrawing all the lines, and the gpu is slow in OC

            syscalls.graphics_set(1,h,line,i)
        end

        table.insert(lines,line)

        return
    end

    for i = 1,truecount do
        syscalls.graphics_set(1,#lines+1,line,i)
    end

    table.insert(lines,line)
end

addLine("Welcome to BTerm version " .. version)

while true do
    -- addLine("ho")
    coroutine.yield()
end
