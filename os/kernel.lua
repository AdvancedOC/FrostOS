AllDrivers = {}
MemoryConservative = computer.totalMemory() < 512*1024

function log(...)

end

dofile("os/kernel/utils.lua")
dofile("os/kernel/gio.lua")
dofile("os/kernel/pio.lua")
dofile("os/kernel/process.lua")
dofile("os/kernel/events.lua")
dofile("os/kernel/scheduler.lua")

for _, driver in ipairs(gio.list("/os/drivers")) do
	if string.endswith(driver, ".lua") then
  		table.insert(AllDrivers, gio.dofile("/os/drivers/" .. driver))
	end
end

log("Memory Conservative:", tostring(MemoryConservative))

-- Init is PID 0, (guaranteed). It has no parent
Init = Process.spawn(nil, "krnl", "/", nil, nil, nil, {}, 0)

-- For now, forcefully run login
local login = Process.spawn(Init, "login", "/", nil, nil, nil, {}, 1)
Init.children[login.pid] = login

local file, err = gio.open("/os/bin/login.lua")

if not file then error(err) end

local success, err = login:exec(file)
gio.close(file)

if not success then
  error(err)
end

while true do
    local pid = next(allProcs)
    while pid do
    	local proc = allProcs[pid]
     	if proc then
	     	local npid = next(allProcs, pid)
	        proc:resumeThreads()
	        if proc.parent == Init and proc:isProcessOver() then
	        	proc:kill()
	        end
	        pid = npid
        else
        	break -- Oh no
      	end
    end
    --AttemptGC(8*1024,10)
	Events.process(0.01)
end
