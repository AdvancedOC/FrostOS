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
local bterm = Process.spawn("bterm", "/", nil, nil, nil, {}, 2)

local file = gio.open("/os/bin/bterm.lua")

if not file then error("idc") end

local success, err = bterm:exec(file)
gio.close(file)

if not success then
  error(err)
end

while true do
  coroutine.yield()
end
