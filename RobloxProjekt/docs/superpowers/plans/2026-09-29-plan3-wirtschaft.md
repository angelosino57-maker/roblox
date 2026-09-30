# Plan 3: Wirtschaft – Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Schmelzofen (Erz → Barren), Werkbank (Spitzhacken inkl. Lava/RGB, Rucksäcke, exotischere Transportmittel), Händler (Verkauf, Plätze kaufen), täglicher Login-Bonus, Hochfahren per Lore/Geysir.

**Architecture:** Reine Logik `Workshop`, `Market`, `Daily`, `Roster` in `ReplicatedStorage.Shared` (voll getestet), Server-Services `WorkshopService`, `MerchantService`, `DailyService`, erweiterter `TransportService`. UI: gemeinsame `Widgets` (aus CreaturePanel herausgelöst) + neues `WorkshopPanel`.

**Tech Stack:** wie Plan 2 (Studio-Sync, DevBridge, TestRunner).

**Spec:** Abschnitte 2 (Förderschacht), 5, 6. Teil 3 von 4. Umfang wie Plan 2: voller Code für reine Logik und Tests, Services/UI über exakte Schnittstellen und Regeln.

## Global Constraints

- Schmelzofen: 2 Erz → 1 Barren, 5 s pro Barren, Warteschlange (max. 50 Aufträge). Barren tragen die Erz-ID (`storage.bars.copper`).
- Rezepte kosten Barren, verlangen die vorherige Stufe derselben Kategorie; Kauf rüstet das Teil sofort aus.
- Spezial-Spitzhacken: Lava (aus Lava-Erz, Tier 3, Power 3,5), RGB (aus Prisma-Erz, Tier 4, Power 5).
- Runter: Fallschirm 30 → Gleiter 50 → Raketenrucksack 90 (sichere Fallgeschwindigkeit). Hoch: Kletterseil (klettern) → Minenlore 40 Studs/s → Geysir 160 Studs/s (Fahrt per ProximityPrompt „Hochfahren“ am Förderschacht-Boden).
- Händler auf dem Marktplatz (Verkauf nur, wenn der Spieler auf dem Marktplatz steht: |x|, |z| ≤ 48). Preise: Erz Kupfer 2, Eisen 3, Gold 8, Kristall 15, Lava-Erz 40, Prisma-Erz 60; Barren = 3 × Erzpreis; Wesen = `floor(20 × Seltenheit × Mutation × (1 + Ø-Gen / 50))`. Begleiter und Wesen im Nest sind nicht verkaufbar.
- Plätze kaufen: Garten (Start 10, max 20, Preis 500 × n), Brutplätze (Start 3, max 6, 1000 × n), Nester (Start 1, max 3, 5000 × n); n = Anzahl bereits gekaufter Plätze + 1.
- Login-Bonus: 7-Tage-Kalender, UTC-Tag = `os.time() // 86400`; einmal pro Tag; verpasster Tag → Tag 1; nach Tag 7 wieder Tag 1. Belohnungen: 100 Münzen, Erd-Ei, 250 Münzen, Stein-Ei, 500 Münzen, Stein-Ei, Glücks-Ei (Kristall, Seltenheit ≥ Selten).

## Dateistruktur

```
src/shared/Config/Tools.luau      (erweitert) lava/rgb, glider/rocket, minecart/geyser
src/shared/Config/Recipes.luau
src/shared/Config/Prices.luau
src/shared/Config/Daily.luau
src/shared/Roster.luau            isInNest, isCompanion (von BreedService/Market genutzt)
src/shared/Workshop.luau          Rezepte prüfen/bauen, Schmelzen einreihen/abholen
src/shared/Market.luau            Preise, Verkauf, Plätze kaufen
src/shared/Daily.luau             Status/Abholen des Kalenders
src/server/Services/WorkshopService.luau, MerchantService.luau, DailyService.luau
src/server/Services/TransportService.luau (erweitert) rideUp
src/server/Services/ShaftService.luau    (erweitert) ProximityPrompt am Förderschacht-Boden
src/server/WorldBuilder.luau      (erweitert) Händlerstand auf dem Marktplatz
src/client/UI/Widgets.luau        Buttons, Zeilen, Timer, Panel-Gerüst
src/client/UI/CreaturePanel.luau  (umgebaut auf Widgets)
src/client/UI/WorkshopPanel.luau  Tabs Ofen, Werkbank, Händler, Kalender
tests/Workshop.spec.luau, tests/Market.spec.luau, tests/Daily.spec.luau
```

