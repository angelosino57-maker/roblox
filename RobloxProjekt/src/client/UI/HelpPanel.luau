-- Hilfe (Taste H): So funktioniert die Brainrot-Wolke.
local Widgets = require(script.Parent.Widgets)

local HelpPanel = {}

local GUIDE = {
	"1. Setz dich auf das rote Kissen vor deiner Wolke – dann fallen Brainrots herunter.",
	"2. Schnell entscheiden! [E] BEHALTEN oder [F] SKIPPEN (gibt Geld). Wartest du zu lange, fliegt er davon!",
	"3. Stell deine besten 3 Brainrots aufs Podest (Menü C) – sie verdienen jede Sekunde Geld.",
	"4. Platz ist knapp: 3 Podeste + 5 im Rucksack. Ist alles voll, musst du einen ersetzen.",
	"5. Kauf Wolken-Upgrades unten rechts: 🍀 Glück (bessere Brainrots), ⚡ Tempo (schneller), 🤖 Auto-Farm.",
	"🪙 Gold = mehr Geld · 💎 Diamant = mehr Glück · 🌈 Regenbogen = beides!",
	"👑 Wer am meisten pro Sekunde verdient, ist König (×1,5 Glück). Lass dich nicht überholen!",
}

function HelpPanel.start()
	local ui = Widgets.panel({
		name = "HelpPanel",
		toggleText = "?",
		toggleColor = Color3.fromRGB(90, 90, 110),
		slot = 2,
		key = Enum.KeyCode.H,
		tabs = { { "guide", "So geht's" } },
		render = function(lines)
			for _, text in GUIDE do
				lines.infoRow(text)
			end
		end,
	})
	ui.render()
end

return HelpPanel
