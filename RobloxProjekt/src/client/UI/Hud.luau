-- HUD: Geld (zählt hoch), Einkommen, Rang (wen man überholen muss), Knie-Hinweis mit Drop-Countdown,
-- Aufgabe für Neue und die drei Wolken-Upgrades unten rechts.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local CloudConfig = require(Shared.Config.Cloud)
local Remotes = require(Shared.Remotes)
local ClientState = require(script.Parent.Parent.ClientState)

local Hud = {}

local player = Players.LocalPlayer
local gui, coinLabel, incomeLabel, rankLabel, kneelLabel, taskLabel, toastLabel
local upgradeButtons = {}
local coins, shownCoins = 0, 0

local function label(parent, text, size, position, align)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.3
	l.TextScaled = true
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.Size = size
	l.Position = position
	l.Text = text
	l.Parent = parent
	return l
end

local UPGRADE_ORDER = { "luck", "speed", "auto" }

local function renderUpgrades(s)
	for _, kind in UPGRADE_ORDER do
		local u = s.upgrades[kind]
		local b = upgradeButtons[kind]
		local name = CloudConfig.upgrades[kind].name
		if u.price then
			b.Text = string.format("%s  Lv %d  ·  %s", name, u.level, Format.short(u.price))
			b.BackgroundColor3 = if s.coins >= u.price then Color3.fromRGB(60, 180, 90) else Color3.fromRGB(70, 70, 90)
		else
			b.Text = name .. "  MAX"
			b.BackgroundColor3 = Color3.fromRGB(150, 120, 40)
		end
	end
end

local function render(s)
	coins = s.coins
	incomeLabel.Text = "+" .. Format.short(s.income) .. " /s   🍀 ×" .. string.format("%.2f", s.luck)
	if s.tutorial then
		taskLabel.Visible = true
		taskLabel.Text = string.format("Aufgabe %d/%d: %s", s.tutorial.index, s.tutorial.total, s.tutorial.text)
	else
		taskLabel.Visible = false
	end
	renderUpgrades(s)
end

local function renderRank()
	if player:GetAttribute("King") then
		rankLabel.Text = "👑 DU BIST KÖNIG DER WOLKEN – halte die Krone!"
		rankLabel.TextColor3 = Color3.fromRGB(255, 215, 60)
		return
	end
	local rank, total = player:GetAttribute("Rank"), player:GetAttribute("RankTotal")
	local ahead, aheadIncome = player:GetAttribute("AheadName"), player:GetAttribute("AheadIncome")
	rankLabel.TextColor3 = Color3.new(1, 1, 1)
	if rank and ahead and aheadIncome then
		rankLabel.Text = string.format("🏆 Platz %d von %d  ·  überhol %s (%s/s)", rank, total or rank, ahead, Format.short(aheadIncome))
	elseif rank then
		rankLabel.Text = string.format("🏆 Platz %d von %d", rank, total or rank)
	else
		rankLabel.Text = ""
	end
end