---

### Task 1: Reine Logik (Workshop, Market, Daily, Roster) + Config

**Interfaces:**
- `Roster.isInNest(data, id) -> boolean`, `Roster.isCompanion(data, id) -> boolean`
- `Workshop.SMELT_SECONDS = 5`, `Workshop.ORE_PER_BAR = 2`, `Workshop.MAX_QUEUE = 50`, `Workshop.recipe(id)`, `Workshop.canAfford(bars, cost)`, `Workshop.craftCheck(data, recipeId) -> (ok, reason?)` (`"unknown" | "owned" | "locked" | "cost"`), `Workshop.craft(data, recipeId) -> (ok, reason?)`, `Workshop.enqueueSmelt(data, oreId, amount, now) -> (ok, reason?)` (`"invalid args" | "ore" | "queue"`), `Workshop.collect(data, now) -> number`
- `Market.orePrice(id)`, `Market.barPrice(id)`, `Market.creatureValue(creature)`, `Market.slotPrice(kind, data) -> number?` (nil = Maximum erreicht), `Market.sell(data, kind, id, amount) -> (ok, coinsOrReason)` (`kind`: `"ore" | "bar" | "creature"`, Gründe `"invalid args" | "missing" | "companion" | "busy"`), `Market.buySlot(data, kind) -> (ok, reason?)` (`"invalid args" | "max" | "coins"`)
- `Daily.today(now) -> number`, `Daily.status(daily, today) -> (canClaim, day)`, `Daily.claim(daily, today) -> number?`
- Profil neu: `owned = {pickaxe = {wood = true}, backpack = {small = true}, down = {parachute = true}, up = {rope = true}}`, `smelter = {}` (`{ore, readyAt}`)

- [ ] **Step 1: Failing Tests**

`tests/Workshop.spec.luau`:
```lua
local Shared = game:GetService("ReplicatedStorage").Shared
local Expect = require(script.Parent.Expect)
local Workshop = require(Shared.Workshop)

local function data()
	return {
		storage = { ores = { copper = 5, iron = 1 }, bars = {} },
		smelter = {},
		owned = { pickaxe = { wood = true }, backpack = { small = true }, down = { parachute = true }, up = { rope = true } },
		equipped = { pickaxe = "wood", backpack = "small", down = "parachute", up = "rope", companions = {} },
	}
end

return {
	{ "smelting consumes 2 ore per bar and queues 5 s apart", function()
		local d = data()
		Expect.eq((Workshop.enqueueSmelt(d, "copper", 2, 100)), true)
		Expect.eq(d.storage.ores.copper, 1)
		Expect.eq(#d.smelter, 2)
		Expect.eq(d.smelter[1].readyAt, 105)
		Expect.eq(d.smelter[2].readyAt, 110)
		Expect.eq(select(2, Workshop.enqueueSmelt(d, "copper", 1, 100)), "ore")
		Expect.eq(select(2, Workshop.enqueueSmelt(d, "copper", 0, 100)), "invalid args")
		Expect.eq(select(2, Workshop.enqueueSmelt(d, "nope", 1, 100)), "invalid args")
	end },
	{ "new jobs start after the last queued job", function()
		local d = data()
		d.storage.ores.copper = 10
		Workshop.enqueueSmelt(d, "copper", 1, 100)
		Workshop.enqueueSmelt(d, "copper", 1, 101)
		Expect.eq(d.smelter[2].readyAt, 110)
		Workshop.enqueueSmelt(d, "copper", 1, 500)
		Expect.eq(d.smelter[3].readyAt, 505)
	end },
	{ "collect moves only finished bars", function()
		local d = data()
		Workshop.enqueueSmelt(d, "copper", 2, 100)
		Expect.eq(Workshop.collect(d, 106), 1)
		Expect.eq(d.storage.bars.copper, 1)
		Expect.eq(#d.smelter, 1)
		Expect.eq(Workshop.collect(d, 200), 1)
		Expect.eq(d.storage.bars.copper, 2)
	end },
	{ "craft checks unknown, locked, cost, owned", function()
		local d = data()
		Expect.eq(select(2, Workshop.craftCheck(d, "x")), "unknown")
		Expect.eq(select(2, Workshop.craftCheck(d, "pickaxe_gold")), "locked")
		Expect.eq(select(2, Workshop.craftCheck(d, "pickaxe_iron")), "cost")
		d.storage.bars = { copper = 10, iron = 10 }
		Expect.eq((Workshop.craft(d, "pickaxe_iron")), true)
		Expect.eq(d.storage.bars.copper, 0)
		Expect.eq(d.equipped.pickaxe, "iron")
		Expect.eq(d.owned.pickaxe.iron, true)
		Expect.eq(select(2, Workshop.craftCheck(d, "pickaxe_iron")), "owned")
	end },
	{ "backpack craft equips the new backpack", function()
		local d = data()
		d.storage.bars = { copper = 15 }
		Expect.eq((Workshop.craft(d, "backpack_medium")), true)
		Expect.eq(d.equipped.backpack, "medium")
	end },
}
```

