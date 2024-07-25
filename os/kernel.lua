AllDrivers = {}

dofile("os/kernel/utils.lua")
dofile("os/kernel/gio.lua")
dofile("os/kernel/pio.lua")
dofile("os/kernel/process.lua")
dofile("os/kernel/events.lua")

for _, driver in ipairs(gio.list("/os/drivers")) do
  table.insert(AllDrivers, gio.dofile("/os/drivers/" .. driver))
end

-- For now, forcefully run bterm
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
    local zombies
    for pid, proc in pairs(allProcs) do
        proc:resumeThreads()
        if proc.parent == Init and proc:isProcessOver() then
            zombies = zombies or {}
            table.insert(zombies, pid)
        end
    end
    if zombies then
        for i=1,#zombies do
        	if allProcs[zombies[i]] then
	            -- And that process was never seen ever again
	            allProcs[zombies[i]]:kill()
         	end
        end
    end
	Events.process(0.01)
end
