-- Baut die Welt der Brainrot-Wolke in workspace.World: Platz in der Mitte und 8 eingezäunte Gärten
-- mit Wolke, Kissen, Landeplatz und 3 Podesten. Läuft einmal im Editor (per MCP); zur Laufzeit nur,
-- wenn die Welt fehlt oder veraltet ist.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseLayout = require(ReplicatedStorage.Shared.BaseLayout)

local WorldBuilder = {}

local VERSION = 10
local GRASS = Color3.fromRGB(110, 185, 85)
local FENCE = Color3.fromRGB(245, 245, 240)
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- Zylinder-Achse senkrecht

local function makePart(parent, name, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function billboard(parent, text, size, offset, maxDistance)
	local gui = Instance.new("BillboardGui")
	gui.Size = size
	gui.StudsOffset = offset
	gui.AlwaysOnTop = true
	gui.MaxDistance = maxDistance or 250
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = gui
	return label
end
WorldBuilder.billboard = billboard

-- Weißer Lattenzaun wie in Grow a Garden, vorne mit Eingang.
local function fence(parent, frame: CFrame)
	local folder = Instance.new("Folder")
	folder.Name = "Fence"
	folder.Parent = parent
	local half = BaseLayout.SIZE / 2
	local function run(from: Vector3, to: Vector3)
		local length = (to - from).Magnitude
		local dir = (to - from).Unit
		local mid = (from + to) / 2
		for _, y in { 1.1, 2.2 } do
			makePart(folder, "Rail", Vector3.new(0.4, 0.4, length), CFrame.lookAt(mid + Vector3.new(0, y, 0), to + Vector3.new(0, y, 0)), FENCE, Enum.Material.WoodPlanks)
		end
		for d = 0, length, 3 do
			local p = from + dir * d + Vector3.new(0, 1.6, 0)
			makePart(folder, "Picket", Vector3.new(0.6, 3.2, 0.3), CFrame.lookAt(p, p + dir), FENCE, Enum.Material.WoodPlanks)
		end
	end
	local function corner(x, z)
		return (frame * CFrame.new(x, 0, z)).Position
	end
	local g = BaseLayout.GATE_WIDTH / 2
	run(corner(-half, half), corner(half, half))
	run(corner(-half, -half), corner(-half, half))
	run(corner(half, -half), corner(half, half))
	run(corner(-half, -half), corner(-g, -half))
	run(corner(g, -half), corner(half, -half))
end

-- Die Wolke: viele weiche Kugeln, leicht leuchtend, mit Glitzer-Regen.
local function cloud(parent, cf: CFrame)
	local model = Instance.new("Model")
	model.Name = "Cloud"
	local core = makePart(model, "Core", Vector3.one * 12, cf, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	core.Shape = Enum.PartType.Ball
	core.CanCollide = false
	local rng = Random.new(5)
	for _ = 1, 9 do
		local puff = makePart(model, "Puff", Vector3.one * rng:NextNumber(6, 10), cf * CFrame.new(rng:NextNumber(-9, 9), rng:NextNumber(-2, 3), rng:NextNumber(-5, 5)), Color3.fromRGB(245, 248, 255), Enum.Material.SmoothPlastic)
		puff.Shape = Enum.PartType.Ball
		puff.CanCollide = false
	end
	local light = Instance.new("PointLight")
	light.Range = 30
	light.Brightness = 1.5
	light.Color = Color3.fromRGB(200, 230, 255)
	light.Parent = core
	local rain = Instance.new("ParticleEmitter")
	rain.Name = "Rain"
	rain.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	rain.Color = ColorSequence.new(Color3.fromRGB(200, 235, 255))
	rain.Rate = 8
	rain.Lifetime = NumberRange.new(1.2, 1.8)
	rain.Speed = NumberRange.new(6, 10)
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.Size = NumberSequence.new(0.5, 0)
	rain.LightEmission = 1
	rain.Parent = core
	model.PrimaryPart = core
	model.Parent = parent
end

local function buildGarden(parent, i)
	local folder = Instance.new("Folder")
	folder.Name = "Base" .. i
	local frame = BaseLayout.frame(i)
	makePart(folder, "Floor", Vector3.new(BaseLayout.SIZE, 1, BaseLayout.SIZE), frame * CFrame.new(0, -0.4, 0), Color3.fromRGB(100, 175, 80), Enum.Material.Grass)
	-- Beete an den Seiten wie in Grow a Garden
	for _, x in { -32, 32 } do
		makePart(folder, "Bed", Vector3.new(14, 0.6, 70), frame * CFrame.new(x, 0.1, 0), Color3.fromRGB(110, 75, 45), Enum.Material.Ground)
	end
	fence(folder, frame)

	local post = makePart(folder, "Sign", Vector3.new(1, 8, 1), BaseLayout.sign(i) * CFrame.new(0, 4, 0), Color3.fromRGB(150, 105, 65), Enum.Material.Wood)
	billboard(post, "Frei", UDim2.fromOffset(240, 50), Vector3.new(0, 6, 0))

	cloud(folder, BaseLayout.cloud(i))

	-- Kissen zum Knien (Sitz) vor der Wolke
	local seat = Instance.new("Seat")
	seat.Name = "KneelSeat"
	seat.Anchored = true
	seat.Size = Vector3.new(4, 1, 4)
	seat.CFrame = BaseLayout.seat(i) * CFrame.new(0, 0.5, 0)
	seat.Color = Color3.fromRGB(220, 60, 90)
	seat.Material = Enum.Material.Fabric
	seat.Parent = folder
	billboard(seat, "🙏 Hier knien", UDim2.fromOffset(160, 36), Vector3.new(0, 3, 0), 60)

	local pad = makePart(folder, "DropPad", Vector3.new(0.3, 7, 7), BaseLayout.drop(i) * CFrame.new(0, 0.2, 0) * UPRIGHT, Color3.fromRGB(180, 230, 255), Enum.Material.Neon)
	pad.Shape = Enum.PartType.Cylinder
	pad.Transparency = 0.4
	pad.CanCollide = false

	local podiums = Instance.new("Folder")
	podiums.Name = "Podiums"
	podiums.Parent = folder
	for k = 1, BaseLayout.PODIUMS do
		local p = makePart(podiums, "P" .. k, Vector3.new(2, 7, 7), BaseLayout.podium(i, k) * CFrame.new(0, 1, 0) * UPRIGHT, Color3.fromRGB(235, 235, 245), Enum.Material.Marble)
		p.Shape = Enum.PartType.Cylinder
		p:SetAttribute("Index", k)
		local ring = makePart(podiums, "Ring" .. k, Vector3.new(0.4, 7.6, 7.6), BaseLayout.podium(i, k) * CFrame.new(0, 2.05, 0) * UPRIGHT, Color3.fromRGB(255, 210, 80), Enum.Material.Neon)
		ring.Shape = Enum.PartType.Cylinder
		ring.CanCollide = false
	end
	folder.Parent = parent
end

local function buildSky(world)
	local clouds = Instance.new("Folder")
	clouds.Name = "Clouds"
	local rng = Random.new(7)
	for _ = 1, 40 do
		local center = Vector3.new(rng:NextNumber(-500, 500), rng:NextNumber(80, 180), rng:NextNumber(-500, 500))
		for _ = 1, 4 do
			local puff = makePart(clouds, "Puff", Vector3.one * rng:NextNumber(14, 26), CFrame.new(center + Vector3.new(rng:NextNumber(-14, 14), rng:NextNumber(-3, 3), rng:NextNumber(-8, 8))), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
			puff.Shape = Enum.PartType.Ball
			puff.CanCollide = false
			puff.CanQuery = false
			puff.CastShadow = false
			puff.Transparency = 0.15
		end
	end
	clouds.Parent = world
end

function WorldBuilder.ensure(): Folder
	local existing = workspace:FindFirstChild("World")
	if existing and existing:GetAttribute("Version") == VERSION then
		return existing
	end
	if existing then
		existing:Destroy()
	end

	local world = Instance.new("Folder")
	world.Name = "World"
	world:SetAttribute("Version", VERSION)

	makePart(world, "Ground", Vector3.new(1000, 2, 1000), CFrame.new(0, -1.5, 0), GRASS, Enum.Material.Grass)
	makePart(world, "Plaza", Vector3.new(60, 1, 60), CFrame.new(0, -0.4, 0), Color3.fromRGB(215, 200, 170), Enum.Material.Cobblestone)
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(0, 0.5, 0)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = world
	local title = makePart(world, "Title", Vector3.one, CFrame.new(0, 22, 0), Color3.new(), Enum.Material.SmoothPlastic)
	title.Transparency = 1
	title.CanCollide = false
	billboard(title, "☁️ BRAINROT-WOLKE", UDim2.fromOffset(420, 80), Vector3.zero, 400)

	local bases = Instance.new("Folder")
	bases.Name = "Bases"
	bases.Parent = world
	for i = 1, BaseLayout.COUNT do
		buildGarden(bases, i)
	end
	buildSky(world)
	world.Parent = workspace
	return world
end

return WorldBuilder