`tests/Market.spec.luau`:
```lua
local Shared = game:GetService("ReplicatedStorage").Shared
local Expect = require(script.Parent.Expect)
local Market = require(Shared.Market)

local function data()
	return {
		coins = 0,
		storage = { ores = { gold = 3 }, bars = { iron = 2 } },
		creatures = {
			a = { id = "a", species = "mushroom_frog", rarity = "Selten", genes = { luck = 50, dig = 50, carry = 50, income = 50 }, mutation = "gold", generation = 1 },
			b = { id = "b", species = "mushroom_frog", rarity = "Gewöhnlich", genes = { luck = 1, dig = 1, carry = 1, income = 1 }, generation = 1 },
		},
		garden = { "a" },
		nests = {},
		equipped = { companions = { "b" } },
		gardenSlots = 10,
		incubatorSlots = 3,
		nestSlots = 1,
	}
end

return {
	{ "prices", function()
		Expect.eq(Market.orePrice("gold"), 8)
		Expect.eq(Market.barPrice("iron"), 9)
		-- 20 * 1.5 * 1.5 * (1 + 50/50) = 90
		Expect.eq(Market.creatureValue(data().creatures.a), 90)
	end },
	{ "sell ores and bars", function()
		local d = data()
		local ok, coins = Market.sell(d, "ore", "gold", 2)
		Expect.eq(ok, true)
		Expect.eq(coins, 16)
		Expect.eq(d.storage.ores.gold, 1)
		Expect.eq(select(2, Market.sell(d, "ore", "gold", 5)), "missing")
		Expect.eq((Market.sell(d, "bar", "iron", 2)), true)
		Expect.eq(d.coins, 16 + 18)
		Expect.eq(select(2, Market.sell(d, "ore", "gold", 1.5)), "invalid args")
	end },
	{ "sell creature removes it from garden, blocks companions and nest", function()
		local d = data()
		Expect.eq(select(2, Market.sell(d, "creature", "b", 1)), "companion")
		d.nests = { { a = "a", b = "x", readyAt = 0 } }
		Expect.eq(select(2, Market.sell(d, "creature", "a", 1)), "busy")
		d.nests = {}
		Expect.eq((Market.sell(d, "creature", "a", 1)), true)
		Expect.eq(d.creatures.a, nil)
		Expect.eq(#d.garden, 0)
		Expect.eq(d.coins, 90)
	end },
	{ "slot prices grow and cap", function()
		local d = data()
		Expect.eq(Market.slotPrice("garden", d), 500)
		d.coins = 10000
		Expect.eq((Market.buySlot(d, "garden")), true)
		Expect.eq(d.gardenSlots, 11)
		Expect.eq(d.coins, 9500)
		Expect.eq(Market.slotPrice("garden", d), 1000)
		d.nestSlots = 3
		Expect.eq(Market.slotPrice("nest", d), nil)
		Expect.eq(select(2, Market.buySlot(d, "nest")), "max")
		d.coins = 0
		Expect.eq(select(2, Market.buySlot(d, "incubator")), "coins")
		Expect.eq(select(2, Market.buySlot(d, "x")), "invalid args")
	end },
}
```

