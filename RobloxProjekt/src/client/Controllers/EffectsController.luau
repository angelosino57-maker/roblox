-- Client-Effekte: Regenbogen-Farbwechsel, Münz-Pops und fliegende Münzen, Glitzer beim Wolken-Upgrade.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(script.Parent.Parent.Sfx)

local EffectsController = {}

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 60)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(60, 255, 120)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(60, 140, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 60, 255)),
})

local function anchor(position: Vector3): Part
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.Position = position
	holder.Parent = workspace
	return holder
end

local function burst(holder: Part, color: ColorSequence, count: number, speed: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.6, 1.1)
	emitter.Speed = NumberRange.new(speed * 0.6, speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(0.7, 0)
	emitter.Acceleration = Vector3.new(0, -25, 0)
	emitter.LightEmission = 1
	emitter.Color = color
	emitter.Parent = holder
	emitter:Emit(count)
end

-- Schwebender Text, der nach oben steigt und verblasst.
local function floatText(position: Vector3, text: string, color: Color3, size: number)
	local holder = anchor(position)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(size * 6, size)
	gui.AlwaysOnTop = true
	gui.Parent = holder
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = gui
	TweenService:Create(holder, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = position + Vector3.new(0, 8, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(holder, 1.6)
	return holder
end

local function onCollected(amount: number, position: Vector3, icon: string?)
	local holder = floatText(position + Vector3.new(0, 3, 0), "+" .. Format.short(amount) .. " " .. (icon or "💰"), Color3.fromRGB(255, 225, 70), 60)
	burst(holder, ColorSequence.new(Color3.fromRGB(255, 215, 60)), math.clamp(math.floor(math.log10(amount + 1) * 8), 8, 50), 18)
	Sfx.play("coins", 0.6, 0.9 + math.random() * 0.25)
end





-- Wolken-Upgrade: Glitzer-Explosion an der eigenen Wolke.
local function onCloudFx()
	local base = Players.LocalPlayer:GetAttribute("Base")
	local world = workspace:FindFirstChild("World")
	local garden = base and world and world.Bases:FindFirstChild("Base" .. base)
	local cloud = garden and garden:FindFirstChild("Cloud")
	if cloud and cloud.PrimaryPart then
		burst(anchor(cloud.PrimaryPart.Position), RAINBOW, 80, 30)
	end
	Sfx.play("pop", 0.9, 0.8)
end

-- Geld gibt's: Münzen spritzen heraus und fliegen zum Spieler.
local COIN_SIZE = { crystal = 6, bag = 9, chest = 14, mega = 28 }

local function onCoinBurst(amount: number, position: Vector3, kind: string)
	local character = Players.LocalPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local holder = floatText(position + Vector3.new(0, 3, 0), "+" .. Format.short(amount) .. " 💰", Color3.fromRGB(255, 225, 70), if kind == "mega" then 90 else 60)
	burst(holder, ColorSequence.new(Color3.fromRGB(255, 215, 60)), if kind == "mega" then 60 else 20, 22)
	Sfx.play("coins", if kind == "mega" then 1 else 0.5, 0.95 + math.random() * 0.2)
	if hrp == nil then
		return
	end
	for i = 1, COIN_SIZE[kind] or 6 do
		local coin = Instance.new("Part")
		coin.Shape = Enum.PartType.Cylinder
		coin.Size = Vector3.new(0.25, 1.1, 1.1)
		coin.Color = Color3.fromRGB(255, 205, 50)
		coin.Material = Enum.Material.Neon
		coin.Anchored = true
		coin.CanCollide = false
		coin.CanQuery = false
		coin.CastShadow = false
		local start = position + Vector3.new(math.random(-20, 20) / 10, 1, math.random(-20, 20) / 10)
		coin.CFrame = CFrame.new(start) * CFrame.Angles(0, 0, math.rad(90))
		coin.Parent = workspace
		local up = start + Vector3.new(math.random(-30, 30) / 10, 4 + math.random() * 3, math.random(-30, 30) / 10)
		task.delay(i * 0.02, function()
			TweenService:Create(coin, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = up }):Play()
			task.wait(0.28)
			if hrp.Parent then
				TweenService:Create(coin, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = hrp.Position, Size = Vector3.new(0.1, 0.4, 0.4) }):Play()
			end
			Debris:AddItem(coin, 0.4)
		end)
	end
end

function EffectsController.start()
	RunService.RenderStepped:Connect(function()
		local color = Color3.fromHSV((os.clock() * 0.25) % 1, 0.8, 1)
		for _, item in CollectionService:GetTagged("Rainbow") do
			if item:IsA("Highlight") then
				item.FillColor = color
				item.OutlineColor = color
			else
				item.Color = color
			end
		end
	end)
	Remotes.Collected.OnClientEvent:Connect(onCollected)
	Remotes.CoinBurst.OnClientEvent:Connect(onCoinBurst)
	Remotes.CloudFx.OnClientEvent:Connect(onCloudFx)
end

return EffectsController
