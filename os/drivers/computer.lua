local function computer_totalMemory(proc)
	return computer.totalMemory()
end

local function computer_freeMemory(proc)
	return computer.freeMemory()
end

local function computer_shutdown(proc, reboot)
	return computer.shutdown(reboot)
end

local function computer_uptime(proc)
	return computer.uptime()
end

local function computer_maxEnergy(proc)
	return computer.maxEnergy()
end

local function computer_energy(proc)
	return computer.energy()
end

local function computer_dangerouslyLowRAM(proc)
	return MemoryConservative or computer.freeMemory() < 8 * 1024
end

local function computer_uptime()
	return computer.uptime()
end

local function computer_cleanMemory()
	table.clear(ProcPool)
	local pid = next(allProcs)
	while pid do
		local proc = allProcs[pid]
		local package = proc.namespace.package
		if package and package.loaded and package.loaded.syscalls then
			table.clear(package.loaded.syscalls)
		end
		pid = next(allProcs, pid)
	end
	JustDoGC()
end

return function(proc)
	proc:defineSyscall("computer_totalMemory", computer_totalMemory)
	proc:defineSyscall("computer_freeMemory", computer_freeMemory)
	proc:defineSyscall("computer_shutdown", computer_shutdown)
	proc:defineSyscall("computer_uptime", computer_uptime)
	proc:defineSyscall("computer_maxEnergy", computer_maxEnergy)
	proc:defineSyscall("computer_energy", computer_energy)
	proc:defineSyscall("computer_dangerouslyLowRAM", computer_dangerouslyLowRAM)
	proc:defineSyscall("computer_uptime", computer_uptime)
	proc:defineSyscall("computer_cleanMemory", computer_cleanMemory)
end