`tests/Daily.spec.luau`:
```lua
local Shared = game:GetService("ReplicatedStorage").Shared
local Expect = require(script.Parent.Expect)
local Daily = require(Shared.Daily)

return {
	{ "today is the UTC day index", function()
		Expect.eq(Daily.today(86400 * 3 + 5), 3)
	end },
	{ "first claim is day 1, then once per day", function()
		local d = { streak = 0, lastClaimDay = -1 }
		Expect.eq(Daily.claim(d, 100), 1)
		Expect.eq(Daily.claim(d, 100), nil)
		local can, day = Daily.status(d, 100)
		Expect.eq(can, false)
		Expect.eq(day, 1)
	end },
	{ "consecutive days advance and wrap after 7", function()
		local d = { streak = 0, lastClaimDay = -1 }
		for day = 1, 7 do
			Expect.eq(Daily.claim(d, 100 + day), day)
		end
		Expect.eq(Daily.claim(d, 108), 1)
	end },
	{ "missing a day resets to day 1", function()
		local d = { streak = 3, lastClaimDay = 50 }
		Expect.eq(Daily.claim(d, 52), 1)
	end },
}
```

- [ ] **Step 2: Sync + Tests → `LOAD FAIL` für die drei Specs.**

- [ ] **Step 3: Implementieren**

`src/shared/Config/Tools.luau` – ergänzen:
```lua
-- in pickaxes:
lava = { name = "Lava-Spitzhacke", tier = 3, power = 3.5, special = true, color = Color3.fromRGB(255, 90, 20) },
rgb = { name = "RGB-Spitzhacke", tier = 4, power = 5, special = true, color = Color3.fromRGB(255, 80, 200) },
-- in down:
glider = { name = "Gleiter", fallSpeed = 50 },
rocket = { name = "Raketenrucksack", fallSpeed = 90 },
-- in up (rope bekommt keine speed = klettern):
minecart = { name = "Minenlore", speed = 40 },
geyser = { name = "Geysir-Schleuder", speed = 160 },
```

`src/shared/Config/Recipes.luau`:
```lua
-- Kosten in Barren (Key = Erz-ID). requires = Teil derselben Kategorie, das man besitzen muss.
return {
	{ id = "pickaxe_iron", category = "pickaxe", item = "iron", cost = { copper = 10, iron = 10 }, requires = "wood" },
	{ id = "pickaxe_gold", category = "pickaxe", item = "gold", cost = { iron = 10, gold = 15 }, requires = "iron" },
	{ id = "pickaxe_crystal", category = "pickaxe", item = "crystal", cost = { gold = 15, crystal = 20 }, requires = "gold" },
	{ id = "pickaxe_lava", category = "pickaxe", item = "lava", cost = { iron = 20, lava_ore = 5 }, requires = "iron" },
	{ id = "pickaxe_rgb", category = "pickaxe", item = "rgb", cost = { crystal = 20, prism_ore = 5 }, requires = "crystal" },
	{ id = "backpack_medium", category = "backpack", item = "medium", cost = { copper = 15 }, requires = "small" },
	{ id = "backpack_large", category = "backpack", item = "large", cost = { copper = 10, iron = 20 }, requires = "medium" },
	{ id = "backpack_huge", category = "backpack", item = "huge", cost = { iron = 20, gold = 20 }, requires = "large" },
	{ id = "down_glider", category = "down", item = "glider", cost = { iron = 10 }, requires = "parachute" },
	{ id = "down_rocket", category = "down", item = "rocket", cost = { gold = 10, crystal = 5 }, requires = "glider" },
	{ id = "up_minecart", category = "up", item = "minecart", cost = { iron = 15 }, requires = "rope" },
	{ id = "up_geyser", category = "up", item = "geyser", cost = { gold = 15, crystal = 5 }, requires = "minecart" },
}
```

`src/shared/Config/Prices.luau`:
```lua
return {
	ores = { copper = 2, iron = 3, gold = 8, crystal = 15, lava_ore = 40, prism_ore = 60 },
	BAR_FACTOR = 3,
	CREATURE_BASE = 20,
	SLOTS = {
		garden = { field = "gardenSlots", start = 10, max = 20, base = 500 },
		incubator = { field = "incubatorSlots", start = 3, max = 6, base = 1000 },
		nest = { field = "nestSlots", start = 1, max = 3, base = 5000 },
	},
}
```

`src/shared/Config/Daily.luau`:
```lua
return {
	{ kind = "coins", amount = 100 },
	{ kind = "egg", zone = "earth" },
	{ kind = "coins", amount = 250 },
	{ kind = "egg", zone = "stone" },
	{ kind = "coins", amount = 500 },
	{ kind = "egg", zone = "stone" },
	{ kind = "egg", zone = "crystal", minRarity = "Selten" },
}
```

