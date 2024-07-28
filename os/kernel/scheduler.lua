-- Component scheduler for multiple hardware.
-- Only for drivers to use multiple hardware

local group = {}
group.__index = group

local allGroups = {}

function group.new(cards, kind, where)
	local group = setmetatable({
		cards = cards,
		kind = kind,
		where = where,
		cur = 1,
	}, group)

	allGroups[kind] = allGroups[kind] or {}
	table.insert(allGroups[kind], group)

	return group
end

local function component_added(addr, kind)
	if not allGroups[kind] then return end
	for _, group in ipairs(allGroups[kind]) do
		if not group.where or group.where(addr) then
			table.insert(group.cards, addr)
		end
	end
end

local function component_removed(addr, kind)
	if not allGroups[kind] then return end
	for _, group in ipairs(allGroups[kind]) do
		local i
		for j, card in ipairs(group.cards) do
			if card == addr then i = j break end
		end
		if i then table.remove(group.cards, i) end
	end
end

Events.addCallback("component_added", component_added)
Events.addCallback("component_removed", component_removed)

function group:run(f, ...)
	local idx = self.cur
	self.cur = self.cur + 1
	if self.cur > #self.cards then
		self.cur = 1
	end
	if type(f) == "string" then
		return component.invoke(self.cards[idx], f, ...)
	end
	return f(self.cards[idx], ...)
end

function group:count()
	return #self.cards
end

function group:runAll(f, ...)
	for i=1,#self.cards do
		f(self.cards[i], ...)
	end
end

Scheduler = {}

function Scheduler.all(kind)
	local cards = {}
	for card in component.list(kind) do
		table.insert(cards, card)
	end
	return group.new(cards, kind)
end

function Scheduler.allWhere(kind, requirement)
	local cards = {}
	for card in component.list(kind) do
		if requirement(card) then
			table.insert(cards, card)
		end
	end
	return group.new(cards, kind, requirement)
end
