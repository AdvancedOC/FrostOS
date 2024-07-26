local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local padder = "="

local function base64num(num,padding)
	if num == 0 then return alphabet:sub(1,1) end

	local result = ""

	while num > 0 do
		local n = num % 64
		result = string.sub(alphabet, n + 1, n + 1) .. result
		num = math.floor(num / 64)
	end

	if padding then
		while #result < padding do
			result = alphabet:sub(1,1) .. result
		end
	end

	return result
end

local function unbase64num(input)
	local num = 0

	for i = 1,#input do
		local n = #input - i
		local c = input:sub(i,i)

		local val = alphabet:find(c,nil,true) - 1

		local add = 64^n * val

		num = num + add
	end

	return num
end

local function encodeNumAsBinary(num,padlength)
	local output = ""

	while num > 0 do
		local char = tostring(math.floor(num % 2))
		output = char .. output
		num = math.floor(num/2)
	end

	if padlength then
		while #output < padlength do
			output = "0" .. output
		end
	end

	return output
end

local function binaryToNum(binary)
	local num = 0

	for i = 1,#binary do
		num = num * 2
		num = num + tonumber(binary:sub(i,i))
	end

	return num
end

local function base64(str)
	local bits = ""
	local out = ""

	for i = 1,#str do
		local ch = str:sub(i,i)
		bits = bits .. encodeNumAsBinary(ch:byte(),8)
	end

	for i = 1,#bits,6 do
		local stuff = bits:sub(i,i+5)
		while #stuff < 6 do stuff = stuff .. "0" end -- there might not be enough bits at the end, so the sub just cuts off

		local num = binaryToNum(stuff)

		local base64char = base64num(num,1)

		out = out .. base64char
	end

	while #out % 4 ~= 0 do
		out = out .. padder
	end

	return out
end

local function unbase64(enc)
	local bits = ""
	local out = ""

	for i = 1,#enc do
		local ch = enc:sub(i,i)
		local num
		if ch == "=" then
			num = 0
		else
			num = unbase64num(ch)
		end
		bits = bits .. encodeNumAsBinary(num,6)
	end

	local padcount = 0
	while enc:sub(#enc) == padder do
		padcount = padcount + 1
		enc = enc:sub(1,#enc-1)
	end

	for i = 1,#bits,8 do
		local stuff = bits:sub(i,i+7)
		while #stuff < 8 do stuff = stuff .. "0" end -- there might not be enough bits at the end, so the sub just cuts off
		                                             -- although this means it'll probably be removed because it's caused by padding

		local num = binaryToNum(stuff)

		local char = string.char(num)

		out = out .. char
	end

	for i = 1,padcount do out = out:sub(1,#out-1) end

	return out
end

return {
	encode = base64,
	decode = unbase64
}
