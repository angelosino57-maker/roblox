# Dig & Breed – Design (MVP)

Stand: 29.09.2026 · Arbeitstitel: „Breed your Brainrot“ (endgültiger Name offen)

## 1. Ziel

Roblox-Spiel mit Kern-Loop **Graben → Schlüpfen → Brüten → Upgraden → tiefer graben**.
Das Alleinstellungsmerkmal sind **eigene Wesen mit vererbbaren Genen und sichtbaren Mutationen**,
die direkt helfen, besser zu graben. Die erste Version (MVP) soll diesen Loop komplett spielbar machen.
Alles, was unter „Später“ steht, gehört ausdrücklich nicht in den MVP.

## 2. Welt

- **Server:** max. 8 Spieler, jeder bekommt beim Beitreten ein **Grundstück (Plot)**.
- **Grundstück:** Garten (Wesen-Ausstellung), Brutstation, Brüt-Nest, Schmelzofen, Werkbank, Schachteingang.
- **Marktplatz** in der Kartenmitte (gemeinsam): Händler (Verkauf), Treffpunkt zum Handeln, Login-Kalender.
- **Eigener Schacht** unter jedem Grundstück, 12×12 Blöcke breit (Blockgröße 4 Studs), nach unten begrenzt durch die Zonen.
  Der Schacht gehört nur dem Besitzer; andere Spieler können ihn nicht betreten oder abbauen.

### Tiefenzonen

| Zone | Schichten | Nötige Spitzhacke | Erze | Ei |
|---|---|---|---|---|
| Erde | 1–50 | Holz | Kupfer, Eisen | Erd-Ei |
| Stein | 51–150 | Eisen | Eisen, Gold, *Lava-Erz (selten, ab 100)* | Stein-Ei |
| Kristallhöhle | 151–300 | Kristall | Gold, Kristall, *Prisma-Erz (selten)* | Kristall-Ei |

Schicht 300 ist im MVP der Boden. Blöcke einer Zone lassen sich ohne passende Spitzhacke nicht abbauen.
Seltenheit der Erze (für den Luck-Faktor): Kupfer, Eisen = Gewöhnlich · Gold = Ungewöhnlich · Kristall = Selten · Lava-Erz, Prisma-Erz = Episch.

### Förderschacht

In einer Ecke jedes Schachts gibt es eine 2×2-Säule, die man nicht abbauen kann (Förderschacht).
Sie reicht automatisch bis zur tiefsten erreichten Schicht. Über sie funktionieren alle Transportmittel:

- **Runter** (in den Förderschacht springen): ohne Hilfsmittel gibt es Fallschaden ab 60 Studs (Respawn oben, Rucksack bleibt).
  Fallschirm → Gleiter → Raketenrucksack: jede Stufe ist schneller unten, und man landet auf Wunsch direkt auf der tiefsten Schicht.
- **Hoch:** Kletterseil (langsam) → Minenlore auf Schienen (mittel) → Geysir-Schleuder (fast sofort).
  Jede Stufe hat ein eigenes Aussehen mit Effekten.

## 3. Spielkreislauf (ein Durchgang ca. 3–5 Min.)

1. Per Förderschacht runter.
2. Blöcke abbauen; dabei landen Erze und Eier im **Rucksack** (Kapazität begrenzt, jeder Gegenstand belegt 1 Platz).
3. Ist der Rucksack voll, kann man nichts mehr aufnehmen → per Förderschacht hoch.
4. Oben Rucksack ablegen (automatisch beim Betreten des Grundstücks): Eier kommen in die Brutstation, Erze ins Lager.
5. Schmelzen, bauen, brüten, Begleiter wählen, wieder runter.

## 4. Wesen

### Arten (MVP: 8 + 2 Mischarten)
Pilzfrosch, Kristallwurm, Lava-Axolotl, Maulwurf-Drache, Glühqualle, Stein-Schildkröte, Donner-Hamster, Schattenkatze.
Mischarten (nur durch Brüten): **Glutschildkröte** (Lava-Axolotl × Stein-Schildkröte), **Sturmqualle** (Glühqualle × Donner-Hamster).
Bekannte Brainrot-Figuren (Tung Tung usw.) kommen später als Sonder-Editionen, nicht im MVP.

