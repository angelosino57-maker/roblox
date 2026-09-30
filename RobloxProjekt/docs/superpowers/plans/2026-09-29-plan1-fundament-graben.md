# Plan 1: Fundament + Graben – Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Spielbarer Grab-Loop: Spieler bekommt ein Grundstück mit eigenem Schacht, gräbt Blöcke ab, sammelt Erze und Eier im Rucksack, legt sie oben ab; Förderschacht mit Kletterseil und Fallschirm; Spielstand wird gespeichert.

**Architecture:** Rojo synchronisiert `src/` nach Studio. Reine Logik (Config, Loot, ShaftGen, MinedMask, Stats) liegt in `ReplicatedStorage.Shared` und wird getestet. Server-Services (Data, Plot, State, Backpack, Shaft, Transport) entscheiden alles; der Client schickt nur Anfragen (Dig, FellHard) und zeigt einen State-Snapshot an.

**Tech Stack:** Luau, Rojo 7.7 (Homebrew), ProfileStore (vendored, MAD STUDIO), Roblox Studio MCP (Tests/Playtests).

**Spec:** `docs/superpowers/specs/2026-09-29-dig-and-breed-design.md` (Abschnitte 2, 3, 8). Dieser Plan ist Teil 1 von 4 (2: Wesen, 3: Wirtschaft, 4: Handel + Effekte).

## Abweichungen bei der Umsetzung (29.09.2026)

- **Kein Rojo.** Der Nutzer möchte, dass Claude selbst in Studio baut, ohne manuelle Schritte. Stattdessen:
  `python3 tools/manifest.py` erzeugt `manifest.json`, `python3 -m http.server 34999 --bind 127.0.0.1` stellt die Dateien bereit,
  und `ServerStorage.DevTools.Sync` (Quelle: `tools/sync.luau`) holt sie per MCP `execute_luau` (Edit) in Studio.
  HTTP wird dabei nur für die Dauer des Syncs eingeschaltet. Aufruf:
  ```lua
  local dev = game:GetService("ServerStorage").DevTools
  local copy = dev.Sync:Clone(); copy.Parent = dev
  local result = require(copy)(); copy:Destroy(); return result
  ```
- **DevBridge statt direktem `require`.** Code aus `execute_luau` bekommt eigene Modul-Instanzen und sieht die laufenden Services nicht.
  Deshalb legt `Main.server` nur in Studio `ServerStorage.DevBridge` (BindableFunction) an:
  `bridge:Invoke("ShaftService", "tryDig", player, x, layer, z)`. Alle Service-Prüfungen in den Tasks laufen darüber.

## Global Constraints

- Schacht: 12×12 Blöcke, Blockgröße 4 Studs, Schichten 1–300, Förderschacht = Zellen x∈{0,1}, z∈{0,1} (nicht abbaubar).
- Zonen: Erde 1–50 (Holz), Stein 51–150 (Eisen), Kristallhöhle 151–300 (Kristall).
- Reichweite beim Graben: Server akzeptiert ≤ 14 Studs Abstand HumanoidRootPart ↔ Blockmitte (12 Studs + halbe Blockdiagonale).
- Fallschaden ab 60 Studs ohne ausgelösten Fallschirm → Tod/Respawn, Rucksack bleibt.
- Startausrüstung: Holz-Spitzhacke, Rucksack 20, Fallschirm, Kletterseil.
- Speichern: ProfileStore, Store-Name `PlayerData_v1`, Key `Player_<UserId>`, Auto-Save 60 s. Lädt ein Profil nicht → Kick, nie mit leerem Profil weiterspielen.
- Server ist autoritativ; jede Remote wird rate-limitiert und Argumente werden auf Typ/Ganzzahl geprüft.
- Max. 8 Grundstücke; ohne freies Grundstück → Kick „Server voll“.
- Alle Texte für Spieler auf Deutsch.

## Dateistruktur

```
default.project.json            Rojo-Mapping
.gitignore
src/shared/                      -> ReplicatedStorage.Shared
  Config/Rarity.luau             Seltenheits-Reihenfolge + Multiplikatoren
  Config/Ores.luau               Erz-Definitionen (Name, Seltenheit, Farbe)
  Config/Eggs.luau               Ei-Seltenheitsgewichte
  Config/Zones.luau              Zonen + forLayer()
  Config/Tools.luau              Spitzhacken, Rucksäcke, Transport, Fallschaden
  Loot.luau                      gewichtete Ziehung mit Luck
  ShaftGen.luau                  deterministischer Blocktyp
  MinedMask.luau                 Bitmaske abgebauter Blöcke (Hex pro Schicht)
  Stats.luau                     abgeleitete Werte aus Profil (Kapazität, Grabzeit, Luck)
  Remotes.luau                   RemoteEvents anlegen/finden
src/server/                      -> ServerScriptService.Server
  Main.server.luau               startet Services in fester Reihenfolge
  ProfileTemplate.luau
  RateLimiter.luau
  Services/DataService.luau
  Services/PlotService.luau
  Services/StateService.luau
  Services/BackpackService.luau
  Services/ShaftService.luau
  Services/TransportService.luau
src/vendor/ProfileStore.luau     -> ServerScriptService.Vendor
src/client/                      -> StarterPlayer.StarterPlayerScripts.Client
  Main.client.luau
  ClientState.luau
  UI/Hud.luau
  Controllers/DigController.luau
  Controllers/FallController.luau
tests/                           -> ServerStorage.Tests
  TestRunner.luau, Expect.luau, *.spec.luau
```

## Tests ausführen (gilt für alle Tasks)

Tests laufen im **Server-Datenmodell während eines Playtests** (so gibt es keinen veralteten `require`-Cache):
1. `rojo serve` läuft, das Rojo-Plugin in Studio ist verbunden.
2. MCP `start_stop_play(is_start=true)`.
3. MCP `execute_luau(datamodel_type="Server")` mit
   ```lua
   return require(game:GetService("ServerStorage").Tests.TestRunner).run("<Filter oder nil>")
   ```
4. MCP `start_stop_play(is_start=false)`.

Die erste Zeile der Ausgabe lautet `N passed, M failed`; danach folgt eine Zeile pro Fehler.

---

### Task 1: Toolchain, Projektgerüst, Test-Runner

**Files:**
- Create: `default.project.json`, `.gitignore`, `src/vendor/ProfileStore.luau`, `src/server/Main.server.luau`, `src/client/Main.client.luau`, `src/shared/Config/.gitkeep`
- Create: `tests/TestRunner.luau`, `tests/Expect.luau`, `tests/Smoke.spec.luau`

**Interfaces:**
- Produces: `TestRunner.run(filter: string?) -> string`; `Expect.eq(actual, expected, msg?)`, `Expect.truthy(v, msg?)`, `Expect.near(a, b, tol, msg?)`, `Expect.errors(fn, msg?)`. Spec-Dateien heißen `<Name>.spec.luau` und geben `{ {name: string, fn: () -> ()} }` zurück.

- [ ] **Step 1: Rojo installieren und Plugin in Studio installieren**

```bash
brew install rojo
rojo --version        # erwartet: Rojo 7.7.x
rojo plugin install   # legt das Plugin in Studios Plugin-Ordner
```
Dann Studio neu starten (der Nutzer muss das tun), damit das Plugin erscheint.

- [ ] **Step 2: Projektdateien anlegen**

`default.project.json`:
```json
{
  "name": "DigAndBreed",
  "tree": {
    "$className": "DataModel",
    "ReplicatedStorage": {
      "Shared": { "$path": "src/shared" }
    },
    "ServerScriptService": {
      "Server": { "$path": "src/server" },
      "Vendor": { "$path": "src/vendor" }
    },
    "ServerStorage": {
      "Tests": { "$path": "tests" }
    },
    "StarterPlayer": {
      "StarterPlayerScripts": {
        "Client": { "$path": "src/client" }
      }
    }
  }
}
```

`.gitignore` (der Place ist fast leer; die Welt entsteht zur Laufzeit, Code ist die Quelle der Wahrheit):
```
.DS_Store
sourcemap.json
*.rbxl
*.rbxlx
*.rbxl.lock
*.rbxlx.lock
```

ProfileStore holen:
```bash
mkdir -p src/vendor src/shared/Config src/server/Services src/client/UI src/client/Controllers tests
curl -fsSL https://raw.githubusercontent.com/MadStudioRoblox/ProfileStore/main/ProfileStore.luau -o src/vendor/ProfileStore.luau
head -3 src/vendor/ProfileStore.luau   # erwartet: "--[[" und "MAD STUDIO (by loleris)"
touch src/shared/Config/.gitkeep
```

`src/server/Main.server.luau` (wird in Task 6 erweitert):
```lua
print("[DigAndBreed] Server gestartet")
```

`src/client/Main.client.luau` (wird in Task 10 erweitert):
```lua
print("[DigAndBreed] Client gestartet")
```

- [ ] **Step 3: Test-Runner schreiben**

`tests/Expect.luau`:
```lua
local Expect = {}

local function show(v)
	if typeof(v) == "table" then
		return "<table>"
	end
	return tostring(v)
end

local function prefix(msg)
	return if msg then msg .. ": " else ""
end

function Expect.eq(actual, expected, msg)
	if actual ~= expected then
		error(prefix(msg) .. "expected " .. show(expected) .. ", got " .. show(actual), 2)
	end
end

function Expect.truthy(v, msg)
	if not v then
		error(prefix(msg) .. "expected truthy, got " .. show(v), 2)
	end
end

function Expect.near(a, b, tol, msg)
	if math.abs(a - b) > tol then
		error(prefix(msg) .. string.format("expected %.4f ± %.4f, got %.4f", b, tol, a), 2)
	end
end

function Expect.errors(fn, msg)
	local ok = pcall(fn)
	if ok then
		error(prefix(msg) .. "expected an error", 2)
	end
end

return Expect
```

`tests/TestRunner.luau`:
```lua
local TestRunner = {}

function TestRunner.run(filter: string?): string
	local passed, failed = 0, 0
	local lines = {}
	local specs = {}
	for _, inst in script.Parent:GetDescendants() do
		if inst:IsA("ModuleScript") and inst.Name:match("%.spec$") then
			if filter == nil or inst.Name:find(filter, 1, true) then
				table.insert(specs, inst)
			end
		end
	end
	table.sort(specs, function(a, b)
		return a.Name < b.Name
	end)

	for _, spec in specs do
		local ok, cases = pcall(require, spec)
		if not ok then
			failed += 1
			table.insert(lines, "LOAD FAIL " .. spec.Name .. ": " .. tostring(cases))
			continue
		end
		for _, case in cases do
			local okCase, err = pcall(case[2])
			if okCase then
				passed += 1
			else
				failed += 1
				table.insert(lines, "FAIL " .. spec.Name .. " > " .. case[1] .. ": " .. tostring(err))
			end
		end
	end

	table.insert(lines, 1, string.format("%d passed, %d failed", passed, failed))
	return table.concat(lines, "\n")
end

return TestRunner
```

