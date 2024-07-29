local keys = {}

-- absolutely robbed this shit from OpenOS lol
keys["1"]           = 0x02
keys["2"]           = 0x03
keys["3"]           = 0x04
keys["4"]           = 0x05
keys["5"]           = 0x06
keys["6"]           = 0x07
keys["7"]           = 0x08
keys["8"]           = 0x09
keys["9"]           = 0x0A
keys["0"]           = 0x0B
keys.a               = 0x1E
keys.b               = 0x30
keys.c               = 0x2E
keys.d               = 0x20
keys.e               = 0x12
keys.f               = 0x21
keys.g               = 0x22
keys.h               = 0x23
keys.i               = 0x17
keys.j               = 0x24
keys.k               = 0x25
keys.l               = 0x26
keys.m               = 0x32
keys.n               = 0x31
keys.o               = 0x18
keys.p               = 0x19
keys.q               = 0x10
keys.r               = 0x13
keys.s               = 0x1F
keys.t               = 0x14
keys.u               = 0x16
keys.v               = 0x2F
keys.w               = 0x11
keys.x               = 0x2D
keys.y               = 0x15
keys.z               = 0x2C

keys.apostrophe      = 0x28
keys.at              = 0x91
keys.back            = 0x0E -- backspace
keys.backslash       = 0x2B
keys.capital         = 0x3A -- capslock
keys.colon           = 0x92
keys.comma           = 0x33
keys.enter           = 0x1C
keys.equals          = 0x0D
keys.grave           = 0x29 -- accent grave
keys.lbracket        = 0x1A
keys.lcontrol        = 0x1D
keys.lmenu           = 0x38 -- left Alt
keys.lshift          = 0x2A
keys.minus           = 0x0C
keys.numlock         = 0x45
keys.pause           = 0xC5
keys.period          = 0x34
keys.rbracket        = 0x1B
keys.rcontrol        = 0x9D
keys.rmenu           = 0xB8 -- right Alt
keys.rshift          = 0x36
keys.scroll          = 0x46 -- Scroll Lock
keys.semicolon       = 0x27
keys.slash           = 0x35 -- / on main keyboard
keys.space           = 0x39
keys.stop            = 0x95
keys.tab             = 0x0F
keys.underline       = 0x93

-- Keypad (and numpad with numlock off)
keys.up              = 0xC8
keys.down            = 0xD0
keys.left            = 0xCB
keys.right           = 0xCD
keys.home            = 0xC7
keys["end"]         = 0xCF
keys.pageUp          = 0xC9
keys.pageDown        = 0xD1
keys.insert          = 0xD2
keys.delete          = 0xD3

-- Function keys
keys.f1              = 0x3B
keys.f2              = 0x3C
keys.f3              = 0x3D
keys.f4              = 0x3E
keys.f5              = 0x3F
keys.f6              = 0x40
keys.f7              = 0x41
keys.f8              = 0x42
keys.f9              = 0x43
keys.f10             = 0x44
keys.f11             = 0x57
keys.f12             = 0x58
keys.f13             = 0x64
keys.f14             = 0x65
keys.f15             = 0x66
keys.f16             = 0x67
keys.f17             = 0x68
keys.f18             = 0x69
keys.f19             = 0x71

-- Japanese keyboards
keys.kana            = 0x70
keys.kanji           = 0x94
keys.convert         = 0x79
keys.noconvert       = 0x7B
keys.yen             = 0x7D
keys.circumflex      = 0x90
keys.ax              = 0x96

-- Numpad
keys.numpad0         = 0x52
keys.numpad1         = 0x4F
keys.numpad2         = 0x50
keys.numpad3         = 0x51
keys.numpad4         = 0x4B
keys.numpad5         = 0x4C
keys.numpad6         = 0x4D
keys.numpad7         = 0x47
keys.numpad8         = 0x48
keys.numpad9         = 0x49
keys.numpadmul       = 0x37
keys.numpaddiv       = 0xB5
keys.numpadsub       = 0x4A
keys.numpadadd       = 0x4E
keys.numpaddecimal   = 0x53
keys.numpadcomma     = 0xB3
keys.numpadenter     = 0x9C
keys.numpadequals    = 0x8D

