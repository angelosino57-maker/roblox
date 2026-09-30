-- Formen eines Brainrots: Gold (mehr Geld), Diamant (mehr Glück an der Wolke), Regenbogen (beides).
local Mutations = {}

Mutations.list = {
	{ id = "gold", name = "Gold", icon = "🪙", money = 3, luck = 0, chance = 0.06, color = Color3.fromRGB(255, 205, 60) },
	{ id = "diamond", name = "Diamant", icon = "💎", money = 1.5, luck = 0.5, chance = 0.03, color = Color3.fromRGB(150, 235, 255) },
	{ id = "rainbow", name = "Regenbogen", icon = "🌈", money = 5, luck = 1, chance = 0.007, color = Color3.fromRGB(255, 80, 200) },
}

Mutations.byId = {}
for _, m in Mutations.list do
	Mutations.byId[m.id] = m
end

return Mutations
