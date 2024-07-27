term = {}

function term.escape(...)
	local out = "\x1B"
	local c = select("#", ...)
	for i=1,c do
		local val = select(i, ...)
		out = out .. tostring(val)
	end
	out = out .. "\x1B"
	return out
end

function term.send(...)
	io.write(io.stdout, term.escape(...))
	io.flush(io.stdout)
end

function term.readPassword()
	term.send("P*")
	local line = io.read(io.stdin, "l")
	term.send("P")
	return line
end

function term.setForeground(r, g, b)
	return term.send('F', r, ';', g, ';', b)
end

function term.setBackground(r, g, b)
	return term.send('B', r, ';', g, ';', b)
end

function term.clear()
	return term.send('C')
end

function term.clearLine(y)
	return term.send('C', y)
end

function term.resetForeground()
	return term.send('FR')
end

function term.move(x, y)
	return term.send('MR', x, ';', y)
end

function term.moveTo(x, y)
	return term.send('MR', x, ';', y)
end

function term.resetBackground()
	return term.send('BR')
end

return term
