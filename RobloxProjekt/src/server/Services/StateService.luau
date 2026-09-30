-- Schickt dem Client den kompletten Spielstand (nach jeder Änderung) und kurze Meldungen.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Cloud = require(Shared.Cloud)
local Remotes = require(Shared.Remotes)
local Tutorial = require(Shared.Tutorial)
local CloudConfig = require(Shared.Config.Cloud)
local RateLimiter = require(ServerScriptService.Server.RateLimiter)
local DataService = require(script.Parent.DataService)

local StateService = {}

local requestLimiter = RateLimiter.new(2)

function StateService.push(player: Player)
	local data = DataService.get(player)
	if data == nil then
		return
	end
	local upgrades = {}
	for kind in CloudConfig.upgrades do
		upgrades[kind] = { level = data.cloud[kind], price = Cloud.upgradePrice(kind, data.cloud[kind]) }
	end
	Remotes.State:FireClient(player, {
		coins = math.floor(data.coins),
		income = Cloud.totalIncome(data),
		luck = Cloud.luck(data),
		interval = Cloud.interval(data.cloud.speed),
		autoInterval = Cloud.autoInterval(data.cloud.speed, data.cloud.auto),
		creatures = data.creatures,
		equipped = data.equipped,
		equipMax = CloudConfig.EQUIP_MAX,
		capacity = Cloud.capacity(),
		upgrades = upgrades,
		tutorial = Tutorial.current(data),
	})
end

function StateService.notify(player: Player, text: string)
	Remotes.Notify:FireClient(player, text)
end

function StateService.start()
	Remotes.State.OnServerEvent:Connect(function(player)
		if requestLimiter:allow(player) then
			StateService.push(player)
		end
	end)
	DataService.onLoaded(StateService.push)
	DataService.onRemoving(function(player)
		requestLimiter:forget(player)
	end)
end

return StateService