`tests/Smoke.spec.luau`:
```lua
local Expect = require(script.Parent.Expect)

return {
	{ "runner works", function()
		Expect.eq(1 + 1, 2)
	end },
	{ "errors are caught", function()
		Expect.errors(function()
			error("boom")
		end)
	end },
}
```

- [ ] **Step 4: Rojo starten und verbinden**

```bash
rojo serve   # im Hintergrund laufen lassen (Port 34872)
```
Der Nutzer klickt in Studio: Plugins → Rojo → **Connect**. Danach per MCP (`execute_luau`, Edit) prüfen:
```lua
local rs = game:GetService("ReplicatedStorage")
local ss = game:GetService("ServerStorage")
return tostring(rs:FindFirstChild("Shared") ~= nil) .. " " .. tostring(ss:FindFirstChild("Tests") ~= nil)
```
Expected: `true true`

- [ ] **Step 5: Standard-Baseplate und SpawnLocation aus dem Place entfernen**

Die Welt baut sich zur Laufzeit selbst auf (Task 7). MCP `execute_luau` (Edit):
```lua
local removed = {}
for _, name in { "Baseplate", "SpawnLocation" } do
	local inst = workspace:FindFirstChild(name)
	if inst then
		inst:Destroy()
		table.insert(removed, name)
	end
end
return table.concat(removed, ", ")
```
Danach speichert der Nutzer den Place (Datei → Speichern unter) als `RobloxProjekt/DigAndBreed.rbxl`.

- [ ] **Step 6: Tests ausführen**

Siehe „Tests ausführen“. Expected: `2 passed, 0 failed`.

- [ ] **Step 7: Commit**

```bash
git add default.project.json .gitignore src tests
git commit -m "chore: Rojo-Projekt, ProfileStore und Test-Runner einrichten"
```

---

### Task 2: Config (Seltenheit, Erze, Eier, Zonen) + Loot

**Files:**
- Create: `src/shared/Config/Rarity.luau`, `src/shared/Config/Ores.luau`, `src/shared/Config/Eggs.luau`, `src/shared/Config/Zones.luau`, `src/shared/Loot.luau`
- Delete: `src/shared/Config/.gitkeep`
- Test: `tests/Loot.spec.luau`

**Interfaces:**
- Produces:
  - `Rarity.order: {string}`, `Rarity.multiplier: {[string]: number}`, `Rarity.index(name) -> number`, `Rarity.LUCK_FROM = 3`
  - `Ores[id] = {name: string, rarity: string, color: Color3}` für `copper, iron, gold, crystal, lava_ore, prism_ore`
  - `Eggs.rarityEntries: {{id: string, weight: number, rarity: string}}`, `Eggs.byZone[zoneId] = {name: string}`
  - `Zones.list: {Zone}`, `Zones.byId[id]`, `Zones.forLayer(layer) -> Zone`. Zone = `{id, name, fromLayer, toLayer, requiredTier, hardness, oreChance, eggChance, color, material, oreColor, ores: {{id, weight, minLayer?}}}`
  - `Loot.pick(entries, rng: Random, luck: number) -> entry`, `Loot.probabilities(entries, luck) -> {[id]: number}`, `Loot.rollOre(zone, layer, rng, luck) -> string`

- [ ] **Step 1: Failing Test schreiben**

`tests/Loot.spec.luau`:
```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Expect = require(script.Parent.Expect)
local Loot = require(Shared.Loot)
local Zones = require(Shared.Config.Zones)
local Eggs = require(Shared.Config.Eggs)

local entries = {
	{ id = "a", weight = 75, rarity = "Gewöhnlich" },
	{ id = "b", weight = 25, rarity = "Selten" },
}

return {
	{ "probabilities follow weights without luck", function()
		local p = Loot.probabilities(entries, 1)
		Expect.near(p.a, 0.75, 1e-9)
		Expect.near(p.b, 0.25, 1e-9)
	end },
	{ "luck multiplies only rarity >= Selten", function()
		local p = Loot.probabilities(entries, 3)
		-- a: 75, b: 25*3 = 75 -> 50/50
		Expect.near(p.a, 0.5, 1e-9)
		Expect.near(p.b, 0.5, 1e-9)
	end },
	{ "pick matches probabilities in a sample", function()
		local rng = Random.new(42)
		local counts = { a = 0, b = 0 }
		for _ = 1, 20000 do
			local e = Loot.pick(entries, rng, 1)
			counts[e.id] += 1
		end
		Expect.near(counts.b / 20000, 0.25, 0.02)
	end },
	{ "rollOre respects minLayer", function()
		local stone = Zones.byId.stone
		local rng = Random.new(1)
		for _ = 1, 2000 do
			Expect.truthy(Loot.rollOre(stone, 60, rng, 1) ~= "lava_ore", "lava_ore below layer 100")
		end
		local seenLava = false
		for _ = 1, 5000 do
			if Loot.rollOre(stone, 120, rng, 1) == "lava_ore" then
				seenLava = true
				break
			end
		end
		Expect.truthy(seenLava, "lava_ore possible at layer 120")
	end },
	{ "egg rarity probabilities sum to 1", function()
		local sum = 0
		for _, p in Loot.probabilities(Eggs.rarityEntries, 1) do
			sum += p
		end
		Expect.near(sum, 1, 1e-9)
	end },
	{ "zones cover layers 1..300", function()
		Expect.eq(Zones.forLayer(1).id, "earth")
		Expect.eq(Zones.forLayer(50).id, "earth")
		Expect.eq(Zones.forLayer(51).id, "stone")
		Expect.eq(Zones.forLayer(150).id, "stone")
		Expect.eq(Zones.forLayer(151).id, "crystal")
		Expect.eq(Zones.forLayer(300).id, "crystal")
	end },
}
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag prüfen**

Filter `"Loot"`. Expected: `LOAD FAIL Loot.spec: ... Loot is not a valid member of Folder "ReplicatedStorage.Shared"`.

- [ ] **Step 3: Config und Loot implementieren**

`src/shared/Config/Rarity.luau`:
```lua
local Rarity = {}

Rarity.order = { "Gewöhnlich", "Ungewöhnlich", "Selten", "Episch", "Legendär", "Mythisch" }

Rarity.multiplier = {
	["Gewöhnlich"] = 1,
	["Ungewöhnlich"] = 1.2,
	["Selten"] = 1.5,
	["Episch"] = 2,
	["Legendär"] = 3,
	["Mythisch"] = 5,
}

-- Luck wirkt auf alle Seltenheiten ab diesem Index ("Selten").
Rarity.LUCK_FROM = 3

local indexOf = {}
for i, name in Rarity.order do
	indexOf[name] = i
end

function Rarity.index(name: string): number
	local i = indexOf[name]
	assert(i, "unknown rarity " .. tostring(name))
	return i
end

return Rarity
```

`src/shared/Config/Ores.luau`:
```lua
return {
	copper = { name = "Kupfer", rarity = "Gewöhnlich", color = Color3.fromRGB(196, 116, 70) },
	iron = { name = "Eisen", rarity = "Gewöhnlich", color = Color3.fromRGB(170, 170, 180) },
	gold = { name = "Gold", rarity = "Ungewöhnlich", color = Color3.fromRGB(240, 200, 60) },
	crystal = { name = "Kristall", rarity = "Selten", color = Color3.fromRGB(120, 220, 255) },
	lava_ore = { name = "Lava-Erz", rarity = "Episch", color = Color3.fromRGB(255, 90, 30) },
	prism_ore = { name = "Prisma-Erz", rarity = "Episch", color = Color3.fromRGB(255, 120, 255) },
}
```

`src/shared/Config/Eggs.luau`:
```lua
local Eggs = {}

Eggs.byZone = {
	earth = { name = "Erd-Ei" },
	stone = { name = "Stein-Ei" },
	crystal = { name = "Kristall-Ei" },
}

-- Seltenheit wird beim Finden gewürfelt (mit Luck).
Eggs.rarityEntries = {
	{ id = "Gewöhnlich", weight = 60, rarity = "Gewöhnlich" },
	{ id = "Ungewöhnlich", weight = 25, rarity = "Ungewöhnlich" },
	{ id = "Selten", weight = 10, rarity = "Selten" },
	{ id = "Episch", weight = 4, rarity = "Episch" },
	{ id = "Legendär", weight = 0.9, rarity = "Legendär" },
	{ id = "Mythisch", weight = 0.1, rarity = "Mythisch" },
}

return Eggs
```

`src/shared/Config/Zones.luau`:
```lua
local Zones = {}

Zones.list = {
	{
		id = "earth",
		name = "Erde",
		fromLayer = 1,
		toLayer = 50,
		requiredTier = 1,
		hardness = 1,
		oreChance = 0.08,
		eggChance = 0.008,
		color = Color3.fromRGB(110, 78, 52),
		material = Enum.Material.Ground,
		oreColor = Color3.fromRGB(185, 120, 70),
		ores = { { id = "copper", weight = 60 }, { id = "iron", weight = 40 } },
	},
	{
		id = "stone",
		name = "Stein",
		fromLayer = 51,
		toLayer = 150,
		requiredTier = 2,
		hardness = 2,
		oreChance = 0.10,
		eggChance = 0.010,
		color = Color3.fromRGB(120, 120, 125),
		material = Enum.Material.Slate,
		oreColor = Color3.fromRGB(215, 185, 90),
		ores = {
			{ id = "iron", weight = 55 },
			{ id = "gold", weight = 40 },
			{ id = "lava_ore", weight = 5, minLayer = 100 },
		},
	},
	{
		id = "crystal",
		name = "Kristallhöhle",
		fromLayer = 151,
		toLayer = 300,
		requiredTier = 4,
		hardness = 3,
		oreChance = 0.12,
		eggChance = 0.012,
		color = Color3.fromRGB(110, 90, 170),
		material = Enum.Material.Ice,
		oreColor = Color3.fromRGB(120, 220, 255),
		ores = {
			{ id = "gold", weight = 50 },
			{ id = "crystal", weight = 45 },
			{ id = "prism_ore", weight = 5 },
		},
	},
}

Zones.byId = {}
for _, zone in Zones.list do
	Zones.byId[zone.id] = zone
end

