local Shared = game:GetService("ReplicatedStorage").Shared
local Expect = require(script.Parent.Expect)
local Migrate = require(Shared.Migrate)

return {
	{ "old dig profile ends up as a cloud profile", function()
		local d = {
			version = 2,
			coins = 10,
			eggs = { { id = "e1", rarity = "Selten" } },
			storage = { ores = { gold = 2 }, bars = {} },
			creatures = { c1 = { id = "c1", species = "mushroom_frog", rarity = "Selten", mutation = "lava", genes = {} } },
			equipped = { pickaxe = "wood", companions = { "c1" } },
			gardenSlots = 25,
		}
		Expect.eq(Migrate.run(d), true)
		Expect.eq(d.version, 7)
		Expect.eq(d.coins, 10 + 16 + 500)
		Expect.eq(d.creatures.c1.species, "schleimi")
		Expect.eq(d.creatures.c1.mutation, "gold")
		Expect.eq(d.creatures.c1.genes, nil)
		Expect.eq(d.equipped[1], "c1")
		Expect.eq(d.gardenSlots, nil)
		Expect.eq(d.eggs, nil)
	end },
	{ "v6 → v7: forms mapped, best three equipped", function()
		local d = {
			version = 6,
			coins = 50,
			creatures = {
				a = { id = "a", species = "schleimi", rarity = "Gewöhnlich" },
				b = { id = "b", species = "sternenwal", rarity = "Legendär", mutation = "galaxy" },
				c = { id = "c", species = "donnerdrache", rarity = "Episch", mutation = "frost" },
				d = { id = "d", species = "prismapfau", rarity = "Selten" },
			},
			equipped = { companions = { "a" } },
			garden = { "d" },
			unlocked = 3,
		}
		Expect.eq(Migrate.run(d), true)
		Expect.eq(d.creatures.b.mutation, "rainbow")
		Expect.eq(d.creatures.c.mutation, "diamond")
		Expect.eq(#d.equipped, 3)
		Expect.eq(d.equipped[1], "b")
		Expect.eq(d.unlocked, nil)
		Expect.eq(d.garden, nil)
		Expect.eq(d.coins, 50)
	end },
	{ "v7 keeps only the best 8 creatures, the rest becomes coins", function()
		local creatures = {}
		for i = 1, 10 do
			creatures["c" .. i] = { id = "c" .. i, species = "schleimi", rarity = if i <= 2 then "Gewöhnlich" else "Selten" }
		end
		local d = { version = 6, coins = 0, creatures = creatures }
		Migrate.run(d)
		local n = 0
		for _ in d.creatures do
			n += 1
		end
		Expect.eq(n, 8)
		Expect.eq(d.coins, 2 * 2 * 10)
	end },
	{ "migration is idempotent", function()
		local d = { version = 1, coins = 0, creatures = {} }
		Expect.eq(Migrate.run(d), true)
		Expect.eq(Migrate.run(d), false)
		Expect.eq(d.version, 7)
	end },
}
