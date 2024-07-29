-- this installer tries to make a live environment in the ram

local component = component or require("component") -- support OpenOS because why the heck not
local computer = computer or require("computer")

local is_openos = (package ~= nil and package.loaded.coroutine ~= nil)

local gpu = component.list("gpu")()
local screen = component.list("screen")()

component.invoke(gpu, "bind", screen)

local w,h = component.invoke(gpu, "maxResolution")

component.invoke(gpu, "setResolution", w, h)

component.invoke(gpu, "setForeground", 0xFFFFFF)
component.invoke(gpu, "setBackground", 0x000000)
component.invoke(gpu, "fill", 1, 1, w, h, " ")

local y = 1
local function printMsg(msg)
	if y == h+1 then
		component.invoke(gpu, "copy", 1,2,w,h-1,0,-1)
	end

	component.invoke(gpu, "set", 1, math.min(h,y), msg .. string.rep(" ",w-#msg))

	if y < h+1 then y = y + 1 end
end

local internetcard = component.list("internet")()

printMsg("Loading utilities...")

function string.escape_pattern(text)
	return text:gsub("([^%w])", "%%%1")
end

function string.contains(s, sub)
	return string.find(s, sub, nil, true) ~= nil
end

function string.startswith(s,sub)
	return s:sub(1,#sub) == sub
end

function string.endswith(s,sub)
	return s:sub(#s-#sub+1) == sub
end

function string.split(inputstr, sep)
	sep=string.escape_pattern(sep)
	local t={}
	for field,s in string.gmatch(inputstr, "([^"..sep.."]*)("..sep.."?)") do
		table.insert(t,field)
		if s=="" then
			return t
		end
	end
	return t
end

local function fixPath(path)
	if not string.startswith(path,"/") then path = "/" .. path end
	if path:sub(#path) == "/" then
		path = path:sub(1,#path-1)
	end
	return path
end

printMsg("Making ramfs...")

local ramfsUUID = "abcdefgh-ijkl-mnop-qrst-uvwxyz123456" -- very realistic, i know

local ramfs = {}

ramfs.files = {}

ramfs.spaceUsed = function() return 0 end -- i am not calculating that screw off
ramfs.setLabel = function() return end
ramfs.getLabel = function() return "ramstick" end
ramfs.isReadOnly = function() return false end

ramfs.makeDirectory = function(path)
	path = fixPath(path)
	local segs = string.split(path,"/")

	local cur = ""
	for i = 1,#segs-1 do
		cur = cur .. segs[i]
		if not ramfs[cur] then ramfs[cur] = true end
		cur = cur .. "/"
	end

	cur = cur .. segs[#segs]

	ramfs[cur] = true -- define it as a folder
	return true
end

ramfs.isDirectory = function(path)
	path = fixPath(path)

	return ramfs[path] == true
end

ramfs.open = function(path,mode)
	mode = mode or "r"
	path = fixPath(path)

	if string.contains(mode,"r") and type(ramfs[path]) ~= "string" then return nil end

	return {
		path = path,
		buf = {},
		mode = mode,
	}
end

ramfs.write = function(handle, data)
	handle.buf[#handle.buf+1] = data
end

ramfs.read = function(handle, amount)
	handle.i = handle.i or 1
	amount = math.min(amount,#ramfs[handle.path] - handle.i + 1)

	if handle.i <= #ramfs[handle.path] then
		local data = ramfs[handle.path]:sub(handle.i,handle.i+amount - 1)
		handle.i = handle.i + amount
		return data
	end

	return nil
end

ramfs.seek = function(handle, whence, offset)
	if whence == "set" then
		handle.i = offset
	elseif whence == "cur" then
		handle.i = handle.i + offset
	elseif whence == "end" then
		handle.i = #ramfs[handle.path] - offset
	end

	handle.i = math.min(math.max(offset,1),#ramfs[handle.path] + 1)

	return handle.i
end

ramfs.close = function(handle)
	if string.contains(handle.mode, "w") then
		ramfs[handle.path] = table.concat(handle.buf)
	end
end

ramfs.exists = function(path)
	path = fixPath(path)

	return ramfs[path] ~= nil
end

ramfs.rename = function(path,topath)
	path = fixPath(path)
	topath = fixPath(topath)

	ramfs[topath] = ramfs[path]
	ramfs[path] = nil
end

ramfs.list = function(path)
	path = fixPath(path)

	local parts = string.split(path,"/")

	-- error(path .. "   " .. tostring(ramfs[path]))

	if ramfs[path] ~= true then
		return {}
	end

	local startcheck = path .. "/" -- i know we just removed a potential slash and now we're adding it and that's dumb but skill issue

	local items = {}

	for k,v in pairs(ramfs) do
		if string.startswith(k,startcheck) then
			local newparts = string.split(k,"/")

			if #newparts == #parts + 1 then
				items[#items+1] = k:sub(#startcheck+1)
			end
		end
	end

	return items
end

ramfs.lastModified = function(path)
	return 0 -- January 1st, 1970
end

ramfs.remove = function(path)
	path = fixPath(path)
	local succ = true

	if ramfs[path] then
		if ramfs.isDirectory(path) then
			local children = ramfs.list(path)
			for i,v in ipairs(children) do
				if not ramfs.remove(path .. "/" .. v) then succ = false end
			end

			ramfs[path] = nil
		else
			ramfs[path] = nil
		end
	else
		succ = false
	end

	return succ
end

printMsg("Adding ramfs to components...")

local ci = component.invoke
function component.invoke(addr, func, ...)
	if addr == ramfsUUID then
		return ramfs[func](...)
	else
		return ci(addr,func,...)
	end
end

local compprox = component.proxy
function component.proxy(addr)
	if addr == ramfsUUID then
		return ramfs
	else
		return compprox(addr)
	end
end

local cl = component.list
function component.list(filter, exact)
	local vals = cl(filter,exact)

	if exact and filter == "filesystem" then
		vals[ramfsUUID] = "filesystem"
	elseif (not exact) and string.contains("filesystem", filter) then
		vals[ramfsUUID] = "filesystem"
	elseif (not exact) and #filter == 0 then
		vals[ramfsUUID] = "filesystem"
	end

	return vals
end

printMsg("Making sure the computer knows it's booting off of the ramfs...")

function computer.getBootAddress() return ramfsUUID end -- make sure to use this one

local function downloadFile(url)
	local request,err = component.invoke(internetcard, "request", url)

	if not request then error(err) end

	local succ,err = pcall(request.finishConnect)

	if not succ then return nil, err end

	local fulldata = ""

	while true do
		local data = request.read(math.huge)

		if data then fulldata = fulldata .. data else break end
	end

	request.close()

	return fulldata
end

local function downloadFileAndWrite(url,path)
	path = fixPath(path)
	local data = downloadFile(url)

	ramfs[path] = data -- i could do handles and everything but like... why not just this
end

local repo = "https://raw.githubusercontent.com/AdvancedOC/FrostOS/main"

printMsg("Getting list of files to download...")

local toInstall = downloadFile(repo .. "/os_toinstall")

local lines = string.split(toInstall,"\n")

printMsg("Starting downloads...")

-- download all the shit
for i, line in ipairs(lines) do
	if string.startswith(line, "file ") then
		local filepath = line:sub(6)

		printMsg("Downloading file " .. filepath)
		downloadFileAndWrite(repo .. filepath, filepath)
	elseif string.startswith(line, "directory ") then
		local dirpath = line:sub(11)

		printMsg("Making directory " .. dirpath)

		ramfs.makeDirectory(dirpath)
	end
end

printMsg("Making usertab...")

local usertab = [["admin" "47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=" 0]]
-- ^ this is a constant string because loading the base64 & sha256 libaries is extra work for no reason
ramfs["/os/etc/usertab"] = usertab

local coroutine = coroutine

if is_openos then
	printMsg("Completely bypassing all of OpenOS's security to get the actual coroutine table...")

	local process = require("process")

	for k,v in pairs(process.list) do
		if v.command == "init" and v.path == "/init.lua" then
			coroutine = v.data.coroutine_handler
		end
	end
end

printMsg("Setting up an environment...")
local environment
environment = setmetatable({}, {
	__index = function(tab,idx)
		if idx == "computer" then
			return computer
		elseif idx == "component" then
			return component
		elseif idx == "coroutine" then
			return coroutine
		elseif idx == "_G" then
			return environment
		else
			return _G[idx]
		end
	end,
	__newindex = function(tab,idx,val)
		_G[idx] = val
	end
})

local oload = load
function load(a,b,c,env)
	env = env or environment
	return oload(a,b,c,env)
end

printMsg("Trying to boot FrostOS...")

local initfiledata = ramfs["/init.lua"]

local loaded,err = load(initfiledata,"=init.lua","bt",environment)

if not loaded then error(err) end

loaded()

-- return loaded()
