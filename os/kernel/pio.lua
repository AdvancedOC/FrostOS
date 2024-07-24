local protectedPaths = {}

local function protectedSort(a, b)
  return #a > #b
end

local function protectionApplies(path, info)
  return strings.startswith(path, info.path .. "/") or path == info.path
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

function pio.giveFile(process, file)
  local i = 3
  while process.files[i] ~= nil then
    i = i + 1
  end
  process.files[i] = file
  return i
end

function pio.open(process, path, mode)
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
  process:defineSyscall("pkill", pio.kill)
end
