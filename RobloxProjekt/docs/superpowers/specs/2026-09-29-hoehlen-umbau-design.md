# Höhlen-Umbau – Design

Stand: 29.09.2026 · ersetzt die Ei-Blöcke und den Transport „nur im Förderschacht“ aus dem MVP-Design
(`2026-09-29-dig-and-breed-design.md`). Alles Übrige aus dem MVP bleibt gültig.

## 1. Warum

Feedback aus dem ersten Handtest:
- Eier als Blöcke sind langweilig → Eier sollen in **großen, gestalteten Höhlen** liegen und selbst aufgehoben werden.
- Man steckt in selbst gegrabenen Löchern fest → **Nach-oben-Gadgets überall** nutzbar.
- Unklar, wo das Inventar ist → **richtiges Inventar**, feste Button-Leiste mit Tasten, Aufgabenleiste für Neue.
- Wenige Biome sind okay, aber jedes muss **viel zum Erkunden** haben, inkl. versteckter Händler.

Umsetzung in drei Paketen, jedes für sich spielbar: **P1 Höhlen**, **P2 Gadgets + Inventar + Bedienung**, **P3 Erkunden**.

## 2. Welt: Schächte + gemeinsame Biom-Höhlen (P1)

- Die eigenen Schächte (12×12 Blöcke, Schichten 1–300) bleiben unverändert: Man gräbt nach Erz, die Zonen/Spitzhacken-Stufen bleiben.
- In fünf Tiefenbändern liegen **gemeinsame Biom-Höhlen** (für alle Spieler des Servers), gebaut aus **Roblox-Terrain** plus Deko-Parts:

| Biom | id | Schichten (Boden = letzte) | Zone | Terrain-Materialien | Licht/Nebel |
|---|---|---|---|---|---|
| Dschungel | `jungle` | 20–40 | Erde | Grass, LeafyGrass, Mud, Water | grün, warm |
| Eishöhle | `ice` | 70–95 | Stein | Ice, Glacier, Snow | hellblau |
| Vulkanhöhle | `volcano` | 115–140 | Stein | Basalt, CrackedLava, Rock | rot-orange |
| Kristallgrotte | `crystal` | 180–210 | Kristall | Slate, Glass (Kristalle als Parts), Salt | lila |
| El Dorado | `eldorado` | 260–290 | Kristall | Sandstone, Limestone, Pavement (Gold-Parts) | golden |

- Höhlenfläche: x, z ∈ [−200, 200] (die ganze Karte + Rand). Die Schacht-Säulen (Schacht + Wände, 56×56) stehen als Pfeiler in der Höhle; Terrain wird dort nie gefüllt.
- **Tor:** Die zur Kartenmitte zeigende Wand jedes Schachts hat pro Biom ein Loch (2 Zellen breit, 3 Zellen hoch, direkt über dem Höhlenboden). Gräbt man im eigenen Schacht bis dorthin, steht man in der Höhle. Die Zellen direkt am Tor werden immer gerendert (sichtbar aus der Höhle).
- Fremde Schächte kann nur der Besitzer abbauen (wie bisher); betreten darf man offene Gänge.
- Die Höhlen werden **einmal im Editor** per MCP gebaut (`CaveBuilder`, deterministisch aus festen Seeds) und im Place gespeichert. Zur Laufzeit wird nichts am Terrain verändert.
- Jedes Biom hat **mehrere Bereiche** (je Biom 3, siehe Tabelle unten), verbunden durch Gänge; P1 baut die Hallen, Gänge, Grund-Deko und Ei-Ankerpunkte; P3 ergänzt Truhen, Geheimräume, Händler.

| Biom | Bereiche |
|---|---|
| Dschungel | Wasserfall-Lichtung · Baumkronen-Pfad (Hängebrücken) · versunkener Tempel |
| Eis | gefrorener See · Eisspalten-Labyrinth · Mammut-Grab |
| Vulkan | Lavafluss mit Sprung-Steinen · Schmiede-Ruine · Magmakammer |
| Kristall | Pilzwald · Spiegel-Grotte · schwebende Kristallinseln |
| El Dorado | Goldstadt · Königsgrab · Schatzkammer |

