pool = {}
pool.__index = pool

--[[
	Creates a new pool.
	Spec should be a list of key data with some extra config options. IE,
	local myObjectPool = pool.define {
		"normalKey",
		{
			"arrayWeShouldReuse",
			create = {},
			reset = table.clean,
		},
		prealloc = 20,
		maximum = 50,
	}
]]
function pool.define(spec)
	local p = setmetatable({
		spec = spec,
		pool = {},
	}, pool)
	if p.spec.prealloc then
		for i=1,p.spec.prealloc do
			p:prepare()
		end
	end
	return p
end

function pool:prepare(n)
	if n then
		for i=1,n do
			self:prepare()
		end
		return
	end

	if self.spec.maximum then
		if #self.pool >= self.spec.maximum then
			return
		end
	end

	local obj = {}
	for _, key in ipairs(self.spec) do
		if type(key) == "string" then
			obj[key] = nil
		elseif type(key) == "table" then
			local field = key[1]
			if type(key.create) == "function" then
				obj[field] = key.create()
			elseif type(key.create) == "table" then
				obj[field] = table.copy(key.create)
			else
				obj[field] = nil
			end
		end
	end
	table.insert(self.pool, obj)
end

function pool:alloc()
	if #self.pool > 0 then
		local obj = self.pool[#self.pool]
		self.pool[#self.pool] = nil
		return obj
	else
		self:prepare()
		return self:alloc()
	end
end

function pool:free(object)
	for _, key in ipairs(self.spec) do
		if type(key) == "string" then
			object[key] = nil
		elseif type(key) == "table" then
			local field = key[1]
			if type(key.reset) == "function" then
				key.reset(object[field])
			else
				object[field] = nil
			end
		end
	end
	table.insert(self.pool, object)
end

return pool
