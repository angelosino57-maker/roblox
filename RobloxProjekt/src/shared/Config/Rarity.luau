local Rarity = {}

Rarity.order = { "Gewöhnlich", "Ungewöhnlich", "Selten", "Episch", "Legendär", "Mythisch", "Geheim" }

Rarity.multiplier = {
	["Gewöhnlich"] = 1,
	["Ungewöhnlich"] = 1.2,
	["Selten"] = 1.5,
	["Episch"] = 2,
	["Legendär"] = 3,
	["Mythisch"] = 5,
	["Geheim"] = 8,
}

Rarity.color = {
	["Gewöhnlich"] = Color3.fromRGB(200, 200, 200),
	["Ungewöhnlich"] = Color3.fromRGB(90, 220, 90),
	["Selten"] = Color3.fromRGB(70, 150, 255),
	["Episch"] = Color3.fromRGB(180, 80, 255),
	["Legendär"] = Color3.fromRGB(255, 200, 40),
	["Mythisch"] = Color3.fromRGB(255, 60, 120),
	["Geheim"] = Color3.fromRGB(20, 255, 220),
}

-- Luck wirkt auf alle Seltenheiten ab diesem Index ("Selten").
Rarity.LUCK_FROM = 3

local indexOf = {}
for i, name in Rarity.order do
	indexOf[name] = i
end

function Rarity.index(name: string): number
	local i = indexOf[name]
	assert(i, "unknown rarity " .. tostring(name))
	return i
end

return Rarity
