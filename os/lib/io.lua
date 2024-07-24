-- TODO: IO Library
-- Provides buffered io in userspace (using syscalls)
local syscalls = require("syscalls")

io = {}
io.__index = io

function io:__gc()
    self:close()
end

function io.from(descriptor)
    return setmetatable({
        buffer = "",
        bufidx = 1,
        buflimit = 64,
        fd = descriptor,
    }, io)
end

io.stdout = io.from(0)
io.stdin = io.from(1)
io.stderr = io.from(2)

function io.open(file, mode)
    local fd, err = syscalls.fopen(file, mode)
    if not fd then return nil, err end
    return io.from(fd)
end

function io.close(file)
    return syscalls.fclose(file.fd)
end

function io.flush(file)
    file = file or io.stdout

    syscalls.fwrite(file.fd, file.buffer)
    file.buffer = ""
    file.bufidx = 1
end

function io.write(file, ...)
    local values = {...}
    for _, value in ipairs(values) do
        file.buffer = file.buffer .. tostring(value)
        if string.contains(file.buffer, "\n") or file.buffer == file.buflimit then
            -- Time to flush!
            file:flush()
        end
    end
end

function io.getc(file)
    file = file or io.stdin

    if file.buffer == "" then
        file.buffer = syscalls.fread(file.fd, file.buflimit)
    end
    local c = string.sub(file.buffer, file.bufidx, file.bufidx)
    if file.bufidx == #file.buffer then
        -- Oh no, we ran out of buffer
        file.buffer = syscalls.fread(file.fd, file.buflimit)
        file.bufidx = 1
    else
        file.bufidx = file.bufidx + 1
    end
    if c == nil then
        file.buffer = ""
        file.bufidx = 1
    end
    return c
end

function io.read(file, mode)
    if type(file) == "string" then
        return io.read(io.stdin, file)
    end

    mode = mode or "l"

    if mode == "a" then
        local buf
        while true do
            local c = file:getc()
            if c == nil then break end
            buf = (buf or "") .. c
        end
        return buf
    elseif mode == "l" then
        local buf
        while true do
            local c = file:getc()
            if c == nil or c == '\n' then break end
            buf = (buf or "") .. c
        end
        return buf
    elseif mode == "L" then
        local buf
        while true do
            local c = file:getc()
            if c == nil then break end
            buf = (buf or "") .. c
            if c == '\n' then break end
        end
        return buf
    end

    -- Unsupported mode, just default to reading line
    return io.read(file, "l")
end

function io.lines(path)
    local file = io.open(path)
    if not file then return function() return nil end end
    return function()
        if file == nil then return nil end
        local line = file:read("l")
        if line == nil then
            file:close()
            file = nil
        end
        return line
    end
end

function io.remove(path)

end

function io.exists(path)

end

function io.seek(path)

end

function io.mkdir(path)

end

function io.list(path)

end
