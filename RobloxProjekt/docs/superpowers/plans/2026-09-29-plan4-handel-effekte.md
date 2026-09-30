# Plan 4: Handel + Effekte – Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sicheres Handelsfenster zwischen Spielern auf demselben Server sowie sichtbare Effekte für Mutationen, Spezial-Spitzhacken und Transportmittel.

**Architecture:** Reine Logik `Trade` (Prüfen und atomares Tauschen) und `TradeSession` (Zustandsmaschine: Angebote, Bestätigungen, Version) in `ReplicatedStorage.Shared`, voll getestet mit Fake-Spielern. `TradeService` ist nur noch Verdrahtung (Anfragen, Remotes, 3-s-Countdown, Speichern, Log). Client: `TradeClient` (Zustand) + `TradePanel` (Widgets). Effekte: `CreatureModel` bekommt Partikel, ein Client-`EffectsController` animiert Regenbogen und Dig-Effekte, Transport-Optik im `FallController` und `TransportService`.

**Spec:** Abschnitte 4 (Mutationen), 5 (Spezial-Spitzhacken), 7 (Handel). Teil 4 von 4. Umfang wie Plan 2/3.

## Global Constraints

- Handelbar: Wesen, Eier, Barren, Spezial-Spitzhacken. Nicht: Münzen, Begleiter, ausgerüstete Spitzhacke, Wesen im Nest, brütende Eier.
- Max. 8 Einträge pro Seite (ein Barren-Eintrag = eine Erz-ID mit Menge).
- Jede Änderung setzt beide Bestätigungen zurück. Beide bestätigt → 3 s Countdown → Server prüft erneut und tauscht atomar; danach sofort beide Profile speichern und den Tausch protokollieren.
- Abbruch, wenn ein Spieler geht oder abbricht; ein Spieler ist in höchstens einem Handel. Anfragen verfallen nach 30 s.
- Empfänger-Lager (100 Wesen) darf nicht überlaufen (`"storage"`); eine Spezial-Spitzhacke, die der Empfänger schon besitzt, blockiert den Tausch (`"owned"`).

---

### Task 1: Trade + TradeSession (reine Logik)

**Interfaces:**
- Angebot = Array von `{kind: "creature"|"egg"|"bar"|"pickaxe", id: string, amount: number?}` (amount nur bei `bar`)
- `Trade.MAX_ITEMS = 8`, `Trade.validateOffer(data, offer) -> (ok, reason?)` mit Gründen `"invalid" | "too many" | "duplicate" | "missing" | "companion" | "busy" | "equipped"`, `Trade.sanitize(offer) -> offer` (Kopie nur mit bekannten Feldern), `Trade.execute(dataA, offerA, dataB, offerB) -> (ok, reason?, side?)` (`side` = `"a"`/`"b"`, zusätzlich `"storage" | "owned"`)
- `TradeSession.new(a, b)`, `:has(p)`, `:partner(p)`, `:setOffer(p, offer, data) -> (ok, reason?)` (setzt Bestätigungen zurück, erhöht `version`), `:confirm(p) -> boolean` (true = beide bestätigt), `:execute(dataA, dataB) -> (ok, reason?, side?)`, `:view(p) -> {myOffer, theirOffer, myConfirmed, theirConfirmed, version}`

- [ ] **Step 1: Failing Test** – `tests/Trade.spec.luau` prüft:
  - Validierung: Begleiter (`"companion"`), Nest (`"busy"`), brütendes Ei (`"busy"`), fehlendes Wesen (`"missing"`), doppeltes Wesen (`"duplicate"`), Barren über Bestand (auch über mehrere Einträge summiert, `"missing"`), normale Spitzhacke (`"invalid"`), ausgerüstete Spezial-Spitzhacke (`"equipped"`), 9 Einträge (`"too many"`), Tabelle mit Nicht-Array-Keys (`"invalid"`).
  - `execute` tauscht Wesen (auch aus dem Garten entfernt), Eier, Barren und Spitzhacken in beide Richtungen; bei einem Fehler auf einer Seite bleiben **beide** Profile unverändert; `"storage"` und `"owned"`.
  - `TradeSession`: `setOffer` setzt Bestätigungen zurück und erhöht die Version; `confirm` gibt erst bei beiden `true` zurück; `view` spiegelt die Seiten.
- [ ] **Step 2:** Sync + Tests → `LOAD FAIL`.
- [ ] **Step 3:** Implementieren (`src/shared/Trade.luau`, `src/shared/TradeSession.luau`); `execute` prüft zuerst alles und verändert erst danach Daten (keine Fehler mehr nach der ersten Mutation möglich).
- [ ] **Step 4:** Sync + Tests → `0 failed`. **Step 5:** Commit `feat: Handelslogik (Prüfung, atomarer Tausch, Sitzung)`.

