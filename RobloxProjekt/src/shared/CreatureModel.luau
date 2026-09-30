-- 3D-Modell eines Wesens: Vorlage aus ReplicatedStorage.CreatureModels.<art> (Ersatz: Kugel mit Augen),
-- Größe nach Seltenheit, Mutation als Leuchtschimmer + Partikel, Namensschild. Pivot = Mitte unten.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarity = require(script.Parent.Config.Rarity)
local Species = require(script.Parent.Config.Species)
local Mutations = require(script.Parent.Config.Mutations)

local CreatureModel = {}

local NEON = { lava = true, galaxy = true, rainbow = true }
local SPARKLES = { gold = true, diamond = true, galaxy = true, rainbow = true }
local GLOW_FROM = Rarity.index("Legendär")

-- Partikel/Leuchten je Mutation; Regenbogen färbt der Client (Tag "Rainbow").
local function addEffects(body: BasePart, creature)
	local mutation = creature.mutation
	if mutation and SPARKLES[mutation] then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Mutations.byId[mutation].color
		sparkles.Parent = body
	end
	if mutation == "lava" then
		local fire = Instance.new("Fire")
		fire.Color = Color3.fromRGB(255, 120, 30)
		fire.SecondaryColor = Color3.fromRGB(255, 40, 0)
		fire.Size = body.Size.X * 1.2
		fire.Heat = 4
		fire.Parent = body
	elseif mutation == "frost" then
		local snow = Instance.new("ParticleEmitter")
		snow.Color = ColorSequence.new(Color3.fromRGB(235, 248, 255))
		snow.Size = NumberSequence.new(0.25, 0)
		snow.Lifetime = NumberRange.new(1, 1.6)
		snow.Rate = 8
		snow.Speed = NumberRange.new(1, 2)
		snow.Acceleration = Vector3.new(0, -3, 0)
		snow.SpreadAngle = Vector2.new(60, 60)
		snow.Parent = body
	elseif mutation == "rainbow" then
		CollectionService:AddTag(body, "Rainbow")
	end
	if Rarity.index(creature.rarity) >= GLOW_FROM or mutation == "galaxy" then
		local light = Instance.new("PointLight")
		light.Color = body.Color
		light.Brightness = 2
		light.Range = 10
		light.Parent = body
	end
end

local function part(parent, name, size, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Ball
	p.Size = size
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

local BASE_HEIGHT = 4 -- Höhe eines gewöhnlichen Wesens in Studs

local function fromTemplate(creature): Model?
	local folder = ReplicatedStorage:FindFirstChild("CreatureModels")
	local template = folder and folder:FindFirstChild(creature.species)
	if template == nil then
		return nil
	end
	local model = template:Clone()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	return model
end

local function fallback(creature): Model
	local model = Instance.new("Model")
	local color = Species.byId[creature.species].color
	local ball = part(model, "Ball", Vector3.one * BASE_HEIGHT, color, Enum.Material.SmoothPlastic)
	ball.Position = Vector3.new(0, BASE_HEIGHT / 2, 0)
	for _, side in { -1, 1 } do
		local eye = part(model, "Eye", Vector3.one * (BASE_HEIGHT * 0.18), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
		eye.Position = ball.Position + Vector3.new(side * BASE_HEIGHT * 0.2, BASE_HEIGHT * 0.15, -BASE_HEIGHT * 0.45)
	end
	return model
end

-- `scale` verkleinert/vergrößert zusätzlich (z. B. 0.55 für Begleiter).
function CreatureModel.build(creature, scale: number?): Model
	local model = fromTemplate(creature) or fallback(creature)
	model.Name = creature.id

	-- Auf Standardhöhe × Seltenheit bringen, Pivot mittig unten.
	local height = BASE_HEIGHT * (1 + 0.15 * (Rarity.index(creature.rarity) - 1)) * (scale or 1)
	local _, size = model:GetBoundingBox()
	model:ScaleTo(model:GetScale() * height / size.Y)
	local cf, box = model:GetBoundingBox()

	-- Unsichtbarer Körper als PrimaryPart: Anker für Prompts, Effekte und Bewegung.
	local body = part(model, "Body", box, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	body.Shape = Enum.PartType.Block
	body.Size = box
	body.Transparency = 1
	body.CFrame = cf
	model.PrimaryPart = body
	model.WorldPivot = cf * CFrame.new(0, -box.Y / 2, 0)

	if creature.mutation then
		local glow = Instance.new("Highlight")
		glow.FillColor = Mutations.byId[creature.mutation].color
		glow.FillTransparency = if NEON[creature.mutation] then 0.35 else 0.55
		glow.OutlineColor = Mutations.byId[creature.mutation].color
		glow.DepthMode = Enum.HighlightDepthMode.Occluded
		glow.Parent = model
		if creature.mutation == "rainbow" then
			CollectionService:AddTag(glow, "Rainbow")
		end
	end
	body.Color = if creature.mutation then Mutations.byId[creature.mutation].color else Species.byId[creature.species].color
	addEffects(body, creature)

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(170, 38)
	gui.StudsOffset = Vector3.new(0, box.Y / 2 + 1.4, 0)
	gui.MaxDistance = 80
	gui.Parent = body
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Rarity.color[creature.rarity]
	label.TextStrokeTransparency = 0.2
	label.Text = Species.displayName(creature) .. "\n" .. creature.rarity
	label.Parent = gui

	return model
end

return CreatureModel
