-- Kernel Events. SUPER complex.
Events = {}
Events.queues = {} --kwiwis
Events.callbacks = {}

function Events.process(timeout)
	local rawdata = { computer.pullSignal(timeout) }
	if #rawdata == 0 then
		return -- No signal, cuz we timed out
	end
	local name = rawdata[1]
	table.remove(rawdata, 1)

	Events.queues[name] = Events.queues[name] or {}
	table.insert(Events.queues[name], rawdata)
	while #Events.queues[name] > 20 do
		table.remove(Events.queues[name], 1)
	end

	local callbacks = Events.callbacks[name]
	if not callbacks then
		return
	end
	for i=1,#callbacks do
		callbacks[i](table.unpack(rawdata))
	end
end

function Events.addCallback(name, callback)
	Events.callbacks[name] = Events.callbacks[name] or {}
	table.insert(Events.callbacks[name], callback)
end

function Events.inQueue(name)
	if not Events.queues[name] then return false end
	return #Events.queues[name] > 0
end

function Events.pull(name, timeout)
	Events.queues[name] = Events.queues[name] or {}

	while true do
		local queue = Events.queues[name]
		if #queue == 0 then
			Events.process(timeout)
		else
			local eventData = queue[1]
			table.remove(queue, 1)
			return table.unpack(eventData)
		end
	end
end

function Events.raise(name, ...)
	computer.pushSignal(name, ...)
end