local aliases = {
	shift = "lshift",
	backspace = "back",
	control = "lcontrol"
}

local invkeys = {} -- inverse lookup table because memory usage can suck my dick

if MemoryConservative then -- performance vs ram usage tradeoff
	invkeys = setmetatable(invkeys,{
		__index = function (tab,k)
			for k2,v in pairs(keys) do
				if v == k then return k2 end
			end
		end
	})
else
	for k,v in pairs(keys) do invkeys[v] = k end
end

local downkeys = {}

local justpressed = {}
local justreleased = {}

local function keyPressed(keyboardAddr, char, code, playerName)
	downkeys[code] = true
	justpressed[code] = computer.uptime()
end

local function keyReleased(keyboardAddr, char, code, playerName)
	downkeys[code] = false
	justreleased[code] = computer.uptime()
end

-- local function clipboardThing(keyboardAddr, value, playerName)

-- end

Events.addCallback("key_down", keyPressed)
Events.addCallback("key_up", keyReleased)
-- Events.addCallback("clipboard", clipboardThing)

local function getKey(proc, label)
	label = aliases[label] or label
	return keys[label] or 0x00
end

local function getLabel(proc, key)
	return invkeys[key] or "none"
end

local function isControlCharacter(proc, char)
	return type(char) == "number" and (char < 0x20 or (char >= 0x7F and char <= 0x9F))
end

local function isKeyDown(proc, key)
	local segments = string.split(key, " ")

	for i = 1,#segments do
		local segment = segments[i]

		if type(segment) == "string" then segment = getKey(nil, segment) end

		if not downkeys[segment] then return false end
	end

	return true
end

local function isKeyUp(proc, key)
	local segments = string.split(key, " ")

	for i = 1,#segments do
		local segment = segments[i]

		if type(segment) == "string" then segment = getKey(nil, segment) end

		if downkeys[segment] then return false end
	end

	return true
end

local function isKeyPressed(proc,key)
	local segments = string.split(key, " ")

	for i = 1,#segments-1 do
		local segment = segments[i]

		if type(segment) == "string" then segment = getKey(nil, segment) end

		if not downkeys[segment] then return false end
	end

	local actkey = segments[#segments]

	if type(actkey) == "string" then actkey = getKey(nil, actkey) end


	if justpressed[actkey] then
		local timePressed = justpressed[actkey]
		local curTime = computer.uptime()
		justpressed[actkey] = nil
		if curTime-timePressed < 0.2 then
			return true
		end
	end

	return false
end

local function isKeyReleased(proc,key)
	local segments = string.split(key, " ")

	for i = 1,#segments-1 do
		local segment = segments[i]

		if type(segment) == "string" then segment = getKey(nil, segment) end

		if not downkeys[segment] then return false end
	end

	local actkey = segments[#segments]

	if type(actkey) == "string" then actkey = getKey(nil, actkey) end

	if justreleased[actkey] then
		local timePressed = justreleased[actkey]
		local curTime = computer.uptime()
		justreleased[actkey] = nil
		if curTime-timePressed < 0.2 then
			return true
		end
	end

	return false
end

local function getText(proc)
	if Events.inQueue("key_down") then
		local keyboardAddr, char, code, player = Events.pull("key_down", 0.001) -- the timeout should never happen anyway
		if not isControlCharacter(nil, char) then
			return string.char(char)
		end
	end
	if Events.inQueue("clipboard") then
		local keyboardAddr, value, player = Events.pull("clipboard", 0.001)
		return value
	end

	return ""
end

return function (process)
	process:defineSyscall("keyboard_getKey", getKey)
	process:defineSyscall("keyboard_getLabel", getLabel)
	process:defineSyscall("keyboard_isControlCharacter", isControlCharacter)

	process:defineSyscall("keyboard_isKeyDown", isKeyDown)
	process:defineSyscall("keyboard_isKeyUp", isKeyUp)

	process:defineSyscall("keyboard_isKeyPressed", isKeyPressed)
	process:defineSyscall("keyboard_isKeyReleased", isKeyReleased)

	process:defineSyscall("keyboard_getText", getText)
end
