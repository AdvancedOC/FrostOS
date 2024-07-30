component = component or require("component") -- support OpenOS because why the heck not
computer = computer or require("computer")

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

coroutine = coroutine

if is_openos then
	printMsg("Completely bypassing all of OpenOS's security to get the actual coroutine table...")

	local process = require("process")

	for k,v in pairs(process.list) do
		if v.command == "init" and v.path == "/init.lua" then
			coroutine = v.data.coroutine_handler
		end
	end
end

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

printMsg("Setting up an environment...")
local environment

local function envLoad(data, chunkname, mode, env)
	env = env or environment

	return load(data,chunkname,mode,env)
end


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
		elseif idx == "load" then
			return envLoad
		else
			return _G[idx]
		end
	end,
	__newindex = function(tab,idx,val)
		_G[idx] = val
	end
})

printMsg("Downloading Diskless from github...")
local disklessLink = "https://raw.githubusercontent.com/AdvancedOC/Diskless/main/diskless.lua"

local disklessData = downloadFile(disklessLink)

local diskless = load(disklessData, "=diskless.lua", "bt", environment)() -- not even gonna error check, i trust Diskless
-- ^ diskless is running in the environment to make sure it can do its modifications to computer, component, etc

printMsg("Making RamFS using diskless...")

local MiB = 1024^2
local floppySize = MiB * 0.5 -- floppies have 0.5 MiB of space, we'll fake this size, to be as hidden as possible

local ramfsUUID = diskless.makeRamFS(false, floppySize)

local function downloadFileAndWrite(url, path)
	local file = downloadFile(url)

	diskless.forceWrite(ramfsUUID, path, file)
end

local repo = "https://raw.githubusercontent.com/AdvancedOC/FrostOS/main"
printMsg("Getting list of files to download from github...")

local toInstall = downloadFile(repo .. "/os_toinstall")

local function string_escape_pattern(text)
	return text:gsub("([^%w])", "%%%1")
end

local function string_split(inputstr, sep)
	sep=string_escape_pattern(sep)
	local t={}
	for field,s in string.gmatch(inputstr, "([^"..sep.."]*)("..sep.."?)") do
		table.insert(t,field)
		if s=="" then
			return t
		end
	end
	return t
end

local function string_startswith(s,sub)
	return s:sub(1,#sub) == sub
end

local lines = string_split(toInstall,"\n")

printMsg("Starting downloads...")

for i, line in ipairs(lines) do
	if string_startswith(line, "file ") then
		local filepath = line:sub(6)

		printMsg("Downloading file " .. filepath .. "...")
		downloadFileAndWrite(repo .. filepath, filepath)
	elseif string_startswith(line, "directory ") then
		local dirpath = line:sub(11)

		printMsg("Making directory " .. dirpath .. "...")
		diskless.funcs.makeDirectory(ramfsUUID, dirpath)
	end
end

printMsg("Making usertab...")

local usertab = [["admin" "47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=" 0]]
diskless.forceWrite(ramfsUUID, "/os/etc/usertab", usertab)

printMsg("Making sure boot address is set...")
function computer.getBootAddress() return ramfsUUID end

printMsg("Trying to boot FrostOS...")

local initfile = diskless.forceRead(ramfsUUID, "/init.lua")

local loaded,err = load(initfile,"=init.lua","bt", environment)

if not loaded then error(err) end

loaded()