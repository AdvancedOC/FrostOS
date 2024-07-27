-- To update the /os_install file open FrostOS and probably run structure / -i /.git -i /tmp -i /mnt -i /os/etc > /os_install as administrator.

local args = ...

local folders = {}

local hidden = {}

local i = 1
while args[i] do
	if args[i] == "-i" or args[i] == "--ignore" then
		table.insert(hidden, args[i+1])
		i = i + 2
	else
		table.insert(folders, args[i])
		i = i + 1
	end
end

local function pjoin(folder, p)
	if folder == "/" then return "/" .. p end
	return folder .. "/" .. p
end

local function writePaths(path)
	for _, forbidden in ipairs(hidden) do
		if forbidden == path then return end
	end
	if io.isFile(path) then
		print("file " .. path)
	elseif io.isMount(path) then
		print("mount " .. path)
	elseif io.isSymlink(path) then
		print("symlink " .. path)
	elseif io.isDirectory(path) then
		print("directory " .. path)
		for _, name in ipairs(io.list(path)) do
			writePaths(pjoin(path, name))
		end
	end
end

for _, folder in ipairs(folders) do
	writePaths(folder)
end