`src/shared/Roster.luau`:
```lua
local Roster = {}

function Roster.isInNest(data, id: string): boolean
	for _, nest in data.nests do
		if nest.a == id or nest.b == id then
			return true
		end
	end
	return false
end

function Roster.isCompanion(data, id: string): boolean
	return table.find(data.equipped.companions, id) ~= nil
end

return Roster
```

`src/shared/Workshop.luau`:
```lua
local Recipes = require(script.Parent.Config.Recipes)
local Ores = require(script.Parent.Config.Ores)

local Workshop = {}

Workshop.SMELT_SECONDS = 5
Workshop.ORE_PER_BAR = 2
Workshop.MAX_QUEUE = 50

local byId = {}
for _, recipe in Recipes do
	byId[recipe.id] = recipe
end

function Workshop.recipe(id: string)
	return byId[id]
end

function Workshop.canAfford(bars, cost): boolean
	for id, amount in cost do
		if (bars[id] or 0) < amount then
			return false
		end
	end
	return true
end

function Workshop.craftCheck(data, recipeId): (boolean, string?)
	local recipe = typeof(recipeId) == "string" and byId[recipeId]
	if not recipe then
		return false, "unknown"
	end
	local owned = data.owned[recipe.category]
	if owned[recipe.item] then
		return false, "owned"
	end
	if not owned[recipe.requires] then
		return false, "locked"
	end
	if not Workshop.canAfford(data.storage.bars, recipe.cost) then
		return false, "cost"
	end
	return true
end

function Workshop.craft(data, recipeId): (boolean, string?)
	local ok, reason = Workshop.craftCheck(data, recipeId)
	if not ok then
		return false, reason
	end
	local recipe = byId[recipeId]
	for id, amount in recipe.cost do
		data.storage.bars[id] -= amount
	end
	data.owned[recipe.category][recipe.item] = true
	data.equipped[recipe.category] = recipe.item
	return true
end

function Workshop.enqueueSmelt(data, oreId, amount, now: number): (boolean, string?)
	if typeof(oreId) ~= "string" or Ores[oreId] == nil or typeof(amount) ~= "number" or amount % 1 ~= 0 or amount < 1 then
		return false, "invalid args"
	end
	if (data.storage.ores[oreId] or 0) < amount * Workshop.ORE_PER_BAR then
		return false, "ore"
	end
	if #data.smelter + amount > Workshop.MAX_QUEUE then
		return false, "queue"
	end
	data.storage.ores[oreId] -= amount * Workshop.ORE_PER_BAR
	local last = data.smelter[#data.smelter]
	local start = if last then math.max(now, last.readyAt) else now
	for i = 1, amount do
		table.insert(data.smelter, { ore = oreId, readyAt = start + Workshop.SMELT_SECONDS * i })
	end
	return true
end

function Workshop.collect(data, now: number): number
	local done = 0
	while data.smelter[1] and data.smelter[1].readyAt <= now do
		local job = table.remove(data.smelter, 1)
		data.storage.bars[job.ore] = (data.storage.bars[job.ore] or 0) + 1
		done += 1
	end
	return done
end

return Workshop
```

