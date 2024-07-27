local cl, ci = component.list, component.invoke

local function get_eeprom()
	local eeprom

	for addr, ctype in cl("eeprom") do
		eeprom = addr -- since computers can only have one eeprom, we don't have to worry about the possibility of multiple
		break
	end

	return eeprom
end

local function eeprom_read(proc)
	local eeprom = get_eeprom()

	if eeprom then
		return ci(eeprom, "get")
	end
end

local function eeprom_write(proc, data)
	local eeprom = get_eeprom()

	if eeprom then
		return ci(eeprom, "set", data)
	end
end

local function eeprom_getLabel(proc)
	local eeprom = get_eeprom()

	if eeprom then
		return ci(eeprom, "getLabel")
	end
end

local function eeprom_setLabel(proc, newLabel)
	local eeprom = get_eeprom()

	if eeprom then
		return ci(eeprom, "setLabel", newLabel)
	end
end

local function eeprom_getSize(proc)
	local eeprom = get_eeprom()

	if eeprom then
		return ci(eeprom, "getSize")
	end
end

local function eeprom_getDataSize(proc)
	local eeprom = get_eeprom()

	if eeprom then
		return ci(eeprom, "getDataSize")
	end
end

local function eeprom_getChecksum(proc)
	local eeprom = get_eeprom()

	if eeprom then
		return ci(eeprom, "getChecksum")
	end
end

local function eeprom_makeReadonly(proc) -- this is irreversible, maybe we should add a warning? or maybe just don't have it?
	local eeprom = get_eeprom()

	if eeprom then
		return ci(eeprom, "makeReadonly")
	end
end

local function eeprom_getData(proc)
	local eeprom = get_eeprom()

	if eeprom then
		return ci(eeprom, "getData")
	end
end

local function eeprom_setData(proc)
	local eeprom = get_eeprom()

	if eeprom then
		return ci(eeprom, "setData")
	end
end

---@param process Kernel.Process
return function (process)
	process:defineSyscall("eeprom_read", eeprom_read)

	process:defineSyscall("eeprom_getLabel", eeprom_getLabel)

	process:defineSyscall("eeprom_getSize", eeprom_getSize)

	process:defineSyscall("eeprom_getChecksum", eeprom_getChecksum)

	process:defineSyscall("eeprom_getDataSize", eeprom_getDataSize)

	process:defineSyscall("eeprom_getData", eeprom_getData)

	-- Writes are only for cool boys
	if process.ring > 2 then return end
	process:defineSyscall("eeprom_write", eeprom_write)

	process:defineSyscall("eeprom_setLabel", eeprom_setLabel)

	process:defineSyscall("eeprom_setData", eeprom_setData)

	if process.ring > 1 then return end -- very dangerous function, only let kernel, drivers & login mess with it
	process:defineSyscall("eeprom_makeReadonly", eeprom_makeReadonly)
end
