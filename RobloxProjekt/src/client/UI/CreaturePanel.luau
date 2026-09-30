-- Brainrots (Taste C): 3 Podeste (verdienen Geld) und der Rucksack. Platz ist knapp!
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Cloud = require(Shared.Cloud)
local Format = require(Shared.Format)
local Species = require(Shared.Config.Species)
local Rarity = require(Shared.Config.Rarity)
local Remotes = require(Shared.Remotes)
local ClientState = require(script.Parent.Parent.ClientState)
local Widgets = require(script.Parent.Widgets)

local CreaturePanel = {}

local ACTIVE, IDLE = Widgets.ACTIVE, Widgets.IDLE
local button = Widgets.button

local function row(lines, c, onPodium: boolean)
	local label, buttons = lines.row(string.format("%s · %s\n💰 +%s/s", Species.displayName(c), c.rarity, Format.short(Cloud.income(c))))
	label.Parent.Size = UDim2.new(1, -8, 0, 48)
	label.TextColor3 = Rarity.color[c.rarity]
	if onPodium then
		button(buttons, "⬇ Runter", IDLE, function()
			Remotes.Equip:FireServer(c.id, false)
		end)
	else
		button(buttons, "⬆ Aufs Podest", ACTIVE, function()
			Remotes.Equip:FireServer(c.id, true)
		end)
	end
	button(buttons, "👋 +" .. Format.short(Cloud.skipValue(c)), IDLE, function()
		Remotes.Release:FireServer(c.id)
	end)
end

local function render(lines, s)
	local total = 0
	for _ in s.creatures do
		total += 1
	end
	lines.row(string.format("🏆 Podeste %d/%d  ·  🎒 Brainrots %d/%d  ·  💰 +%s/s", #s.equipped, s.equipMax, total, s.capacity, Format.short(s.income)))
	lines.row("— Auf den Podesten (verdienen Geld) —")
	for _, id in s.equipped do
		local c = s.creatures[id]
		if c then
			row(lines, c, true)
		end
	end
	lines.row("— Im Rucksack —")
	local bag = {}
	for id, c in s.creatures do
		if not table.find(s.equipped, id) then
			table.insert(bag, c)
		end
	end
	table.sort(bag, function(a, b)
		return Cloud.income(a) > Cloud.income(b)
	end)
	for _, c in bag do
		row(lines, c, false)
	end
	if total == 0 then
		lines.infoRow("Noch keine Brainrots – knie dich vor deine Wolke!")
	end
end

function CreaturePanel.start()
	local ui = Widgets.panel({
		name = "CreaturePanel",
		toggleText = "Brainrots",
		toggleColor = Color3.fromRGB(120, 80, 200),
		slot = 1,
		key = Enum.KeyCode.C,
		tabs = { { "all", "Brainrots" } },
		render = function(lines)
			local s = ClientState.current
			if s then
				render(lines, s)
			end
		end,
	})
	ClientState.changed:Connect(ui.render)
end

return CreaturePanel
