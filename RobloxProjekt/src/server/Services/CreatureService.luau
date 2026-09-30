-- Ausgerüstete Brainrots (max. 3) stehen auf den Podesten im Garten und verdienen jede Sekunde Geld.
-- Dazu: ausrüsten/abnehmen (Rucksack ↔ Podest), freilassen (gegen Geld), Offline-Einkommen.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Cloud = require(Shared.Cloud)
local CreatureModel = require(Shared.CreatureModel)
local Format = require(Shared.Format)
local Species = require(Shared.Config.Species)
local CloudConfig = require(Shared.Config.Cloud)
local EconomyConfig = require(Shared.Config.Economy)
local Remotes = require(Shared.Remotes)
local RemoteHandler = require(ServerScriptService.Server.RemoteHandler)
local WorldBuilder = require(ServerScriptService.Server.WorldBuilder)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local StateService = require(script.Parent.StateService)
local FomoService = require(script.Parent.FomoService)

local CreatureService = {}

local folders = {} -- [player] = Folder mit den Podest-Modellen

local REASONS = {
	missing = "Diesen Brainrot gibt es nicht mehr.",
	full = "Nur 3 Brainrots können ausgerüstet sein – nimm erst einen ab.",
}

function CreatureService.refresh(player: Player)
	local data = DataService.get(player)
	local plot = PlotService.getPlot(player)
	local folder = folders[player]
	if data == nil or plot == nil or folder == nil then
		return
	end
	folder:ClearAllChildren()
	for k = 1, CloudConfig.EQUIP_MAX do
		local podium = plot.folder.Podiums:FindFirstChild("P" .. k)
		local id = data.equipped[k]
		local creature = id and data.creatures[id]
		if podium and creature then
			local model = CreatureModel.build(creature, 1.3)
			model:PivotTo(CFrame.new(podium.Position + Vector3.new(0, 1, 0)) * plot.folder.Floor.CFrame.Rotation) -- Blick zum Eingang
			CollectionService:AddTag(model, "Idle")
			model.Parent = folder
			local label = WorldBuilder.billboard(folder, "💰 +" .. Format.short(Cloud.income(creature)) .. "/s", UDim2.fromOffset(150, 34), Vector3.new(0, 11, 0), 120)
			label.TextColor3 = Color3.fromRGB(255, 225, 80)
			label.Parent.Adornee = podium
		elseif podium then
			local label = WorldBuilder.billboard(folder, "Leerer Platz", UDim2.fromOffset(140, 30), Vector3.new(0, 4, 0), 60)
			label.Parent.Adornee = podium
		end
	end
end

function CreatureService.equip(player: Player, id, on): (boolean, string?)
	local data = DataService.get(player)
	if data == nil or typeof(id) ~= "string" or typeof(on) ~= "boolean" or data.creatures[id] == nil then
		return false, "missing"
	end
	local index = table.find(data.equipped, id)
	if on and not index then
		if #data.equipped >= CloudConfig.EQUIP_MAX then
			return false, "full"
		end
		table.insert(data.equipped, id)
	elseif not on and index then
		table.remove(data.equipped, index)
	end
	CreatureService.refresh(player)
	return true
end

-- Freilassen: gibt so viel Geld wie Skippen.
function CreatureService.release(player: Player, id): (boolean, string?)
	local data = DataService.get(player)
	local creature = data and typeof(id) == "string" and data.creatures[id]
	if not creature then
		return false, "missing"
	end
	local index = table.find(data.equipped, id)
	if index then
		table.remove(data.equipped, index)
	end
	data.creatures[id] = nil
	DataService.addCoins(player, Cloud.skipValue(creature))
	StateService.notify(player, "👋 " .. Species.displayName(creature) .. " freigelassen: +" .. Format.short(Cloud.skipValue(creature)))
	CreatureService.refresh(player)
	return true
end

local function onLoaded(player: Player, data)
	local folder = Instance.new("Folder")
	folder.Name = tostring(player.UserId)
	folder.Parent = workspace:FindFirstChild("Creatures")
	folders[player] = folder
	-- Offline-Einkommen (halb, höchstens 8 Stunden)
	if data.lastOnline > 0 then
		local seconds = math.clamp(os.time() - data.lastOnline, 0, EconomyConfig.OFFLINE_MAX_SECONDS) * EconomyConfig.OFFLINE_RATE
		local earned = math.floor(Cloud.totalIncome(data) * seconds)
		if earned > 0 then
			DataService.addCoins(player, earned)
			StateService.notify(player, "💤 Während du weg warst, haben deine Brainrots " .. Format.short(earned) .. " verdient!")
		end
	end
	CreatureService.refresh(player)
end

function CreatureService.start()
	local root = Instance.new("Folder")
	root.Name = "Creatures"
	root.Parent = workspace
	RemoteHandler.connect(Remotes.Equip, CreatureService.equip, REASONS)
	RemoteHandler.connect(Remotes.Release, CreatureService.release, REASONS)
	DataService.onLoaded(onLoaded)
	DataService.onRemoving(function(player)
		if folders[player] then
			folders[player]:Destroy()
		end
		folders[player] = nil
	end)
	-- Jede Sekunde verdienen die ausgerüsteten Brainrots Geld.
	task.spawn(function()
		while true do
			task.wait(1)
			local money = FomoService.money()
			for _, player in Players:GetPlayers() do
				local data = DataService.get(player)
				if data then
					DataService.addCoins(player, Cloud.totalIncome(data) * money)
				end
			end
		end
	end)
end

return CreatureService
