# Himmelsbaum: Neuausrichtung (Design)

Stand 30.09.2026. Ersetzt das Graben komplett. Ziel: ständiger Dopamin-Rausch und FOMO wie bei Steal a Brainrot / Grow a Garden, aber mit eigener, stärkerer Idee.

## Kernschleife

1. **Wesen auf Sockeln** in der eigenen Basis produzieren Münzen pro Sekunde. Das Geld sammelt sich **auf dem Sockel** an (Billboard „💰 1.2K“). Wer über die **goldene Platte** vor dem Sockel läuft, kassiert mit Pop und Sound.
2. **Münzen füttern den Baum.** Der Baum wächst sichtbar, seine Höhe in Metern schwebt für alle sichtbar darüber und steht in der Spielerliste.
3. **Der Baum trägt Wunderfrüchte.** Jede Frucht reift zu einem Wesen. Je höher der Baum, desto mehr Fruchtplätze und desto seltener die Früchte. Die Reifezeit wächst mit der Seltenheit (15 s bis 8 min).
4. **Wolkendecken:** Bei bestimmten Höhen stoppt der Baum. Der Durchbruch kostet einmalig viel und wird serverweit angesagt. Danach beginnt eine neue Himmels-Ebene mit stärkeren Wesen (Einkommen ×2 pro Ebene).

Statt Laufband (zu abgelutscht) gibt es diese FOMO-Quellen:

- **Früchte im fremden Baum:** Knospen ab Episch werden serverweit angesagt, z. B. „✨ An Angelos Baum wächst eine LEGENDÄRE Frucht – reif in 4:00“. Jeder kann Früchte (reif oder unreif) und Sockel-Wesen klauen: E halten, dann zur eigenen Basis tragen. Der Besitzer kann den Dieb berühren und bekommt so alles zurück.
- **Himmelswal-Abwurf:** Alle 2 Minuten fliegt ein riesiger Wal über die Karte (20 s Vorwarnung) und wirft 8+ leuchtende Kapseln ab: Wesen, Samen oder Münzen. Auch in die Basen der anderen. Wer zuerst öffnet, bekommt sie. Kapseln ab Legendär werden mit Landeort angesagt.
- **Schild:** Knopf am Eingang der Basis. 60 s Laserwand, Fremde fliegen raus. Danach muss man selbst wieder drücken, also vor Ort sein.
- **Mutations-Wetter** (bestehende Welt-Events): Während Regenbogen, Sternschnuppen oder Glut können **Wesen auf den Sockeln live mutieren** und neue Knospen mutiert wachsen. Dazu kommen 💰 Geldregen (Einkommen ×2) und 🍎 Wachstumsschub (Früchte reifen ×3 schneller).
- **Samen-Laden** (vorher Eier-Laden): Lieferung alle 5 min, begrenzter Vorrat. Samen werden am Baum gepflanzt und garantieren die Seltenheit.
- Bleiben: Wilde Wesen und Meteoriten (vorerst auf dem Himmelsplatz), Gratis-Geschenke, Daily, Züchten, Handel, Begleiter.

## Himmels-Ebenen (Config `Tree.layers`)

| # | Name | ab Höhe | Wesen | Gene | Einkommen |
|---|------|---------|-------|------|-----------|
| 0 | Wiese | 0 m | Pilzfrosch, Donner-Hamster | 5–25 | ×1 |
| 1 | Wolkenwald | 100 m | Kristallwurm, Schattenkatze | 15–35 | ×2 |
| 2 | Regenbogeninseln | 300 m | Glühqualle, Stein-Schildkröte | 25–45 | ×4 |
| 3 | Donnerwolken | 700 m | Lava-Axolotl, Maulwurf-Drache | 35–60 | ×8 |
| 4 | Sternenmeer | 1500 m | Goldjaguar, Sonnenschlange | 50–75 | ×16 |
| 5 | Götterhimmel | 3000 m | Glutschildkröte, Sturmqualle | 65–90 | ×32 |

Wesen merken sich ihre Ebene (`creature.layer`, alt = 0).

## Phasen

- **A (jetzt):** Basis mit Sockeln, Platten, Baum, Schild. Früchte, Füttern, Wolkendecken, Wal-Abwurf, Klauen von Wesen und Früchten, Samen-Laden, Live-Mutationen, Spielerliste. Graben, Schacht, Höhlen, Erze, Spitzhacken, Ofen, Gadgets und Quests werden entfernt.
- **B:** Himmels-Inseln über jeder Wolkendecke. Man fährt die Baumkrone hoch und sammelt Ebenen-Ressourcen, die der Durchbruch zusätzlich braucht. Wilde Wesen und Meteoriten ziehen auf die Inseln, runter geht es mit dem Fallschirm.
- **C:** Wiedergeburt (Baum zurücksetzen gegen dauerhaften Multiplikator), globale Bestenliste, schönere Modelle für Baum, Wal und Wesen.

## Daten (Profil v3)

- neu: `tree = {height, layer, fruits = {[slot] = {rarity, mutation?, layer, readyAt, seeded?}}}`
- neu: `pending = {[creatureId] = coins}`, `seeds = {{id, rarity, mutation?}}`
- neu: `stats = {harvested, collected, capsules}`
- Migration v2 → v3: Eier (auch im Brüter und im Rucksack) werden zu Samen. Erze und Barren werden zu Münzen ausgezahlt. Die Gen-Namen bleiben (`dig` heißt in der Anzeige „Wachstum“ und lässt den Baum nebenbei wachsen).
- Weg: `deepestLayer`, `minedLayers`, `backpack`, `storage`, `smelter`, `incubators`, `owned` / `equipped` außer `companions`, `quests`, `seals`, `relics`.

## Regeln und Invarianten

- Der Server ist die Autorität für alle Werte, der Client zeigt nur an.
- Aus dem Garten nimmt ein Wesen nur `Roster.removeFromGarden` heraus. Dabei wird `pending` ausgezahlt. Ausnahme ist Klauen: Dann verfällt das Sockelgeld.
- Wachstum ist gedeckelt bei der Höhe der nächsten, noch nicht durchbrochenen Wolkendecke.
- Klauen ist nicht möglich bei aktivem Schild und während der Schutzzeit nach einem Diebstahl (60 s).
- Keine Robux-Käufe und kein Kaufdruck.
