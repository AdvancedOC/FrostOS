-- Kernel Events. SUPER complex.
Events = {}
Events.queues = {}

function Events.process(timeout)
    local rawdata = {computer.pullSignal()}
    local name = rawdata[1]
    table.remove(rawdata, 1)

    Events.queues[name] = Events.queues[name] or {}
    table.insert(Events.queues[name], rawdata)
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