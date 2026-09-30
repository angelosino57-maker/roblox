-- Oben rechts: das nächste Welt-Event mit Countdown (angekündigt → läuft → nächstes).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Fomo = require(ReplicatedStorage.Shared.Fomo)
local Widgets = require(script.Parent.Widgets)

local FomoWidget = {}

function FomoWidget.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "FomoWidget"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local line = Instance.new("TextLabel")
	line.AnchorPoint = Vector2.new(1, 0)
	line.Position = UDim2.new(1, -12, 0, 104)
	line.Size = UDim2.fromOffset(420, 32)
	line.BackgroundTransparency = 1
	line.Font = Enum.Font.FredokaOne
	line.TextScaled = true
	line.TextColor3 = Color3.new(1, 1, 1)
	line.TextStrokeTransparency = 0.3
	line.TextXAlignment = Enum.TextXAlignment.Right
	line.Parent = gui
	local pulse = Instance.new("UIScale")
	pulse.Parent = line

	local lastPhase
	while true do
		local now = workspace:GetServerTimeNow()
		local t0, seed = ReplicatedStorage:GetAttribute("FomoT0"), ReplicatedStorage:GetAttribute("FomoSeed")
		if t0 and seed then
			local state = Fomo.eventAt(now, t0, seed)
			local left = Widgets.fmtTime(state.phaseEndsAt - now)
			if state.phase == "active" then
				line.Text = state.event.name .. " – noch " .. left
				line.TextColor3 = Color3.fromHSV((os.clock() * 0.5) % 1, 0.6, 1)
			elseif state.phase == "warning" then
				line.Text = "⚡ " .. state.event.name .. " in " .. left .. "!"
				line.TextColor3 = Color3.fromRGB(255, 220, 90)
			else
				line.Text = "⚡ Nächstes Event in " .. Widgets.fmtTime(state.phaseEndsAt + Fomo.WARNING - now)
				line.TextColor3 = Color3.new(1, 1, 1)
			end
			if state.phase ~= lastPhase then
				lastPhase = state.phase
				pulse.Scale = 1.3
				TweenService:Create(pulse, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			end
		end
		task.wait(0.25)
	end
end

return FomoWidget
