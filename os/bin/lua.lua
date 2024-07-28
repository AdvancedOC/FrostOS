local args = ...
local term = require("term")
local syscalls = require("syscalls")

local years = {["Lua 5.2"] = "2015", ["Lua 5.3"] = "2020", ["Lua 5.4"] = "2024"}

function lon(value)
	if value == nil then return "nil" end
	if type(value) == "number" then
		return tostring(value)
	end
	if type(value) == "string" then
		local str = "\""
		for i=1,#value do
			local c = value:sub(i, i)
			if c == "\n" then
				str = str .. "\\n"
			elseif c == "\t" then
				str = str .. "\\t"
			elseif c == "\"" then
				str = str .. '"'
			else
				str = str .. c
			end
		end
		str = str .. "\""
		return str
	end
	if type(value) == "table" then
		local str = "{"
		local inList = {}
		for i=1,#value do
			inList[i] = true
			str = str .. lon(value[i]) .. ", "
		end
		for k, v in pairs(value) do
			if not inList[k] then
				if type(k) == "string" then
					if lon(k) == '"' .. k .. '"' then
						str = str .. k .. " = " .. lon(v) .. ", "
					else
						str = str .. "[" .. lon(k) .. "] = " .. lon(v) .. ", "
					end
				else
					str = str .. "[" .. lon(k) .. "] = " .. lon(v) .. ", "
				end
			end
		end
		str = str:sub(1, -3) .. "}"
		return str
	end
	return "<" .. tostring(value) .. ">"
end

if #args == 0 then
	print(_VERSION .. "  Copyright (C) 1994-" .. years[_VERSION] or "2024" .. " Lua.org, PUC-Rio")
	while true do
		term.setForeground(0, 255, 13)
		io.write("> ")
		term.setForeground(255, 255, 255)
		local code = io.read("l")
		if code == nil or code == "" or code == "exit" then break end
		if code:sub(1,1) == "=" then code = code:sub(2) end
		local fun, err = load("return " .. code, "=repl", "t")
		if fun then
			local res = fun()
			if res ~= nil then print(res) end
		else
			local expr, err = load(code, "=repl", "t")
			if expr then
				expr()
			else
				print("Error: " .. err)
			end
		end
	end
else
	local file = args[1]
	local f, err = io.open(file, "r")
	if not f then error("Error: " .. err) end
	local code = ""
	while true do
		local data = io.read(f, "a")
		if not data then break end
		code = code .. data
	end
	io.close(f)
	local fun, err = load(code, "=" .. args[1], "t")
	if not fun then error("Error: " .. err) end
	fun()
end