### Daten eines Wesens
- `species`, `rarity` (Gewöhnlich, Ungewöhnlich, Selten, Episch, Legendär, Mythisch; Multiplikator 1 / 1,2 / 1,5 / 2 / 3 / 5)
- `genes`: `luck`, `dig`, `carry`, `income`, ganzzahlig 1–100
- `mutation`: keine | Gold ×1,5 | Diamant ×2 | Frost ×2 | Lava ×2,5 | Regenbogen ×3 | Galaxy ×4
  (jede Mutation hat eigene Partikel-, Leucht- und Farbeffekte; Regenbogen wechselt die Farben)
- `generation`, `id` (GUID)

**Effektivwert** eines Gens = `gen × Seltenheits-Multiplikator × Mutations-Multiplikator`.

### Begleiter (max. 3 ausgerüstet)
- **Glück:** `luckFactor = 1 + Σ effektives luck / 300`, gedeckelt bei ×5. Bei Eiern und Erzen werden die Gewichte aller Seltenheiten ab „Selten“ mit `luckFactor` multipliziert.
- **Grabkraft:** Abbauzeit × `1 / (1 + Σ effektives dig / 400)`
- **Tragkraft:** Rucksack + `floor(Σ effektives carry / 20)` Plätze
- Einkommen bringt ein Wesen nur im Garten, nicht als Begleiter.

### Garten
- Anfangs 10 Plätze. Jedes Wesen dort bringt `effektives income × 0,1` Münzen/Sek.
- Offline-Einkommen: für höchstens 8 Stunden, zu 50 % ausgezahlt.
- Lagerplatz für nicht ausgestellte Wesen: 100.

### Eier und Schlüpfen
- Die Seltenheit wird **beim Finden** ausgewürfelt (Luck-Faktor gilt hier) und ist am Ei sichtbar. Art und Gene werden beim Schlüpfen ausgewürfelt.
- Gene beim Schlüpfen: Grundbereich je Zone (Erde 5–25, Stein 15–40, Kristall 30–60).
- Mutationschance beim Schlüpfen: 1 %.
- Brutzeit: Erde 30 s, Stein 2 min, Kristall 5 min. Anfangs 3 Brutplätze.
- **Alle Wahrscheinlichkeiten sind an der Brutstation sichtbar.**

### Brüten (Nest, 5 min, anfangs 1 Nest)
- **Art:** 50/50 eine Elternart; gibt es für das Elternpaar eine Mischart, entsteht sie mit 5 %.
- **Gene:** `clamp(round((a + b) / 2 + Zufall(-6..+10)), 1, 100)`. Der leichte Aufschlag macht Wesen über die Generationen stärker.
- **Seltenheit:** die höhere der beiden Eltern; 3 % Chance auf eine Stufe höher.
- **Mutation:** Grundchance 5 %, +5 % je mutiertem Elternteil. Tritt eine Mutation auf und hat ein Elternteil eine, wird mit 50 % deren Typ übernommen, sonst wird zufällig gewürfelt.
- Die Eltern bleiben erhalten; ausgerüstete Begleiter können nicht ins Nest.

## 5. Ressourcen, Upgrades, Münzen

- **Schmelzofen:** 2 Erz → 1 Barren, 5 s pro Barren, Warteschlange.
- **Werkbank** (Kosten in Barren, genaue Werte in der Config):

| Kategorie | Stufen |
|---|---|
| Spitzhacke | Holz → Eisen → Gold → Kristall (schaltet Zonen frei und gräbt schneller) |
| Spezial-Spitzhacke | **Lava** (aus Lava-Erz, Flammen-Spur), **RGB** (aus Prisma-Erz, Farbwechsel-Spur); je etwas besser als die normale Stufe, handelbar |
| Rucksack | 20 → 40 → 80 → 150 |
| Runter | Fallschirm → Gleiter → Raketenrucksack |
| Hoch | Kletterseil → Minenlore → Geysir-Schleuder |

- **Münzen** bekommt man aus dem Garten und vom Händler (Verkauf von Erz, Barren, Wesen).
  Man gibt sie aus für: mehr Garten-, Brut- und Nestplätze.

## 6. Täglicher Login-Bonus

- 7-Tage-Kalender (Tageswechsel: UTC). Tag 1–6: Münzen bzw. Eier, Tag 7: **Glücks-Ei** (Seltenheit mindestens „Selten“).
- Wer einen Tag verpasst, beginnt wieder bei Tag 1. Nach Tag 7 fängt der Kalender von vorn an.
- Belohnung holt man per Klick am Kalender ab; das ist einmal pro UTC-Tag möglich.

## 7. Handel

