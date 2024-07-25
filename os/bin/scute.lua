local syscalls = require("syscalls")
local process = require("process")

-- unimplemented lol

local function isBackslashed(str, i)
	if str:sub(i - 1, i - 1) == "\\" then
		return not isBackslashed(str, i - 1)
	end
	return false
end

local function parseCommand(cmd)
	local args = {}
	local current = ""

	local i = 0
	while i < #cmd do
		i = i + 1

		local ch = string.sub(cmd, i, i)

		if ch == " " and not isBackslashed(cmd, i) then
			args[#args + 1] = current
			current = ""
		elseif ch == '"' and not isBackslashed(cmd,i) then
			i = i + 1
		 	while cmd:sub(i,i) ~= '"' or isBackslashed(cmd,i) do
				current = current .. cmd:sub(i,i)
		  		i = i + 1
			end
			i = i + 1
		else
			current = current .. cmd:sub(i,i)
		end
	end

	if #current > 0 then args[#args+1] = current end

	return args
end

local function which(command)
    local shellPath = "/usr/bin/?.lua:/usr/bin/?/init.lua:/os/bin/?.lua:/os/bin/?/init.lua"
    local shellConfig = "/\n:\n?\n"

    return package.pathOf(command, shellConfig, shellPath)
end

-- TODO: make io use separate buffers gosh darn it
io.stdout.buflimit = 0

while true do
	local wd = process.cwd()

	io.write(io.stdout, wd .. " > ")
	local line = io.read(io.stdin, "l")

	local parsed = parseCommand(line)

	if #parsed >= 1 then
		local program = which(parsed[1])
		if program then
    		local progargs = {}

    		for i = 1,#parsed do
    			progargs[i-1] = parsed[i]
    		end

			local prog = process.spawn("Program " .. program, {
    			[0] = io.stdout.fd,
    			[1] = io.stdin.fd,
    			[2] = io.stderr.fd,
    		}, nil, wd, 3)
            process.exec(prog, program, progargs)

    		while process.status(prog) ~= "dead" do
    		  coroutine.yield()
    		end

      		process.kill(prog)
        else
			print("Unknown command: " .. parsed[1])
		end
	end

	coroutine.yield()
end
