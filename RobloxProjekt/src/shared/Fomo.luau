-- Welt-Events, die Spieler online halten: angekündigt, dann 2 Minuten aktiv.
-- Alles deterministisch aus Serverstart + Seed, damit Server und Client dieselben Countdowns zeigen.
local Fomo = {}

Fomo.EVENTS = {
	{ id = "luckrain", name = "🍀 GLÜCKSREGEN", text = "Alle Wolken haben DREIFACHES Glück!", luck = 3 },
	{ id = "rainbow", name = "🌈 REGENBOGEN-STURM", text = "Gold-, Diamant- und Regenbogen-Brainrots 4× häufiger!", formBoost = 4 },
	{ id = "burst", name = "⚡ WOLKENBRUCH", text = "Alle Wolken droppen DOPPELT so schnell!", speed = 2 },
	{ id = "money", name = "💰 GELDREGEN", text = "Alle Brainrots verdienen DOPPELT!", money = 2 },
}

Fomo.CALM = 30 -- ruhige Phase
Fomo.WARNING = 20 -- angekündigt
Fomo.ACTIVE = 120 -- läuft
Fomo.CYCLE = Fomo.CALM + Fomo.WARNING + Fomo.ACTIVE

local function eventFor(index: number, seed: number)
	return Fomo.EVENTS[Random.new(seed * 1000 + index):NextInteger(1, #Fomo.EVENTS)]
end

-- Liefert {phase = "calm"|"warning"|"active", event, phaseEndsAt} für Zeitpunkt t.
function Fomo.eventAt(t: number, t0: number, seed: number)
	local elapsed = math.max(0, t - t0)
	local index = elapsed // Fomo.CYCLE
	local offset = elapsed % Fomo.CYCLE
	local cycleStart = t0 + index * Fomo.CYCLE
	local event = eventFor(index, seed)
	if offset < Fomo.CALM then
		return { phase = "calm", event = event, phaseEndsAt = cycleStart + Fomo.CALM }
	elseif offset < Fomo.CALM + Fomo.WARNING then
		return { phase = "warning", event = event, phaseEndsAt = cycleStart + Fomo.CALM + Fomo.WARNING }
	end
	return { phase = "active", event = event, phaseEndsAt = cycleStart + Fomo.CYCLE }
end

return Fomo
