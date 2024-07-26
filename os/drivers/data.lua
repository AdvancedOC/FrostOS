local sha256
local base64

local dataCards = Scheduler.all("data")

local function data_sha256(proc, data)
	if dataCards:count() == 0 then
		if not sha256 then sha256 = gio.dofile("/os/drivers/data/sha256.lua") end
		return sha256(data)
	else
		sha256 = nil
	end
	return dataCards:run("sha256", data)
end

local function data_encode64(proc, data)
	if dataCards:count() == 0 then
		if not base64 then base64 = gio.dofile("/os/drivers/data/base64.lua") end
		return base64.encode(data)
	else
		base64 = nil
	end
	return dataCards:run("encode64", data)
end

local function data_decode64(proc, data)
	if dataCards:count() == 0 then
		if not base64 then base64 = gio.dofile("/os/drivers/data/base64.lua") end
		return base64.decode(data)
	else
		base64 = nil
	end
	return dataCards:run("decode64", data)
end

return function(proc)
	proc:defineSyscall("data_sha256", data_sha256)
	proc:defineSyscall("data_encode64", data_encode64)
	proc:defineSyscall("data_decode64", data_decode64)
end
