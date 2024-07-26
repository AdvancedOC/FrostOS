local args = ...
local syscalls = require("syscalls")

local function round(val)
	return math.floor(val * 10 + 0.5) / 10
end

local format = "rf"

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
	krf = {1024, "kRF"},
	rf = {1, "RF"},
}

format = format:lower()

local unit = formats[format]

local divisor = unit[1]
local unitname = unit[2]

if args[1] == "total" or args[1] == "max" or args[1] == "capacity" then
	local rawTotalEnergy = syscalls.computer_maxEnergy()

	local totalEnergy = round(rawTotalEnergy / divisor)

	print(tostring(totalEnergy) .. " " .. unitname .. " of energy capacity")
elseif args[1] == "current" or args[1] == "available" then
	local rawEnergy = syscalls.computer_energy()

	local energy = round(rawEnergy / divisor)

	print(tostring(energy) .. " " .. unitname .. " of energy available")
else
	local rawTotalEnergy = syscalls.computer_maxEnergy()
	local rawEnergy = syscalls.computer_energy()

	local totalEnergy = round(rawTotalEnergy / divisor)
	local energy = round(rawEnergy / divisor)

	print(tostring(energy) .. " " .. unitname .. "/" .. tostring(totalEnergy) .. " " .. unitname .. " (" .. tostring(round((rawEnergy)/rawTotalEnergy*100)) .. "%) of energy capacity available")
end
