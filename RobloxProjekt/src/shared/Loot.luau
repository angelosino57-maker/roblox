local Rarity = require(script.Parent.Config.Rarity)

local Loot = {}

local function effectiveWeights(entries, luck: number)
	local weights, total = {}, 0
	for i, entry in entries do
		local w = entry.weight
		if Rarity.index(entry.rarity) >= Rarity.LUCK_FROM then
			w *= luck
		end
		weights[i] = w
		total += w
	end
	return weights, total
end

function Loot.pick(entries, rng: Random, luck: number)
	local weights, total = effectiveWeights(entries, luck)
	local r = rng:NextNumber() * total
	for i, entry in entries do
		r -= weights[i]
		if r < 0 then
			return entry
		end
	end
	return entries[#entries]
end

function Loot.probabilities(entries, luck: number)
	local weights, total = effectiveWeights(entries, luck)
	local result = {}
	for i, entry in entries do
		result[entry.id] = weights[i] / total
	end
	return result
end

return Loot
