local internetCards = Scheduler.all("internet")

local function internet_request(proc, url, postdata, headers)
	return internetCards:run("request", url, postdata, headers)
end

local function internet_isTCPEnabled(proc)
	return internetCards:run("isTcpEnabled")
end

local function internet_isHTTPEnabled(proc)
	return internetCards:run("isHttpEnabled")
end

local function internet_connect(proc, address, port)
	return internetCards:run("connect", address, port)
end

local function internet_download(proc, address)
	local request = internet_request(proc, address)

	local succ,err = pcall(request.finishConnect)

	if not succ then return nil, err end

	local fulldata = ""

	while true do
		local data = request.read(math.huge)

		if data then fulldata = fulldata .. data else break end
	end

	return fulldata
end

return function(process)
	process:defineSyscall("internet_request", internet_request)
	process:defineSyscall("internet_isTCPEnabled", internet_isTCPEnabled)
	process:defineSyscall("internet_isHTTPEnabled", internet_isHTTPEnabled)
	process:defineSyscall("internet_connect", internet_connect)
	process:defineSyscall("internet_download", internet_download)
end
