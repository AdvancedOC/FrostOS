local args = ...

local process = require("process")

local info = process.info()

print("Program running at ring " .. tostring(info.ring))
