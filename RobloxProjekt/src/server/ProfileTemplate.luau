-- Neue Felder hier ergänzen; Profile:Reconcile() füllt sie bei bestehenden Profilen auf.
return {
	version = 7, -- siehe Shared/Migrate
	coins = 0,
	totalEarned = 0,
	seed = 0, -- wird beim ersten Laden gesetzt
	creatures = {}, -- [id] = {id, species, rarity, mutation?}  (mutation = Form: gold/diamond/rainbow)
	equipped = {}, -- bis zu 3 IDs, die auf den Podesten Geld verdienen
	cloud = { luck = 0, speed = 0, auto = 0 }, -- Wolken-Upgrades
	stats = { drops = 0, kept = 0, skipped = 0, upgrades = 0 },
	lastOnline = 0,
}
