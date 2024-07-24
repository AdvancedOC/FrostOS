function string.split(s, sep)

end

function string.contains(s, sub)
    return string.find(s, sub, nil, true) ~= nil
end

function string.startswith(s,sub)
    return s:sub(1,#sub) == sub
end