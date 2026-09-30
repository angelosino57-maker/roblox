-- Profil-Migrationen. Idempotent; gibt true zurück, wenn etwas geändert wurde.
local Migrate = {}

Migrate.VERSION = 7

-- Alte Verkaufspreise (Graben-Zeit), damit Erze und Barren fair zu Münzen werden.
local ORE_PRICES = { copper = 2, iron = 3, gold = 8, crystal = 15, lava_ore = 40, prism_ore = 60 }
local BAR_FACTOR = 3
local REMOVED = { "deepestLayer", "minedLayers", "backpack", "storage", "eggs", "incubators", "incubatorSlots", "smelter", "owned", "quests", "seals", "relics" }

-- v4: neue Meme-Wesen ersetzen die alten Arten (gleiche Ebene, gleiche Rolle).
Migrate.SPECIES = {
	mushroom_frog = "brokkolini", thunder_hamster = "toasti",
	crystal_worm = "wolki", shadow_cat = "pinguino",
	glow_jelly = "donut_dracula", stone_turtle = "einhoernchen",
	lava_axolotl = "blitzkroko", mole_dragon = "kaktus_karate",
	gold_jaguar = "astro_nudel", sun_serpent = "goldzahn",
	ember_turtle = "pharao_pommes", storm_jelly = "gurke_gustav",
}

-- v5: exotische Wesen ersetzen die Essens-Memes.
Migrate.SPECIES_V5 = {
	brokkolini = "schleimi", toasti = "mooshamster", wolki = "nebelqualle", pinguino = "frostfuchs",
	donut_dracula = "prismapfau", einhoernchen = "zuckerzyklop", blitzkroko = "donnerdrache", kaktus_karate = "robofrosch",
	astro_nudel = "sternenwal", goldzahn = "goldphoenix", pharao_pommes = "kosmokrake", gurke_gustav = "kristalldrache",
	toastzilla = "lavaxolotl", wolkendonut = "geisterhai",
}

local function toSeed(egg)
	return { id = egg.id, rarity = egg.rarity, mutation = egg.mutation }
end

local function toV3(data)
	-- Himmelsbaum: Eier werden Samen, Erze/Barren werden Münzen, Graben-Felder fallen weg.
	data.seeds = data.seeds or {}
	for _, egg in data.eggs or {} do
		table.insert(data.seeds, toSeed(egg))
	end
	for i, item in data.backpack or {} do
		if item.kind == "egg" then
			table.insert(data.seeds, toSeed({ id = "bp" .. i, rarity = item.rarity, mutation = item.mutation }))
		elseif item.kind == "ore" and ORE_PRICES[item.id] then
			data.coins = (data.coins or 0) + ORE_PRICES[item.id]
		end
	end
	local storage = data.storage or {}
	for id, n in storage.ores or {} do
		data.coins = (data.coins or 0) + (ORE_PRICES[id] or 0) * n
	end
	for id, n in storage.bars or {} do
		data.coins = (data.coins or 0) + (ORE_PRICES[id] or 0) * BAR_FACTOR * n
	end
	for _, key in REMOVED do
		data[key] = nil
	end
	if data.equipped then
		data.equipped = { companions = data.equipped.companions or {} }
	end
	if data.gardenSlots then
		data.gardenSlots = math.clamp(data.gardenSlots, 8, 16)
	end
end

local function renameSpecies(data)
	for _, creature in data.creatures or {} do
		local s = Migrate.SPECIES[creature.species] or creature.species
		creature.species = Migrate.SPECIES_V5[s] or s
	end
end

-- v6: Pet-Sim-Kern. Zonen statt Baum-Ebenen, Samen werden Münzen, Nest/Ressourcen/Baum entfallen.
local SEED_COINS = 500
local TEAM_MAX = 4

local function toV6(data)
	data.unlocked = if data.tree then data.tree.layer or 0 else 0
	data.coins = (data.coins or 0) + #(data.seeds or {}) * SEED_COINS
	data.totalEarned = data.coins
	data.seeds, data.nests, data.nestSlots, data.resources, data.tree = nil, nil, nil, nil, nil
	if data.stats then
		data.stats = { collected = data.stats.collected or 0, capsules = data.stats.capsules or 0, steals = data.stats.steals or 0 }
	end
	local team = data.equipped and data.equipped.companions
	if team then
		while #team > TEAM_MAX do
			table.remove(team)
		end
	end
end

-- v7: Brainrot-Wolke. Formen statt Mutationen, 3 ausgerüstete Brainrots, alles andere entfällt.
local FORM = { gold = "gold", diamond = "diamond", rainbow = "rainbow", lava = "gold", frost = "diamond", galaxy = "rainbow" }
local INCOME = { ["Gewöhnlich"] = 2, ["Ungewöhnlich"] = 6, ["Selten"] = 20, ["Episch"] = 70, ["Legendär"] = 250, ["Mythisch"] = 1000, ["Geheim"] = 5000 }
local FORM_MONEY = { gold = 3, diamond = 1.5, rainbow = 5 }
local DROPPED = { "garden", "pending", "gardenSlots", "unlocked", "rebirths", "speedLevel", "daily" }

local function toV7(data)
	local creatures = {}
	local ranked = {}
	for id, c in data.creatures or {} do
		local form = c.mutation and FORM[c.mutation]
		creatures[id] = { id = id, species = c.species, rarity = c.rarity, mutation = form }
		table.insert(ranked, { id = id, value = (INCOME[c.rarity] or 1) * (if form then FORM_MONEY[form] else 1) })
	end
	table.sort(ranked, function(a, b)
		return a.value > b.value
	end)
	-- Bestand ist jetzt knapp (3 Podeste + 5 Rucksack): die besten 8 bleiben, der Rest wird zu Geld
	for i = 9, #ranked do
		creatures[ranked[i].id] = nil
		data.coins = (data.coins or 0) + ranked[i].value * 10
	end
	data.creatures = creatures
	data.equipped = {}
	for i = 1, math.min(3, #ranked) do
		table.insert(data.equipped, ranked[i].id)
	end
	for _, key in DROPPED do
		data[key] = nil
	end
	data.stats = nil -- neu aus der Vorlage
end

function Migrate.run(data): boolean
	local version = data.version or 1
	if version >= Migrate.VERSION then
		return false
	end
	if version < 3 then
		toV3(data)
	end
	renameSpecies(data)
	if version < 6 then
		toV6(data)
	end
	if version < 7 then
		toV7(data)
	end
	data.version = Migrate.VERSION
	return true
end

return Migrate
