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
---@field usyscalls {[string]: function, _proc: Kernel.Process}
---@field threads {[number]: thread}
---@field children {[number]: Kernel.Process}
Process = {}
Process.__index = Process

---@type {[number]: Kernel.Process}
allProcs = {}
ProcPool = {}
local npid = 0

---@param parent? Kernel.Process
---@param name string
---@param cwd string
---@param stdout? Kernel.File
---@param stdin? Kernel.File
---@param stderr? Kernel.File
---@param env? {[string]: string}
---@param ring? number
---@return Kernel.Process?, string?
function Process.spawn(parent, name, cwd, stdout, stdin, stderr, env, ring)
	local pid = npid
	npid = npid + 1
	local process
	if #ProcPool == 0 then
		process = setmetatable({
			parent = parent,
			name = name,
			cwd = cwd,
			ring = ring or 3,
			files = {
				[0] = stdout,
				[1] = stdin,
				[2] = stderr,
			},
			pid = pid,
			syscalls = {},
			usyscalls = {},
			env = env or {},
			namespace = {},
			threads = {},
			children = {},
		}, Process)
		setmetatable(process.syscalls, {
			__index = function(sys, index)
		 		if process.usyscalls[index] then
		   			local sysc = process.usyscalls[index]
		   			sys[index] = function(...)
			  			return sysc(process, ...)
			  		end
				 	return sys[index]
		   		end
		 	end,
		})
	else
		process = ProcPool[#ProcPool]
		ProcPool[#ProcPool] = nil
		process.namespace = {}
		process.parent = parent
		process.name = name
		process.cwd = cwd
		process.ring = ring or 3
		process.pid = pid
		process.files[0] = stdout
		process.files[1] = stdin
		process.files[2] = stderr
		if env then
			local key = next(env)
			while key do process.env[key] = env[key] key = next(env, key) end
		end
		setmetatable(process.syscalls, {
			__index = function(sys, index)
		 		if process.usyscalls[index] then
		   			local sysc = process.usyscalls[index]
		   			sys[index] = function(...)
			  			return sysc(process, ...)
			  		end
				 	return sys[index]
		   		end
		 	end,
		})
	end


	local err = process:initEnvironment()
	if err then return nil, err end

	allProcs[pid] = process

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
	namespace.assert = assert
	namespace.error = error
	namespace.getmetatable = getmetatable
	namespace.ipairs = ipairs
	namespace.load = function(code, name, type, env) return load(code, name, type, env or namespace) end
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
	namespace.log = log

	if self.ring <= 2 then
		namespace.Events = Events -- ONLY privileged commands, shell and/or environment gets this.
	end
	if self.ring <= 1 then
		namespace.Kernel = _G
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

	local ok, err = self:preload("io", "/os/lib/io.lua")
	if not ok then return err end
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
		if self:isProcessOver() then
			-- Don't care, process died, can't be bothered
		 	return
		end
		if not good then
			log(tostring(err) .. "\n" .. debug.traceback(thread))
			if self.ring == 0 then
	 		error(tostring(err) .. "\n" .. debug.traceback(thread))
		 	end
			if self.files[2] then gio.write(self.files[2], tostring(err) .. "\n" .. debug.traceback(thread) .. "\n") end
		 	--error(tostring(err) .. debug.traceback(thread))
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
	self.usyscalls[name] = callback
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

	load(code, "=" .. name, "bt", self.namespace)()

	self.namespace.package.loaded[name] = self.namespace[name]
end

---@param proc number|Kernel.Process
function Process.kill(proc)
	if type(proc) == "number" then
		return Process.kill(allProcs[proc])
	end

	if not allProcs[proc.pid] then
		return -- Somehow, the process is already dead
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
		local nchild = next(proc.children, pid)
		local child = proc.children[pid]
		if child:isProcessOver() then
			child:kill() -- Just forget about it
		else
			Init.children[pid] = child
			child.parent = Init
		end
		pid = nchild
	end

	-- Remove the proc
	if proc.parent then
		proc.parent.children[proc.pid] = nil
	end
	allProcs[proc.pid] = nil
	table.clear(proc.files)
	table.clear(proc.threads)
	table.clear(proc.children)
	table.clear(proc.env)
	table.clear(proc.syscalls)
	table.clear(proc.usyscalls)
	if #ProcPool < 50 or not MemoryConservative then table.insert(ProcPool, proc) end
end
