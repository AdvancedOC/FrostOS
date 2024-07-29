function string.escape_pattern(text)
	return text:gsub("([^%w])", "%%%1")
end

function string.contains(s, sub)
	return string.find(s, sub, nil, true) ~= nil
end

function string.startswith(s,sub)
	return s:sub(1,#sub) == sub
end

function string.endswith(s,sub)
	return s:sub(#s-#sub+1) == sub
end

function string.split(inputstr, sep)
	sep=string.escape_pattern(sep)
	local t={}
	for field,s in string.gmatch(inputstr, "([^"..sep.."]*)("..sep.."?)") do
		table.insert(t,field)
		if s=="" then
			return t
		end
	end
	return t
end

function table.copy(tab)
	local ntab = {}

	for k,v in pairs(tab) do
		if type(v) == "table" then
			ntab[k] = table.copy(v)
		else
			ntab[k] = v
		end
	end

	return ntab
end

function table.clear(t)
	local key = next(t)
	while key do t[key] = nil key = next(t, key) end
	return t
end

function JustDoGC()
	local mem = computer.freeMemory()
	for i=1,200 do
		local t = {}
		t = nil
		Events.process(0.01)
		-- GC!!!!
		if computer.freeMemory() > mem then break end
	end
end

---@param spaceNeeded? number
---@param attempts? integer
function AttemptGC(spaceNeeded, attempts)
	spaceNeeded = spaceNeeded or (16*1024)
	attempts = attempts or 200
	repeat
		Events.process(0.01)
		attempts = attempts - 1
	until computer.freeMemory() >= spaceNeeded or attempts < 1
end
