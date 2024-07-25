-- The IO Library.
-- Provides buffered IO and importing.

function package.pathOf(import, config, path)
    local config = string.split(config or package.config, "\n")
    local pathSep = config[1]
    local packagePathSep = config[2]
    local nameMark = config[3]

    local paths = string.split(path or package.path, packagePathSep)
    local name = table.concat(string.split(import, "."), pathSep)

    for _, path in ipairs(paths) do
        local truePath = table.concat(string.split(path, nameMark), name)
        if io.isFile(truePath) then
            return truePath
        end
    end
end

-- Yes, require is provided by the IO library.
function require(...)
    local path = ...
    if package.loaded[path] then
        return package.loaded[path]
    end

    if package.preload[path] then
        local res = package.preload[path](...)
        if res == nil then res = true end
        package.loaded[path] = res
        return res
    end

    local lib = package.pathOf(path)
    if lib then
        local file = io.open(lib, "r")
        if file then
            local code = file:read("a")
            local func, err = load(code, "=" .. lib, "bt", _G)
            if not func then error("Unable to load module " .. file .. ": " .. (err or "Bad chunk")) end
            file:close()
            local res = func(...)
            if res == nil then res = true end
            package.loaded[path] = res
            return res
        else
            error("Unable to open module file " .. lib)
        end
    end

    error("Unable to load module " .. path)
end

local syscalls = require("syscalls")

io = {}
io.__index = io

function io:__gc()
    self:close()
end

function io.from(descriptor)
    return setmetatable({
        buffer = "",
        bufidx = 1,
        buflimit = 64,
        fd = descriptor,
    }, io)
end

io.stdout = io.from(0)
io.stdin = io.from(1)
io.stderr = io.from(2)

function io.open(file, mode)
    local fd, err = syscalls.fopen(file, mode)
    if not fd then return nil, err end
    return io.from(fd)
end

function io.close(file)
    return syscalls.fclose(file.fd)
end

function io.flush(file)
    file = file or io.stdout

    syscalls.fwrite(file.fd, file.buffer)
    file.buffer = ""
    file.bufidx = 1
end

function io.write(file, ...)
    local values = {...}
    for _, value in ipairs(values) do
        file.buffer = (file.buffer or "") .. tostring(value)
        if string.contains(file.buffer, "\n") or #file.buffer >= file.buflimit then
            -- Time to flush!
            file:flush()
        end
    end
end

function io.getc(file)
    file = file or io.stdin

    if file.buffer == "" then
        file.buffer = syscalls.fread(file.fd, file.buflimit)
    end
    if file.buffer == nil then return nil end
    local c = string.sub(file.buffer, file.bufidx, file.bufidx)
    if file.bufidx == #file.buffer then
        -- Oh no, we ran out of buffer
        file.buffer = ""
        file.bufidx = 1
    else
        file.bufidx = file.bufidx + 1
    end
    if c == "" then c = nil end
    if c == nil then
        file.buffer = ""
        file.bufidx = 1
    end
    return c
end

function io.read(file, mode)
    if type(file) == "string" then
        return io.read(io.stdin, file)
    end

    mode = mode or "l"

    if mode == "a" then
        local buf
        while true do
            local c = file:getc()
            if c == nil then break end
            buf = (buf or "") .. c
        end
        return buf
    elseif mode == "l" then
        local buf
        while true do
            local c = file:getc()
            if c == '\n' then return buf or "" end
            if c == nil then break end
            buf = (buf or "") .. c
        end
        return buf
    elseif mode == "L" then
        local buf
        while true do
            local c = file:getc()
            if c == nil then break end
            buf = (buf or "") .. c
            if c == '\n' then break end
        end
        return buf
    end

    if type(mode) == "number" then
    	local buf
    	for i=1,mode do
     		local c = file:getc()
       		if c == nil then break end
         	buf = (buf or "") .. c
     	end
      	return buf
    end

    -- Unsupported mode, just default to reading line
    return io.read(file, "l")
end

function io.lines(path)
    local file = io.open(path)
    if not file then return function() return nil end end
    return function()
        if file == nil then return nil end
        local line = file:read("l")
        if line == nil then
            file:close()
            file = nil
        end
        return line
    end
end

function io.remove(path)
    return syscalls.fremove(path)
end

function io.exists(path)
    return syscalls.fexists(path)
end

function io.seek(file, whence, off)
    file:flush() -- This fixes bugs
    return syscalls.fseek(file.fd, whence, off)
end

function io.mkdir(path)
    return syscalls.diropen(path)
end

function io.list(path)
    return syscalls.dirlist(path)
end

function io.type(path)
    return syscalls.fkind(path)
end

function io.isFile(path)
    return io.type(path) == "file"
end

function io.isSymlink(path)
    return io.type(path) == "file"
end

function io.isMount(path)
    return io.type(path) == "mount"
end

function io.isDirectory(path)
    return io.type(path) == "directory"
end

function io.memory(buffer, mode)
    local fd = syscalls.fmemory(buffer, mode)
    return io.from(fd)
end

-- Warning!! Crashes can cause kernel problems!!!!
function io.stream(writer, reader, mode)
    local fd = syscalls.fstream(writer, reader, mode)
    return io.from(fd)
end

function print(...)
    io.write(io.stdout, table.concat({...}, '\t'), '\n')
end
