-- Debugging drivers. Provides the log function.

local ocelot

for c in component.list("ocelot") do
	ocelot = c
	break
end
local proxy = component.proxy(ocelot)

if ocelot then
	function log(...)
		proxy.log(table.concat({...}, ' '))
	end
end

return function() end
