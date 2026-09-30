local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Expect = require(script.Parent.Expect)
local Loot = require(Shared.Loot)
local CloudConfig = require(Shared.Config.Cloud)

local entries = {
	{ id = "a", weight = 75, rarity = "Gewöhnlich" },
	{ id = "b", weight = 25, rarity = "Selten" },
}

return {
	{ "probabilities follow weights without luck", function()
		local p = Loot.probabilities(entries, 1)
		Expect.near(p.a, 0.75, 1e-9)
		Expect.near(p.b, 0.25, 1e-9)
	end },
	{ "luck multiplies only rarity >= Selten", function()
		local p = Loot.probabilities(entries, 3)
		-- a: 75, b: 25*3 = 75 -> 50/50
		Expect.near(p.a, 0.5, 1e-9)
		Expect.near(p.b, 0.5, 1e-9)
	end },
	{ "pick matches probabilities in a sample", function()
		local rng = Random.new(42)
		local counts = { a = 0, b = 0 }
		for _ = 1, 20000 do
			local e = Loot.pick(entries, rng, 1)
			counts[e.id] += 1
		end
		Expect.near(counts.b / 20000, 0.25, 0.02)
	end },
	{ "fruit rarity probabilities sum to 1", function()
		local sum = 0
		for _, p in Loot.probabilities(CloudConfig.drops, 1) do
			sum += p
		end
		Expect.near(sum, 1, 1e-9)
	end },
}
