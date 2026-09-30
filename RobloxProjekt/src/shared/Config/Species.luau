-- Brainrots: Name, Spruch, Ersatzfarbe. Die Seltenheit bestimmt, welche Art aus der Wolke fällt.
-- 3D-Modelle liegen in ReplicatedStorage.CreatureModels.<id>.
local Species = {}

Species.byRarity = {
	["Gewöhnlich"] = { "schleimi", "mooshamster" },
	["Ungewöhnlich"] = { "nebelqualle", "frostfuchs" },
	["Selten"] = { "prismapfau", "zuckerzyklop" },
	["Episch"] = { "donnerdrache", "robofrosch" },
	["Legendär"] = { "sternenwal", "goldphoenix" },
	["Mythisch"] = { "kosmokrake", "kristalldrache" },
	["Geheim"] = { "lavaxolotl", "geisterhai", "nullkatze", "glitchdino" },
}

Species.byId = {
	schleimi = { name = "Schleimi Schlabberkopf", tagline = "Drei Augen, null Plan.", color = Color3.fromRGB(120, 230, 120) },
	mooshamster = { name = "Moos-Hamster Moritz", tagline = "Riecht nach Waldboden. Stolz drauf.", color = Color3.fromRGB(90, 160, 70) },
	nebelqualle = { name = "Nebelqualle Norbert", tagline = "Schwebt. Glibbert. Leuchtet.", color = Color3.fromRGB(190, 225, 255) },
	frostfuchs = { name = "Frostflatter-Fuchs", tagline = "Friert nie. Flattert immer.", color = Color3.fromRGB(200, 240, 255) },
	prismapfau = { name = "Prisma-Pfau Pablo", tagline = "Zu schön für diese Welt.", color = Color3.fromRGB(120, 200, 255) },
	zuckerzyklop = { name = "Zuckerwatte-Zyklop", tagline = "Ein Auge, zehn Kilo Zucker.", color = Color3.fromRGB(255, 160, 210) },
	donnerdrache = { name = "Donnerdrache Dieter", tagline = "Macht BOOM. Immer.", color = Color3.fromRGB(110, 90, 220) },
	robofrosch = { name = "Robo-Frosch 3000", tagline = "Quak.exe wurde gestartet.", color = Color3.fromRGB(90, 220, 160) },
	sternenwal = { name = "Sternenwal Walter", tagline = "Hat eine Galaxie verschluckt.", color = Color3.fromRGB(60, 70, 180) },
	goldphoenix = { name = "Goldphönix Gabi", tagline = "Stirbt nie. Glänzt immer.", color = Color3.fromRGB(255, 190, 50) },
	kosmokrake = { name = "Kosmo-Krake Kevin", tagline = "Acht Arme, unendlich Aura.", color = Color3.fromRGB(150, 60, 220) },
	kristalldrache = { name = "Kristall-Einhorndrache", tagline = "Das Letzte, was du nie bekommst.", color = Color3.fromRGB(180, 240, 255) },
	lavaxolotl = { name = "Lava-Axolotl Luigi", tagline = "Heiß. Süß. Gefährlich.", color = Color3.fromRGB(255, 100, 40) },
	geisterhai = { name = "Geisterhai Günther", tagline = "Buh. Und dann Biss.", color = Color3.fromRGB(140, 255, 200) },
	nullkatze = { name = "Nullkatze Nova", tagline = "Ein schwarzes Loch mit Schnurrhaaren.", color = Color3.fromRGB(40, 20, 70) },
	glitchdino = { name = "Glitch-Dino Gerd", tagline = "Err0r 404: Dino nicht gefunden.", color = Color3.fromRGB(80, 255, 120) },
}

function Species.displayName(creature): string
	local name = Species.byId[creature.species].name
	if creature.mutation then
		local Mutations = require(script.Parent.Mutations)
		name = Mutations.byId[creature.mutation].icon .. " " .. name
	end
	return name
end

return Species
