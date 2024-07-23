-- This is the kernel loadfile.
-- This should ONLY be accessible to the kernel.
function loadfile(file)
    local boot = computer.getBootAddress()
    local invoke = component.invoke

    local handle, err = invoke(boot, "open", file)
    assert(handle, err)
    local buf = ""
    repeat
        local data, reason = invoke(boot, "read", handle, math.huge)
        assert(data or not reason, reason)
        buf = buf .. (data or "")
    until not data

    invoke(boot, "close", handle)
    return load(buf, "=" .. file, "bt", _G)
end

-- Kernel dofile.
function dofile(file, ...)
    return loadfile(file)(...)
end

dofile("os/kernel.lua")
