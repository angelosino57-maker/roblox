-- Drop-Karte: Ein Brainrot ist aus der Wolke gefallen. Countdown läuft – BEHALTEN (E) oder SKIPPEN (F).
-- Ist kein Platz mehr frei, zeigt „Behalten“ die eigenen Brainrots zum Ersetzen.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Cloud = require(Shared.Cloud)
local Format = require(Shared.Format)
local Species = require(Shared.Config.Species)
local Rarity = require(Shared.Config.Rarity)
local Mutations = require(Shared.Config.Mutations)
local Remotes = require(Shared.Remotes)
local ClientState = require(script.Parent.Parent.ClientState)
local Sfx = require(script.Parent.Parent.Sfx)

local DropCard = {}

local frame, header, nameLabel, infoLabel, barFill, skipButton, replaceRow, scale
local offer -- {creature, skipValue, endsAt}

local function text(parent, size, position, textSize)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.2
	l.Size = size
	l.Position = position
	l.TextSize = textSize
	l.Parent = parent
	return l
end

local function bigButton(parent, label, color, position, onClick)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0.48, 0, 0, 56)
	b.Position = position
	b.BackgroundColor3 = color
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = label
	b.Parent = parent
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 12)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.Parent = b
	b.Activated:Connect(onClick)
	return b
end

local function isFull(): boolean
	local s = ClientState.current
	if s == nil then
		return false
	end
	local n = 0
	for _ in s.creatures do
		n += 1
	end
	return n >= s.capacity
end

-- Bei vollem Bestand: eigene Brainrots als Ersetzen-Knöpfe (schwächster zuerst).
local function showReplace()
	local s = ClientState.current
	replaceRow:ClearAllChildren()
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Wraps = true
	layout.Padding = UDim.new(0, 6)
	layout.Parent = replaceRow
	local list = {}
	for _, c in s.creatures do
		table.insert(list, c)
	end
	table.sort(list, function(a, b)
		return Cloud.income(a) < Cloud.income(b)
	end)
	for _, c in list do
		local b = Instance.new("TextButton")
		b.Size = UDim2.fromOffset(170, 44)
		b.BackgroundColor3 = Rarity.color[c.rarity]:Lerp(Color3.new(0, 0, 0), 0.45)
		b.Font = Enum.Font.FredokaOne
		b.TextScaled = true
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Text = "✖ " .. Species.displayName(c) .. "\n" .. Format.short(Cloud.income(c)) .. "/s"
		b.Parent = replaceRow
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
		b.Activated:Connect(function()
			Remotes.DropChoice:FireServer("keep", c.id)
		end)
	end
	replaceRow.Visible = true
	infoLabel.Text = "🎒 Kein Platz mehr! Welchen wirfst du raus? (wird zu Geld)"
end

local function choose(action: string)
	if offer == nil then
		return
	end
	if action == "keep" and isFull() then
		showReplace()
		return
	end
	Remotes.DropChoice:FireServer(action)
end

local function show(creature, skipValue: number, endsAt: number)
	offer = { creature = creature, skipValue = skipValue, endsAt = endsAt, total = math.max(1, endsAt - workspace:GetServerTimeNow()) }
	local color = Rarity.color[creature.rarity]
	local form = creature.mutation and Mutations.byId[creature.mutation]
	header.Text = string.upper(creature.rarity) .. (if form then "  ·  " .. form.icon .. " " .. string.upper(form.name) else "")
	header.TextColor3 = color
	nameLabel.Text = Species.byId[creature.species].name
	infoLabel.Text = string.format("„%s“  ·  💰 +%s/s auf dem Podest", Species.byId[creature.species].tagline, Format.short(Cloud.income(creature)))
	skipButton.Text = "[F] SKIPPEN  +" .. Format.short(skipValue)
	replaceRow.Visible = false
	frame.BackgroundColor3 = color:Lerp(Color3.fromRGB(20, 20, 30), 0.7)
	frame.Visible = true
	scale.Scale = 0.3
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	Sfx.play("pop", 0.8, 1.5 - Rarity.index(creature.rarity) * 0.1)
end

local function hide()
	offer = nil
	frame.Visible = false
end

function DropCard.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DropCard"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -80)
	frame.Size = UDim2.fromOffset(560, 230)
	frame.Visible = false
	frame.Parent = gui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 18)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Parent = frame
	scale = Instance.new("UIScale")
	scale.Parent = frame
	header = text(frame, UDim2.new(1, -24, 0, 34), UDim2.fromOffset(12, 8), 30)
	nameLabel = text(frame, UDim2.new(1, -24, 0, 44), UDim2.fromOffset(12, 42), 40)
	infoLabel = text(frame, UDim2.new(1, -24, 0, 24), UDim2.fromOffset(12, 88), 20)
	local barBack = Instance.new("Frame")
	barBack.Position = UDim2.fromOffset(12, 118)
	barBack.Size = UDim2.new(1, -24, 0, 12)
	barBack.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	barBack.Parent = frame
	Instance.new("UICorner", barBack).CornerRadius = UDim.new(1, 0)
	barFill = Instance.new("Frame")
	barFill.Size = UDim2.fromScale(1, 1)
	barFill.BackgroundColor3 = Color3.fromRGB(90, 230, 110)
	barFill.Parent = barBack
	Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)
	bigButton(frame, "[E] BEHALTEN", Color3.fromRGB(60, 180, 90), UDim2.new(0, 12, 0, 142), function()
		choose("keep")
	end)
	skipButton = bigButton(frame, "[F] SKIPPEN", Color3.fromRGB(90, 90, 110), UDim2.new(0.52, -12, 0, 142), function()
		choose("skip")
	end)
	replaceRow = Instance.new("Frame")
	replaceRow.BackgroundTransparency = 1
	replaceRow.Position = UDim2.new(0, 0, 0, -110)
	replaceRow.Size = UDim2.new(1, 0, 0, 100)
	replaceRow.Visible = false
	replaceRow.Parent = frame

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or offer == nil then
			return
		end
		if input.KeyCode == Enum.KeyCode.E then
			choose("keep")
		elseif input.KeyCode == Enum.KeyCode.F then
			choose("skip")
		end
	end)
	Remotes.DropOffer.OnClientEvent:Connect(function(creature, skipValue, endsAt)
		if creature then
			show(creature, skipValue, endsAt)
		else
			hide()
		end
	end)
	-- Countdown-Balken und Tick-Geräusch in den letzten Sekunden
	task.spawn(function()
		local lastTick = -1
		while true do
			task.wait(0.05)
			if offer then
				local left = offer.endsAt - workspace:GetServerTimeNow()
				local p = math.clamp(left / offer.total, 0, 1)
				barFill.Size = UDim2.fromScale(p, 1)
				barFill.BackgroundColor3 = if left < 3 then Color3.fromRGB(255, 70, 70) elseif left < 6 then Color3.fromRGB(255, 200, 60) else Color3.fromRGB(90, 230, 110)
				local whole = math.ceil(left)
				if whole <= 3 and whole > 0 and whole ~= lastTick then
					lastTick = whole
					Sfx.play("pop", 0.5, 2)
				end
			end
		end
	end)
end

return DropCard
