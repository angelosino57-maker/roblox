# Pet-Sim-Kern: Vereinfachung (Design)

Stand 30.09.2026. Der Nutzer fand Inseln und Systeme zu kompliziert und zu langweilig. Neuer Kern nach dem Vorbild von Pet Simulator 99, dazu das Klauen aus Steal a Brainrot.

## Kernschleife (ein Satz)

Klick auf Schätze → dein Team zerschlägt sie → Geld fliegt zu dir → kauf Eier für stärkere Wesen → schalte die nächste Insel frei (×12 Geld) → Wiedergeburt (dauerhaft mehr Geld).

## Regeln

- **Wesen** haben nur einen sichtbaren Wert: ⚔️ Kraft. Formel: `Kraft = Ø Gene × Seltenheit × Mutation × Zonenstärke (6^Zone)`.
- **Team:** bis zu 4 Wesen (bisher „Begleiter“) laufen mit und greifen an. Neue Wesen kommen automatisch ins Team, wenn sie stärker sind.
- **Sockel** in der Basis: Wesen verdienen `Kraft × 0,2` Münzen pro Sekunde. Das Geld liegt auf dem Sockel, die Platte kassiert es. Fremde können klauen, der Schild schützt.
- **Schätze:** Kristall, Geldsack, Truhe und Mega-Truhe liegen überall in der Zone. Die Lebenspunkte wachsen ×8 pro Zone, die Münzen ×12. Ein Klick setzt das Team auf ein Ziel, danach sucht es automatisch das nächste. Die Beute wird nach Schadensanteil verteilt.
- **Zonen:**
  - 0 = Himmelsplatz (Boden)
  - 1–5 = Inseln, die man über ein Portal auf dem Platz freikauft (15K × 14^(k−1)). Jede Insel hat ein Portal zurück.
- **Eier:** An jedem Eier-Stand kostet ein Ei 200 × 12^Zone. Es enthält die Wesen dieser Zone, die Seltenheit wird mit Glück gewürfelt.
- **Wiedergeburt:** Ab Zone 5 und 5 Mrd. Münzen. Münzen und Zonen werden zurückgesetzt, die Wesen bleiben, die Münzen gibt es dauerhaft ×(1 + 0,5 × Wiedergeburten).
- **Himmelsbaum:** Er wächst automatisch mit dem Gesamtverdienst. Seine Gestalt entspricht der höchsten freigeschalteten Zone. Das ist reiner Status.

## Tempo (wie Steal an Egg)

- **Stufen:** Tempo-Stufen kauft man mit Münzen. Der Preis ist 150 × 1,55^Stufe, das Lauftempo 16 + 1,6 × Stufe (höchstens 70).
- **Beim Klauen:** Wer ein Wesen trägt, läuft mit 75 % seines Tempos. Ein schnellerer Besitzer holt den Dieb ein, ein schnellerer Dieb entkommt.
- **Weit draußen:** Mega-Truhen liegen am Rand der Zone, Wal-Kapseln verteilen sich über die ganze Karte, das erste Öffnen gewinnt.
- **Sichtbar:** Das Tempo steht in der Spielerliste. Wer nicht weiter levelt, wird überholt.

## FOMO (bleibt)

- **Welt-Events:** Geldregen ×2, Glücksschub (Eier ×3 Glück), Mutations-Wetter (geschlüpfte Wesen mutieren).
- **Riesen-Boss** alle 4 min als Riesen-Schatz: das Team greift an, dazu Schockwellen, MVP-Wesen.
- **Weitere Drops:** Himmelswal-Kapseln, Meteor (goldene Mega-Truhe mit Ansage), Gratis-Geschenke, Daily.

## Entfällt

Füttern, Früchte, Samen und Samen-Laden, Liebesnest, Ressourcen, Insel-Aufträge, Lift und Wolkenflug, wilde Wesen.

## Daten (Profil v6)

- neu: `unlocked` (höchste Zone, aus `tree.layer`), `rebirths`, `totalEarned`, `speedLevel`
- `equipped.companions` = Team (max. 4)
- entfällt: `seeds` (je 500 Münzen), `nests` (Wesen bleiben), `resources`, `tree`
