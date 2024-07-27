local syscalls = require("syscalls")
local process = require("process")

local symbols = {";", ">", "|", "\n"}

local function tableContains(tab,val)
	for i = 1,#symbols do local sep = symbols[i] if sep == val then return true end end
	return false
end

local function isBackslashed(str, i)
	if str:sub(i - 1, i - 1) == "\\" then
		return not isBackslashed(str, i - 1)
	end
	return false
end

local function isWhitespace(char)
	return char:match("%s") ~= nil
end

-- implementing a shell lexer

local function lex(fullinp)
	local segments = {}
	local current = ""

	local i = 1
	while i <= #fullinp do
		local ch = fullinp:sub(i, i)

		if tableContains(symbols, ch) and not isBackslashed(fullinp, i) then
			if current ~= "" then
				segments[#segments+1] = {type="str", val=current}
				current = ""
			end
			segments[#segments+1] = {type="symbol", val=ch}
		elseif isWhitespace(ch) and not isBackslashed(fullinp, i) then
			if current ~= "" then
				segments[#segments+1] = {type="str", val=current}
				current = ""
			end
		elseif ch == '"' then
			local str = ""
			i = i + 1

			while fullinp:sub(i, i) ~= '"' or isBackslashed(str,i) do
				local char = fullinp:sub(i, i)

				if char == "" then return nil, "unterminated string" end

				if char == '"' and isBackslashed(str, i) then
					str = str .. char
				elseif char == "\\" then
					if isBackslashed(str,i) then str = str .. char end
				else
					str = str .. char
				end

				i = i + 1
			end

			-- we are on the closing quote

			current = current .. str -- this lets us still have fancy bullshit like echo h"i g"uys
		elseif ch == "\\" then
			if isBackslashed(fullinp, i) then
				current = current .. ch
			end
		elseif ch == "#" then
			-- comment, skip to next newline or end of file

			while fullinp:sub(i, i) ~= "\n" and fullinp:sub(i,i) ~= "" do
				i = i + 1
			end
		else
			current = current .. ch
		end

		i = i + 1
	end

	if #current > 0 then
		segments[#segments+1] = {type="str", val=current}
	end

	return segments
end

-- for i = 1, #parts do
-- 	print(parts[i].type, parts[i].val)
-- end

local Command = {}
Command.__index = Command

function Command:new(name, args)
	local cmd = {}
	setmetatable(cmd, Command)
	cmd.name = name
	cmd.args = args
	return cmd
end

local Pipeline = {}
Pipeline.__index = Pipeline

function Pipeline:new(commands)
	local pl = {}
	setmetatable(pl, Pipeline)
	pl.commands = commands
	return pl
end

local Statement = {}
Statement.__index = Statement

function Statement:new(pipeline, redirection)
	local stmt = {}
	setmetatable(stmt, Statement)
	stmt.pipeline = pipeline
	stmt.redirection = redirection
	return stmt
end

local function parse(tokens)
	local pipelines = {{}}
	local args = {}
	local redirection = nil

	local i = 1
	while i <= #tokens do
		local token = tokens[i]
		if token.type == "str" then
			table.insert(args, token.val)
		elseif token.type == "symbol" then
			if token.val == ";" or token.val == "\n" then
				if #args > 0 then
					table.insert(pipelines[#pipelines], Command:new(table.remove(args, 1), args))
					args = {}
					table.insert(pipelines, {})
				end
			elseif token.val == "|" then
				if #args > 0 then
					table.insert(pipelines[#pipelines], Command:new(table.remove(args, 1), args))
					args = {}
				end
			elseif token.val == ">" then
				redirection = tokens[i + 1].val
				i = i + 1
			end
		end
		i = i + 1
	end

	if #args > 0 then
		table.insert(pipelines[#pipelines], Command:new(table.remove(args, 1), args))
	end

	local statements = {}
	for _, pipeline in ipairs(pipelines) do
		if #pipeline > 0 then
			table.insert(statements, Statement:new(Pipeline:new(pipeline), redirection))
		end
	end

	return statements
end

local builtin = {}

function builtin.cd(args, stdout, stdin)
	local err = process.changeDirectory(args[1])
	if err then
		io.write(stdout, "Error: " .. err .. "\n")
		io.flush(stdout)
		return
	end
end

function builtin.which(args, stdout, stdin)
	local info = which(args[1])
	if type(info) == "function" then
		io.write(stdout, "Built-in shell command\n")
		return
	elseif type(info) == "string" then
		io.write(stdout, info, "\n")
	elseif info == nil then
		io.write(stdout, "Command not found\n")
	end
end

function which(command)
	if builtin[command] then return builtin[command] end

	local shellPath = "/usr/bin/?.lua:/usr/bin/?/init.lua:/os/bin/?.lua:/os/bin/?/init.lua:/mnt/?.lua:/mnt/?/init.lua"
	local shellConfig = "/\n:\n?\n"

	return package.pathOf(command, shellConfig, shellPath)
end

-- TODO: make io use separate buffers gosh darn it
io.stdout.buflimit = 0

local function awaitRam()
	repeat
		if Events then Events.process(0.01) end
		coroutine.yield()
	until syscalls.computer_freeMemory() > 10*1024
end

local function runStr(parsed)
	local runningProcs = {}

	local inToUse

	-- now loop the commands
	for i = 1,#parsed do
		local pipeline = parsed[i].pipeline
		for j = 1, #pipeline.commands do
			local program = which(pipeline.commands[j].name)
			if program then
				local progargs = table.copy(pipeline.commands[j].args)

				progargs[0] = pipeline.commands[j].name

				local outtouse
				local closeoutlater = false
				if j == #pipeline.commands then
					if parsed[i].redirection then
						if not io.allowed(parsed[i].redirection,3,"w") then print("Can't write to " .. parsed[i].redirection .. ": Operation not permitted.") break end
						outtouse = io.open(parsed[i].redirection, "w")
						closeoutlater = true
					else
						outtouse = io.stdout
					end
				else
					local c = ""
					-- we gotta make an output we can use as input to the next one
					local new = io.stream(function(data) c = c .. data end, function() return nil end, "w")
					local infornext = io.stream(function() end, function() local ret = c c = nil return ret end, "r")

					inToUse = infornext

					outtouse = new
				end

				local closeinlater = false
				local intouse
				if j == 1 then
					intouse = io.stdin
				else
					intouse = inToUse
					closeinlater = true
				end

				if outtouse then
					if type(program) == "function" then
						program(progargs, outtouse, intouse)
					elseif type(program) == "string" then
						awaitRam()
						local proc, err = process.spawn("Program " .. program, {
							[0] = outtouse,
							[1] = intouse,
							[2] = io.stderr.fd,
						}, nil, wd, 3)
						if not proc then
							print("Error: " .. err)
						end
						process.exec(proc, program, progargs)

						runningProcs[#runningProcs+1] = {proc=proc, out=outtouse, closeout = closeoutlater, inp=intouse, closein = closeinlater}
					end
				end
			else
				print("Unknown command: " .. pipeline.commands[j].name)
			end
		end
	end

	-- Wait for all processes to finish
	for i = 1,#runningProcs do
		local proc = runningProcs[i].proc
		while process.status(proc) ~= "dead" do
			coroutine.yield()
		end
		process.kill(proc)
		if runningProcs[i].closeout then
			runningProcs[i].out:flush()
			runningProcs[i].out:close()
		end
		if runningProcs[i].closein then
			runningProcs[i].inp:close()
		end
	end
end

if not syscalls.computer_dangerouslyLowRAM() then -- don't load scuterc for memory reasons
	if io.exists("/usr/etc/.scuterc") then
		awaitRam()
		log("Running /usr/etc/.scuterc")
		local rc = io.open("/usr/etc/.scuterc", "r")

		if rc then
			local data = rc:read("a")

			local tokens,err = lex(data)

			if not tokens then print("Failed to lex /usr/etc/.scuterc! " .. tostring(err)) end

			local parsed,errnew = parse(tokens)

			if not parsed then print("Failed to parse /usr/etc/.scuterc! " .. tostring(errnew)) end

			runStr(parsed)
		end
	end
end

while true do
	local wd = process.cwd()

	local folderColor = {
		r = 0,
		g = 255,
		b = 0,
	}

	if io.readonly(wd) then
		folderColor.b = 223
		folderColor.g = 223
	end

	io.write(io.stdout, "\x1BF", folderColor.r, ";", folderColor.g,";", folderColor.b, "\x1B", wd, " \x1BF0;233;233\x1B>\x1BFR\x1B ")
	-- io.write(" > ")
	local line = io.read(io.stdin, "l")

	local tokens,err = lex(line)

	if not tokens then print("Failed to lex command! " .. tostring(err)) end

	local parsed,errnew = parse(tokens)

	if not parsed then print("Failed to parse command! " .. tostring(errnew)) end

	runStr(parsed)

	coroutine.yield()
end
