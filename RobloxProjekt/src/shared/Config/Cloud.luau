-- Zahlen der Brainrot-Wolke.
return {
	-- Drop-Chancen je Seltenheit (Glück wirkt ab „Selten“, siehe Loot).
	drops = {
		{ id = "Gewöhnlich", rarity = "Gewöhnlich", weight = 60 },
		{ id = "Ungewöhnlich", rarity = "Ungewöhnlich", weight = 25 },
		{ id = "Selten", rarity = "Selten", weight = 10 },
		{ id = "Episch", rarity = "Episch", weight = 4 },
		{ id = "Legendär", rarity = "Legendär", weight = 0.9 },
		{ id = "Mythisch", rarity = "Mythisch", weight = 0.1 },
		{ id = "Geheim", rarity = "Geheim", weight = 0.01 },
	},
	-- Geld pro Sekunde eines ausgerüsteten Brainrots (× Form).
	income = {
		["Gewöhnlich"] = 2,
		["Ungewöhnlich"] = 6,
		["Selten"] = 20,
		["Episch"] = 70,
		["Legendär"] = 250,
		["Mythisch"] = 1000,
		["Geheim"] = 5000,
	},
	SKIP_FACTOR = 10, -- Skippen bringt so viele Sekunden Einkommen
	EQUIP_MAX = 3, -- Podeste
	BAG_MAX = 5, -- Rucksack: mehr Brainrots kann man nicht haben (3 + 5) – echte Entscheidungen!
	DECIDE_SECONDS = 10, -- so lange liegt ein Drop, dann fliegt er davon
	AUTO_DECIDE_SECONDS = 20, -- seltene Drops der Auto-Farm warten etwas länger
	BASE_INTERVAL = 6, -- Sekunden zwischen Drops beim Knien
	MIN_INTERVAL = 1,
	AUTO_SLOWER = 2, -- Auto-Farm droppt halb so schnell
	AUTO_WAIT_FROM = "Selten", -- Auto-Farm verkauft alles darunter; ab hier (oder mit Form) musst DU entscheiden
	KING_LUCK = 1.5,
	upgrades = {
		luck = { name = "🍀 Glück", price = 100, growth = 2.2, max = 30, step = 0.25 },
		speed = { name = "⚡ Tempo", price = 150, growth = 2.4, max = 15, step = 0.88 },
		auto = { name = "🤖 Auto-Farm", price = 5000, growth = 6, max = 5 },
	},
}