- **Atmosphäre:** Der Client stellt Licht/Nebel/Farbton passend zum Biom ein, sobald der Spieler in dessen Tiefenband und außerhalb eines Schachts ist; oben wieder Tageslicht.

## 3. Eier in den Höhlen (P1)

- **Keine Ei-Blöcke mehr** (`eggChance = 0`); Blöcke liefern nur noch Erz.
- Jedes Biom hat **Ei-Ankerpunkte** (Parts in `workspace.Caves.<biom>.EggAnchors`, Attribut `Spot` = eindeutige ID): auf dem Boden, in Baumkronen, in Nestern.
- **Pro Spieler und Biom sind 6 Eier aktiv**, an zufälligen Ankern. Nur dieser Spieler sieht und hebt sie (Server schickt die Liste an genau diesen Client, der Client zeigt Ei-Modelle + ProximityPrompt „Aufheben“, Taste E).
- Aufheben: Server prüft Anker aktiv für diesen Spieler, Abstand HumanoidRootPart ↔ Anker ≤ 12 Studs, Rucksack nicht voll, Spitzhacken-Stufe reicht für das Biom. Dann wird die Seltenheit gewürfelt (mit Glück) und das Ei landet im Rucksack. Nach **60 s** wächst an einem anderen freien Anker ein neues nach.
- Ei-Daten: `{id, biome, rarity, foundAt}` (statt `zone`). Alte Eier werden beim Laden umgestellt: earth→jungle, stone→ice, crystal→crystal.
- **Arten pro Biom** (Schlüpfen würfelt nur aus der Biom-Liste):
  - Dschungel: Pilzfrosch, Donner-Hamster · Eis: Kristallwurm, Schattenkatze · Vulkan: Lava-Axolotl, Maulwurf-Drache · Kristall: Glühqualle, Stein-Schildkröte · El Dorado: **Goldjaguar**, **Sonnenschlange** (neu).
- Gene beim Schlüpfen je Biom: Dschungel 5–25, Eis 15–35, Vulkan 25–45, Kristall 35–60, El Dorado 50–75. Brutzeit: 30 s / 90 s / 150 s / 240 s / 360 s. Seltenheits-Gewichte wie bisher, El Dorado ohne „Gewöhnlich“.
- Mischarten und Brüten bleiben unverändert.
- **Ei-Events (für alle):** Alle 10 Minuten kündigt der Server an: „🔔 In <Biom> erscheint in 2 Minuten ein <Seltenheit> [mutiertes] Ei!“ (Seltenheit mind. Episch, 50 % mit Mutation). Nach 2 Minuten erscheint es an einem zufälligen Anker des Bioms, **für alle Spieler sichtbar** und leuchtend; wer es zuerst aufhebt (gleiche Prüfungen wie oben), bekommt es, alle werden benachrichtigt („X hat das Event-Ei gefunden!“). Nach 5 Minuten ohne Finder verschwindet es. Das Event-Ei trägt die Mutation und schlüpft garantiert mit ihr.

## 4. Gadgets (P2)

- **Nach oben** ist jederzeit nutzbar (Button „⬆ Nach oben“, Taste **R**): 1 s stillstehen („Aufladen“, Abbruch bei Bewegung), dann fliegt das Gadget den Spieler (verankert, ohne Kollision) auf sein Grundstück. Dauer = Strecke / Tempo. 5 s Abklingzeit; während der Fahrt kein Fallschaden.

| Gadget | id | Tempo (Studs/s) | Effekt | Herkunft |
|---|---|---|---|---|
| Kletterseil | `rope` | 12 | Seil nach oben | Start |
| Enterhaken | `grapple` | 30 | Haken + Kette | Werkbank: 15 Eisen |
| Mini-Rakete | `minirocket` | 70 | Rauch + Flammen | Werkbank: 15 Gold + 5 Kristall, braucht Enterhaken |
| Geysir-Schleuder | `geyser` | 120 | Wasserfontäne | Werkbank: 15 Kristall + 5 Lava-Erz, braucht Mini-Rakete |
| UFO | `ufo` | 250 | Leuchtstrahl | nur geheimer Händler (P3) |

