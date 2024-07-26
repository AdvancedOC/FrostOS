local syscalls = require("syscalls")

thread = {}

function thread.spawn(func)
	return syscalls.tspawn(func)
end

function thread.kill(threadID)
	return syscalls.tkill(threadID or thread.current())
end

waitGroup = {}
waitGroup.__index = waitGroup

function thread.waitGroup(n)
    n = n or 0

    return setmetatable({n = n}, waitGroup)
end

function waitGroup:add(n)
   n = n or 1
   self.n = self.n + n
end

function waitGroup:done(n)
   n = n or 1
   self.n = self.n - n
end

function waitGroup:wait()
    while self.n > 0 do
        coroutine.yield()
    end
end

-- Mostly useless
mutex = {}
mutex.__index = mutex

---@param kind? "plain"|"recursive"
function thread.mutex(kind, value)
    kind = kind or "plain"
    return setmetatable({
        locked = false,
        kind = kind,
        value = value,
    }, mutex)
end

function mutex:tryLock()
    if self.kind == "recursive" then
        if self.thread ~= thread.current() and self.thread then
            return false -- Failed to lock
        end
        if self.thread == thread.current() then
            self.count = self.count + 1
            return true
        end
        self.thread = thread.current()
        self.count = 1
        return true
    end
    local wasLocked = self.locked
    self.locked = true
    return not wasLocked
end

function mutex:lock()
    while not self:tryLock() do
        coroutine.yield()
    end
end

function mutex:unlock()
    if mutex.kind == "recursive" then
        mutex.count = mutex.count - 1
        if mutex.count == 0 then
            mutex.thread = nil
        end
        return
    end
    mutex.locked = false
end

function thread.current()
	return syscalls.tself()
end

function thread.isRunning(threadID)
	return syscalls.trunning(threadID or thread.current())
end

function thread.join(...)
    local threadIDs = {...}
    for _, threadID in ipairs(threadIDs) do
        while thread.isRunning(threadID) do coroutine.yield() end
    end
end

return thread
