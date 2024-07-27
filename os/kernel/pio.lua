local protectedPaths = {}

local function protectedSort(a, b)
  return #a > #b
end

local function protectionApplies(path, info)
  return string.startswith(path, info.path .. "/") or path == info.path
end

local function isModeProblematic(mode, path, ring)
	if string.contains(mode, "w") or string.contains(mode, "a") then
		if gio.isPathReadOnly(path) then return true end
	end
	for _, info in ipairs(	protectedPaths) do
		if protectionApplies(path,	info	) then
			for k, protection in pairs(info.protection) do
				if string.contains(mode, k	) and protection < ring then
					return true
				end
			end
			return false
		end
	end
	return false
end

function addProtectedPath(path, protection)
  table.insert(protectedPaths, {path = path, protection = protection})
  table.sort(protectedPaths, protectedSort)
end

addProtectedPath("/os/bin", {
  r = 3,
  w = 2,
  a = 2,
})

addProtectedPath("/os/lib", {
  r = 3,
  w = 2,
  a = 2,
})

addProtectedPath("/os/etc", {
  r = 1,
  w = 0,
  a = 0,
})

addProtectedPath("/os/drivers", {
  r = 3,
  w = 2,
  a = 2,
})

addProtectedPath("/os", {
	r = 3,
  w = 1,
  a = 1,
})

addProtectedPath("/init.lua", {
	r = 3,
	w = 1,
	a = 1,
})

pio = {}

