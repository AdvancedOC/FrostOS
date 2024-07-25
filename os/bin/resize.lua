local args = ...
local syscalls = require("syscalls")

local width = tonumber(args[1])
local height = width == nil and nil or tonumber(args[2])

local resizeAll = true
local i = 1
while args[i] do
    if args[i] == "-d" or args[i] == "--device" then
        resizeAll = false
        local d = tonumber(args[i+1])
        if not d then
            print("Error: Invalid device ID " .. args[i+1])
            return
        end
        local mw, mh = syscalls.graphics_maxResolution(d)
        syscalls.graphics_setResolution(width or mw, height or mh, d)
        i = i + 1
    end
end

if resizeAll then
    local gpuCount = syscalls.graphics_gpuCount()
    for i=1,gpuCount do
        local mw, mh = syscalls.graphics_maxResolution(i)
        syscalls.graphics_setResolution(width or mw, height or mh, i)
    end
end
