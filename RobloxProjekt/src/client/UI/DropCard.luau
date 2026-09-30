-- Drop-Karte: Erst grummelt die Wolke (die Seltenheit klettert Stufe für Stufe nach oben – je seltener,
-- desto länger), dann ist der Brainrot da. Countdown läuft – BEHALTEN (E) oder SKIPPEN (F).
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

local CARD_POSITION = UDim2.new(0.5, 0, 1, -80)
local DARK = Color3.fromRGB(20, 20, 30)
local GREEN, YELLOW, RED = Color3.fromRGB(90, 230, 110), Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 70, 70)
local CLOUD_LIGHT = { color = Color3.fromRGB(200, 230, 255), brightness = 1.5 }

local frame, stroke, header, nameLabel, infoLabel, barBack, barFill, keepButton, skipButton, replaceRow, scale
local badge, badgeLabel, badgeScale
local offer -- {creature, skipValue, endsAt, revealAt, total, revealTotal, revealed, step}
local lastTick = -1 -- zuletzt getickte Countdown-Sekunde

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

local function punch(target: UIScale, from: number)
	target.Scale = from
	TweenService:Create(target, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- Licht der eigenen Wolke (blitzt während der Spannung in der Farbe der Seltenheit).
local function cloudLight(): PointLight?
	local base = Players.LocalPlayer:GetAttribute("Base")
	local world = workspace:FindFirstChild("World")
	local garden = base and world and world:FindFirstChild("Bases") and world.Bases:FindFirstChild("Base" .. base)
	local cloud = garden and garden:FindFirstChild("Cloud")
	return cloud and cloud.PrimaryPart and cloud.PrimaryPart:FindFirstChildOfClass("PointLight")
end

local function setCloudLight(color: Color3, brightness: number)
	local light = cloudLight()
	if light then
		light.Color = color
		light.Brightness = brightness
	end
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
	if offer == nil or not offer.revealed then
		return
	end
	if action == "keep" and isFull() then
		showReplace()
		return
	end
	Remotes.DropChoice:FireServer(action)
end

local function setChoiceVisible(visible: boolean)
	keepButton.Visible = visible
	skipButton.Visible = visible
	barBack.Visible = visible
	badge.Visible = visible
end

-- Spannung: Die Seltenheit klettert von „Gewöhnlich“ bis zur echten – jede Stufe ein Blitz und ein höherer Ton.
local function climbTo(step: number)
	offer.step = step
	local rarity = Rarity.order[step]
	local color = Rarity.color[rarity]
	header.Text = "☁️ " .. string.upper(rarity) .. " …?"
	header.TextColor3 = color
	stroke.Color = color
	frame.BackgroundColor3 = color:Lerp(DARK, 0.8)
	setCloudLight(color, 3 + step)
	punch(scale, 1.06)
	Sfx.play("pop", 0.6, 0.8 + step * 0.15)
end

-- Enthüllung: alles zeigen, großer Knall, Countdown startet.
local function reveal()
	local creature = offer.creature
	offer.revealed = true
	local color = Rarity.color[creature.rarity]
	local form = creature.mutation and Mutations.byId[creature.mutation]
	header.Text = string.upper(creature.rarity) .. (if form then "  ·  " .. form.icon .. " " .. string.upper(form.name) else "")
	header.TextColor3 = color
	stroke.Color = if form then form.color else color
	nameLabel.Text = Species.byId[creature.species].name
	infoLabel.Text = string.format("„%s“  ·  💰 +%s/s auf dem Podest", Species.byId[creature.species].tagline, Format.short(Cloud.income(creature)))
	skipButton.Text = "[F] SKIPPEN  +" .. Format.short(offer.skipValue)
	frame.BackgroundColor3 = color:Lerp(DARK, 0.7)
	setChoiceVisible(true)
	setCloudLight(CLOUD_LIGHT.color, CLOUD_LIGHT.brightness)
	local big = Rarity.index(creature.rarity) >= Rarity.index("Episch") or form ~= nil
	punch(scale, if big then 1.3 else 1.12)
	Sfx.play("pop", 1, if big then 0.6 else 1.2)
	if big then
		Sfx.play("coins", 0.8, 0.8)
	end
end

local function show(creature, skipValue: number, endsAt: number, revealAt: number?)
	local now = workspace:GetServerTimeNow()
	revealAt = revealAt or now
	offer = {
		creature = creature,
		skipValue = skipValue,
		endsAt = endsAt,
		revealAt = revealAt,
		total = math.max(1, endsAt - revealAt),
		revealTotal = math.max(0.01, revealAt - now),
		revealed = false,
		step = 0,
	}
	lastTick = -1
	replaceRow.Visible = false
	setChoiceVisible(false)
	barFill.Size = UDim2.fromScale(1, 1)
	barFill.BackgroundColor3 = GREEN
	badgeLabel.Text = tostring(math.ceil(offer.total))
	nameLabel.Text = "???"
	infoLabel.Text = "Die Wolke grummelt … was fällt da raus?"
	frame.Position = CARD_POSITION
	frame.Visible = true
	climbTo(1)
	-- Einblenden nach climbTo, sonst überschreibt dessen kleiner Stoß das Aufploppen
	scale.Scale = 0.3
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	if revealAt <= now then
		reveal()
	end
end

local function hide()
	offer = nil
	frame.Visible = false
	frame.Position = CARD_POSITION
	setCloudLight(CLOUD_LIGHT.color, CLOUD_LIGHT.brightness)
end

-- Jede Aktualisierung (20× pro Sekunde): Spannung hochklettern lassen oder Countdown laufen lassen.
local function update()
	if offer == nil then
		return
	end
	local now = workspace:GetServerTimeNow()
	if not offer.revealed then
		local target = Rarity.index(offer.creature.rarity)
		local q = math.clamp(1 - (offer.revealAt - now) / offer.revealTotal, 0, 1)
		local step = math.clamp(math.floor(q * target) + 1, 1, target)
		if step > offer.step then
			climbTo(step)
		end
		if now >= offer.revealAt then
			reveal()
		end
		return
	end
	local left = offer.endsAt - now
	local color = if left < 3 then RED elseif left < 6 then YELLOW else GREEN
	barFill.Size = UDim2.fromScale(math.clamp(left / offer.total, 0, 1), 1)
	barFill.BackgroundColor3 = color
	badge.BackgroundColor3 = color:Lerp(DARK, 0.25)
	local whole = math.max(0, math.ceil(left))
	badgeLabel.Text = tostring(whole)
	if whole <= 3 and whole > 0 then
		-- Letzte Sekunden: Karte zittert, Zahl pocht, Ticken wird immer höher
		frame.Position = CARD_POSITION + UDim2.fromOffset(math.random(-4, 4), math.random(-3, 3))
		if whole ~= lastTick then
			lastTick = whole
			punch(badgeScale, 1.5)
			Sfx.play("pop", 0.7, 1.6 + (3 - whole) * 0.35)
		end
	else
		frame.Position = CARD_POSITION
	end
end

function DropCard.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DropCard"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = CARD_POSITION
	frame.Size = UDim2.fromOffset(560, 230)
	frame.Visible = false
	frame.Parent = gui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 18)
	stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Parent = frame
	scale = Instance.new("UIScale")
	scale.Parent = frame
	header = text(frame, UDim2.new(1, -112, 0, 34), UDim2.fromOffset(56, 8), 30) -- Platz für die Countdown-Zahl
	nameLabel = text(frame, UDim2.new(1, -24, 0, 44), UDim2.fromOffset(12, 42), 40)
	infoLabel = text(frame, UDim2.new(1, -24, 0, 24), UDim2.fromOffset(12, 88), 20)
	barBack = Instance.new("Frame")
	barBack.Position = UDim2.fromOffset(12, 118)
	barBack.Size = UDim2.new(1, -24, 0, 12)
	barBack.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	barBack.Parent = frame
	Instance.new("UICorner", barBack).CornerRadius = UDim.new(1, 0)
	barFill = Instance.new("Frame")
	barFill.Size = UDim2.fromScale(1, 1)
	barFill.BackgroundColor3 = GREEN
	barFill.Parent = barBack
	Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)
	keepButton = bigButton(frame, "[E] BEHALTEN", Color3.fromRGB(60, 180, 90), UDim2.new(0, 12, 0, 142), function()
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

	-- Große Countdown-Zahl oben rechts an der Karte
	badge = Instance.new("Frame")
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.new(1, -8, 0, 8)
	badge.Size = UDim2.fromOffset(68, 68)
	badge.BackgroundColor3 = GREEN
	badge.ZIndex = 3
	badge.Parent = frame
	Instance.new("UICorner", badge).CornerRadius = UDim.new(1, 0)
	local badgeStroke = Instance.new("UIStroke")
	badgeStroke.Thickness = 3
	badgeStroke.Color = Color3.new(1, 1, 1)
	badgeStroke.Parent = badge
	badgeScale = Instance.new("UIScale")
	badgeScale.Parent = badge
	badgeLabel = text(badge, UDim2.fromScale(0.8, 0.8), UDim2.fromScale(0.1, 0.1), 40)
	badgeLabel.ZIndex = 4

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
	Remotes.DropOffer.OnClientEvent:Connect(function(creature, skipValue, endsAt, revealAt)
		if creature then
			show(creature, skipValue, endsAt, revealAt)
		else
			hide()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.05)
			update()
		end
	end)
end

return DropCard
