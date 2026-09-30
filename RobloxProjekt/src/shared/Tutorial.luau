-- Aufgabenleiste für neue Spieler; der Fortschritt ergibt sich aus dem Profil.
local Tutorial = {}

Tutorial.STEPS = {
	{ text = "Setz dich auf das Kissen vor deiner Wolke ☁️ – dann fallen Brainrots!", done = function(d)
		return d.stats.drops >= 1
	end },
	{ text = "Behalte einen Brainrot (E), bevor der Countdown abläuft!", done = function(d)
		return d.stats.kept >= 1
	end },
	{ text = "Stell ihn aufs Podest (Menü C) – dann verdient er Geld!", done = function(d)
		return #d.equipped >= 1
	end },
	{ text = "Kauf ein Wolken-Upgrade (Knöpfe unten rechts)", done = function(d)
		return d.stats.upgrades >= 1
	end },
	{ text = "Rüste 3 Brainrots aus (C) – werde 👑 König!", done = function(d)
		return #d.equipped >= 3
	end },
}

-- Liefert {index, total, text} für den ersten offenen Schritt, oder nil, wenn alles erledigt ist.
-- Ein späterer erledigter Schritt zählt auch die früheren als erledigt.
function Tutorial.current(data)
	local lastDone = 0
	for i, step in Tutorial.STEPS do
		if step.done(data) then
			lastDone = i
		end
	end
	if lastDone >= #Tutorial.STEPS then
		return nil
	end
	local index = lastDone + 1
	return { index = index, total = #Tutorial.STEPS, text = Tutorial.STEPS[index].text }
end

return Tutorial
