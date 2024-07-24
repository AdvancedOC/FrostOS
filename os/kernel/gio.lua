-- Defines the kernel IO table.
-- This is IO at the KERNEL level. This should NEVER leak into any process ever.

gio = {}

-- fstab cache
local fstab = {}

-- symtab cache
local symtab = {}

---@return string, string
local function getPathInfo(path)
    if path:sub(1,1) ~= "/" then
    error(path)
    end
    assert(path:sub(1, 1) == "/")
    local diskID, diskPath = computer.getBootAddress(), path

    -- TODO: handle fstab and symtab

    return diskID, diskPath
end

-- A file for the Kernel
---@class Kernel.File
---@field kind "memory"|"disk"|"stream"
---@field memory string
---@field cursor number
---@field handle number
---@field diskID string
---@field writer fun(content: string)
---@field reader fun(n: number?): string
---@field mode string

---@return Kernel.File?, string?
function gio.open(path, mode)
    local diskID, diskPath = getPathInfo(path)
    local handle, err = component.invoke(diskID, "open", diskPath, mode)
    if not handle then
        return nil, err
    end
    return {
        kind = "disk",
        handle = handle,
        diskID = diskID,
        mode = mode,
    }
end

---@return Kernel.File
function gio.new(memory, mode)
    return {
        kind = "memory",
        memory = memory,
        cursor = #memory,
        mode = mode,
    }
end

function gio.newStream(writer, reader, readOnly)
    local mode = readOnly and "r" or "rw"

    return {
        kind = "stream",
        writer = writer,
        reader = reader,
    }
end

---@param file Kernel.File
function gio.close(file)
    if file.kind == "disk" then
        component.invoke(file.diskID, "close", file.handle)
    end
end

---@param file Kernel.File
---@param memory string
function gio.write(file, memory)
    if file.kind == "disk" then
        return component.invoke(file.diskID, "write", file.handle, memory)
    elseif file.kind == "memory" then
        if string.contains(file.mode, "a") then
            -- Append sucks
            local before = string.sub(file.memory, 1, file.cursor)
            local after = string.sub(file.memory, file.cursor+1)
            file.memory = before .. memory .. after
            file.cursor = file.cursor + #memory
        elseif string.contains(file.mode, "w") then
            file.memory = file.memory .. memory
            file.cursor = file.cursor + #memory
        end
    elseif file.kind == "stream" then
        if file.mode == "rw" then
            file.writer(memory)
        end
    end
end

---@param file Kernel.File
---@param amount? number
-- Returns memory, error
---@return string?, string?
function gio.read(file, amount)
    if amount == nil then
        -- Read everything
        if file.kind == "disk" then
            local buf = ""
            repeat
                local data, err = component.invoke(file.diskID, "read", file.handle, math.huge)
                -- assert(data or not err, err)
                if err then return nil,err end
                buf = buf .. (data or "")
            until not data
            return buf
        elseif file.kind == "memory" then
            local chunk = string.sub(file.memory, file.cursor+1)
            file.cursor = #file.memory
            return chunk
        elseif file.kind == "stream" then
            return file.reader()
        end
    end

    if file.kind == "disk" then
        return component.invoke(file.diskID, "read", file.handle, amount)
    elseif file.kind == "memory" then
        local chunk = string.sub(file.memory, file.cursor+1, file.cursor+amount)
        file.cursor = file.cursor + #chunk
        return chunk
    elseif file.kind == "stream" then
        return file.reader(amount)
    end
end

---@return string[]?, string?
function gio.list(directory)
    local driveID, truePath = getPathInfo(directory)
    return component.invoke(driveID, "list", truePath)
end

function gio.dofile(path,...)
    local file,err = gio.open(path, "r")

    if not file then error(err) end

    local data,derr = gio.read(file)

    if not data then error(derr) end

    gio.close(file)

    return load(data or "", "=" .. path, "bt", _G)(...)
end

function gio.remove(path)
    local diskID, truePath = getPathInfo(path)
    return component.invoke(diskID, "remove", truePath)
end

function gio.size(path)
    local diskID, truePath = getPathInfo(path)
    return component.invoke(diskID, "size", truePath)
end

---@param file Kernel.File
---@param whence? "cur"|"set"|"end"
---@param pos? number
---@return number, string?
function gio.seek(file, whence, pos)
    whence = whence or "cur"
    pos = pos or 0
    if file.kind == "disk" then
        return component.invoke(file.diskID, "seek", file.handle, whence, pos)
    elseif file.kind == "memory" then
        if whence == "set" then
            file.cursor = math.min(pos, #file.memory)
        elseif whence == "end" then
            file.cursor = math.max(0, #file.memory - pos)
        elseif whence == "cur" then
            file.cursor = math.min(file.cursor + pos, #file.memory)
        end
        return file.cursor
    else
        return 0, "gio_seek: Unsupported file type"
    end
end

function gio.mkdir(path)
    local diskID, truePath = getPathInfo(path)
    return component.invoke(diskID, "makeDirectory", truePath)
end

function gio.exists(path)
    local diskID, truePath = getPathInfo(path)
    return component.invoke(diskID, "exists", truePath)
end