### Task 2: TradeService

**Interfaces / Regeln:**
- Remotes: `TradeRequest(targetUserId)`, `TradeRespond(fromUserId, accept: boolean)`, `TradeSetOffer(offer)`, `TradeConfirm()`, `TradeCancel()`; Server → Client: `TradeInvite(fromUserId, fromName)`, `TradeUpdate(view | nil)` (`view` + `partnerName`, `partnerUserId`, `countdownEndsAt?`).
- `TradeService.request(player, targetUserId) -> (ok, reason?)`: Ziel existiert, ist nicht man selbst (`"self"`), beide sind in keinem Handel (`"busy"`) → Einladung merken (30 s gültig) und `TradeInvite` an das Ziel.
- `TradeService.respond(player, fromUserId, accept)`: gültige Einladung → bei `accept` Sitzung starten und beiden `TradeUpdate` senden; sonst Notify „abgelehnt“.
- `setOffer`/`confirm`/`cancel` über die Sitzung; nach jeder Änderung beiden `TradeUpdate`. Beide bestätigt → `countdownEndsAt = now + 3`, nach 3 s nur ausführen, wenn die Version unverändert ist. Erfolg → `DataService.save` für beide, `CreatureService.refresh` für beide, `StateService.push` für beide, Notify „Handel abgeschlossen!“, Log `print("[Trade] a <-> b ...")`, Sitzung schließen. Fehler → Notify mit Grund, Bestätigungen zurücksetzen.
- `DataService.onRemoving` → laufende Sitzung abbrechen (Partner bekommt Notify + `TradeUpdate(nil)`), Einladungen löschen.
- [ ] **Step 1:** Implementieren, syncen und per DevBridge prüfen (1 Spieler): `request(player, player.UserId)` → `"self"`; `request(player, 1)` → `"missing"`. Der Handel zwischen zwei Spielern wird über die `TradeSession`-Tests und im Abschluss-Handtest des Nutzers (Studio → Test → 2 Spieler) geprüft.
- [ ] **Step 2:** Commit `feat: TradeService (Anfrage, Countdown, Speichern, Log)`.

### Task 3: Handels-UI

- `TradeClient.start()`, `TradeClient.view`, `TradeClient.invites` (`{[userId] = name}`), `TradeClient.changed`.
- `TradePanel` (Widgets-Panel „Handeln“, Tabs **Spieler** und **Handel**):
  - **Spieler:** andere Spieler mit „Handel anfragen“; offene Einladungen mit „Annehmen“/„Ablehnen“.
  - **Handel:** Partnername und Status (bestätigt / Countdown); „Dein Angebot“ (Einträge mit „−“); „Sein Angebot“; darunter die eigenen handelbaren Sachen mit „+“ (Wesen, Eier, Barren in 1er- und 10er-Schritten, Spezial-Spitzhacken); Buttons „Bestätigen“ und „Abbrechen“. Wechselt automatisch zum Tab Handel, wenn eine Sitzung startet.
- [ ] Implementieren, syncen, Panel öffnen (Screenshot), Tabs prüfen. Commit `feat: Handels-Panel`.

### Task 4: Effekte

- `CreatureModel`: Partikel je Mutation (Gold/Diamant: Funkeln, Frost: Schnee, Lava: Feuer, Galaxy: Sterne) und Attribut `Rainbow` bei Regenbogen. Legendäre und mythische Wesen leuchten (PointLight).
- `EffectsController` (Client): färbt alle Teile mit Attribut `Rainbow` fortlaufend (HSV-Zyklus); spielt beim Abbauen einen kurzen Partikel-Burst am Block – normal Staub in der Zonenfarbe, Lava-Spitzhacke Flammen, RGB-Spitzhacke Regenbogen-Funken. Dazu sendet der `DigController` ein lokales Ereignis `DigController.dug` mit Position und Zone.
- `FallController`: Aussehen nach Runter-Teil – Fallschirm (roter Schirm), Gleiter (breite blaue Flügel), Raketenrucksack (Feuer-Partikel unter dem Spieler).
- `TransportService.rideUp`: während der Fahrt eine Lore (Minenlore) bzw. Wasser-/Dampf-Partikel (Geysir) am Spieler, danach entfernen.
- [ ] Implementieren, syncen; Screenshots: Wesen mit Mutationen im Editor (Vorschau wie in Plan 2), Dig-Burst im Playtest. Commit `feat: Effekte für Mutationen, Spitzhacken und Transport`.

### Task 5: Abschluss

- [ ] Alle Tests, Konsole, Obsidian-Fortschritt, Merge in `main`, Abschlussbericht mit Handtest-Liste für den Nutzer.
