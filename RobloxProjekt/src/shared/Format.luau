-- Große Zahlen kurz: 1234 → "1.2K", 5600000 → "5.6M".
local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

function Format.short(n: number): string
	n = math.floor(n)
	if math.abs(n) < 1000 then
		return tostring(n)
	end
	local i = 1
	local v = n
	while math.abs(v) >= 1000 and i < #SUFFIXES do
		v /= 1000
		i += 1
	end
	local text = if math.abs(v) < 10 then string.format("%.2f", v) elseif math.abs(v) < 100 then string.format("%.1f", v) else string.format("%d", math.floor(v))
	if text:find(".", 1, true) then
		text = text:gsub("0+$", ""):gsub("%.$", "") -- nur Nachkommastellen kürzen
	end
	return text .. SUFFIXES[i]
end

return Format
