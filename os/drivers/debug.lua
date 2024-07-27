-- Debugging drivers. Provides the log function.

local ocelot

for c in component.list("ocelot") do
	ocelot = c
	break
end

if ocelot then
	local proxy = component.proxy(ocelot)
	function log(...)
		proxy.log(table.concat({...}, ' '))
	end
end

return function() end
