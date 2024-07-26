local args = ...
local syscalls = require("syscalls")

local card = args[1] or "data"

local function gettime()
	return syscalls.computer_uptime()
end

local function benchmarkFunc(name, duration, f, ...)
	print("Started benchmarking " .. name .. "...")
	local t = gettime()
	local amount = 0
	local lastYield = gettime()
	while gettime() - t <= duration do
		f(...)
		amount = amount + 1
		if gettime() - lastYield >= 1 then
			coroutine.yield()
			lastYield = gettime()
		end
	end
	print("Finished benchmarking " .. name)
	return amount
end

local benchmarks = {}

function benchmarks.data()
	local durations = 3
	local dummydata = string.rep("dummy data lol", 1024)
	local sha256 = benchmarkFunc("sha256", durations, syscalls.data_sha256, dummydata)
	local encode64 = benchmarkFunc("encode64", durations, syscalls.data_encode64, dummydata)
	local correctData = syscalls.data_encode64(dummydata)
	local decode64 = benchmarkFunc("decode64", durations, syscalls.data_decode64, correctData)

	print("Data Card Driver Speed:")
	print(string.format("sha256 (%d total) - %fs average", sha256, durations / sha256))
	print(string.format("encode64 (%d total) - %fs average", encode64, durations / encode64))
	print(string.format("decode64 (%d total) - %fs average", decode64, durations / decode64))
end

if not benchmarks[card] then
	error("Unsupported card type: " .. card)
end

benchmarks[card]()
