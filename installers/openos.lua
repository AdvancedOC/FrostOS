local repository = "https://raw.githubusercontent.com/Blendi-Goose/FrostOS/main"

local component = require("component")
local computer = require("computer")

local internet = require("internet")

if not internet then
	print("No internet API detected, please make sure you have a internet card installed.")
	return
end

local drives = {}

for fileSys in component.list("filesystem") do
	if computer.tmpAddress() ~= fileSys then
		local proxy = component.proxy(fileSys)
		if proxy.spaceTotal() > 512*1024 then -- drive needs to have 0.5MiB or i don't want it
			if not proxy.isReadOnly() then -- can't really install to read-only can
				table.insert(drives, fileSys)
			end
		end
	end
end

print("Welcome to the FrostOS installer.")

local function roundval(x) return math.floor(x*10 + 0.5)/10 end
local MiB = 1024*1024

local drivenames = {}

for k,v in ipairs(drives) do
	local proxy = component.proxy(v)

	local name = k .. ". "

	if proxy.getLabel() then
		name = name .. proxy.getLabel() .. " (" .. v:sub(1,5) .. ")"
	else
		name = name .. v:sub(1,5)
	end

	local usedSpace = proxy.spaceUsed()
	local totalSpace = proxy.spaceTotal()

	name = name .. " " .. tostring(roundval(usedSpace/MiB)) .. " MiB of " .. tostring(roundval(totalSpace/MiB)) .. " MiB total used"

	print(name)

	drivenames[k] = name
end

print("Choose a drive by inputting the number to the left of the drive you want.")
io.write("Drive: ")

local chosendrive = io.read("l")
chosendrive = tonumber(chosendrive)

if not chosendrive or not drives[chosendrive] then print("Invalid drive selected. Installation canceled.") return end

local chosendriveid = drives[chosendrive]
local chosendriveproxy = component.proxy(chosendriveid)

print("You have chosen drive " .. drivenames[chosendrive])
io.write("Are you sure? y/N: ")
local ans = io.read("l")

if ans:lower() ~= "y" then print("Canceled installation.") return end

print("Would you like to delete all the files on this drive?")
io.write("y/N: ")
ans = io.read("l")
if ans:lower() == "y" then
	local files = chosendriveproxy.list("/")
	for k,v in ipairs(files) do
		print("Deleting " .. v .. "...")
		chosendriveproxy.remove(v)
	end
end

local function downloadFile(link)
	local result = ""

	local handle = internet.request(link)
	for chunk in handle do result = result .. chunk end

	return result
end

print("Downloading the list of files to install from github...")
local toInstall = downloadFile(repository .. "/os_toinstall")

local function escape_pattern(text)
    return text:gsub("([^%w])", "%%%1")
end

local function splitString(inputstr, sep)
    sep=escape_pattern(sep)
    local t={}
    for field,s in string.gmatch(inputstr, "([^"..sep.."]*)("..sep.."?)") do
        table.insert(t,field)
        if s=="" then
            return t
        end
    end
    return t
end

local function stringStartsWith(s,sub)
    return s:sub(1,#sub) == sub
end

local function writeDataToFile(path,data)
	local handle = chosendriveproxy.open(path, "w")

	print("Writing file " .. path .. "...")
	chosendriveproxy.write(handle,data)

	chosendriveproxy.close(handle)
end

print("Downloading files...")
local list = splitString(toInstall,"\n")

for i,v in ipairs(list) do
	if stringStartsWith(v,"directory") then
		local path = v:sub(11)

		print("Making directory " .. path .. "...")
		chosendriveproxy.makeDirectory(path)
	elseif stringStartsWith(v,"file") then
		local path = v:sub(6)

		local downloaded = downloadFile(repository .. path)

		writeDataToFile(path,downloaded)
	end
end

local usertab = ""
local users = {}

print("Create Administrator user")
local name = "admin"
local password
while true do
	io.write("Password: ")
	password = io.read("l")
	io.write("Password (again): ")
	local pass2 = io.read("l")
	if password == pass2 then break end
	print("Passwords don't match! Try again.")
end

table.insert(users, {name = name, password = password})

while true do
	print("Create another user:")
	io.write("Name (empty to cancel): ")
	local name = io.read("l")
	if #name == 0 then break end

	local password
	while true do
		io.write("Password: ")
		password = io.read("l")
		io.write("Password (again): ")
		local pass2 = io.read("l")
		if password == pass2 then break end
		print("Passwords don't match! Try again.")
	end

	table.insert(users, {name = name, password = password})
end

local function readFile(path)
	local handle = chosendriveproxy.open(path, "r")

	local fulldata = ""

	local finished = false
	while not finished do
		local data = chosendriveproxy.read(handle, 99)

		if data then fulldata = fulldata .. data else finished = true end
	end

	return fulldata
end

print("Loading base64 and sha256 libraries from downloaded files...")
local base64file = readFile("/os/drivers/data/base64.lua")

local base64 = load(base64file, "=base64", "bt")()

local sha256file = readFile("/os/drivers/data/sha256.lua")

local sha256 = load(sha256file, "=sha256", "bt")()

print("Writing user login information into /os/etc/usertab..")
for i = 1,#users do
	local user = users[i]
	local hash = base64.encode(sha256(user.password))
	local ring = 3
	if i == 1 then ring = 0 end
	usertab = usertab .. '"' .. user.name .. '" "' .. hash .. '" ' .. tostring(ring) .. "\n"
end

writeDataToFile("/os/etc/usertab", usertab)

print("Set the label of the drive to FrostOS?")
io.write("y/N: ")
ans = io.read("l")

if ans:lower() == "y" then
	chosendriveproxy.setLabel("FrostOS")
else
	print("Would you like to set a custom label?")
	io.write("y/N: ")
	ans = io.read("l")

	if ans:lower() == "y" then
		io.write("New label: ")

		local newlabel = io.read("l")

		local setTo = chosendriveproxy.setLabel(newlabel)

		print("Label set to " .. setTo)
	end
end

print("You should probably reboot now, if you want to try FrostOS.")
io.write("Reboot? Y/n: ")

ans = io.read()

if ans:lower() == "n" then return end

computer.shutdown(true)