function Hud.toast(text: string)
	toastLabel.Text = text
	toastLabel.TextTransparency = 0
	toastLabel.TextStrokeTransparency = 0.3
	task.delay(3, function()
		if toastLabel.Text == text then
			TweenService:Create(toastLabel, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

function Hud.setCompact(_compact: boolean) end

function Hud.start()
	gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	panel.BackgroundTransparency = 0.35
	panel.Size = UDim2.fromOffset(330, 118)
	panel.Position = UDim2.fromOffset(12, 60)
	panel.Parent = gui
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
	coinLabel = label(panel, "💰 0", UDim2.new(1, -16, 0, 46), UDim2.fromOffset(8, 4))
	coinLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
	local pop = Instance.new("UIScale")
	pop.Name = "Pop"
	pop.Parent = coinLabel
	incomeLabel = label(panel, "", UDim2.new(1, -16, 0, 26), UDim2.fromOffset(8, 52))
	rankLabel = label(panel, "", UDim2.new(1, -16, 0, 26), UDim2.fromOffset(8, 84))

	taskLabel = label(gui, "", UDim2.fromOffset(620, 32), UDim2.new(0.5, -310, 0, 64), Enum.TextXAlignment.Center)
	taskLabel.BackgroundTransparency = 0.3
	taskLabel.BackgroundColor3 = Color3.fromRGB(40, 110, 60)
	Instance.new("UICorner", taskLabel).CornerRadius = UDim.new(0, 10)

	kneelLabel = label(gui, "", UDim2.fromOffset(520, 34), UDim2.new(0.5, -260, 1, -150), Enum.TextXAlignment.Center)
	toastLabel = label(gui, "", UDim2.fromOffset(640, 36), UDim2.new(0.5, -320, 0, 20), Enum.TextXAlignment.Center)
	toastLabel.TextTransparency = 1

	-- Wolken-Upgrades unten rechts
	for i, kind in UPGRADE_ORDER do
		local b = Instance.new("TextButton")
		b.AnchorPoint = Vector2.new(1, 1)
		b.Position = UDim2.new(1, -12, 1, -12 - (#UPGRADE_ORDER - i) * 56)
		b.Size = UDim2.fromOffset(280, 48)
		b.Font = Enum.Font.FredokaOne
		b.TextScaled = true
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Parent = gui
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 12)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 10)
		pad.PaddingRight = UDim.new(0, 10)
		pad.PaddingTop = UDim.new(0, 6)
		pad.PaddingBottom = UDim.new(0, 6)
		pad.Parent = b
		b.Activated:Connect(function()
			Remotes.Upgrade:FireServer(kind)
		end)
		upgradeButtons[kind] = b
	end

	ClientState.changed:Connect(render)
	if ClientState.current then
		render(ClientState.current)
	end
	Remotes.Notify.OnClientEvent:Connect(Hud.toast)
	Remotes.Coins.OnClientEvent:Connect(function(value: number)
		coins = value
		local s = ClientState.current
		if s then
			s.coins = value
			renderUpgrades(s)
		end
	end)
	for _, attr in { "Rank", "RankTotal", "AheadName", "AheadIncome", "King" } do
		player:GetAttributeChangedSignal(attr):Connect(renderRank)
	end

	-- Geld zählt sichtbar hoch, Knie-Hinweis mit Countdown bis zum nächsten Drop
	task.spawn(function()
		while true do
			local diff = coins - shownCoins
			if math.abs(diff) >= 1 then
				local before = shownCoins
				shownCoins += diff * 0.25
				if math.abs(coins - shownCoins) < 1 then
					shownCoins = coins
				end
				if shownCoins - before > 20 then
					pop.Scale = 1.12
					TweenService:Create(pop, TweenInfo.new(0.15), { Scale = 1 }):Play()
				end
			end
			coinLabel.Text = "💰 " .. Format.short(shownCoins)
			local nextDrop = player:GetAttribute("NextDrop")
			if player:GetAttribute("Kneeling") then
				kneelLabel.Text = if nextDrop then string.format("🙏 Du kniest … nächster Drop in %.1f s", math.max(0, nextDrop - workspace:GetServerTimeNow())) else "🙏 Du kniest …"
				kneelLabel.TextColor3 = Color3.fromRGB(180, 230, 255)
			elseif nextDrop then
				kneelLabel.Text = string.format("🤖 Auto-Farm: nächster Drop in %.1f s  ·  Knien geht schneller!", math.max(0, nextDrop - workspace:GetServerTimeNow()))
				kneelLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
			else
				kneelLabel.Text = "☁️ Setz dich auf das rote Kissen vor deiner Wolke!"
				kneelLabel.TextColor3 = Color3.fromRGB(255, 230, 120)
			end
			task.wait(0.05)
		end
	end)
end

return Hud
