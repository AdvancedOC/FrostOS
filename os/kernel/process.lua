---@class Kernel.Process
---@field parent? Kernel.Process
---@field name number
---@field pid number
---@field ring number
---@field cwd string
---@field files {[number]: Kernel.File}
---@field env {[string]: string}
---@field namespace table
---@field syscalls {[string]: function}
---@field threads {[number]: thread}
---@field children {[number]: Kernel.Process}
Process = {}
Process.__index = Process

---@type {[number]: Kernel.Process}
allProcs = {}
local npid = 0

---@param parent? Kernel.Process
---@param name string
---@param cwd string
---@param stdout? Kernel.File
---@param stdin? Kernel.File
---@param stderr? Kernel.File
---@param env? {[string]: string}
---@param ring? number
---@return Kernel.Process
function Process.spawn(parent, name, cwd, stdout, stdin, stderr, env, ring)
    local pid = npid
    npid = npid + 1
    local process = setmetatable({
        parent = parent,
        name = name,
        cwd = cwd,
        ring = ring or 3,
        files = {
            [0] = stdout or gio.new("", "a"),
            [1] = stdin or gio.new("", "r"),
            [2] = stderr or gio.new("", "a"),
        },
        pid = pid,
        syscalls = {},
        env = env or {},
        namespace = {},
        threads = {},
        children = {},
    }, Process)

    allProcs[pid] = process

    process:initEnvironment()

    return process
end

function Process:initEnvironment()
    local namespace = self.namespace

    local loadpath = {
        "?.lua",
        "?/init.lua",
        "/usr/lib/?.lua",
        "/usr/lib/?/init.lua",
        "/os/lib/?.lua",
        "/os/lib/?/init.lua",
        "/usr/bin/?.lua",
        "/usr/bin/?/init.lua",
        "/os/bin/?.lua",
        "/os/bin/?/init.lua",
    }

    -- Minimal Lua library we can provide
    namespace.package = {
        config = '/\n;\n?\n!\n~',
        preload = {},
        ---@type table
        loaded = {
            syscalls = self.syscalls,
        },
        path = table.concat(loadpath, ';'),
    }

    namespace.assert = assert
    namespace.error = error
    namespace.getmetatable = getmetatable
    namespace.ipairs = ipairs
    namespace.load = load
    namespace.next = next
    namespace.pairs = pairs
    namespace.pcall = pcall
    namespace.rawequal = rawequal
    namespace.rawget = rawget
    namespace.rawlen = rawlen
    namespace.rawset = rawset
    namespace.select = select
    namespace.setmetatable = setmetatable
    namespace.tonumber = tonumber
    namespace.tostring = tostring
    namespace.type = type
    namespace.xpcall = xpcall
    namespace.checkArg = checkArg

    if self.ring <= 2 then
    	namespace.Events = Events -- ONLY privliged commands, shell and/or environment gets this.
    end

    if coroutine then namespace.coroutine = table.copy(coroutine) end
    if math then namespace.math = table.copy(math) end
    if table then namespace.table = table.copy(table) end
    if bit32 then namespace.bit32 = table.copy(bit32) end
    if string then namespace.string = table.copy(string) end
    if unicode then namespace.unicode = table.copy(unicode) end
    if utf8 then namespace.utf8 = table.copy(utf8) end

    if os then namespace.os = table.copy(os) end

    namespace._G = namespace

    namespace._VERSION = computer.getArchitecture()

    -- Important OS stuff
    pio.registerFor(self)

    for _, init in ipairs(AllDrivers) do
        init(self)
    end

    self:preload("io", "/os/lib/io.lua")
end

---@param file Kernel.File
---@return boolean, any
function Process:exec(file, ...)
    local code, err = gio.read(file)
    if code == nil then return false, err end
    local predicted = self:predictThreadID()
    local func, err = load(code, "=" .. self.name .. " thread" .. predicted, "bt", self.namespace)
    if func == nil then return false, err end
    if select("#", ...) == 0 then
        return true, self:spawnThread(func)
    end
    local payload = {...}
    return true, self:spawnThread(function() func(table.unpack(payload)) end)
end

function Process:predictThreadID()
    local threadID = 1
    while self.threads[threadID] ~= nil do
        threadID = threadID + 1
    end
    return threadID
end

function Process:spawnThread(func)
    local threadID = self:predictThreadID()
    self.threads[threadID] = coroutine.create(func)
    return threadID
end

---@return thread?
function Process:getRawThread(id)
    return self.threads[id]
end

function Process:resumeThreads()
    local cleanup
    for id, thread in pairs(self.threads) do
        local good, err = coroutine.resume(thread)
        if not good then
        	gio.write(self.files[2], err .. "\n" .. debug.traceback(thread) .. "\n")
         	self:kill()
         	break
        end
        if coroutine.status(thread) == "dead" then
            -- Mark for cleanup
            cleanup = cleanup or {}
            table.insert(cleanup, id)
        end
    end
    if cleanup then
        for i=1,#cleanup do
            self.threads[cleanup[i]] = nil
        end
    end
end

-- A process is "over" if all threads are done (except for Init).
-- Init will kill all threads that are over for it.
function Process:isProcessOver()
    return not next(self.threads)
end

function Process:defineSyscall(name, callback)
    self.syscalls[name] = function(...)
        return callback(self, ...)
    end
end

---@param name string
---@param file Kernel.File|string
-- Returns error
---@return string?
function Process:preload(name, file)
    if type(file) == "string" then
        local f, err = gio.open(file, "r")
        if not f then return err end
        err = self:preload(name, f)
        gio.close(f)
        if err ~= nil then return err end
        return
    end
    local code, err = gio.read(file)
    if not code then return err end

    load(code, name, "bt", self.namespace)()

    self.namespace.package.loaded[name] = self.namespace[name]
end

---@param proc number|Kernel.Process
function Process.kill(proc)
    if type(proc) == "number" then
        return Process.kill(allProcs[proc])
    end

    -- Designed to not allocate, to attempt to recover from a forkbomb

    -- Do NOT close stdout, stdin, stderr. Those are managed by the spawner.
    -- But close all other files the app forgot about
    local nextFD = next(proc.files)
    while nextFD do
    	gio.close(proc.files[nextFD])
    	nextFD = next(proc.files, nextFD)
    end

    -- If we have child processes, we need to kill them. If they are not done, well, we move them to Init and make it Init's problem.
    local pid = next(proc.children)
    while pid do
    	local child = proc.children[pid]
        if child:isProcessOver() then
            child:kill() -- Just forget about it
        else
            Init.children[pid] = child
            child.parent = Init
        end
        pid = next(proc.children, pid)
    end

    -- Remove the proc
    if proc.parent then
        proc.parent.children[proc.pid] = nil
    end
    allProcs[proc.pid] = nil
end

-- Init is PID 0, (guaranteed). It has no parent
Init = Process.spawn(nil, "krnl", "/", nil, nil, nil, {}, 0)
