---@class Kernel.Process
---@param name number
---@field pid number
---@field ring number
---@field cwd string
---@field files {[number]: Kernel.File}
---@field env {[string]: string}
---@field namespace table
---@field syscalls {[string]: function}
Process = {}
Process.__index = Process

---@type {[number]: Kernel.Process}
local allProcs = {}
local npid = 0

---@param name string
---@param cwd string
---@param stdout? Kernel.File
---@param stdin? Kernel.File
---@param stderr? Kernel.File
---@param env? {[string]: string}
---@param ring? number
---@return Kernel.Process
function Process.spawn(name, cwd, stdout, stdin, stderr, env, ring)
    local pid = npid
    npid = npid + 1
    local process = setmetatable({
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

    function namespace.require(...)
        local path = ...
        if namespace.package.loaded[path] then
            return namespace.package.loaded[path]
        end

        if namespace.package.preload[path] then
            local res = namespace.package.preload[path](...)
            if res == nil then res = true end
            namespace.package.loaded[path] = res
            return res
        end
    end

    -- Important OS stuff
    pio.registerFor(self)

    self:preload("io", "/os/lib/io.lua")
end

---@param file Kernel.File
---@return boolean, any
function Process:exec(file, ...)
    local code = gio.read(file)
    return pcall(load(code, self.name, "bt", self.namespace), ...)
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

    -- Do NOT close stdout, stdin, stderr. Those are managed by the spawner.
    -- But close all other files the app forgot about
    for _, file in pairs(proc.files) do
        gio.close(file)
    end

    -- Remove the proc
    allProcs[proc.pid] = nil
end

-- Init is PID 0, (guaranteed)
Init = Process.spawn("krnl", "/", nil, nil, nil, {}, 0)
