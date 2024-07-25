local function computer_totalMemory(proc)
	return computer.totalMemory()
end

local function computer_freeMemory(proc)
	return computer.freeMemory()
end

local function computer_shutdown(proc, reboot)
	return computer.shutdown(reboot)
end

return function(proc)
	proc:defineSyscall("computer_totalMemory", computer_totalMemory)
	proc:defineSyscall("computer_freeMemory", computer_freeMemory)
	proc:defineSyscall("computer_shutdown", computer_shutdown)
end
