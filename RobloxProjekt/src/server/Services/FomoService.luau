-- Welt-Events (Glücksregen, Regenbogen-Sturm, Wolkenbruch, Geldregen) mit Ansagen an alle.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Fomo = require(Shared.Fomo)
local StateService = require(script.Parent.StateService)

local FomoService = {}

local t0 = os.time()
local seed = Random.new():NextInteger(1, 1000000)

function FomoService.announce(text: string)
	for _, player in Players:GetPlayers() do
		StateService.notify(player, text)
	end
end

function FomoService.t0(): number
	return t0
end

function FomoService.activeEvent()
	local state = Fomo.eventAt(os.time(), t0, seed)
	return if state.phase == "active" then state.event else nil
end

local function field(name: string): number
	local e = FomoService.activeEvent()
	return e and e[name] or 1
end

-- Aktuelle Event-Faktoren (1 = kein Event).
function FomoService.luck(): number
	return field("luck")
end

function FomoService.formBoost(): number
	return field("formBoost")
end

function FomoService.speed(): number
	return field("speed")
end

function FomoService.money(): number
	return field("money")
end

function FomoService.start()
	ReplicatedStorage:SetAttribute("FomoT0", t0)
	ReplicatedStorage:SetAttribute("FomoSeed", seed)
	task.spawn(function()
		local lastKey
		while true do
			local state = Fomo.eventAt(os.time(), t0, seed)
			local key = state.phase .. state.phaseEndsAt
			if key ~= lastKey then
				lastKey = key
				local e = state.event
				if state.phase == "warning" then
					FomoService.announce("⚡ In 20 Sekunden: " .. e.name .. " – " .. e.text)
				elseif state.phase == "active" then
					FomoService.announce("⚡ " .. e.name .. " IST LOS! " .. e.text .. " (2 Min)")
				end
			end
			task.wait(1)
		end
	end)
end

return FomoService