`src/shared/Market.luau`:
```lua
local Prices = require(script.Parent.Config.Prices)
local Rarity = require(script.Parent.Config.Rarity)
local Mutations = require(script.Parent.Config.Mutations)
local Genetics = require(script.Parent.Genetics)
local Roster = require(script.Parent.Roster)

local Market = {}

function Market.orePrice(id: string): number
	return Prices.ores[id]
end

function Market.barPrice(id: string): number
	return Prices.ores[id] * Prices.BAR_FACTOR
end

function Market.creatureValue(creature): number
	local sum = 0
	for _, gene in Genetics.GENES do
		sum += creature.genes[gene]
	end
	local avg = sum / #Genetics.GENES
	local mutation = if creature.mutation then Mutations.byId[creature.mutation].multiplier else 1
	return math.floor(Prices.CREATURE_BASE * Rarity.multiplier[creature.rarity] * mutation * (1 + avg / 50))
end

local function isCount(v): boolean
	return typeof(v) == "number" and v % 1 == 0 and v >= 1
end

function Market.sell(data, kind, id, amount): (boolean, any)
	if typeof(id) ~= "string" then
		return false, "invalid args"
	end
	local coins
	if kind == "ore" or kind == "bar" then
		if Prices.ores[id] == nil or not isCount(amount) then
			return false, "invalid args"
		end
		local store = if kind == "ore" then data.storage.ores else data.storage.bars
		if (store[id] or 0) < amount then
			return false, "missing"
		end
		store[id] -= amount
		coins = amount * (if kind == "ore" then Market.orePrice(id) else Market.barPrice(id))
	elseif kind == "creature" then
		local creature = data.creatures[id]
		if creature == nil then
			return false, "missing"
		end
		if Roster.isCompanion(data, id) then
			return false, "companion"
		end
		if Roster.isInNest(data, id) then
			return false, "busy"
		end
		local index = table.find(data.garden, id)
		if index then
			table.remove(data.garden, index)
		end
		data.creatures[id] = nil
		coins = Market.creatureValue(creature)
	else
		return false, "invalid args"
	end
	data.coins += coins
	return true, coins
end

function Market.slotPrice(kind, data): number?
	local slot = Prices.SLOTS[kind]
	local current = data[slot.field]
	if current >= slot.max then
		return nil
	end
	return slot.base * (current - slot.start + 1)
end

function Market.buySlot(data, kind): (boolean, string?)
	if Prices.SLOTS[kind] == nil then
		return false, "invalid args"
	end
	local price = Market.slotPrice(kind, data)
	if price == nil then
		return false, "max"
	end
	if data.coins < price then
		return false, "coins"
	end
	data.coins -= price
	data[Prices.SLOTS[kind].field] += 1
	return true
end

return Market
```

`src/shared/Daily.luau`:
```lua
local Daily = {}

local DAY = 86400

function Daily.today(now: number): number
	return now // DAY
end

-- Liefert, ob heute abgeholt werden kann und welcher Kalendertag (1–7) das ist bzw. zuletzt war.
function Daily.status(daily, today: number): (boolean, number)
	if daily.lastClaimDay == today then
		return false, daily.streak
	end
	if daily.lastClaimDay == today - 1 then
		return true, daily.streak % 7 + 1
	end
	return true, 1
end

function Daily.claim(daily, today: number): number?
	local canClaim, day = Daily.status(daily, today)
	if not canClaim then
		return nil
	end
	daily.streak = day
	daily.lastClaimDay = today
	return day
end

return Daily
```

`BreedService.isInNest` ruft ab jetzt `Roster.isInNest` auf (Funktion bleibt als Weiterleitung, damit `CreatureService` unverändert bleibt).

- [ ] **Step 4: Sync + Tests → `0 failed`.**
- [ ] **Step 5: Commit** `feat: Werkstatt-, Markt- und Kalender-Logik`

---

### Task 2: Server-Services

**Interfaces / Regeln:**
- ProfileTemplate: `owned`, `smelter` (siehe Task 1).
- Remotes neu: `Smelt(oreId, amount)`, `Craft(recipeId)`, `Equip(category, item)`, `Sell(kind, id, amount)`, `BuySlot(kind)`, `ClaimDaily()`. Alle mit RateLimiter 5/s.
- `WorkshopService.start()`, `.smelt(player, oreId, amount)`, `.craft(player, recipeId)`, `.equip(player, category, item)` (Kategorie ∈ pickaxe/backpack/down/up, Teil muss in `owned` sein), 1-s-Loop `Workshop.collect` (bei > 0 Notify „+n Barren“ und push).
- `MerchantService.start()`, `.sell(player, kind, id, amount)` (nur auf dem Marktplatz, sonst `"far"` → Notify „Geh zum Händler auf dem Marktplatz“), `.buySlot(player, kind)`; nach Wesen-Verkauf `CreatureService`-Modelle neu aufbauen (neue öffentliche Funktion `CreatureService.refresh(player)`).
- `DailyService.start()`, `.claim(player) -> number?`: `Daily.claim(data.daily, Daily.today(os.time()))`; Münzen gutschreiben oder Ei in `data.eggs` (`{id=GUID, zone, rarity, foundAt}`); Seltenheit per `Loot.pick` über `Eggs.rarityEntries` mit `Stats.luck`, bei `minRarity` nur Einträge ab dieser Seltenheit. Notify „Tag n: …“.
- `TransportService.rideUp(player) -> (ok, reason?)`: Ausgerüstetes Hoch-Teil braucht `speed` (sonst `"climb"`); der Spieler muss im eigenen Schacht sein (Y < 0 und innerhalb des Schachts); Dauer = Tiefe / speed; HumanoidRootPart verankern, per TweenService bis 6 Studs über den Boden fahren, danach Anker lösen. Läuft schon eine Fahrt → `"busy"`.
- `ShaftService`: ProximityPrompt „Hochfahren“ (ActionText, HoldDuration 0) am `ColumnFloor`; `Triggered` → `TransportService.rideUp` (ShaftService darf TransportService nicht requiren, weil TransportService später startet → der Prompt wird in `TransportService.start` über `workspace.Shafts` verbunden: `PromptTriggered` auf `ProximityPromptService`, Prompt-Name `RideUp`, Owner-Attribut = UserId).
- Snapshot ergänzt um: `bars`, `smelter`, `owned`, `equipped` (pickaxe/backpack/down/up), `daily = {canClaim, day, streak}`, `slotPrices = {garden, incubator, nest}`, `onMarket` entfällt (Client zeigt nur den Hinweis).
- WorldBuilder: `Merchant`-Stand (Theke + Schild „Händler“) auf dem Marktplatz, wird auch in einer schon vorhandenen Welt ergänzt.

