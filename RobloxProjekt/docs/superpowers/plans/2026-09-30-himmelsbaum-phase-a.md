# Himmelsbaum Phase A: Umsetzungsplan

**Ziel:** Graben durch die Baum-Schleife ersetzen (Sockel-Einkommen, Baum füttern, Früchte, Wal-Abwurf, Klauen, Schild). Die Spezifikation steht in `docs/superpowers/specs/2026-09-30-himmelsbaum-design.md`.

**Architektur:** Die Spiellogik liegt als reine Module in `src/shared` (`Tree`, `Format`, `Economy`, `Roster`, `Migrate`, `Fomo`) und ist mit Specs unter `tests/` abgedeckt. Die Server-Services besitzen die Welt-Objekte:
- `PlotService`: Basen
- `CreatureService`: Sockel und Platten
- `TreeService`: Baum und Früchte
- `StealService`: Klauen und Schild
- `AirdropService`: Wal
- `ActionService`: wilde Wesen und Meteoriten
- `FomoService`: Wetter und Laden

Der Client zeigt an und schickt Wünsche per Remote.

## Aufgaben

1. **Shared-Kern mit Tests**
   - `Config/Tree` für Ebenen, Seltenheiten, Reifezeiten, Fruchtplätze, Kosten und Wolkendecken.
   - `Tree` mit den Funktionen `fruitSlots`, `meterCost`, `feed`, `cap`, `rollFruit`, `physicalHeight`, `layerAt`.
   - `Format.short`.
   - `Genetics.hatch({layer, rarity, mutation})`.
   - `Economy` (pro Wesen, Ebenen-Macht, Event-Faktor).
   - `Roster.removeFromGarden`.
   - `Migrate` v3.
   - `ProfileTemplate` v3.
   - `Fomo`: neue Events, `nextWhaleAt`, Samen-Angebote.
2. **Graben entfernen**
   - Löschen: Shaft*, Dig*, Zones, Ores, Tools, Recipes, Workshop*, Gear, Transport, CaveEgg*, CaveBuilder, Quests*, Ambience, Gadget, Backpack, Hatch, Biomes, Eggs, Prices.ores sowie deren Tests.
   - Anpassen: Trade (Samen statt Eier/Barren/Hacken), Market (nur Wesen und Plätze), Daily (Münzen/Samen), Tutorial, StateService-Snapshot.
3. **Welt**
   - `BaseLayout` (Positionen) und `WorldBuilder` v3: Himmelsplatz, Samen-Stand, 8 Basen mit Zaun, Eingang, Laser, Schild-Knopf, 10 Sockeln mit Platten und Baumplatz.
   - Löschen: alte Höhlen, Hüllen und das Terrain.
4. **Server-Services**
   - PlotService (Basen)
   - CreatureService (Sockel-Billboards, Platten, pending-Einkommen)
   - TreeService (Modell, Füttern E/F, Früchte, Ernten, Pflanzen, Durchbruch, leaderstats)
   - StealService (Wesen und Früchte, Schild 60 s, Schutzzeit)
   - AirdropService (Wal alle 120 s)
   - ActionService (Plaza-Punkte, Meteor gibt Münzen und Samen)
   - FomoService (Samen-Laden, Live-Mutation, Einkommens- und Reife-Faktor)
5. **Client**
   - Hud (Münzen, /s, Höhe, nächstes Ziel)
   - RevealController (großes Banner) und Sammel-Pops
   - FomoWidget mit Wal-Countdown
   - Panels (Samen, Wesen, Laden/Händler/Kalender, Handel, Hilfe)
   - Dig-, Gadget-, Höhlen- und Ambience-Controller entfernen
6. **In Studio**
   - Synchronisieren, Welt bauen, Terrain leeren.
   - Playtest mit DevBridge: Füttern, Ernten, Wal, Klauen-Logik.
   - Screenshots machen, Tests grün, committen.

**Nachweis:** `TestRunner.run()` ist grün. Im Playtest werden geprüft: Füttern erhöht die Höhe, eine Frucht reift und lässt sich ernten, die Platte zahlt aus, Wal-Kapseln landen und lassen sich öffnen, der Schild wirft Fremde raus.
