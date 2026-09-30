# Brainrot-Wolke: Neustart (Design)

Stand 30.09.2026, Idee des Nutzers. Alle früheren Systeme entfallen, weil sie zu kompliziert waren.

## Spiel in einem Satz

Knie dich vor deine Wolke → Brainrots fallen herunter → behalten oder skippen (Geld) → 3 ausrüsten, die Geld pro Sekunde verdienen → Wolke upgraden → werde 👑 König des Servers.

## Regeln

- **Garten:** Jeder Spieler hat einen eingezäunten Garten mit Wolke, einem Kissen davor und 3 Podesten.
- **Knien:** Wer auf dem Kissen sitzt, bekommt einen Drop alle `Intervall` Sekunden. Der Drop fällt aus der Wolke, und eine Karte fragt „BEHALTEN“ (E) oder „SKIPPEN (+Geld)“ (F). Solange die Karte offen ist, kommt kein neuer Drop.
- **Brainrots:** Die Seltenheit bestimmt die Art (je Seltenheit 2 Arten, „Geheim“ hat 4). Chancen: 60 / 25 / 10 / 4 / 0,9 / 0,1 / 0,01 %. Glück wirkt ab „Selten“.
- **Formen:**

  | Form | Geld | Glück | Chance |
  |---|---|---|---|
  | 🪙 Gold | ×3 | – | 6 % |
  | 💎 Diamant | ×1,5 | +50 % | 3 % |
  | 🌈 Regenbogen | ×5 | +100 % | 0,7 % |

- **Einkommen pro Sekunde nach Seltenheit:** 2 / 6 / 20 / 70 / 250 / 1000 / 5000, jeweils × Form. Skippen bringt das 10-fache des Einkommens.
- **Ausrüsten:** Höchstens 3 Brainrots stehen auf den Podesten und verdienen. Das Lager fasst 60, ist es voll, wird automatisch geskippt.
- **Wolken-Upgrades** (Preise wachsen):
  - 🍀 Glück: +25 % pro Stufe
  - ⚡ Tempo: Intervall 6 s × 0,88^Stufe, mindestens 1 s
  - 🤖 Auto-Farm: Die Wolke droppt auch ohne Knien, mit dem doppelten Intervall. Sie behält automatisch Selten+ oder Formen und skippt den Rest.
- **👑 König:** Der Spieler mit dem höchsten Einkommen pro Sekunde auf dem Server bekommt eine Krone und ×1,5 Glück. Überholungen werden gemeldet. Das HUD zeigt Platz und den nächsten Gegner.
- **Events (FOMO):**
  - 🍀 Glücksregen (×3 Glück)
  - 🌈 Regenbogen-Sturm (Formen ×4 häufiger)
  - ⚡ Wolkenbruch (doppeltes Tempo)
  - 💰 Geldregen (×2)
- **Ansagen:** Drops ab Legendär, Formen ab Diamant und Geheim-Brainrots werden serverweit angesagt.

## Daten (Profil v7)

`coins`, `totalEarned`, `creatures` (`{id, species, rarity, mutation}`), `equipped` (max. 3 IDs), `cloud = {luck, speed, auto}`, `stats`.

Migration: Die Wesen bleiben. Ihre Mutation wird zur Form (frost → Diamant, lava → Gold, galaxy → Regenbogen). Die Ausrüstung sind die 3 stärksten.