- Spieler anklicken → Anfrage → der andere nimmt an → Handelsfenster.
- Handelbar: Wesen, Eier, Barren, Spezial-Spitzhacken. Nicht handelbar: Münzen, ausgerüstete Gegenstände, Wesen im Nest.
- Max. 8 Gegenstände pro Seite.
- Jede Änderung setzt beide Bestätigungen zurück. Wenn beide bestätigt haben, läuft ein Countdown von 3 s; danach führt der Server den Tausch aus.
- Der Server prüft beim Ausführen erneut den Besitz, tauscht alles auf einmal und speichert sofort beide Profile.
  Verlässt ein Spieler den Server oder schlägt eine Prüfung fehl, wird abgebrochen und nichts ändert sich.
- Ein Spieler kann nur in einem Handel gleichzeitig sein; alle Tausche werden protokolliert.

## 8. Technik

### Grundsätze
- **Der Server entscheidet alles.** Der Client schickt nur Anfragen (z. B. `DigBlock(x, y, z)`); der Server prüft Besitz, Reichweite (≤ 12 Studs), Werkzeug/Zone und Abbautempo.
- Remote-Aufrufe werden pro Spieler begrenzt (Rate-Limit); alle Argumente werden auf Typ und Wertebereich geprüft.
- Alle Balancing-Werte liegen in Config-Modulen.

### Code-Organisation (Rojo, git)
```
src/
  shared/            -> ReplicatedStorage.Shared
    Config/          Zones, Ores, Eggs, Species, Mutations, Tools, Transport, Daily, Economy
    Genetics.luau    reine Logik: Schlüpfen, Brüten, Effektivwerte, Boni der Begleiter
    Loot.luau        reine Logik: gewichtete Ziehung mit Luck-Faktor
    ShaftGen.luau    reine Logik: Blocktyp für (seed, x, y, z) – deterministisch
    Remotes.luau     Namen und Definitionen aller Remotes
  server/            -> ServerScriptService.Server
    Services/        Data, Plot, Shaft, Inventory, Hatch, Breed, Craft, Garden, Trade, Daily, Merchant, Transport
    Main.server.luau Startet die Services
  client/            -> StarterPlayer.StarterPlayerScripts.Client
    Controllers/     Dig, Transport, Companion, Effects
    UI/              HUD, Inventar, Brutstation, Nest, Werkbank, Handel, Kalender
  vendor/ProfileStore.luau
tests/               Tests für die reinen Logik-Module
```

### Schacht-Technik
- Blocktyp = `ShaftGen(seed, x, y, z)`; der `seed` wird einmal pro Spieler erzeugt und gespeichert.
- Es werden **nur freiliegende Blöcke** (die an Luft grenzen) als Parts erzeugt; beim Abbauen entstehen die Nachbarn neu.
- Gespeichert werden: tiefste erreichte Schicht und eine Bitmaske der abgebauten Blöcke pro Schicht (144 Bit, Base64); ca. 7 KB bei 300 Schichten.

### Speichern
- Mit **ProfileStore** (Session-Locking gegen doppelte Gegenstände bei Serverwechseln).
- Profil: `coins, seed, deepestLayer, minedLayers, backpack, storage{ores, bars}, creatures{}, eggs{}, incubators, nests, gardenSlots, equipped{companions, pickaxe, down, up}, unlocks, daily{streak, lastClaimDay}, lastOnline, version`.
- Automatisches Speichern alle 60 s, beim Verlassen und sofort nach jedem Handel. `version` erlaubt spätere Migrationen.

### Fehlerbehandlung
- Ungültige Anfragen werden verworfen und protokolliert, der Client erhält den korrekten Zustand zurück.
- Lädt ein Profil nicht, wird der Spieler mit Hinweis gekickt; es wird nie mit einem leeren Profil weitergespielt und dieses dann gespeichert.

### Tests
- Reine Module (Genetics, Loot, ShaftGen, Handelsprüfung) mit einem kleinen Test-Runner, ausgeführt in Studio per MCP.
  Geprüft werden: Gen-Grenzen, Wahrscheinlichkeitsverteilungen (Stichprobe), Determinismus von ShaftGen, Handel (atomar, Abbruchfälle).
- Spieltest in Studio per MCP: Play starten, Konsole prüfen, Screenshots.

## 9. Später (nicht im MVP)
Robux-Shop/Gamepasses, Glücksrad (mit angezeigten Wahrscheinlichkeiten), Armee-PvP, Waffen/Superkräfte,
Sonder-Editionen bekannter Brainrots, Event-Höhlen, Marktstand, Bohrfahrzeuge, Jetpack, Reiten auf fliegenden Wesen,
weitere Zonen und Spezial-Spitzhacken (Frost, Galaxy), Handel zwischen Servern.