- Die Minenlore entfällt (besessene Lore wird beim Laden zum Enterhaken). Der „Hochfahren“-Prompt am Förderschacht entfällt; das Seil im Förderschacht bleibt zum Klettern.
- Runter bleibt: Fallschirm, Gleiter, Raketenrucksack (wichtig beim Sprung in Höhlen).

## 5. Inventar und Bedienung (P2)

- **Button-Leiste unten** mit Tastenhinweisen: 🎒 Inventar (B) · Wesen (C) · Werkstatt (V) · Handeln (T) · ⬆ Nach oben (R) · ? Hilfe. Am Handy große Buttons, Tasten nur als Hinweis.
- **Inventar-Panel** (Tabs): **Rucksack** (getragene Erze/Eier mit Anzahl), **Lager** (Erze, Barren, Eier), **Ausrüstung** (Spitzhacke, Rucksack, Runter-, Hoch-Gadget; jeweils besessene Varianten mit „Wechseln“).
- **Aufgabenleiste** oben für Neue (Fortschritt im Profil `tutorialStep`): 1) In dein Loch springen 2) Block halten zum Graben 3) Bis Tiefe 20 graben – dort wartet der Dschungel 4) Ein Ei aufheben (E) 5) Mit ⬆ zurück nach oben 6) Ei im Wesen-Menü ausbrüten. Danach verschwindet sie.
- **Hilfe-Panel („?“)** mit allen Tasten und Kurzerklärungen der Systeme.
- Die HUD-Box oben links wird kompakter und überlappt die Panels nicht mehr (Panels rücken nach rechts/unten).

## 6. Erkunden (P3)

- **Schatztruhen** in allen Biom-Bereichen: pro Spieler einmal pro UTC-Tag öffnbar (Münzen, Barren, Biom-Eier; Inhalt nach Biom gestaffelt).
- **Geheimräume**: hinter „rissigen Wänden“ (abbaubare Deko-Parts, nur mit passender Spitzhacke), mit besserer Truhe.
- **Biom-Händler** (sichtbar, je Biom einer): verkauft Biom-Eier (Seltenheit mind. „Ungewöhnlich“), Gadgets/Rezepte der Stufe.
- **Geheime Händler** (versteckt, 1–2 pro Biom): UFO, **Tränke** (Glück ×2 / Grabtempo ×2 für 10 min), Eier mit garantierter Mutation.
- **Geheimkammern im eigenen Schacht**: pro Schicht kleine Chance (aus dem Schacht-Seed), dass eine 3×3×2-Kammer entsteht, mit Truhe oder (selten) wanderndem Händler.
- **Tränke** sind ein neues kleines System: Profil `buffs = {luck = endsAt, dig = endsAt}`, Stats berücksichtigt aktive Buffs.

## 7. Technik

- Neue Module: `Config/Biomes` (Tiefenbänder, Materialien, Licht, Arten, Gene, Brutzeiten, Seltenheit), `CaveBuilder` (Editor: Terrain + Deko + Anker, deterministisch), `CaveEggService` (pro Spieler aktive Anker, Aufheben, Nachwachsen), Client `CaveEggController` (Ei-Modelle + Prompts), `AmbienceController` (Licht je Biom).
- Anpassungen: `ShaftService` (Wände mit Toren, Tor-Zellen immer rendern), `ShaftGen` (keine Ei-Blöcke), `Genetics.hatch` (Biom statt Zone), `Eggs`/`Creatures`-Config, Datenmigration im `DataService` (Profil-`version` 2).
- Tests: reine Logik (Biome-Lookup, Egg-Spawn-Auswahl/Respawn, Hatch pro Biom, Migration, Gadget-Dauer, Tutorial-Fortschritt) im TestRunner; Rest per Playtest/DevBridge/Screenshots.
- Performance-Ziel: Terrain statt Tausender Parts; Deko-Parts pro Biom ≤ 400; Ei-Modelle nur clientseitig.
