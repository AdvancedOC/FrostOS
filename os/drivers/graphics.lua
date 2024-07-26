local defaultGPU

-- TODO: implement custom buffer and/or use the VRAM buffer from the GPU (but it's not in skyfac :sob:)
-- TODO: figure out a smart way to detect when to use or not to use the buffer

local cl,ci = component.list,component.invoke

local screens = {}

for addr,type in cl("screen") do
    table.insert(screens, addr)
end

if #screens < 1 then error("No screens found") end

local gpus = {}

for addr,type in cl("gpu") do
    table.insert(gpus, addr)
end

if #gpus < 1 then error("No GPUs found") end

defaultGPU = 1
-- local supportsVRAMBuffer = false -- we don't assume it does, because a lot of modpacks run slightly outdated versions of OpenComputers
-- do
--     local shitproxy = component.proxy(gpus[defaultGPU]) -- we need a proxy to be able to check if a function exists

--     if shitproxy.buffers then
--         supportsVRAMBuffer = true
--     end
-- end

local gpuResolutions = {}

-- everything is a local function because ram usage is important in OpenComputers

local function graphics_gpuCount()
    return #gpus
end
local function graphics_setDefaultGPU(proc, gpuID)
    defaultGPU = gpuID
end
local function graphics_getScreens()
    return table.copy(screens)
end

local function graphics_getGPUID(proc, uuid)
	for i = 1,#gpus do
		if gpus[i] == uuid then return i end
	end
end

local function graphics_bind(proc, screenAddr, gpuID)
    gpuID = gpuID or defaultGPU

    gpuResolutions[gpuID] = nil -- can't trust old cache

    return ci(gpus[gpuID],"bind",screenAddr)
end
local function graphics_getScreen(proc, gpuID)
    gpuID = gpuID or defaultGPU
    return ci(gpus[gpuID],"getScreen")
end

local function graphics_getResolution(proc, gpuID)
    gpuID = gpuID or defaultGPU

	if not gpuResolutions[gpuID] then
		gpuResolutions[gpuID] = {ci(gpus[gpuID],"getResolution")}
	end

    return table.unpack(gpuResolutions[gpuID])
end
local function graphics_maxResolution(proc, gpuID)
    gpuID = gpuID or defaultGPU
    return ci(gpus[gpuID],"maxResolution")
end
local function graphics_setResolution(proc, w, h, gpuID)
    gpuID = gpuID or defaultGPU

    local succ,err = ci(gpus[gpuID],"setResolution",w,h)

    if succ then
    	gpuResolutions[gpuID] = {w,h}
    end

    return succ,err
end

local function graphics_getBackground(proc, gpuID)
    gpuID = gpuID or defaultGPU
    return ci(gpus[gpuID],"getBackground")
end
local function graphics_setBackground(proc, color, gpuID)
    gpuID = gpuID or defaultGPU
    return ci(gpus[gpuID],"setBackground",color)
end

local function graphics_getForeground(proc, gpuID)
    gpuID = gpuID or defaultGPU
    return ci(gpus[gpuID],"getForeground")
end
local function graphics_setForeground(proc, color, gpuID)
    gpuID = gpuID or defaultGPU
    return ci(gpus[gpuID],"setForeground",color)
end

local function graphics_fill(proc, x, y, w, h, char, gpuID)
    gpuID = gpuID or defaultGPU
    return ci(gpus[gpuID],"fill",x,y,w,h,char)
end
local function graphics_copy(proc, x, y, w, h, tx, ty, gpuID)
    gpuID = gpuID or defaultGPU
    return ci(gpus[gpuID],"copy",x,y,w,h,tx,ty)
end
local function graphics_set(proc, x, y, text, gpuID)
    gpuID = gpuID or defaultGPU
    return ci(gpus[gpuID],"set",x,y,text)
end
local function graphics_get(proc, x, y, gpuID)
    gpuID = gpuID or defaultGPU
    return ci(gpus[gpuID],"get",x,y)
end

---@param process Kernel.Process
return function (process)
    -- custom things

    process:defineSyscall("graphics_getGPUID", graphics_getGPUID)

    process:defineSyscall("graphics_gpuCount", graphics_gpuCount)
    if process.ring < 3 then process:defineSyscall("graphics_setDefaultGPU", graphics_setDefaultGPU) end
    process:defineSyscall("graphics_getScreens", graphics_getScreens)

    -- basically recreations of the functions in the gpu component
    if process.ring < 3 then process:defineSyscall("graphics_bind", graphics_bind) end
    process:defineSyscall("graphics_getScreen", graphics_getScreen)

    process:defineSyscall("graphics_getResolution", graphics_getResolution)
    process:defineSyscall("graphics_maxResolution", graphics_maxResolution)
    process:defineSyscall("graphics_setResolution", graphics_setResolution)

    process:defineSyscall("graphics_getBackground", graphics_getBackground)
    process:defineSyscall("graphics_setBackground", graphics_setBackground)

    process:defineSyscall("graphics_getForeground", graphics_getForeground)
    process:defineSyscall("graphics_setForeground", graphics_setForeground)

    process:defineSyscall("graphics_fill", graphics_fill)
    process:defineSyscall("graphics_copy", graphics_copy)
    process:defineSyscall("graphics_set", graphics_set)
    process:defineSyscall("graphics_get", graphics_get)
end
