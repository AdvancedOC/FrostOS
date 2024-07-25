local args = ...

if #args == 0 then
    print("ld - System linker")
    print("\t<file> - Set <file> as input base file")
    print("\t-l<module> - Link <module> (specified as a Lua module, ex. -lprocess or -lfolder.file)")
    print("\t-L<folder> - Add <folder> to the search path. This only affects -l links after it.")
    return
end

local input
local output
local toLink = {}

local i = 1
while args[i] ~= nil do
    local arg = args[i]

    if string.startswith(arg, "-l") then
        local module = arg:sub(3)
        local path = package.pathOf(module)
        if not path then
            io.write(io.stderr, "Error: Unable to locate module " .. module .. "\n")
            return
        end
        table.insert(toLink, {module = module, file = path})
        i = i + 1
    elseif string.startswith(arg, "-L") then
        local folder = arg:sub(3)
        package.path = package.path .. ";" .. folder .. "/?.lua" .. ";" .. folder .. "/?/init.lua"
        i = i + 1
    elseif arg == "-o" or arg == "--out" then
        if output then
            io.write(io.stderr, "Error: Multiple output files\n")
            return
        end
        output = args[i+1]
        i = i + 2
    else
        if string.startswith(arg, "-") then
            io.write(io.stderr, "Error: Unknown argument\n")
            return
        end
        if input then
            io.write(io.stderr, "Error: Multiple input files\n")
            return
        end
        input = arg
        i = i + 1
    end
end

if not input then
    io.write(io.stderr, "Error: No input file\n")
    return
end

local function codeOf(path)
    local file = io.open(path)
    if not file then return "" end
    local all = io.read(file, "a")
    file:close()
    return all
end

local out = ""

for _, linkInfo in ipairs(toLink) do
    local module = linkInfo.module
    local code = codeOf(linkInfo.file)
    out = out .. "package.preload[\"" .. module .. "\"] = function(...)\n" .. code .. "\nend\n"
end
out = out .. codeOf(input)

if output then
	local outfile = io.open(output, "w")
	outfile:write(out)
	outfile:flush()
	outfile:close()
else
    io.write(io.stdout, out, "\n")
    io.flush(io.stdout)
end
