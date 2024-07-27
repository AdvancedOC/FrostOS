local args = ...

local syscalls = require("syscalls")

local function round(val)
	return math.floor(val * 10 + 0.5) / 10
end

local format = "mb"

if syscalls.computer_totalMemory() < 1024*1024 then format = "kb" end

local i = 1
while i <= #args do
	local arg = args[i]

	if arg == "-u" or arg == "--unit" then
		format = args[i+1]
		i = i + 1
	end

	i = i + 1
end

local formats = {
	gb = {1024^3, "GiB"},
	mb = {1024^2, "MiB"},
	kb = {1024, "KiB"},
	b = {1, "B"},
	bt = {1/8, " bits"}
}

format = format:lower()
if #format == 3 and format:sub(2,2) == "i" then format = format:sub(1,1) .. format:sub(3,3) end -- so we can type mib or gib aswell

local unit = formats[format]

if not unit then
	print("invalid unit specified")
	return
end

local divisor = unit[1]
local unitname = unit[2]

if args[1] == "free" then
	local rawtotal = syscalls.computer_totalMemory()
	local rawfree = syscalls.computer_freeMemory()

	local totalmem = round(syscalls.computer_totalMemory()/divisor)
	local freemem = round(syscalls.computer_freeMemory()/divisor)

	print(tostring(freemem) .. unitname .. " (" .. tostring(round((rawfree)/rawtotal*100)) .. "%) of RAM free")
elseif args[1] == "used" then
	local rawtotal = syscalls.computer_totalMemory()
	local rawfree = syscalls.computer_freeMemory()

	local totalmem = round(syscalls.computer_totalMemory()/divisor)
	local freemem = round(syscalls.computer_freeMemory()/divisor)

	print(tostring(totalmem-freemem) .. unitname .. " (" .. tostring(round((rawtotal-rawfree)/rawtotal*100)) .. "%) of RAM used")
elseif args[1] == "total" then
	local totalmem = round(syscalls.computer_totalMemory()/divisor)

	print(tostring(totalmem) .. unitname .. " of RAM total")
elseif args[1] == "clean" then
	local before = syscalls.computer_freeMemory()
	syscalls.computer_cleanMemory()
	local after = syscalls.computer_freeMemory()

	local rawsavedmem = before-after
	local savedmem = round(rawsavedmem/divisor)
	local rawtotal = syscalls.computer_totalMemory()

	if rawsavedmem < 0 then
		print("We have managed to increase your memory usage by "  .. tostring(math.abs(savedmem)) .. " " .. unitname .. " (" .. tostring(-round(rawsavedmem/rawtotal*100)) .. "%)")
	else
		print("Decreased memory usage by " .. tostring(savedmem) .. " " .. unitname .. " (" .. tostring(round(rawsavedmem/rawtotal*100)) .. "%)")
	end

else
	local rawtotal = syscalls.computer_totalMemory()
	local rawfree = syscalls.computer_freeMemory()

	local totalmem = round(syscalls.computer_totalMemory()/divisor)
	local freemem = round(syscalls.computer_freeMemory()/divisor)

	print(tostring(totalmem-freemem) .. unitname .. "/" .. tostring(totalmem) .. unitname .. " (" .. tostring(round((rawtotal-rawfree)/rawtotal*100)) .. "%) of RAM used")
end
