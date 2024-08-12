local args = ...
local term = require("term")
local syscalls = require("syscalls")

local file = args[1]
if not file then
	print("No input file")
	return
end
local cx, cy = 1, 1
local ocx, ocy = 1, 1
local lines = {}
local lines2 = {}
local offX = 0
local offY = 0
local modified = false
local message = "Editing " .. file
local readonly = false
if io.readonly(file) then
	message ="Reading " .. file
	readonly = true
end

if io.exists(file) then
	-- read the file
	for line in io.lines(file) do
		table.insert(lines, line)
	end
end

local function getCharWidth(char)
	if #char ~= 1 then local w = 0 for i = 1,#char do w = w + getCharWidth(char:sub(i,i)) end return w end
	if char == "\t" then return 4 else return 1 end
end

local function getRenderCursorPos(x,y,offx,offy,line)
	return getCharWidth(line:sub(1,x-1)) - offx + 1, y - offy
end

local function computeRenderLine(line,w)
	line = line:gsub("\t", "    ")
	return line:sub(offX+1)
end

local function goUp(w, h)
	cy = cy - 1
	if cy < 1 then cy = 1 end
	local _, rcy = getRenderCursorPos(cx, cy, offX, offY, lines[cy] or "")
	if rcy < 1 then
		offY = offY - 1
		local old = term.getChar(ocx, ocy)
		term.moveTo(ocx, ocy)
		io.write(io.stdout, old)
		io.flush(io.stdout)
		term.shift(0, 1)
		for i=h,2,-1 do
			lines2[i] = lines2[i-1]
		end
		lines2[1] = nil
	end
	cx = math.min(cx, #(lines[cy] or "")+1)
end

local function goDown(w, h)
	cy = cy + 1
	if cy > #lines then cy = #lines end
	local _, rcy = getRenderCursorPos(cx, cy, offX, offY, lines[cy] or "")
	if rcy > h then
		offY = offY + 1
		local old = term.getChar(ocx, ocy)
		term.moveTo(ocx, ocy)
		io.write(io.stdout, old)
		io.flush(io.stdout)
		term.shift(0, -1)
		for i=1,h-1 do
			lines2[i] = lines2[i+1]
		end
		lines2[h] = nil
	end
	cx = math.min(cx, #(lines[cy] or "")+1)
end

local function fixHorizonalOffset(w,h)
	local rcx,rcy = getRenderCursorPos(cx,cy,offX,offY,lines[cy] or "")

	if rcx > w then
		local offset = rcx-w

		offX = offX + offset

		local old = term.getChar(ocx, ocy)
		term.moveTo(ocx, ocy)
		io.write(io.stdout, old)
		io.flush(io.stdout)
		term.shift(-offset,0)

		-- for now, just let it rerender, not worth it
		for i = 1,h do
			lines2[i] = computeRenderLine(lines[offY+i-1] or "",w)
		end
	elseif rcx < 1 then
		local offset = -rcx + 1

		offX = offX - offset

		local old = term.getChar(ocx, ocy)
		term.moveTo(ocx, ocy)
		io.write(io.stdout, old)
		io.flush(io.stdout)

		term.shift(offset,0)

		-- for now, just let it rerender, not worth it
		for i = 1,h do
			lines2[i] = computeRenderLine(lines[offY+i-1] or "",w)
		end
	end
end

local function goLeft(w,h)
	cx = cx - 1
	if cx < 1 then
		goUp(w, h)

		cx = #(lines[cy] or "")+1
	end

	fixHorizonalOffset(w,h)
end

local function goRight(w,h)
	cx = cx + 1
	if cx > #(lines[cy] or "")+1 then
		goDown(w, h)

		cx = 1
	end

	fixHorizonalOffset(w,h)
end

term.clear()

while true do
	local w, h = term.getWidth(), term.getHeight()-1
	for i=1,h do
		local j = i + offY
		if not lines[j] and not lines2[i] then break end
		local line = lines[j] or ""
		local rline = computeRenderLine(line, w)
		if rline ~= lines2[i] then
			term.clearLine(i)
			if lines[j] then
				term.moveTo(1, i)
				io.write(io.stdout, rline)
				io.flush(io.stdout)
			end
		end
		lines2[i] = rline
	end
	local rcx,rcy = getRenderCursorPos(cx,cy,offX,offY,lines[cy] or "")
	term.moveTo(rcx,rcy)
	term.setForeground(0, 0, 0)
	term.setBackground(255, 255, 255)
	io.write(io.stdout, term.getChar(rcx,rcy))
	io.flush()
	term.moveTo(1, h+1)
	term.clearLine(h+1)
	io.write(message, " ", cx, ":", cy)
	io.flush()
	term.setForeground(255, 255, 255)
	term.setBackground(0, 0, 0)

	if syscalls.keyboard_isKeyPressed("up") then
		goUp(w, h)
	elseif syscalls.keyboard_isKeyPressed("down") then
		goDown(w,h)
	elseif syscalls.keyboard_isKeyPressed("left") then
		goLeft(w,h)
	elseif syscalls.keyboard_isKeyPressed("right") then
		goRight(w,h)
	elseif syscalls.keyboard_isKeyPressed("control w") then
		if modified then
			term.moveTo(1, h+1)
			term.clearLine(h+1)
			io.write("You have unsaved changes. Exit anyways? [y/N] ")
			local c = io.read("l")
			if c:lower():sub(1, 1) == "y" then
				term.clear()
				break
			else
				term.shift(0, 1)
				lines2[1] = nil
			end
		else
			-- If you have unsaved work, fuck you
			term.clear()
			break
		end
	elseif syscalls.keyboard_isKeyPressed("control r") then
		for i=1,h do
			lines2[i] = nil
		end
	elseif syscalls.keyboard_isKeyPressed("control s") then
		if readonly then
			term.moveTo(1, h+1)
			term.clearLine(h+1)
			io.write("File is in readonly mode")
			io.flush()
			local schedule = syscalls.computer_uptime()+1
			while syscalls.computer_uptime() < schedule do coroutine.yield() end
		else
			local f, err = io.open(file, "w")
			if err then
				term.moveTo(1, h+1)
				term.clearLine(h+1)
				io.write(err)
				io.flush()
				local schedule = syscalls.computer_uptime()+1
				while syscalls.computer_uptime() < schedule do coroutine.yield() end
			else
				for i=1,#lines do
					io.write(f, lines[i], '\n')
				end
				io.flush(f)
				io.close(f)
			end
			modified = false
		end
	elseif syscalls.keyboard_isKeyPressed("enter") then
		local line = lines[cy] or ""
		lines[cy] = line:sub(1, cx-1)
		table.insert(lines, cy+1, line:sub(cx))
		goDown(w, h)
	elseif syscalls.keyboard_isKeyPressed("back") then
		local line = lines[cy] or ""
		if cx == 1 then
			table.remove(lines, cy)
			goUp(w, h)
		else
			local pre = line:sub(1, cx-2)
			local after = line:sub(cx)
			lines[cy] = pre .. after
			cx = cx - 1
		end
	else
		local t = syscalls.keyboard_getText()
		if t and #t > 0 then
			local i = 1
			while true do
				local c = t:sub(i, i)
				if i > #t or c == "\n" then
					local line = lines[cy] or ""
					local pre = line:sub(1,cx-1)
					local post = line:sub(cx)
					local chunk = t:sub(1, i-1)
					lines[cy] = pre .. chunk .. post
					cx = cx + #chunk
				elseif c == "\n" then
					local line = lines[cy] or ""
					lines[cy] = line:sub(1, cx-1)
					table.insert(lines, cy+1, line:sub(cx))
					cy = cy + 1
					if cy > #lines then cy = #lines end
					if cy - offY > h then
						offY = offY + 1
						local old = term.getChar(ocx, ocy)
						term.moveTo(ocx, ocy)
						io.write(io.stdout, old)
						io.flush(io.stdout)
						term.shift(0, -1)
						for i=1,h-1 do
							lines2[i] = lines2[i+1]
						end
						lines2[h] = nil
					end
				end
				if i > #t then break end
				i = i + 1
			end
			modified = true
		end
	end

	local x, y = getRenderCursorPos(cx,cy,offX,offY,lines[cy] or "")
	if x ~= ocx or y ~= ocy then
		local old = term.getChar(ocx, ocy)
		term.moveTo(ocx, ocy)
		io.write(io.stdout, old)
		io.flush(io.stdout)
		ocx = x
		ocy = y
		term.moveTo(x, y)
	end

	coroutine.yield()
end