function Zones.forLayer(layer: number)
	for _, zone in Zones.list do
		if layer >= zone.fromLayer and layer <= zone.toLayer then
			return zone
		end
	end
	return Zones.list[#Zones.list]
end

return Zones
```

`src/shared/Loot.luau`:
```lua
local Rarity = require(script.Parent.Config.Rarity)
local Ores = require(script.Parent.Config.Ores)

local Loot = {}

local function effectiveWeights(entries, luck: number)
	local weights, total = {}, 0
	for i, entry in entries do
		local w = entry.weight
		if Rarity.index(entry.rarity) >= Rarity.LUCK_FROM then
			w *= luck
		end
		weights[i] = w
		total += w
	end
	return weights, total
end

function Loot.pick(entries, rng: Random, luck: number)
	local weights, total = effectiveWeights(entries, luck)
	local r = rng:NextNumber() * total
	for i, entry in entries do
		r -= weights[i]
		if r < 0 then
			return entry
		end
	end
	return entries[#entries]
end

function Loot.probabilities(entries, luck: number)
	local weights, total = effectiveWeights(entries, luck)
	local result = {}
	for i, entry in entries do
		result[entry.id] = weights[i] / total
	end
	return result
end

function Loot.rollOre(zone, layer: number, rng: Random, luck: number): string
	local entries = {}
	for _, ore in zone.ores do
		if ore.minLayer == nil or layer >= ore.minLayer then
			table.insert(entries, { id = ore.id, weight = ore.weight, rarity = Ores[ore.id].rarity })
		end
	end
	return Loot.pick(entries, rng, luck).id
end

return Loot
```

```bash
rm src/shared/Config/.gitkeep
```

- [ ] **Step 4: Tests laufen lassen**

Filter `"Loot"`. Expected: `6 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add -A src/shared tests/Loot.spec.luau
git commit -m "feat: Config für Seltenheit, Erze, Eier, Zonen und Loot-Ziehung"
```

---

### Task 3: ShaftGen + MinedMask

**Files:**
- Create: `src/shared/ShaftGen.luau`, `src/shared/MinedMask.luau`
- Test: `tests/ShaftGen.spec.luau`, `tests/MinedMask.spec.luau`

**Interfaces:**
- Consumes: `Zones.forLayer(layer)` (Task 2)
- Produces:
  - `ShaftGen.SIZE = 12`, `ShaftGen.BLOCK = 4`, `ShaftGen.MAX_LAYER = 300`
  - `ShaftGen.isColumn(x, z) -> boolean`, `ShaftGen.inBounds(x, layer, z) -> boolean`
  - `ShaftGen.kind(seed: number, x, layer, z) -> "column" | "ore" | "egg" | "solid"`
  - `MinedMask.isMined(masks, x, layer, z) -> boolean`, `MinedMask.setMined(masks, x, layer, z)`; `masks` ist `{[string]: string}` mit Keys `"L<layer>"` und 36-stelligen Hex-Strings

- [ ] **Step 1: Failing Tests schreiben**

`tests/ShaftGen.spec.luau`:
```lua
local Shared = game:GetService("ReplicatedStorage").Shared
local Expect = require(script.Parent.Expect)
local ShaftGen = require(Shared.ShaftGen)
local Zones = require(Shared.Config.Zones)

return {
	{ "kind is deterministic", function()
		for layer = 1, 20 do
			for x = 0, 11 do
				Expect.eq(ShaftGen.kind(12345, x, layer, 7), ShaftGen.kind(12345, x, layer, 7))
			end
		end
	end },
	{ "column cells are always column", function()
		for layer = 1, 300, 37 do
			Expect.eq(ShaftGen.kind(1, 0, layer, 0), "column")
			Expect.eq(ShaftGen.kind(1, 1, layer, 1), "column")
			Expect.truthy(ShaftGen.kind(1, 2, layer, 0) ~= "column")
		end
	end },
	{ "inBounds limits", function()
		Expect.truthy(ShaftGen.inBounds(0, 1, 0))
		Expect.truthy(ShaftGen.inBounds(11, 300, 11))
		Expect.truthy(not ShaftGen.inBounds(12, 1, 0))
		Expect.truthy(not ShaftGen.inBounds(0, 0, 0))
		Expect.truthy(not ShaftGen.inBounds(0, 301, 0))
		Expect.truthy(not ShaftGen.inBounds(-1, 5, 0))
	end },
	{ "ore and egg rates match zone config", function()
		local zone = Zones.byId.earth
		local ores, eggs, total = 0, 0, 0
		for layer = 1, 50 do
			for x = 0, 11 do
				for z = 0, 11 do
					local k = ShaftGen.kind(777, x, layer, z)
					if k ~= "column" then
						total += 1
						if k == "ore" then ores += 1 elseif k == "egg" then eggs += 1 end
					end
				end
			end
		end
		Expect.near(ores / total, zone.oreChance, 0.015, "ore rate")
		Expect.near(eggs / total, zone.eggChance, 0.004, "egg rate")
	end },
	{ "different seeds give different shafts", function()
		local same = 0
		for x = 2, 11 do
			for z = 2, 11 do
				if ShaftGen.kind(1, x, 10, z) == ShaftGen.kind(2, x, 10, z) then
					same += 1
				end
			end
		end
		Expect.truthy(same < 100, "at least one cell differs")
	end },
}
```

`tests/MinedMask.spec.luau`:
```lua
local Shared = game:GetService("ReplicatedStorage").Shared
local Expect = require(script.Parent.Expect)
local MinedMask = require(Shared.MinedMask)

return {
	{ "empty masks report nothing mined", function()
		Expect.eq(MinedMask.isMined({}, 3, 5, 7), false)
	end },
	{ "setMined marks exactly one cell", function()
		local masks = {}
		MinedMask.setMined(masks, 3, 5, 7)
		Expect.eq(MinedMask.isMined(masks, 3, 5, 7), true)
		Expect.eq(MinedMask.isMined(masks, 4, 5, 7), false)
		Expect.eq(MinedMask.isMined(masks, 3, 6, 7), false)
		Expect.eq(MinedMask.isMined(masks, 3, 5, 6), false)
	end },
	{ "all 144 cells round-trip", function()
		local masks = {}
		for z = 0, 11 do
			for x = 0, 11 do
				MinedMask.setMined(masks, x, 1, z)
			end
		end
		Expect.eq(masks.L1, string.rep("f", 36))
		for z = 0, 11 do
			for x = 0, 11 do
				Expect.eq(MinedMask.isMined(masks, x, 1, z), true)
			end
		end
	end },
	{ "setMined is idempotent and string stays 36 chars", function()
		local masks = {}
		MinedMask.setMined(masks, 11, 300, 11)
		MinedMask.setMined(masks, 11, 300, 11)
		Expect.eq(#masks.L300, 36)
		Expect.eq(MinedMask.isMined(masks, 11, 300, 11), true)
	end },
}
```

- [ ] **Step 2: Tests laufen lassen, Fehlschlag prüfen**

Filter `"Shaft"` und `"Mined"`. Expected: `LOAD FAIL` für beide Specs.

- [ ] **Step 3: Implementieren**

`src/shared/ShaftGen.luau`:
```lua
local Zones = require(script.Parent.Config.Zones)

local ShaftGen = {}

ShaftGen.SIZE = 12
ShaftGen.BLOCK = 4
ShaftGen.MAX_LAYER = 300

local TWO32 = 2 ^ 32

local function roll(seed: number, x: number, layer: number, z: number): number
	local h = bit32.bxor(seed % TWO32, (x * 73856093) % TWO32, (layer * 19349663) % TWO32, (z * 83492791) % TWO32)
	return Random.new(h):NextNumber()
end

function ShaftGen.isColumn(x: number, z: number): boolean
	return x <= 1 and z <= 1
end

function ShaftGen.inBounds(x: number, layer: number, z: number): boolean
	return x >= 0 and x < ShaftGen.SIZE and z >= 0 and z < ShaftGen.SIZE and layer >= 1 and layer <= ShaftGen.MAX_LAYER
end

function ShaftGen.kind(seed: number, x: number, layer: number, z: number): string
	if ShaftGen.isColumn(x, z) then
		return "column"
	end
	local zone = Zones.forLayer(layer)
	local r = roll(seed, x, layer, z)
	if r < zone.eggChance then
		return "egg"
	elseif r < zone.eggChance + zone.oreChance then
		return "ore"
	end
	return "solid"
end

return ShaftGen
```

`src/shared/MinedMask.luau`:
```lua
-- Pro Schicht 144 Bit (12x12) als 36-stelliger Hex-String, Key "L<layer>".
local SIZE = 12
local HEX_LEN = 36
local EMPTY = string.rep("0", HEX_LEN)

local MinedMask = {}

local function locate(x: number, z: number): (number, number)
	local index = z * SIZE + x
	return index // 4 + 1, bit32.lshift(1, index % 4)
end

function MinedMask.isMined(masks, x: number, layer: number, z: number): boolean
	local s = masks["L" .. layer]
	if s == nil then
		return false
	end
	local pos, bit = locate(x, z)
	return bit32.btest(tonumber(string.sub(s, pos, pos), 16), bit)
end

function MinedMask.setMined(masks, x: number, layer: number, z: number)
	local key = "L" .. layer
	local s = masks[key] or EMPTY
	local pos, bit = locate(x, z)
	local nibble = bit32.bor(tonumber(string.sub(s, pos, pos), 16), bit)
	masks[key] = string.sub(s, 1, pos - 1) .. string.format("%x", nibble) .. string.sub(s, pos + 1)
end

return MinedMask
```

- [ ] **Step 4: Tests laufen lassen**

Ohne Filter. Expected: alle bisherigen Tests grün, `0 failed`.

- [ ] **Step 5: Commit**

```bash
git add src/shared/ShaftGen.luau src/shared/MinedMask.luau tests/ShaftGen.spec.luau tests/MinedMask.spec.luau
git commit -m "feat: deterministische Schacht-Generierung und Bitmaske abgebauter Blöcke"
```

---

### Task 4: Tools-Config + Stats

**Files:**
- Create: `src/shared/Config/Tools.luau`, `src/shared/Stats.luau`
- Test: `tests/Stats.spec.luau`

**Interfaces:**
- Consumes: `Zones` (Task 2)
- Produces:
  - `Tools.pickaxes[id] = {name, tier, power}` (`wood, iron, gold, crystal`), `Tools.backpacks[id] = {name, capacity}` (`small, medium, large, huge`), `Tools.down[id] = {name, fallSpeed}` (`parachute`), `Tools.up[id] = {name}` (`rope`), `Tools.FALL_DAMAGE_HEIGHT = 60`
  - `Stats.canMine(data, layer) -> boolean`, `Stats.digTime(data, layer) -> number`, `Stats.zoneTable(data) -> {[zoneId]: {canMine: boolean, digTime: number}}`, `Stats.backpackCapacity(data) -> number`, `Stats.luck(data) -> number`
  - `data` ist das Profil (`data.equipped.pickaxe`, `data.equipped.backpack`)

- [ ] **Step 1: Failing Test schreiben**

`tests/Stats.spec.luau`:
```lua
local Shared = game:GetService("ReplicatedStorage").Shared
local Expect = require(script.Parent.Expect)
local Stats = require(Shared.Stats)

local function profile(pickaxe, backpack)
	return { equipped = { pickaxe = pickaxe, backpack = backpack, down = "parachute", up = "rope", companions = {} } }
end

return {
	{ "wood pickaxe mines earth only", function()
		local d = profile("wood", "small")
		Expect.eq(Stats.canMine(d, 1), true)
		Expect.eq(Stats.canMine(d, 50), true)
		Expect.eq(Stats.canMine(d, 51), false)
		Expect.eq(Stats.canMine(d, 151), false)
	end },
	{ "iron mines stone, crystal pickaxe mines crystal", function()
		Expect.eq(Stats.canMine(profile("iron", "small"), 51), true)
		Expect.eq(Stats.canMine(profile("gold", "small"), 151), false)
		Expect.eq(Stats.canMine(profile("crystal", "small"), 151), true)
	end },
	{ "dig time formula", function()
		-- 0.3 + hardness * 0.6 / power
		Expect.near(Stats.digTime(profile("wood", "small"), 10), 0.9, 1e-9)
		Expect.near(Stats.digTime(profile("iron", "small"), 60), 0.9, 1e-9)
		Expect.near(Stats.digTime(profile("iron", "small"), 10), 0.6, 1e-9)
	end },
	{ "zoneTable has every zone", function()
		local t = Stats.zoneTable(profile("wood", "small"))
		Expect.eq(t.earth.canMine, true)
		Expect.eq(t.stone.canMine, false)
		Expect.near(t.earth.digTime, 0.9, 1e-9)
	end },
	{ "backpack capacity and base luck", function()
		Expect.eq(Stats.backpackCapacity(profile("wood", "small")), 20)
		Expect.eq(Stats.backpackCapacity(profile("wood", "huge")), 150)
		Expect.eq(Stats.luck(profile("wood", "small")), 1)
	end },
}
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag prüfen**

Filter `"Stats"`. Expected: `LOAD FAIL`.

- [ ] **Step 3: Implementieren**

`src/shared/Config/Tools.luau`:
```lua
return {
	pickaxes = {
		wood = { name = "Holz-Spitzhacke", tier = 1, power = 1 },
		iron = { name = "Eisen-Spitzhacke", tier = 2, power = 2 },
		gold = { name = "Gold-Spitzhacke", tier = 3, power = 3 },
		crystal = { name = "Kristall-Spitzhacke", tier = 4, power = 4 },
	},
	backpacks = {
		small = { name = "Kleiner Rucksack", capacity = 20 },
		medium = { name = "Rucksack", capacity = 40 },
		large = { name = "Großer Rucksack", capacity = 80 },
		huge = { name = "Riesen-Rucksack", capacity = 150 },
	},
	down = {
		parachute = { name = "Fallschirm", fallSpeed = 30 },
	},
	up = {
		rope = { name = "Kletterseil" },
	},
	FALL_DAMAGE_HEIGHT = 60,
}
```

`src/shared/Stats.luau`:
```lua
-- Abgeleitete Spielwerte aus dem Profil. Plan 2 ergänzt hier die Begleiter-Boni.
local Tools = require(script.Parent.Config.Tools)
local Zones = require(script.Parent.Config.Zones)

local Stats = {}

local function pickaxe(data)
	return Tools.pickaxes[data.equipped.pickaxe]
end

local function digTimeForZone(data, zone): number
	return 0.3 + zone.hardness * 0.6 / pickaxe(data).power
end

function Stats.canMine(data, layer: number): boolean
	return pickaxe(data).tier >= Zones.forLayer(layer).requiredTier
end

function Stats.digTime(data, layer: number): number
	return digTimeForZone(data, Zones.forLayer(layer))
end

function Stats.zoneTable(data)
	local result = {}
	for _, zone in Zones.list do
		result[zone.id] = {
			canMine = pickaxe(data).tier >= zone.requiredTier,
			digTime = digTimeForZone(data, zone),
		}
	end
	return result
end

function Stats.backpackCapacity(data): number
	return Tools.backpacks[data.equipped.backpack].capacity
end

function Stats.luck(_data): number
	return 1
end

return Stats
```

- [ ] **Step 4: Tests laufen lassen**

Ohne Filter. Expected: `0 failed`.

- [ ] **Step 5: Commit**

```bash
git add src/shared/Config/Tools.luau src/shared/Stats.luau tests/Stats.spec.luau
git commit -m "feat: Werkzeug-Config und abgeleitete Spielwerte (Stats)"
```

---

### Task 5: RateLimiter + Remotes

**Files:**
- Create: `src/server/RateLimiter.luau`, `src/shared/Remotes.luau`
- Test: `tests/RateLimiter.spec.luau`

**Interfaces:**
- Produces:
  - `RateLimiter.new(maxPerSecond: number, clock: (() -> number)?) -> limiter`, `limiter:allow(key) -> boolean`, `limiter:forget(key)`
  - `Remotes.DigBlock`, `Remotes.FellHard`, `Remotes.State`, `Remotes.Notify` (RemoteEvents in `ReplicatedStorage.Remotes`)

- [ ] **Step 1: Failing Test schreiben**

`tests/RateLimiter.spec.luau`:
```lua
local ServerScriptService = game:GetService("ServerScriptService")
local Expect = require(script.Parent.Expect)
local RateLimiter = require(ServerScriptService.Server.RateLimiter)

local function fakeClock()
	local t = 0
	return function()
		return t
	end, function(dt)
		t += dt
	end
end

return {
	{ "allows a burst up to max", function()
		local clock = fakeClock()
		local limiter = RateLimiter.new(3, clock)
		Expect.eq(limiter:allow("p"), true)
		Expect.eq(limiter:allow("p"), true)
		Expect.eq(limiter:allow("p"), true)
		Expect.eq(limiter:allow("p"), false)
	end },
	{ "refills over time", function()
		local clock, advance = fakeClock()
		local limiter = RateLimiter.new(2, clock)
		limiter:allow("p")
		limiter:allow("p")
		Expect.eq(limiter:allow("p"), false)
		advance(0.5) -- +1 token
		Expect.eq(limiter:allow("p"), true)
		Expect.eq(limiter:allow("p"), false)
	end },
	{ "keys are independent and forget resets", function()
		local clock = fakeClock()
		local limiter = RateLimiter.new(1, clock)
		Expect.eq(limiter:allow("a"), true)
		Expect.eq(limiter:allow("b"), true)
		Expect.eq(limiter:allow("a"), false)
		limiter:forget("a")
		Expect.eq(limiter:allow("a"), true)
	end },
}
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag prüfen**

Filter `"Rate"`. Expected: `LOAD FAIL`.

- [ ] **Step 3: Implementieren**

`src/server/RateLimiter.luau`:
```lua
-- Token-Bucket pro Key (meist der Player).
local RateLimiter = {}
RateLimiter.__index = RateLimiter

function RateLimiter.new(maxPerSecond: number, clock: (() -> number)?)
	return setmetatable({
		max = maxPerSecond,
		clock = clock or os.clock,
		buckets = {},
	}, RateLimiter)
end

function RateLimiter:allow(key): boolean
	local now = self.clock()
	local bucket = self.buckets[key]
	if bucket == nil then
		bucket = { tokens = self.max, at = now }
		self.buckets[key] = bucket
	end
	bucket.tokens = math.min(self.max, bucket.tokens + (now - bucket.at) * self.max)
	bucket.at = now
	if bucket.tokens >= 1 then
		bucket.tokens -= 1
		return true
	end
	return false
end

function RateLimiter:forget(key)
	self.buckets[key] = nil
end

return RateLimiter
```

`src/shared/Remotes.luau`:
```lua
-- Server legt die RemoteEvents an, Client wartet darauf.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = { "DigBlock", "FellHard", "State", "Notify" }

local folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes")
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in NAMES do
		if folder:FindFirstChild(name) == nil then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local Remotes = {}
for _, name in NAMES do
	Remotes[name] = folder:WaitForChild(name)
end
return Remotes
```

- [ ] **Step 4: Tests laufen lassen**

Ohne Filter. Expected: `0 failed`.

- [ ] **Step 5: Commit**

```bash
git add src/server/RateLimiter.luau src/shared/Remotes.luau tests/RateLimiter.spec.luau
git commit -m "feat: RateLimiter und Remote-Definitionen"
```

---

### Task 6: DataService (ProfileStore) + Main

**Files:**
- Create: `src/server/ProfileTemplate.luau`, `src/server/Services/DataService.luau`
- Modify: `src/server/Main.server.luau` (komplett ersetzen)

**Interfaces:**
- Consumes: `ServerScriptService.Vendor.ProfileStore`
- Produces:
  - `DataService.start()`, `DataService.get(player) -> data?`, `DataService.save(player)`
  - `DataService.onLoaded(cb: (player, data) -> ())`, `DataService.onRemoving(cb: (player, data) -> ())`. Callbacks laufen der Reihe nach in Registrierungsreihenfolge, dürfen nicht yielden, Fehler werden per `warn` gemeldet.
  - Profilfelder (Plan 1): `version, coins, seed, deepestLayer, minedLayers, backpack, storage{ores, bars}, eggs, creatures, equipped{pickaxe, backpack, down, up, companions}, daily{streak, lastClaimDay}, lastOnline`
  - Backpack-Items: `{kind = "ore", id = string}` oder `{kind = "egg", zone = string, rarity = string}`

- [ ] **Step 1: Template schreiben**

`src/server/ProfileTemplate.luau`:
```lua
-- Neue Felder hier ergänzen; Profile:Reconcile() füllt sie bei bestehenden Profilen auf.
return {
	version = 1,
	coins = 0,
	seed = 0, -- wird beim ersten Laden gesetzt
	deepestLayer = 0,
	minedLayers = {}, -- ["L<layer>"] = 36-stelliger Hex-String
	backpack = {}, -- { {kind="ore", id=...} | {kind="egg", zone=..., rarity=...} }
	storage = { ores = {}, bars = {} }, -- [id] = Anzahl
	eggs = {}, -- { {id=GUID, zone=..., rarity=..., foundAt=os.time()} }
	creatures = {},
	equipped = {
		pickaxe = "wood",
		backpack = "small",
		down = "parachute",
		up = "rope",
		companions = {},
	},
	daily = { streak = 0, lastClaimDay = -1 },
	lastOnline = 0,
}
```

- [ ] **Step 2: DataService schreiben**

`src/server/Services/DataService.luau`:
```lua
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileStore = require(ServerScriptService.Vendor.ProfileStore)
local Template = require(script.Parent.Parent.ProfileTemplate)

local DataService = {}

local store
local profiles = {}
local loadedCallbacks = {}
local removingCallbacks = {}

local function runCallbacks(list, player, data)
	for _, callback in list do
		local ok, err = pcall(callback, player, data)
		if not ok then
			warn("[DataService] Callback-Fehler: " .. tostring(err))
		end
	end
end

function DataService.onLoaded(callback)
	table.insert(loadedCallbacks, callback)
end

function DataService.onRemoving(callback)
	table.insert(removingCallbacks, callback)
end

function DataService.get(player: Player)
	local profile = profiles[player]
	return profile and profile.Data
end

function DataService.save(player: Player)
	local profile = profiles[player]
	if profile then
		profile:Save()
	end
end

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync("Player_" .. player.UserId, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if profile == nil then
		player:Kick("Dein Spielstand konnte nicht geladen werden. Bitte versuche es gleich nochmal.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Dein Spielstand wurde in einem anderen Server geöffnet.")
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	if profile.Data.seed == 0 then
		profile.Data.seed = Random.new():NextInteger(1, 2 ^ 31 - 1)
	end
	profiles[player] = profile
	runCallbacks(loadedCallbacks, player, profile.Data)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile == nil then
		return
	end
	runCallbacks(removingCallbacks, player, profile.Data)
	profile.Data.lastOnline = os.time()
	profile:EndSession()
end

function DataService.start()
	ProfileStore.SetConstant("AUTO_SAVE_PERIOD", 60)
	store = ProfileStore.New("PlayerData_v1", Template)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return DataService
```

- [ ] **Step 3: Main ersetzen**

`src/server/Main.server.luau`:
```lua
-- Reihenfolge ist wichtig: onLoaded-Callbacks laufen in Registrierungsreihenfolge.
local Services = script.Parent.Services

local ORDER = { "DataService" }

for _, name in ORDER do
	require(Services[name]).start()
end

print("[DigAndBreed] Server gestartet")
```

- [ ] **Step 4: Im Playtest prüfen**

Playtest starten, dann `execute_luau` (Server):
```lua
local Players = game:GetService("Players")
local DataService = require(game:GetService("ServerScriptService").Server.Services.DataService)
local player = Players:GetPlayers()[1]
local deadline = os.clock() + 10
while DataService.get(player) == nil and os.clock() < deadline do task.wait(0.2) end
local data = DataService.get(player)
return data and ("seed=" .. data.seed .. " pickaxe=" .. data.equipped.pickaxe) or "NICHT GELADEN"
```
Expected: `seed=<Zahl ≠ 0> pickaxe=wood`. In der Konsole (`get_console_output`) dürfen keine Fehler stehen. In Studio ohne API-Zugriff nutzt ProfileStore automatisch einen Mock; das ist erwartet.

Tests erneut ohne Filter laufen lassen. Expected: `0 failed`. Playtest stoppen.

- [ ] **Step 5: Commit**

```bash
git add src/server
git commit -m "feat: DataService mit ProfileStore und Profil-Template"
```

---

### Task 7: PlotService + Welt

**Files:**
- Create: `src/server/Services/PlotService.luau`
- Modify: `src/server/Main.server.luau` (`ORDER`)

**Interfaces:**
- Consumes: `DataService.onLoaded/onRemoving`, `ShaftGen.SIZE/BLOCK`
- Produces:
  - `PlotService.start()`
  - `PlotService.getPlot(player) -> {index: number, center: Vector3, shaftOrigin: Vector3, owner: Player?}?` (`shaftOrigin` = Ecke x/z-min des Schachts auf Höhe 0)
  - `PlotService.isOnOwnSurface(player) -> boolean` (steht auf/über dem eigenen Grundstück, Y > 0)
  - Layout: 3×3-Raster aus 96er-Zellen, Mitte = Marktplatz mit SpawnLocation, 8 Grundstücke rundherum, Loch 48×48 in der Grundstücksmitte

- [ ] **Step 1: PlotService schreiben**

`src/server/Services/PlotService.luau`:
```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShaftGen = require(ReplicatedStorage.Shared.ShaftGen)
local DataService = require(script.Parent.DataService)

local PlotService = {}

local CELL = 96
local HOLE = ShaftGen.SIZE * ShaftGen.BLOCK -- 48
local RIM = (CELL - HOLE) / 2 -- 24
local GRASS = Color3.fromRGB(95, 160, 75)
local MARKET = Color3.fromRGB(200, 180, 140)
local GRID = { { -1, -1 }, { 0, -1 }, { 1, -1 }, { -1, 0 }, { 1, 0 }, { -1, 1 }, { 0, 1 }, { 1, 1 } }

local plots = {}
local byPlayer = {}

local function makePart(parent, name, size, position, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function makeSign(parent, position)
	local post = makePart(parent, "Sign", Vector3.new(1, 8, 1), position, Color3.fromRGB(120, 85, 50), Enum.Material.Wood)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 50)
	gui.StudsOffset = Vector3.new(0, 6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 250
	gui.Parent = post
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = "Frei"
	label.Parent = gui
	return label
end

local function buildWorld()
	local world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = workspace

	makePart(world, "Market", Vector3.new(CELL, 4, CELL), Vector3.new(0, -2, 0), MARKET, Enum.Material.Cobblestone)
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(0, 0.5, 0)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = world

	for index, g in GRID do
		local center = Vector3.new(g[1] * CELL, 0, g[2] * CELL)
		local plotFolder = Instance.new("Folder")
		plotFolder.Name = "Plot" .. index
		plotFolder.Parent = world
		local off = HOLE / 2 + RIM / 2 -- 36
		makePart(plotFolder, "RimN", Vector3.new(CELL, 4, RIM), center + Vector3.new(0, -2, -off), GRASS, Enum.Material.Grass)
		makePart(plotFolder, "RimS", Vector3.new(CELL, 4, RIM), center + Vector3.new(0, -2, off), GRASS, Enum.Material.Grass)
		makePart(plotFolder, "RimW", Vector3.new(RIM, 4, HOLE), center + Vector3.new(-off, -2, 0), GRASS, Enum.Material.Grass)
		makePart(plotFolder, "RimE", Vector3.new(RIM, 4, HOLE), center + Vector3.new(off, -2, 0), GRASS, Enum.Material.Grass)
		local sign = makeSign(plotFolder, center + Vector3.new(0, 4, -(HOLE / 2 + 6)))
		plots[index] = {
			index = index,
			center = center,
			shaftOrigin = center - Vector3.new(HOLE / 2, 0, HOLE / 2),
			owner = nil,
			sign = sign,
		}
	end
end

local function teleportHome(player: Player)
	local plot = byPlayer[player]
	local character = player.Character
	if plot and character then
		character:PivotTo(CFrame.new(plot.center + Vector3.new(0, 4, HOLE / 2 + 10)))
	end
end

local function assign(player: Player)
	for _, plot in plots do
		if plot.owner == nil then
			plot.owner = player
			plot.sign.Text = player.DisplayName
			byPlayer[player] = plot
			player.CharacterAdded:Connect(function()
				task.defer(teleportHome, player)
			end)
			teleportHome(player)
			return
		end
	end
	player:Kick("Server voll – bitte einem anderen Server beitreten.")
end

local function release(player: Player)
	local plot = byPlayer[player]
	if plot then
		plot.owner = nil
		plot.sign.Text = "Frei"
		byPlayer[player] = nil
	end
end

function PlotService.getPlot(player: Player)
	return byPlayer[player]
end

function PlotService.isOnOwnSurface(player: Player): boolean
	local plot = byPlayer[player]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if plot == nil or root == nil then
		return false
	end
	local d = root.Position - plot.center
	return math.abs(d.X) <= CELL / 2 and math.abs(d.Z) <= CELL / 2 and root.Position.Y > 0
end

function PlotService.start()
	buildWorld()
	DataService.onLoaded(assign)
	DataService.onRemoving(release)
end

return PlotService
```

- [ ] **Step 2: In Main eintragen**

In `src/server/Main.server.luau`:
```lua
local ORDER = { "DataService", "PlotService" }
```

- [ ] **Step 3: Im Playtest prüfen**

Playtest starten, 3 s warten, `execute_luau` (Server):
```lua
local PlotService = require(game:GetService("ServerScriptService").Server.Services.PlotService)
local player = game:GetService("Players"):GetPlayers()[1]
local plot = PlotService.getPlot(player)
return plot and ("plot=" .. plot.index .. " onSurface=" .. tostring(PlotService.isOnOwnSurface(player))) or "KEIN PLOT"
```
Expected: `plot=1 onSurface=true`. Außerdem zählen: `#workspace.World:GetChildren()` → 10 (Market, SpawnLocation, Plot1–Plot8). Playtest stoppen. **Sichtprüfung durch den Nutzer** im nächsten Playtest: Marktplatz in der Mitte, 8 Grasflächen mit je einem Loch, Schild mit dem eigenen Namen über dem eigenen Grundstück. Tests ohne Filter: `0 failed`.

- [ ] **Step 4: Commit**

```bash
git add src/server
git commit -m "feat: Welt mit Marktplatz und 8 Grundstücken, Zuweisung pro Spieler"
```

---

### Task 8: StateService + BackpackService

**Files:**
- Create: `src/server/Services/StateService.luau`, `src/server/Services/BackpackService.luau`
- Modify: `src/server/Main.server.luau` (`ORDER`)

**Interfaces:**
- Consumes: `DataService.get/onLoaded/onRemoving`, `PlotService.isOnOwnSurface`, `Stats`, `Zones`, `Tools`, `Remotes.State/Notify`, `RateLimiter`
- Produces:
  - `StateService.start()`, `StateService.push(player)`, `StateService.notify(player, text: string)`
  - Snapshot über `Remotes.State` an den Client: `{coins: number, deepestLayer: number, zoneName: string, backpack: number, capacity: number, ores: {[id]: number}, eggs: number, zones: {[zoneId]: {canMine: boolean, digTime: number}}, fallSpeed: number}`
  - Client → Server `Remotes.State:FireServer()` = Snapshot anfordern
  - `BackpackService.start()`, `BackpackService.isFull(player) -> boolean`, `BackpackService.add(player, item) -> boolean`, `BackpackService.deposit(player) -> (ores: number, eggs: number)`

- [ ] **Step 1: StateService schreiben**

`src/server/Services/StateService.luau`:
```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Stats = require(Shared.Stats)
local Zones = require(Shared.Config.Zones)
local Tools = require(Shared.Config.Tools)
local Remotes = require(Shared.Remotes)
local RateLimiter = require(ServerScriptService.Server.RateLimiter)
local DataService = require(script.Parent.DataService)

local StateService = {}

local requestLimiter = RateLimiter.new(2)

function StateService.push(player: Player)
	local data = DataService.get(player)
	if data == nil then
		return
	end
	Remotes.State:FireClient(player, {
		coins = data.coins,
		deepestLayer = data.deepestLayer,
		zoneName = Zones.forLayer(math.max(1, data.deepestLayer)).name,
		backpack = #data.backpack,
		capacity = Stats.backpackCapacity(data),
		ores = data.storage.ores,
		eggs = #data.eggs,
		zones = Stats.zoneTable(data),
		fallSpeed = Tools.down[data.equipped.down].fallSpeed,
	})
end

function StateService.notify(player: Player, text: string)
	Remotes.Notify:FireClient(player, text)
end

function StateService.start()
	Remotes.State.OnServerEvent:Connect(function(player)
		if requestLimiter:allow(player) then
			StateService.push(player)
		end
	end)
	DataService.onLoaded(StateService.push)
	DataService.onRemoving(function(player)
		requestLimiter:forget(player)
	end)
end

return StateService
```

- [ ] **Step 2: BackpackService schreiben**

`src/server/Services/BackpackService.luau`:
```lua
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Stats = require(ReplicatedStorage.Shared.Stats)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local StateService = require(script.Parent.StateService)

local BackpackService = {}

local DEPOSIT_INTERVAL = 0.5

function BackpackService.isFull(player: Player): boolean
	local data = DataService.get(player)
	return data == nil or #data.backpack >= Stats.backpackCapacity(data)
end

function BackpackService.add(player: Player, item): boolean
	if BackpackService.isFull(player) then
		return false
	end
	table.insert(DataService.get(player).backpack, item)
	return true
end

function BackpackService.deposit(player: Player): (number, number)
	local data = DataService.get(player)
	if data == nil then
		return 0, 0
	end
	local ores, eggs = 0, 0
	for _, item in data.backpack do
		if item.kind == "ore" then
			data.storage.ores[item.id] = (data.storage.ores[item.id] or 0) + 1
			ores += 1
		elseif item.kind == "egg" then
			table.insert(data.eggs, {
				id = HttpService:GenerateGUID(false),
				zone = item.zone,
				rarity = item.rarity,
				foundAt = os.time(),
			})
			eggs += 1
		end
	end
	table.clear(data.backpack)
	return ores, eggs
end

function BackpackService.start()
	task.spawn(function()
		while true do
			task.wait(DEPOSIT_INTERVAL)
			for _, player in Players:GetPlayers() do
				local data = DataService.get(player)
				if data and #data.backpack > 0 and PlotService.isOnOwnSurface(player) then
					local ores, eggs = BackpackService.deposit(player)
					StateService.notify(player, string.format("Abgelegt: %d Erze, %d Eier", ores, eggs))
					StateService.push(player)
				end
			end
		end
	end)
end

return BackpackService
```

- [ ] **Step 3: In Main eintragen**

```lua
local ORDER = { "DataService", "PlotService", "StateService", "BackpackService" }
```

- [ ] **Step 4: Im Playtest prüfen**

Playtest starten, 3 s warten, `execute_luau` (Server):
```lua
local Server = game:GetService("ServerScriptService").Server.Services
local DataService = require(Server.DataService)
local BackpackService = require(Server.BackpackService)
local player = game:GetService("Players"):GetPlayers()[1]
local data = DataService.get(player)
BackpackService.add(player, { kind = "ore", id = "copper" })
BackpackService.add(player, { kind = "egg", zone = "earth", rarity = "Selten" })
task.wait(1) -- Spieler steht auf eigenem Grundstück -> Ablage-Loop greift
return string.format("backpack=%d copper=%s eggs=%d", #data.backpack, tostring(data.storage.ores.copper), #data.eggs)
```
Expected: `backpack=0 copper=1 eggs=1`. Konsole ohne Fehler. Playtest stoppen. Tests ohne Filter: `0 failed`.

- [ ] **Step 5: Commit**

```bash
git add src/server
git commit -m "feat: State-Snapshot an den Client und Rucksack mit Ablage auf dem Grundstück"
```

---

### Task 9: ShaftService (Schacht bauen, Graben, Förderschacht)

**Files:**
- Create: `src/server/Services/ShaftService.luau`
- Modify: `src/server/Main.server.luau` (`ORDER`)

**Interfaces:**
- Consumes: `ShaftGen`, `MinedMask`, `Zones`, `Eggs`, `Loot`, `Stats`, `Remotes.DigBlock`, `RateLimiter`, `DataService`, `PlotService.getPlot`, `BackpackService.isFull/add`, `StateService.push/notify`
- Produces:
  - `ShaftService.start()`
  - `ShaftService.tryDig(player, x, layer, z) -> (ok: boolean, reason: string?)` (auch der Remote-Handler)
  - Instanzen: `workspace.Shafts.<UserId>` mit `Blocks` (Parts mit Attributen `X`, `Layer`, `Z`, `Zone`), `Walls`, `ColumnFloor`, `Rope` (TrussPart)

- [ ] **Step 1: ShaftService schreiben**

`src/server/Services/ShaftService.luau`:
```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local ShaftGen = require(Shared.ShaftGen)
local MinedMask = require(Shared.MinedMask)
local Zones = require(Shared.Config.Zones)
local Eggs = require(Shared.Config.Eggs)
local Loot = require(Shared.Loot)
local Stats = require(Shared.Stats)
local Remotes = require(Shared.Remotes)
local RateLimiter = require(ServerScriptService.Server.RateLimiter)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local BackpackService = require(script.Parent.BackpackService)
local StateService = require(script.Parent.StateService)

local ShaftService = {}

local SIZE, BLOCK, MAX = ShaftGen.SIZE, ShaftGen.BLOCK, ShaftGen.MAX_LAYER
local REACH = 14
local TIMING_TOLERANCE = 0.75
local NEIGHBORS = { { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 } }
local EGG_COLOR = Color3.fromRGB(250, 235, 200)

local shafts = {}
local limiter = RateLimiter.new(12)
local rng = Random.new()
local root

local function cellKey(x, layer, z): string
	return x .. "," .. layer .. "," .. z
end

local function cellCenter(origin: Vector3, x, layer, z): Vector3
	return origin + Vector3.new(x * BLOCK + BLOCK / 2, -layer * BLOCK + BLOCK / 2, z * BLOCK + BLOCK / 2)
end

local function isOpen(shaft, x, layer, z): boolean
	if x < 0 or x >= SIZE or z < 0 or z >= SIZE then
		return false
	end
	if layer <= 0 then
		return true
	end
	if layer > MAX then
		return false
	end
	if ShaftGen.isColumn(x, z) then
		return layer <= shaft.data.deepestLayer
	end
	return MinedMask.isMined(shaft.data.minedLayers, x, layer, z)
end

local function renderCell(shaft, x, layer, z)
	if not ShaftGen.inBounds(x, layer, z) or ShaftGen.isColumn(x, z) then
		return
	end
	local key = cellKey(x, layer, z)
	if shaft.parts[key] or MinedMask.isMined(shaft.data.minedLayers, x, layer, z) then
		return
	end
	local exposed = false
	for _, d in NEIGHBORS do
		if isOpen(shaft, x + d[1], layer + d[2], z + d[3]) then
			exposed = true
			break
		end
	end
	if not exposed then
		return
	end

	local zone = Zones.forLayer(layer)
	local kind = ShaftGen.kind(shaft.data.seed, x, layer, z)
	local part = Instance.new("Part")
	part.Name = key
	part.Anchored = true
	part.Size = Vector3.one * BLOCK
	part.Position = cellCenter(shaft.origin, x, layer, z)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if kind == "ore" then
		part.Color = zone.oreColor
		part.Material = Enum.Material.Pebble
	elseif kind == "egg" then
		part.Color = EGG_COLOR
		part.Material = Enum.Material.SmoothPlastic
	else
		part.Color = zone.color
		part.Material = zone.material
	end
	part:SetAttribute("X", x)
	part:SetAttribute("Layer", layer)
	part:SetAttribute("Z", z)
	part:SetAttribute("Zone", zone.id)
	part.Parent = shaft.blocks
	shaft.parts[key] = part
end

local function updateColumn(shaft)
	local deepest = shaft.data.deepestLayer
	local columnCenter = shaft.origin + Vector3.new(BLOCK, 0, BLOCK)
	local floorLayer = deepest + 1
	if floorLayer <= MAX then
		shaft.floor.Position = columnCenter + Vector3.new(0, -floorLayer * BLOCK + BLOCK / 2, 0)
		shaft.floor.Parent = shaft.folder
	else
		shaft.floor.Parent = nil
	end
	-- Seil reicht vom Boden des Förderschachts bis 6 Studs über die Oberfläche.
	local height = deepest * BLOCK + 6
	shaft.rope.Size = Vector3.new(2, height, 2)
	shaft.rope.Position = shaft.origin + Vector3.new(1, 6 - height / 2, 1)
end

local function makeStatic(parent, name, size, position, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material
	part.Parent = parent
	return part
end

local function build(player: Player, data)
	local plot = PlotService.getPlot(player)
	if plot == nil then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = tostring(player.UserId)
	local blocks = Instance.new("Folder")
	blocks.Name = "Blocks"
	blocks.Parent = folder
	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = folder

	local origin = plot.shaftOrigin
	local width = SIZE * BLOCK
	local depth = MAX * BLOCK
	local rock = Color3.fromRGB(60, 50, 45)
	makeStatic(walls, "N", Vector3.new(width + 8, depth, 4), origin + Vector3.new(width / 2, -depth / 2, -2), rock, Enum.Material.Slate)
	makeStatic(walls, "S", Vector3.new(width + 8, depth, 4), origin + Vector3.new(width / 2, -depth / 2, width + 2), rock, Enum.Material.Slate)
	makeStatic(walls, "W", Vector3.new(4, depth, width), origin + Vector3.new(-2, -depth / 2, width / 2), rock, Enum.Material.Slate)
	makeStatic(walls, "E", Vector3.new(4, depth, width), origin + Vector3.new(width + 2, -depth / 2, width / 2), rock, Enum.Material.Slate)
	makeStatic(walls, "Bedrock", Vector3.new(width, 4, width), origin + Vector3.new(width / 2, -depth - 2, width / 2), Color3.fromRGB(20, 20, 20), Enum.Material.Basalt)

	local floor = makeStatic(folder, "ColumnFloor", Vector3.new(2 * BLOCK, BLOCK, 2 * BLOCK), origin, Color3.fromRGB(150, 150, 160), Enum.Material.DiamondPlate)
	local rope = Instance.new("TrussPart")
	rope.Name = "Rope"
	rope.Anchored = true
	rope.Color = Color3.fromRGB(170, 120, 60)
	rope.Parent = folder

	local shaft = {
		player = player,
		data = data,
		origin = origin,
		folder = folder,
		blocks = blocks,
		floor = floor,
		rope = rope,
		parts = {},
		lastDigAt = 0,
	}
	shafts[player] = shaft
	updateColumn(shaft)

	for layer = 1, math.min(data.deepestLayer + 1, MAX) do
		for x = 0, SIZE - 1 do
			for z = 0, SIZE - 1 do
				renderCell(shaft, x, layer, z)
			end
		end
	end
	folder.Parent = root
end

local function destroy(player: Player)
	local shaft = shafts[player]
	if shaft then
		shaft.folder:Destroy()
		shafts[player] = nil
	end
	limiter:forget(player)
end

local function isInteger(v): boolean
	return typeof(v) == "number" and v == v and v % 1 == 0
end

function ShaftService.tryDig(player: Player, x, layer, z): (boolean, string?)
	if not (isInteger(x) and isInteger(layer) and isInteger(z)) then
		return false, "invalid args"
	end
	local shaft = shafts[player]
	if shaft == nil then
		return false, "no shaft"
	end
	local key = cellKey(x, layer, z)
	local part = shaft.parts[key]
	if part == nil then
		return false, "not exposed"
	end
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if hrp == nil or (hrp.Position - part.Position).Magnitude > REACH then
		return false, "out of reach"
	end

	local data = shaft.data
	if not Stats.canMine(data, layer) then
		StateService.notify(player, "Du brauchst eine bessere Spitzhacke für diese Zone!")
		return false, "tool tier"
	end
	local now = os.clock()
	if now - shaft.lastDigAt < Stats.digTime(data, layer) * TIMING_TOLERANCE then
		return false, "too fast"
	end

	local zone = Zones.forLayer(layer)
	local kind = ShaftGen.kind(data.seed, x, layer, z)
	local item
	if kind == "ore" then
		item = { kind = "ore", id = Loot.rollOre(zone, layer, rng, Stats.luck(data)) }
	elseif kind == "egg" then
		item = { kind = "egg", zone = zone.id, rarity = Loot.pick(Eggs.rarityEntries, rng, Stats.luck(data)).id }
	end
	if item and BackpackService.isFull(player) then
		StateService.notify(player, "Rucksack voll! Fahr hoch und leer ihn aus.")
		return false, "backpack full"
	end

	shaft.lastDigAt = now
	MinedMask.setMined(data.minedLayers, x, layer, z)
	part:Destroy()
	shaft.parts[key] = nil

	if layer > data.deepestLayer then
		data.deepestLayer = layer
		updateColumn(shaft)
		for cx = 0, 1 do
			for cz = 0, 1 do
				for _, d in NEIGHBORS do
					renderCell(shaft, cx + d[1], layer + d[2], cz + d[3])
				end
			end
		end
	end
	for _, d in NEIGHBORS do
		renderCell(shaft, x + d[1], layer + d[2], z + d[3])
	end

	if item then
		BackpackService.add(player, item)
		if item.kind == "egg" then
			StateService.notify(player, "Ei gefunden: " .. Eggs.byZone[item.zone].name .. " (" .. item.rarity .. ")")
		end
	end
	StateService.push(player)
	return true
end

function ShaftService.start()
	root = Instance.new("Folder")
	root.Name = "Shafts"
	root.Parent = workspace
	Remotes.DigBlock.OnServerEvent:Connect(function(player, x, layer, z)
		if limiter:allow(player) then
			ShaftService.tryDig(player, x, layer, z)
		end
	end)
	DataService.onLoaded(build)
	DataService.onRemoving(destroy)
end

return ShaftService
```

- [ ] **Step 2: In Main eintragen**

```lua
local ORDER = { "DataService", "PlotService", "StateService", "BackpackService", "ShaftService" }
```

- [ ] **Step 3: Im Playtest prüfen**

Playtest starten, 3 s warten, `execute_luau` (Server):
```lua
local Services = game:GetService("ServerScriptService").Server.Services
local ShaftService = require(Services.ShaftService)
local DataService = require(Services.DataService)
local PlotService = require(Services.PlotService)
local player = game:GetService("Players"):GetPlayers()[1]
local data = DataService.get(player)
local plot = PlotService.getPlot(player)
local blocks = workspace.Shafts[tostring(player.UserId)].Blocks
local before = #blocks:GetChildren()

-- Spieler über Zelle (5, 1, 5) stellen und sie abbauen
local target = plot.shaftOrigin + Vector3.new(5 * 4 + 2, 4, 5 * 4 + 2)
player.Character:PivotTo(CFrame.new(target))
task.wait(0.2)
local ok, reason = ShaftService.tryDig(player, 5, 1, 5)
local tooFast = select(2, ShaftService.tryDig(player, 6, 1, 5))
task.wait(1)
local ok2 = ShaftService.tryDig(player, 5, 2, 5)
local far = select(2, ShaftService.tryDig(player, 11, 1, 11))
local invalid = select(2, ShaftService.tryDig(player, 0 / 0, 1, 1))
return string.format("before=%d ok=%s/%s tooFast=%s ok2=%s far=%s invalid=%s deepest=%d exposedL3=%s",
	before, tostring(ok), tostring(reason), tostring(tooFast), tostring(ok2), tostring(far), tostring(invalid),
	data.deepestLayer, tostring(blocks:FindFirstChild("5,3,5") ~= nil))
```
Expected: `before=140 ok=true/nil tooFast=too fast ok2=true far=out of reach invalid=invalid args deepest=2 exposedL3=true` (140 = 144 Zellen minus 4 Förderschacht-Zellen in Schicht 1). Konsole ohne Fehler. Playtest stoppen. Tests ohne Filter: `0 failed`.

- [ ] **Step 4: Commit**

```bash
git add src/server
git commit -m "feat: eigener Schacht mit Graben, Loot und Förderschacht (Seil)"
```

---

### Task 10: Client – ClientState, HUD, Graben

**Files:**
- Create: `src/client/ClientState.luau`, `src/client/UI/Hud.luau`, `src/client/Controllers/DigController.luau`
- Modify: `src/client/Main.client.luau` (komplett ersetzen)

**Interfaces:**
- Consumes: Snapshot aus Task 8, Block-Attribute aus Task 9, `Remotes.State/Notify/DigBlock`, `Ores` (Namen)
- Produces:
  - `ClientState.start()`, `ClientState.current: Snapshot?`, `ClientState.changed: RBXScriptSignal`
  - `Hud.start()`, `Hud.setProgress(p: number?)` (nil = ausblenden), `Hud.toast(text: string)`
  - `DigController.start()`

- [ ] **Step 1: ClientState schreiben**

`src/client/ClientState.luau`:
```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ClientState = {}

local changed = Instance.new("BindableEvent")
ClientState.current = nil
ClientState.changed = changed.Event

function ClientState.start()
	Remotes.State.OnClientEvent:Connect(function(snapshot)
		ClientState.current = snapshot
		changed:Fire(snapshot)
	end)
	Remotes.State:FireServer()
end

return ClientState
```

- [ ] **Step 2: HUD schreiben**

`src/client/UI/Hud.luau`:
```lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Ores = require(ReplicatedStorage.Shared.Config.Ores)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ClientState = require(script.Parent.Parent.ClientState)

local Hud = {}

local gui, info, progressBack, progressFill, toastLabel

local function label(parent, text, size, position)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.4
	l.TextScaled = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Size = size
	l.Position = position
	l.Text = text
	l.Parent = parent
	return l
end

local function render(s)
	local oreParts = {}
	for id, count in s.ores do
		if count > 0 then
			table.insert(oreParts, Ores[id].name .. " " .. count)
		end
	end
	table.sort(oreParts)
	info.Text = string.format(
		"Tiefe: %d (%s)\nRucksack: %d/%d\nEier: %d\nErze: %s",
		s.deepestLayer,
		s.zoneName,
		s.backpack,
		s.capacity,
		s.eggs,
		#oreParts > 0 and table.concat(oreParts, " · ") or "–"
	)
end

function Hud.setProgress(p: number?)
	if p == nil then
		progressBack.Visible = false
		return
	end
	progressBack.Visible = true
	progressFill.Size = UDim2.fromScale(math.clamp(p, 0, 1), 1)
end

function Hud.toast(text: string)
	toastLabel.Text = text
	toastLabel.TextTransparency = 0
	toastLabel.TextStrokeTransparency = 0.4
	task.delay(2.5, function()
		if toastLabel.Text == text then
			TweenService:Create(toastLabel, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

function Hud.start()
	gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	panel.BackgroundTransparency = 0.35
	panel.Size = UDim2.fromOffset(260, 110)
	panel.Position = UDim2.fromOffset(12, 60)
	panel.Parent = gui
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
	info = label(panel, "Lade …", UDim2.new(1, -16, 1, -12), UDim2.fromOffset(8, 6))
	info.TextScaled = false
	info.TextSize = 18
	info.TextYAlignment = Enum.TextYAlignment.Top

	progressBack = Instance.new("Frame")
	progressBack.AnchorPoint = Vector2.new(0.5, 1)
	progressBack.Position = UDim2.new(0.5, 0, 1, -120)
	progressBack.Size = UDim2.fromOffset(220, 14)
	progressBack.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	progressBack.Visible = false
	progressBack.Parent = gui
	Instance.new("UICorner", progressBack).CornerRadius = UDim.new(1, 0)
	progressFill = Instance.new("Frame")
	progressFill.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
	progressFill.Size = UDim2.fromScale(0, 1)
	progressFill.Parent = progressBack
	Instance.new("UICorner", progressFill).CornerRadius = UDim.new(1, 0)

	toastLabel = label(gui, "", UDim2.fromOffset(600, 36), UDim2.new(0.5, -300, 0, 20))
	toastLabel.TextXAlignment = Enum.TextXAlignment.Center
	toastLabel.TextTransparency = 1

	ClientState.changed:Connect(render)
	if ClientState.current then
		render(ClientState.current)
	end
	Remotes.Notify.OnClientEvent:Connect(Hud.toast)
end

return Hud
```

- [ ] **Step 3: DigController schreiben**

`src/client/Controllers/DigController.luau`:
```lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ClientState = require(script.Parent.Parent.ClientState)
local Hud = require(script.Parent.Parent.UI.Hud)

local DigController = {}

local REACH = 14
local player = Players.LocalPlayer

local pointer = Vector2.zero
local holding = false
local current = nil
local elapsed = 0
local warnedZone = nil
local selection
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include

local function blocksFolder()
	local shafts = workspace:FindFirstChild("Shafts")
	local mine = shafts and shafts:FindFirstChild(tostring(player.UserId))
	return mine and mine:FindFirstChild("Blocks")
end

local function blockUnderPointer()
	local folder = blocksFolder()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if folder == nil or root == nil then
		return nil
	end
	params.FilterDescendantsInstances = { folder }
	local ray = workspace.CurrentCamera:ViewportPointToRay(pointer.X, pointer.Y)
	local result = workspace:Raycast(ray.Origin, ray.Direction * 200, params)
	if result == nil then
		return nil
	end
	local part = result.Instance
	if (root.Position - part.Position).Magnitude > REACH then
		return nil
	end
	return part
end

local function isPointer(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function step(dt: number)
	local part = blockUnderPointer()
	selection.Adornee = part
	local state = ClientState.current
	if not holding or part == nil or state == nil then
		current, elapsed = nil, 0
		Hud.setProgress(nil)
		return
	end
	if part ~= current then
		current, elapsed = part, 0
	end
	local zoneId = part:GetAttribute("Zone")
	local zone = state.zones[zoneId]
	if not zone.canMine then
		Hud.setProgress(nil)
		if warnedZone ~= zoneId then
			warnedZone = zoneId
			Hud.toast("Du brauchst eine bessere Spitzhacke für diese Zone!")
		end
		return
	end
	elapsed += dt
	Hud.setProgress(elapsed / zone.digTime)
	if elapsed >= zone.digTime then
		Remotes.DigBlock:FireServer(part:GetAttribute("X"), part:GetAttribute("Layer"), part:GetAttribute("Z"))
		current, elapsed = nil, 0
	end
end

function DigController.start()
	selection = Instance.new("SelectionBox")
	selection.Color3 = Color3.fromRGB(255, 220, 90)
	selection.LineThickness = 0.06
	selection.Parent = workspace.CurrentCamera

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if isPointer(input) then
			holding = true
			pointer = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			pointer = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if isPointer(input) then
			holding = false
		end
	end)
	RunService.Heartbeat:Connect(step)
end

return DigController
```

- [ ] **Step 4: Client-Main ersetzen**

`src/client/Main.client.luau`:
```lua
local Client = script.Parent

local ClientState = require(Client.ClientState)
local Hud = require(Client.UI.Hud)
local DigController = require(Client.Controllers.DigController)

Hud.start()
ClientState.start()
DigController.start()
```

- [ ] **Step 5: Im Playtest prüfen**

Playtest starten, 3 s warten. `execute_luau` (Client):
```lua
local gui = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("Hud")
return gui and "HUD da" or "KEIN HUD"
```
Expected: `HUD da`. `get_console_output`: keine Fehler. **Handtest durch den Nutzer**: in den Schacht springen, Block anklicken und gedrückt halten → gelbe Umrandung und Fortschrittsbalken, Block verschwindet, HUD-Tiefe steigt, Erz/Ei-Blöcke füllen den Rucksack, am Seil hochklettern → Toast „Abgelegt …“. Playtest stoppen.

- [ ] **Step 6: Commit**

```bash
git add src/client
git commit -m "feat: Client-HUD und Graben mit Halten-Fortschritt"
```

---

### Task 11: Fallschaden + Fallschirm

**Files:**
- Create: `src/server/Services/TransportService.luau`, `src/client/Controllers/FallController.luau`
- Modify: `src/server/Main.server.luau` (`ORDER`), `src/client/Main.client.luau`

**Interfaces:**
- Consumes: `Remotes.FellHard`, `Tools.FALL_DAMAGE_HEIGHT`, Snapshot-Feld `fallSpeed`, `StateService.notify`, `RateLimiter`
- Produces: `TransportService.start()`, `FallController.start()`. Client → Server `Remotes.FellHard:FireServer(drop: number)`

- [ ] **Step 1: TransportService schreiben**

`src/server/Services/TransportService.luau`:
```lua
-- Fallschaden: Der Client meldet einen harten Aufprall, der Server tötet den Charakter.
-- (Ein Cheater kann das nur zu seinem eigenen Vorteil weglassen – kein Risiko für andere oder die Wirtschaft.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Tools = require(ReplicatedStorage.Shared.Config.Tools)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimiter = require(ServerScriptService.Server.RateLimiter)
local DataService = require(script.Parent.DataService)
local StateService = require(script.Parent.StateService)

local TransportService = {}

local limiter = RateLimiter.new(1)

function TransportService.start()
	Remotes.FellHard.OnServerEvent:Connect(function(player, drop)
		if not limiter:allow(player) or typeof(drop) ~= "number" or drop < Tools.FALL_DAMAGE_HEIGHT then
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid.Health = 0
			StateService.notify(player, "Autsch! Drück im Fall die Sprungtaste für den Fallschirm.")
		end
	end)
	DataService.onRemoving(function(player)
		limiter:forget(player)
	end)
end

return TransportService
```

- [ ] **Step 2: FallController schreiben**

`src/client/Controllers/FallController.luau`:
```lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Tools = require(ReplicatedStorage.Shared.Config.Tools)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ClientState = require(script.Parent.Parent.ClientState)

local FallController = {}

local player = Players.LocalPlayer
local falling = false
local deployed = false
local startY = 0
local canopy = nil

local function rootPart()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function removeCanopy()
	if canopy then
		canopy:Destroy()
		canopy = nil
	end
end

local function deploy()
	local root = rootPart()
	if root == nil then
		return
	end
	deployed = true
	canopy = Instance.new("Part")
	canopy.Name = "Parachute"
	canopy.Size = Vector3.new(7, 0.6, 7)
	canopy.Color = Color3.fromRGB(230, 70, 70)
	canopy.Material = Enum.Material.Fabric
	canopy.CanCollide = false
	canopy.Massless = true
	canopy.CFrame = root.CFrame * CFrame.new(0, 6, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = canopy
	weld.Parent = canopy
	canopy.Parent = player.Character
end

local function onCharacter(character: Model)
	falling, deployed = false, false
	removeCanopy()
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.StateChanged:Connect(function(_, new)
		local root = rootPart()
		if root == nil then
			return
		end
		if new == Enum.HumanoidStateType.Freefall then
			if not falling then
				falling, deployed = true, false
				startY = root.Position.Y
			end
		elseif falling and new ~= Enum.HumanoidStateType.Jumping then
			falling = false
			local drop = startY - root.Position.Y
			local wasDeployed = deployed
			deployed = false
			removeCanopy()
			if not wasDeployed and drop >= Tools.FALL_DAMAGE_HEIGHT then
				Remotes.FellHard:FireServer(drop)
			end
		end
	end)
end

function FallController.start()
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	UserInputService.JumpRequest:Connect(function()
		if falling and not deployed and ClientState.current then
			deploy()
		end
	end)
	RunService.Heartbeat:Connect(function()
		if not deployed or ClientState.current == nil then
			return
		end
		local root = rootPart()
		if root == nil then
			return
		end
		local v = root.AssemblyLinearVelocity
		local maxFall = ClientState.current.fallSpeed
		if v.Y < -maxFall then
			root.AssemblyLinearVelocity = Vector3.new(v.X, -maxFall, v.Z)
		end
	end)
end

return FallController
```

- [ ] **Step 3: In beide Mains eintragen**

`src/server/Main.server.luau`:
```lua
local ORDER = { "DataService", "PlotService", "StateService", "BackpackService", "ShaftService", "TransportService" }
```

`src/client/Main.client.luau`:
```lua
local Client = script.Parent

local ClientState = require(Client.ClientState)
local Hud = require(Client.UI.Hud)
local DigController = require(Client.Controllers.DigController)
local FallController = require(Client.Controllers.FallController)

Hud.start()
ClientState.start()
DigController.start()
FallController.start()
```

- [ ] **Step 4: Im Playtest prüfen**

Playtest starten, 3 s warten. Server-Pfad automatisch prüfen: `execute_luau` (Client):
```lua
local Remotes = require(game:GetService("ReplicatedStorage").Shared.Remotes)
Remotes.FellHard:FireServer(10)  -- unter 60: darf nichts tun
task.wait(1.2)
Remotes.FellHard:FireServer(100) -- über 60: Charakter stirbt
return "sent"
```
Dann `execute_luau` (Server):
```lua
local player = game:GetService("Players"):GetPlayers()[1]
local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
return humanoid and ("health=" .. humanoid.Health) or "respawning"
```
Expected: `health=0` oder `respawning`. Konsole ohne Fehler. **Handtest durch den Nutzer**: ca. 16 Schichten tief graben (64 Studs), am Seil hoch, in den Förderschacht springen → ohne Fallschirm Respawn + Toast „Autsch …“; mit Leertaste im Fall → roter Schirm, langsamer Fall, kein Schaden. Playtest stoppen. Tests ohne Filter: `0 failed`.

- [ ] **Step 5: Commit**

```bash
git add src/server src/client
git commit -m "feat: Fallschaden und Fallschirm im Förderschacht"
```

---

### Task 12: Abschluss-Playtest + Dokumentation

**Files:**
- Modify: `/Users/angelosisychos/Documents/alles/Projekte/RobloxGame/Recherche & Idee.md` (Fortschritt ergänzen)

- [ ] **Step 1: Kompletter Durchlauf**

Playtest starten, alle Tests ohne Filter ausführen (`0 failed`), Konsole prüfen (keine Fehler; ProfileStore-Mock-Hinweis ist erlaubt). Der Nutzer spielt einen kompletten Durchgang: runter, graben bis der Rucksack voll ist, am Seil hoch, Ablage-Toast, HUD zeigt Erze/Eier.

- [ ] **Step 2: Obsidian-Notiz ergänzen**

Abschnitt „Fortschritt“ anhängen: Plan 1 fertig, was spielbar ist, bekannte Grenzen (echtes Speichern in Studio erst nach Veröffentlichen + „Studio-Zugriff auf API-Dienste“ aktivieren), nächster Schritt Plan 2 (Wesen).

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "chore: Plan 1 abgeschlossen"
```
