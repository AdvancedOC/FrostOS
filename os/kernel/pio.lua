local protectedPaths = {}

local function protectedSort(a, b)
  return #a > #b
end

local function protectionApplies(path, info)
  return string.startswith(path, info.path .. "/") or path == info.path
end

local function isModeProblematic(mode, path, ring)
  for _, info in ipairs(protectedPaths) do
    for k, protection in pairs(info) do
      if string.contains(mode, k) and protection < ring then
        return true
      end
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

addProtectedPath("/os/drivers", {
  r = 3,
  w = 2,
  a = 2,
})

addProtectedPath("/os", {
  r = 1,
  w = 0,
  a = 0,
})

pio = {}

function pio.canonical(process, path)
  if path:sub(1, 1) ~= "/" then
    return pio.canonical(process, process.cwd .. "/" .. path)
  end

  local parts = string.split(process, "/")
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

  return table.concat(left, "/")
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
  local file, err = gio.open(process, mode)
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
    if isModeProblematic("w", path, process.ring) then return nil, "Operation not permitted" end
    return gio.remove(path)
end

function pio.createDir(process, directory)
    directory = pio.canonical(process, directory)
    if isModeProblematic("w", directory, process.ring) then return "Operation not permitted" end
    return gio.mkdir(directory)
end

function pio.listDir(process, directory)
    directory = pio.canonical(process, directory)
    if isModeProblematic("r", directory, process.ring) then return "Operation not permitted" end
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

function pio.kill(process, pid)
  if process.pid == pid then
    error("Process " .. pid .. " commited suicide")
  end

  local target = allProcs[pid]
  if target == nil then
    return "Invalid PID"
  end
  if target.ring < process.ring then
    return "Operation not permitted"
  end

  Process.kill(pid)
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
  process:defineSyscall("pkill", pio.kill)
end
