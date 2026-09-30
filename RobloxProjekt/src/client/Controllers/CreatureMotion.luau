-- Brainrots auf den Podesten wippen und schauen sich um (flüssig, jedes Bild lokal berechnet).
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local CreatureMotion = {}

local IDLE_RANGE = 140 -- weiter weg wird nicht animiert

local basePivot = setmetatable({}, { __mode = "k" }) -- [Model] = CFrame (Ruhelage auf dem Sockel)
local phase = setmetatable({}, { __mode = "k" })

local function phaseOf(model): number
	local p = phase[model]
	if p == nil then
		p = math.random() * math.pi * 2
		phase[model] = p
	end
	return p
end

local function idle(t: number)
	local camera = workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position or Vector3.zero
	for _, model in CollectionService:GetTagged("Idle") do
		local rest = basePivot[model]
		if rest == nil then
			rest = model:GetPivot()
			basePivot[model] = rest
		end
		if (rest.Position - eye).Magnitude < IDLE_RANGE then
			local p = phaseOf(model)
			local bob = (math.sin(t * 2.2 + p) + 1) * 0.25
			local sway = math.sin(t * 0.9 + p) * 0.35
			model:PivotTo(rest * CFrame.new(0, bob, 0) * CFrame.Angles(0, sway, 0))
		end
	end
end

function CreatureMotion.start()
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		idle(t)
	end)
end

return CreatureMotion
