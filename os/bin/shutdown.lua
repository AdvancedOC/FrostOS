local args = ...

local syscalls = require("syscalls")

local reboot = false

for i=1,#args do
	if args[i] == "-r" then
		reboot = true
	end
end

syscalls.computer_shutdown(reboot)