- [ ] **Step 1:** Implementieren, syncen, Welt im Editor ergänzen und per DevBridge im Playtest prüfen: Erz per `BackpackService.add` + Ablage → `smelt` → nach Loop Barren da; `craft("pickaxe_iron")` mit genug Barren → Spitzhacke `iron`; `equip("pickaxe", "wood")` → ok, `equip("pickaxe", "rgb")` → `"not owned"`; `sell` fern vom Markt → `"far"`, auf dem Markt → Münzen steigen; `buySlot("garden")` mit Münzen → `gardenSlots == 11`; `claim` → Tag 1 und +100 Münzen, zweites `claim` → nil; `rideUp` mit `rope` → `"climb"`.
- [ ] **Step 2: Commit** `feat: Schmelzofen, Werkbank, Händler, Login-Bonus und Hochfahren`

---

### Task 3: UI

**Interfaces:**
- `Widgets.button(parent, text, color, onClick) -> TextButton`
- `Widgets.panel(name, toggleText, toggleOffsetX, tabs: {{id, label}}, onTab) -> {panel: Frame, list: ScrollingFrame, lines: Lines}`; `onTab(id)` wird beim Tab-Klick aufgerufen; Toggle-Button unten links mit x-Offset.
- `Lines` = `{clear(), row(text) -> (label, buttons), infoRow(text) -> label, timerRow(prefix, readyAt), tick(now)}`
- `Widgets.ACTIVE`, `Widgets.IDLE`, `Widgets.fmtTime(seconds)`
- CreaturePanel nutzt nur noch Widgets (gleiches Verhalten wie vorher).
- `WorkshopPanel.start()`: Toggle „Werkstatt“ neben „Wesen“; Tabs:
  - **Ofen:** Erze mit Menge und Buttons „×1“ und „×10“ (Barren), Warteschlange mit Restzeit des nächsten Barrens, Barren-Bestand.
  - **Werkbank:** Rezepte pro Kategorie mit Kosten (z. B. „10 Kupfer + 10 Eisen“), Status „Gebaut“/„Gesperrt“ oder Button „Bauen“; besessene Teile mit Button „Ausrüsten“ (aktiv hervorgehoben).
  - **Händler:** Hinweis „Nur auf dem Marktplatz“; Erze/Barren mit „Alle verkaufen (x Münzen)“; Wesen (keine Begleiter) mit „Verkaufen (x)“; Plätze kaufen mit Preis oder „Maximum“.
  - **Kalender:** 7 Tage mit Belohnung, aktueller Tag markiert, Button „Abholen“ wenn möglich.

- [ ] **Step 1:** Implementieren, syncen und im Playtest prüfen: beide Panels öffnen (per Klick), Tabs durchklicken, Screenshots; per Client-Remote `ClaimDaily` → Snapshot `daily.canClaim == false`. Konsole ohne Fehler, alle Tests grün.
- [ ] **Step 2: Commit** `feat: Werkstatt-Panel und gemeinsame UI-Widgets`

---

### Task 4: Abschluss

- [ ] Kompletter Playtest + alle Tests, Obsidian-Fortschritt, Commit `chore: Plan 3 abgeschlossen`.
