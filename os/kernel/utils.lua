function string.split(s, sep)

end

function string.contains(s, sub)
    return string.find(s, sub, nil, true) ~= nil
end
