-- Defines the kernel IO table.
-- This is IO at the KERNEL level. This should NEVER leak into any process ever.

gio = {}

-- fstab cache
local fstab = {}

local symtab = {}

function gio.alldisks()
	local iter = component.list('filesystem')
	return function()
		local fs = iter()
		if not fs then return nil end
		return component.invoke(fs, 'getLabel') or fs, fs
	end
end

---@return string?
function gio.diskAddress(disk)
	for label, addr in gio.alldisks() do
		if label == disk or addr == disk then
			return label
		end
	end
	return "tmpfs"
end

function gio.getBootMount()
	return "/mnt/" .. gio.diskAddress(computer.getBootAddress())
end


component.invoke(computer.getBootAddress(), 'setLabel', 'FrostOS')

function gio.isReadOnly(disk)
	return component.invoke(disk, 'isReadOnly')
end


---@return string, string
local function getPathInfo(path)
    if path:sub(1,1) ~= "/" then
    error(path)
    end
    assert(path:sub(1, 1) == "/")
    if path == "/tmp" then
    	return computer.tmpAddress(), ""
    end
    if path == "/mnt" then
    	return computer.getBootAddress(), "mnt"
    end
    if string.startswith(path, "/tmp/") then
    	return computer.tmpAddress(), path:sub(6)
    end
    if path == "/mnt/tmpfs" then
    	return computer.tmpAddress(), ""
    end
    if string.startswith(path, "/mnt/tmpfs/") then
    	return computer.tmpAddress(), path:sub(12)
    end
    if string.startswith(path, "/mnt/") then
    	for disk, addr in gio.alldisks() do
     		if path == "/mnt/" .. disk then
       			return addr, ""
       		end
       		if path == "/mnt/" .. addr then
         			return addr, ""
         		end
         	if string.startswith(path, "/mnt/" .. disk .. "/") then
          		local subpath = string.sub(path, 7 + #disk)
            	if addr == computer.getBootAddress() and subpath == "mnt" then
             		return getPathInfo('/mnt')
             	end
            	if addr == computer.getBootAddress() and string.startswith(subpath, "mnt/") then
             		return getPathInfo('/' .. subpath)
             	end
            	return addr, subpath
          	end
     	end
    end

    if fstab[path] then return getPathInfo("/mnt/" .. gio.resolveMount(path)) end
    if symtab[path] then return getPathInfo(symtab[path]) end

    -- fstab and symtab scanning
    local outpath = path
    for i=1,#path do
    	if path:sub(i, i) == "/" then
     		local behind = path:sub(1, i-1)
       		if fstab[behind] then
         		outpath = "/mnt/" .. gio.resolveMount(behind) .. path:sub(i)
           	elseif symtab[behind] then
            	outpath = symtab[behind] .. path:sub(i)
         	end
     	end
    end

    if outpath ~= path then return getPathInfo(outpath) end

    local diskID, diskPath = computer.getBootAddress(), path:sub(2)
    -- TODO: handle fstab and symtab

    return diskID, diskPath
end

function gio.isPathReadOnly(path)
	local disk, path = getPathInfo(path)
	return gio.isReadOnly(disk)
end

function gio.resolveMount(mountpoint)
	if mountpoint == "/" then return gio.diskAddress(computer.getBootAddress()) end
	if string.startswith(mountpoint, "/mnt/") then
		if string.contains(mountpoint:sub(6), "/") then
			local disk, p = getPathInfo(mountpoint)
			assert(p == "", "Very confusing pointpoint: " .. mountpoint)
			return disk
		end
		return gio.diskAddress(mountpoint:sub(6))
	end
	if mountpoint == "/tmp" then
		return computer.tmpAddress()
	end
	while symtab[mountpoint] do
		mountpoint = symtab[mountpoint]
	end
	if not fstab[mountpoint] then return end
	return gio.diskAddress(fstab[mountpoint])
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
	if gio.pathType(path) ~= "file" then return nil, "Not a file" end
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

function gio.newStream(writer, reader, mode)
    return {
        kind = "stream",
        writer = writer,
        reader = reader,
        mode = mode,
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
        if string.contains(file.mode or "r", "w") then
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

local function addTabs(results, directory)
	for path in pairs(fstab) do
    	if string.startswith(path, directory .. "/") or (directory == "/") then
     		-- Mountpoints inside this directory!
       		local sub = string.sub(path, directory == "/" and 2 or #directory + 2)
         	-- If it has /, then it is actually deeper
         	if not string.contains(sub, '/') then
          		table.insert(results, sub)
          	end
     	end
    end
    for path in pairs(symtab) do
       	if string.startswith(path, directory .. "/") or (directory == "/") then
        		-- Mountpoints inside this directory!
          		local sub = string.sub(path, directory == "/" and 2 or #directory + 2)
            	-- If it has /, then it is actually deeper
            	if not string.contains(sub, '/') then
             		table.insert(results, sub)
             	end
        	end
       end
end

---@return string[]?, string?
function gio.list(directory)
	if directory == "/mnt" then
		local results = {}
   		for mnt in gio.alldisks() do
     		table.insert(results, mnt)
    	end
     	addTabs(results, directory)
     	return results
    end

    local driveID, truePath = getPathInfo(directory)
    if driveID == computer.getBootAddress() and truePath == "mnt" then
    	local results = {}
     		for mnt in gio.alldisks() do
       		table.insert(results, mnt)
      	end
       	addTabs(results, directory)
       	return results
    end

    local dirType = gio.pathType(directory)
    if dirType == "file" or dirType == "symlink" then return nil, "Not a directory" end

    if dirType == "mount" then
    	local mountedTo = gio.resolveMount(directory)
     	if directory ~= "/mnt/" .. mountedTo then
     		return gio.list("/mnt/" .. mountedTo)
      	end
    end

    local results, err = component.invoke(driveID, "list", truePath)
    if not results then return nil, err end

    for i=1,#results do
    	if results[i]:sub(-1, -1) == "/" then
     		results[i] = results[i]:sub(1, -2)
     	end
    end

    if driveID == computer.getBootAddress() and truePath == "mnt" then
    	return gio.list("/mnt")
    end

    -- Add virtual folders
    if driveID == computer.getBootAddress() and truePath == "" or truePath == "/" then
    	table.insert(results, 'tmp')
    	table.insert(results, 'mnt')
    end

    addTabs(results, directory)


    return results
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
	if path == "/mnt" then
		return "Operation not permitted"
	end
	for disk in gio.alldisks() do
		if path == "/mnt/" .. disk then
			-- You can't delete a disk.
			return "Operation not permitted"
		end
	end
	if path == "/" then
		return "Operation not permitted"
	end
	if path == "/tmp" then
		return "Operation not permitted"
	end
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
    if diskID == computer.getBootAddress() and truePath == "mnt" then
    	return true
    end
    return component.invoke(diskID, "exists", truePath)
end

function gio.pathType(path)
	if path == "/" then return "directory" end
    if symtab[path] then
    	local child = gio.pathType(symtab[path])
     	if child == "none" then
     		return "symlink"
       	else
        	return child
      	end
    end
    if fstab[path] then return "mount" end
    if not gio.exists(path) then return "none" end
    local driveID, path = getPathInfo(path)
    if driveID == computer.getBootAddress() then
    	if path == "tmp" then return "directory" end
     	if path == "mnt" then return "directory" end
	    if string.startswith(path, "mnt/") then
	      	for disk in gio.alldisks() do
	       		if path == "mnt/" .. disk then return "mount" end
	       	end
	    end
    end
    if path == "" then return "mount" end
    return component.invoke(driveID, "isDirectory", path) and "directory" or "file"
end
