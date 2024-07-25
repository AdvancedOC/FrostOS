local datacard

local cl,ci = component.list, component.invoke

for uuid,name in cl("data") do
	datacard = uuid
	break
end

if not datacard then return function() end end

local function data_sha256(proc, data)
	return ci(datacard, "sha256", data)
end

local function data_encode64(proc, data)
	return ci(datacard, "encode64", data)
end

local function data_decode64(proc, data)
	return ci(datacard, "decode64", data)
end

return function(proc)
	proc:defineSyscall("data_sha256", data_sha256)
	proc:defineSyscall("data_encode64", data_encode64)
	proc:defineSyscall("data_decode64", data_decode64)
end
