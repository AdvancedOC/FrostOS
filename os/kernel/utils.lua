function string.escape_pattern(text)
    return text:gsub("([^%w])", "%%%1")
end


function string.contains(s, sub)
    return string.find(s, sub, nil, true) ~= nil
end

function string.startswith(s,sub)
    return s:sub(1,#sub) == sub
end

function string.split(inputstr, sep) sep=string.escape_pattern(sep) local t={}  for field,s in string.gmatch(inputstr, "([^"..sep.."]*)("..sep.."?)") do table.insert(t,field)  if s=="" then return t end end end