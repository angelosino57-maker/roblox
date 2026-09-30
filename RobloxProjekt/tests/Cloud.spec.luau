local Shared = game:GetService("ReplicatedStorage").Shared
local Expect = require(script.Parent.Expect)
local Cloud = require(Shared.Cloud)
local Species = require(Shared.Config.Species)

local function data()
	return {
		creatures = {
			a = { id = "a", species = "schleimi", rarity = "Gewöhnlich" },
			b = { id = "b", species = "sternenwal", rarity = "Legendär", mutation = "gold" },
			c = { id = "c", species = "prismapfau", rarity = "Selten", mutation = "diamond" },
		},
		equipped = { "a", "b", "c" },
		cloud = { luck = 0, speed = 0, auto = 0 },
	}
end

return {
	{ "income: rarity × form, summed over equipped", function()
		local d = data()
		Expect.eq(Cloud.income(d.creatures.a), 2)
		Expect.eq(Cloud.income(d.creatures.b), 750)
		Expect.eq(Cloud.income(d.creatures.c), 30)
		Expect.eq(Cloud.totalIncome(d), 782)
		Expect.eq(Cloud.skipValue(d.creatures.a), 20)
	end },
	{ "luck grows with cloud level, diamond forms and bonus", function()
		local d = data()
		Expect.near(Cloud.luck(d), 1.5, 1e-9)
		d.cloud.luck = 4
		Expect.near(Cloud.luck(d), 2 * 1.5, 1e-9)
		Expect.near(Cloud.luck(d, 1.5), 2 * 1.5 * 1.5, 1e-9)
	end },
	{ "drops get faster with speed level, auto farm is slower", function()
		Expect.eq(Cloud.interval(0), 6)
		Expect.truthy(Cloud.interval(5) < Cloud.interval(4))
		Expect.eq(Cloud.interval(100), 1)
		Expect.eq(Cloud.interval(0, 2), 3)
		Expect.eq(Cloud.autoInterval(0, 0), nil)
		Expect.eq(Cloud.autoInterval(0, 1), 12)
		Expect.truthy(Cloud.autoInterval(0, 3) < Cloud.autoInterval(0, 1))
	end },
	{ "upgrade prices grow and stop at max", function()
		Expect.eq(Cloud.upgradePrice("luck", 0), 100)
		Expect.truthy(Cloud.upgradePrice("luck", 3) > Cloud.upgradePrice("luck", 2))
		Expect.eq(Cloud.upgradePrice("auto", 5), nil)
		Expect.eq(Cloud.upgradePrice("nope", 0), nil)
	end },
	{ "rolls: species matches rarity, forms are rare", function()
		local rng = Random.new(3)
		local forms = 0
		for _ = 1, 20000 do
			local r = Cloud.roll(rng, 1)
			Expect.truthy(table.find(Species.byRarity[r.rarity], r.species) ~= nil, "species of rarity")
			if r.mutation then
				forms += 1
			end
		end
		-- 0,7 % + 3 % + 6 % (grob, da nacheinander gewürfelt)
		Expect.near(forms / 20000, 0.094, 0.01)
	end },
	{ "auto farm sells only plain common drops", function()
		Expect.eq(Cloud.autoSells({ rarity = "Gewöhnlich" }), true)
		Expect.eq(Cloud.autoSells({ rarity = "Ungewöhnlich" }), true)
		Expect.eq(Cloud.autoSells({ rarity = "Gewöhnlich", mutation = "gold" }), false)
		Expect.eq(Cloud.autoSells({ rarity = "Selten" }), false)
		Expect.eq(Cloud.capacity(), 8)
	end },
}