function pio.canonical(process, path)
	if path == "/" then return "/" end
  if path:sub(1, 1) ~= "/" then
    if process.cwd == "/" then return pio.canonical(process, "/" .. path) end
    return pio.canonical(process, process.cwd .. "/" .. path)
  end

  local parts = string.split(path:sub(2), "/")
  local left = {}

  for i=1,#parts do
    if parts[i] == "." then
      -- Do nothing
    elseif parts[i] == ".." then
      left[#left] = nil
    else
      left[#left+1] = parts[i]
    end
  end

  return "/" .. table.concat(left, "/")
end

function pio.giveFile(process, file)
  local i = 3
  while process.files[i] ~= nil do
    i = i + 1
  end
  process.files[i] = file
  return i
end

function pio.open(process, path, mode)
  path = pio.canonical(process, path)
  mode = mode or "r"
  if isModeProblematic(mode, path, process.ring) then return nil, "Operation not permitted" end
  local file, err = gio.open(path, mode)
  if not file then return nil, err end
  return pio.giveFile(process, file)
end

function pio.close(process, descriptor)
  if not process.files[descriptor] then
    return "Bad file descriptor"
  end
  gio.close(process.files[descriptor])
  process.files[descriptor] = nil
end

function pio.remove(process, path)
    path = pio.canonical(process, path)
    if isModeProblematic("w", path, process.ring) then return "Operation not permitted" end
    return gio.remove(path)
end

function pio.createDir(process, directory)
    directory = pio.canonical(process, directory)
    if isModeProblematic("w", directory, process.ring) then return "Operation not permitted" end
    return gio.mkdir(directory)
end

function pio.listDir(process, directory)
    directory = pio.canonical(process, directory)
    if isModeProblematic("r", directory, process.ring) then return nil, "Operation not permitted" end
    return gio.list(directory)
end

function pio.exists(process, path)
    path = pio.canonical(process, path)
    return gio.exists(path)
end

function pio.seek(process, descriptor, whence, off)
    if not process.files[descriptor] then
      return 0, "Bad file descriptor"
    end
    local file = process.files[descriptor]
    return gio.seek(file, whence, off)
end

function pio.write(process, descriptor, memory)
    if not process.files[descriptor] then
      return "Bad file descriptor"
    end
    return gio.write(process.files[descriptor], memory)
end

function pio.read(process, descriptor, amount)
    if not process.files[descriptor] then
      return nil, "Bad file descriptor"
    end
    return gio.read(process.files[descriptor], amount)
end

function pio.kind(process, path)
    path = pio.canonical(process, path)
    return gio.pathType(path)
end

function pio.size(process, path)
    path = pio.canonical(process, path)
    return gio.size(path)
end

function pio.readonly(process, path)
    path = pio.canonical(process, path)
    return gio.isPathReadOnly(path)
end

function pio.memory(process, buffer, mode)
    return pio.giveFile(process, gio.new(buffer, mode))
end

function pio.stream(process, writer, reader, mode)
    return pio.giveFile(process, gio.newStream(writer, reader, mode))
end

function pio.allowed(process, path, ring, mode)
	mode = mode or "r"
	ring = ring or process.ring
	path = pio.canonical(process, path)
	return not isModeProblematic(mode, path, ring)
end

function pio.islink(process, path)
	path = pio.canonical(process, path)
	return gio.islink(path)
end

function pio.getenv(process, var)
    return process.env[var]
end

function pio.getenvs(process)
    return table.copy(process.env)
end

---@param process Kernel.Process
function pio.spawn(process, name, fileMappings, environment, cwd, ring)
	local spaceNeeded = 16*1024
	if #ProcPool > 0 then
		spaceNeeded = 1024
	end
	if computer.freeMemory() < spaceNeeded then
		AttemptGC(spaceNeeded)
		if computer.freeMemory() < spaceNeeded then
			return nil, "Too many processes"
		end
	end

    name = name or "Unnamed Process"
    cwd = cwd or process.cwd
    ring = ring or process.ring
    environment = environment or table.copy(process.env)
    if ring < process.ring then
        return nil, "Permission denied"
    end
    local files = {
        [0] = process.files[0],
        [1] = process.files[1],
        [2] = process.files[2],
    }

    if fileMappings then
	    for k, v in pairs(fileMappings) do
	        files[k] = process.files[v]
	    end
    end

    local child, err = Process.spawn(process, name, cwd, files[0], files[1], files[2], environment, ring)
    if not child then return nil, err end
    process.children[child.pid] = child
    return child.pid
end

function pio.threadSpawn(process, func)
    return process:spawnThread(func)
end

function pio.threadCurrent(process)
    local current = coroutine.running()
    for id, thread in pairs(process.threads) do
        if thread == current then
            return id
        end
    end

    return nil -- This means you are a zombie.
end

function pio.threadkill(process, thread)
    if not process.threads[thread] then
        return "bad thread id"
    end
    -- there is no way for a thread to exit "gracefully"
    process.thread[thread] = nil
end

function pio.threadRunning(process, thread)
    if not process.threads[thread] then
        return false
    end
    local thread = process.threads[thread]
    local status = coroutine.status(thread)
    return status ~= "dead"
end

---@param process Kernel.Process
function pio.exec(process, child, fd, ...)
    if not allProcs[child] then
        return false, "Bad process ID"
    end
    if not process.children[child] then
        return false, "Permission denied"
    end
    if not process.files[fd] then
        return false, "Bad file descriptor"
    end
    return process.children[child]:exec(process.files[fd], ...)
end

function pio.kill(process, child)
    if not allProcs[child] then
        return "Bad process ID"
    end
    if allProcs[child].ring < process.ring then
        return "Permission denied"
    end
    Process.kill(allProcs[child])
end

function pio.processStatus(process, child)
    if not allProcs[child] then
        return "dead"
    end
    local proc = allProcs[child]
    if proc:isProcessOver() then
        return "dead"
    end
    return "running"
end

function pio.findProcess(process, namePattern)
    for pid, proc in pairs(allProcs) do
        if string.find(proc.name, namePattern) then
            return pid
        end
    end
end

function pio.currentProcess(process)
    return process.pid
end

function pio.processCWD(process)
    return process.cwd
end

function pio.changeDirectory(process, cwd)
	local path = pio.canonical(process, cwd)
	local pt = gio.pathType(path)
	if pt ~= "directory" and pt ~= "mount" then return "Not a directory" end
    process.cwd = path
end

function pio.getParent(process)
    if process.parent then
        return process.parent.pid
    end
end

function pio.getInfo(process, child)
    if not allProcs[child] then
        return nil, "Bad process ID"
    end
    local info = {}
    local proc = allProcs[child]
    info.name = proc.name
    info.pid = proc.pid
    info.cwd = proc.cwd
    info.owned = process.children[child] ~= nil
    info.children = {}
    for pid, _ in pairs(proc.children) do
        table.insert(info.children, pid)
    end
    info.status = pio.processStatus(process, child)
    info.ring = proc.ring
    if process.parent then
        info.parent = process.parent.pid
    end
    return info
end

function pio.getPids(process)
    local pids = {}
    for pid, _ in pairs(allProcs) do
        table.insert(pids, pid)
    end
    return pids
end

function pio.getChildren(process, child)
	if not allProcs[child] then
		return nil, "Bad process ID"
	end
    local pids = {}
    for pid, _ in pairs(allProcs[child].children) do
        table.insert(pids, pid)
    end
    return pids
end

-- Defines the syscalls
function pio.registerFor(process)
  process:defineSyscall("fopen", pio.open)
  process:defineSyscall("fclose", pio.close)
  process:defineSyscall("fseek", pio.seek)
  process:defineSyscall("fexists", pio.exists)
  process:defineSyscall("dirlist", pio.listDir)
  process:defineSyscall("diropen", pio.createDir)
  process:defineSyscall("fexists", pio.exists)
  process:defineSyscall("fremove", pio.remove)
  process:defineSyscall("fwrite", pio.write)
  process:defineSyscall("fread", pio.read)
  process:defineSyscall("fkind", pio.kind)
  process:defineSyscall("fsize", pio.size)
  process:defineSyscall("freadonly", pio.readonly)
  process:defineSyscall("fmemory", pio.memory)
  process:defineSyscall("fstream", pio.stream)
  process:defineSyscall("fallowed", pio.allowed)
  process:defineSyscall("fislink", pio.islink)
  process:defineSyscall("pspawn", pio.spawn)
  process:defineSyscall("pexec", pio.exec)
  process:defineSyscall("pstatus", pio.processStatus)
  process:defineSyscall("pself", pio.currentProcess)
  process:defineSyscall("pwd", pio.processCWD)
  process:defineSyscall("penv", pio.getenv)
  process:defineSyscall("penvs", pio.getenvs)
  process:defineSyscall("pinfo", pio.getInfo)
  process:defineSyscall("pparent", pio.getParent)
  process:defineSyscall("pall", pio.getPids)
  process:defineSyscall("ptree", pio.getChildren)
  process:defineSyscall("pfind", pio.findProcess)
  process:defineSyscall("pcd", pio.changeDirectory)
  process:defineSyscall("pkill", pio.kill)
  process:defineSyscall("tself", pio.threadCurrent)
  process:defineSyscall("tspawn", pio.threadSpawn)
  process:defineSyscall("trunning", pio.threadRunning)
  process:defineSyscall("tkill", pio.threadKill)
end
