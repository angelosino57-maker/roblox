local Expect = {}

local function show(v)
	if typeof(v) == "table" then
		return "<table>"
	end
	return tostring(v)
end

local function prefix(msg)
	return if msg then msg .. ": " else ""
end

function Expect.eq(actual, expected, msg)
	if actual ~= expected then
		error(prefix(msg) .. "expected " .. show(expected) .. ", got " .. show(actual), 2)
	end
end

function Expect.truthy(v, msg)
	if not v then
		error(prefix(msg) .. "expected truthy, got " .. show(v), 2)
	end
end

function Expect.near(a, b, tol, msg)
	if math.abs(a - b) > tol then
		error(prefix(msg) .. string.format("expected %.4f ± %.4f, got %.4f", b, tol, a), 2)
	end
end

function Expect.errors(fn, msg)
	local ok = pcall(fn)
	if ok then
		error(prefix(msg) .. "expected an error", 2)
	end
end

return Expect
