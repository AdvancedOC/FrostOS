local syscalls = require("syscalls")

process = {}

function process.current()
	return syscalls.pself()
end

function process.info(pid)
	return syscalls.pinfo(pid or process.current())
end

function process.parent(pid)
	return syscalls.pparent(pid or process.current())
end

function process.cwd()
	return syscalls.pwd()
end

function process.spawn(name, files, environment, cwd, ring)
    local fileMappings
    if files then
        fileMappings = {}
        for fd, file in pairs(files) do
            if type(file) == "table" and getmetatable(file) == io then
                fileMappings[fd] = file.fd
            else
                fileMappings[fd] = file
            end
        end
    end
    return syscalls.pspawn(name, fileMappings, environment, cwd, ring)
end

function process.exec(pid, file, ...)
    if type(file) == "string" then
        local f, err = io.open(file)
        if not f then return false, err end
        local ok, err = process.exec(pid, f, ...)
        f:close()
        return ok, err
    end
    if type(file) == "table" and getmetatable(file) == io then
        file = file.fd
    end
    return syscalls.pexec(pid, file, ...)
end

function process.status(pid)
    return syscalls.pstatus(pid)
end

function process.kill(pid)
	return syscalls.pkill(pid)
end

function process.children(pid)
	return syscalls.ptree(pid or process.current())
end

function process.all()
	return syscalls.pall()
end

function process.getenv(name)
	return syscalls.penv(name)
end

function process.getenvs()
	return syscalls.penvs()
end

function process.envsWith(extra)
	local env = process.getenvs()
	for k, v in pairs(extra) do
		env[k] = v
	end
	return env
end

return process
