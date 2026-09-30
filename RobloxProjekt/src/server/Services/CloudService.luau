-- Die Brainrot-Wolke: Wer vor seiner Wolke kniet (auf dem Kissen sitzt), bekommt Drops.
-- Erst baut die Wolke Spannung auf (seltener = länger), dann fällt der Brainrot sichtbar herunter und der
-- Spieler entscheidet mit Countdown BEHALTEN oder SKIPPEN (Geld). Wer zu lange wartet, sieht ihn davonfliegen.
-- Platz ist knapp (3 Podeste + 5 Rucksack): wer voll ist, muss einen ersetzen.
-- Die Auto-Farm verkauft nur Gewöhnliches selbst – gute Drops warten auf den Spieler.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Cloud = require(Shared.Cloud)
local CreatureModel = require(Shared.CreatureModel)
local Format = require(Shared.Format)
local BaseLayout = require(Shared.BaseLayout)
local Species = require(Shared.Config.Species)
local Rarity = require(Shared.Config.Rarity)
local CloudConfig = require(Shared.Config.Cloud)
local Remotes = require(Shared.Remotes)
local RemoteHandler = require(ServerScriptService.Server.RemoteHandler)
local DataService = require(script.Parent.DataService)
local StateService = require(script.Parent.StateService)
local PlotService = require(script.Parent.PlotService)
local CreatureService = require(script.Parent.CreatureService)
local FomoService = require(script.Parent.FomoService)

local CloudService = {}

local rng = Random.new()
local pending = {} -- [player] = {creature, model?, revealAt, expiresAt} (model erst nach der Enthüllung)
local nextDropAt = {} -- [player] = os.clock()
local kingBonus = {} -- [player] = Glücks-Faktor (König)

local REVEAL_TOLERANCE = 0.25 -- Uhren von Client und Server laufen nie ganz gleich

local REASONS = {
	coins = "Nicht genug Geld.",
	max = "Schon auf der höchsten Stufe!",
	full = "Kein Platz mehr – wähl einen Brainrot zum Ersetzen!",
}

local function announce(text: string)
	for _, p in Players:GetPlayers() do
		StateService.notify(p, text)
	end
end

function CloudService.setKingBonus(player: Player, bonus: number?)
	kingBonus[player] = bonus
end

local function isKneeling(player: Player, plot): boolean
	local seat = plot.folder:FindFirstChild("KneelSeat")
	local occupant = seat and seat.Occupant
	return occupant ~= nil and occupant.Parent == player.Character
end

local function isSpecial(creature): boolean
	return Rarity.index(creature.rarity) >= Rarity.index("Legendär") or creature.mutation == "diamond" or creature.mutation == "rainbow"
end

---------------------------------------------------------------- Drop

-- Brainrot fällt aus der Wolke auf den Landeplatz.
local function dropVisual(plot, creature): Model
	local model = CreatureModel.build(creature, 1.2)
	local from = BaseLayout.cloud(plot.index).Position - Vector3.new(0, 4, 0)
	local to = BaseLayout.drop(plot.index) -- Blick zum Kissen (Richtung Eingang)
	model:PivotTo(CFrame.new(from) * to.Rotation)
	model.Parent = plot.folder
	local value = Instance.new("CFrameValue")
	value.Value = model:GetPivot()
	value.Changed:Connect(function(cf)
		if model.Parent then
			model:PivotTo(cf)
		end
	end)
	local tween = TweenService:Create(value, TweenInfo.new(0.7, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), { Value = to })
	tween.Completed:Connect(function()
		value:Destroy()
	end)
	tween:Play()
	return model
end

-- Countdown abgelaufen: Der Brainrot dreht sich, schrumpft und fliegt zurück in den Himmel.
local function flyAway(model: Model)
	local start = model:GetPivot()
	local scale = model:GetScale()
	local alpha = Instance.new("NumberValue")
	alpha.Changed:Connect(function(a)
		if model.Parent then
			model:ScaleTo(scale * (1 - 0.8 * a))
			model:PivotTo(start * CFrame.new(0, a * 45, 0) * CFrame.Angles(0, a * math.pi * 6, 0))
		end
	end)
	TweenService:Create(alpha, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = 1 }):Play()
	task.delay(1.7, function()
		alpha:Destroy()
		model:Destroy()
	end)
end

local function newCreature(rolled)
	return { id = HttpService:GenerateGUID(false), species = rolled.species, rarity = rolled.rarity, mutation = rolled.mutation }
end

local function count(data): number
	local n = 0
	for _ in data.creatures do
		n += 1
	end
	return n
end

-- Behalten: freier Platz, sonst muss `replaceId` ersetzt werden (der alte wird zu Geld).
local function keep(player: Player, data, creature, replaceId): (boolean, string?)
	if count(data) >= Cloud.capacity() then
		local old = typeof(replaceId) == "string" and data.creatures[replaceId]
		if not old then
			return false, "full"
		end
		local index = table.find(data.equipped, replaceId)
		data.creatures[replaceId] = nil
		DataService.addCoins(player, Cloud.skipValue(old))
		if index then
			data.equipped[index] = creature.id -- tritt direkt an die Stelle des alten
		end
		data.creatures[creature.id] = creature
		data.stats.kept += 1
		CreatureService.refresh(player)
		return true
	end
	data.creatures[creature.id] = creature
	data.stats.kept += 1
	return true
end

local function skip(player: Player, data, creature, position: Vector3)
	local amount = Cloud.skipValue(creature) * FomoService.money()
	DataService.addCoins(player, amount)
	data.stats.skipped += 1
	Remotes.CoinBurst:FireClient(player, amount, position, "bag")
end

-- Nach der Spannung: Der Brainrot fällt aus der Wolke, besondere werden serverweit angesagt. Nur einmal pro Drop.
local function land(player: Player, p)
	if p.model or p.plot.folder.Parent == nil then
		return
	end
	local creature = p.creature
	p.model = dropVisual(p.plot, creature)
	if isSpecial(creature) then
		announce("☁️ " .. player.DisplayName .. " hat " .. Species.displayName(creature) .. " (" .. creature.rarity .. ") aus der Wolke gezogen!")
	end
	if p.auto then
		StateService.notify(player, "⏳ Ein " .. creature.rarity .. "-Drop wartet an deiner Wolke – " .. p.seconds .. " Sekunden!")
	end
end

local function finish(player: Player, action: string, replaceId): (boolean, string?)
	local p = pending[player]
	local data = DataService.get(player)
	if p == nil or data == nil then
		return false, "invalid args"
	end
	if p.model == nil and action ~= "lost" then
		return false, "reveal" -- noch nicht gelandet
	end
	if action == "keep" then
		local ok, reason = keep(player, data, p.creature, replaceId)
		if not ok then
			return false, reason -- Karte bleibt offen, Spieler wählt einen zum Ersetzen
		end
		StateService.notify(player, "✅ " .. Species.displayName(p.creature) .. " behalten!")
	elseif action == "skip" then
		skip(player, data, p.creature, p.model.PrimaryPart.Position)
	else -- "lost": Countdown abgelaufen – zeigen, was man verpasst hat
		StateService.notify(player, "💨 " .. Species.displayName(p.creature) .. " ist davongeflogen … das wären +" .. Format.short(Cloud.income(p.creature)) .. "/s gewesen!")
	end
	pending[player] = nil
	if p.model and action == "lost" then
		flyAway(p.model)
	elseif p.model then
		p.model:Destroy()
	end
	Remotes.DropOffer:FireClient(player, nil)
	nextDropAt[player] = Cloud.nextDropAfterChoice(nextDropAt[player], os.clock())
	StateService.push(player)
	return true
end

function CloudService.choose(player: Player, action, replaceId): (boolean, string?)
	if action ~= "keep" and action ~= "skip" then
		return false, "invalid args"
	end
	local p = pending[player]
	if p and os.clock() < p.revealAt - REVEAL_TOLERANCE then
		return false, "reveal" -- Die Wolke baut noch Spannung auf
	end
	if p then
		land(player, p) -- Client war ein paar Millisekunden schneller als der Server-Takt
	end
	return finish(player, action, replaceId)
end

function CloudService.drop(player: Player, auto: boolean)
	local data = DataService.get(player)
	local plot = PlotService.getPlot(player)
	if data == nil or plot == nil then
		return
	end
	local luck = Cloud.luck(data, (kingBonus[player] or 1) * FomoService.luck())
	local creature = newCreature(Cloud.roll(rng, luck, FomoService.formBoost()))
	data.stats.drops += 1
	if auto and Cloud.autoSells(creature) then
		-- Auto-Farm: Gewöhnliches wird sofort zu Geld
		local model = dropVisual(plot, creature)
		task.delay(0.9, function()
			if model.Parent then
				local position = model.PrimaryPart.Position
				model:Destroy()
				skip(player, data, creature, position)
			end
		end)
		return
	end
	-- Guter Drop (oder Knien): Erst Spannung (Karte zeigt „???“), dann fällt er und der Countdown läuft.
	local reveal = Cloud.revealSeconds(creature)
	local seconds = if auto then CloudConfig.AUTO_DECIDE_SECONDS else CloudConfig.DECIDE_SECONDS
	local now = os.clock()
	local p = { creature = creature, plot = plot, auto = auto, seconds = seconds, revealAt = now + reveal, expiresAt = now + reveal + seconds }
	pending[player] = p
	local serverNow = workspace:GetServerTimeNow()
	Remotes.DropOffer:FireClient(player, creature, Cloud.skipValue(creature) * FomoService.money(), serverNow + reveal + seconds, serverNow + reveal)
	task.delay(reveal, function()
		if pending[player] == p then
			land(player, p)
		end
	end)
end

---------------------------------------------------------------- Upgrades

local function resizeCloud(player: Player, data)
	local plot = PlotService.getPlot(player)
	local model = plot and plot.folder:FindFirstChild("Cloud")
	if model then
		local levels = data.cloud.luck + data.cloud.speed + data.cloud.auto * 2
		model:ScaleTo(1 + levels * 0.04)
	end
end

function CloudService.upgrade(player: Player, kind): (boolean, string?)
	local data = DataService.get(player)
	if data == nil or typeof(kind) ~= "string" or CloudConfig.upgrades[kind] == nil then
		return false, "invalid args"
	end
	local price = Cloud.upgradePrice(kind, data.cloud[kind])
	if price == nil then
		return false, "max"
	end
	if data.coins < price then
		return false, "coins"
	end
	data.coins -= price
	data.cloud[kind] += 1
	data.stats.upgrades += 1
	resizeCloud(player, data)
	Remotes.CloudFx:FireClient(player, kind, data.cloud[kind])
	StateService.notify(player, CloudConfig.upgrades[kind].name .. " Stufe " .. data.cloud[kind] .. "!")
	return true
end

---------------------------------------------------------------- Takt

local function tick()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		local plot = PlotService.getPlot(player)
		local p = pending[player]
		if data and plot then
			if p then
				if now > p.expiresAt then
					finish(player, "lost") -- zu lange gewartet: weg!
				end
			else
				local kneeling = isKneeling(player, plot)
				local interval = if kneeling
					then Cloud.interval(data.cloud.speed, FomoService.speed())
					else Cloud.autoInterval(data.cloud.speed, data.cloud.auto, FomoService.speed())
				player:SetAttribute("Kneeling", kneeling)
				if interval then
					local due = nextDropAt[player]
					if due == nil then
						nextDropAt[player] = now + interval
					elseif now >= due then
						nextDropAt[player] = now + interval
						CloudService.drop(player, not kneeling)
					end
					player:SetAttribute("NextDrop", workspace:GetServerTimeNow() + math.max(0, nextDropAt[player] - now))
				else
					nextDropAt[player] = nil
					player:SetAttribute("NextDrop", nil)
				end
			end
		end
	end
end

function CloudService.start()
	RemoteHandler.connect(Remotes.DropChoice, CloudService.choose, REASONS, 6)
	RemoteHandler.connect(Remotes.Upgrade, CloudService.upgrade, REASONS, 6)
	DataService.onLoaded(function(player, data)
		task.defer(resizeCloud, player, data)
	end)
	DataService.onRemoving(function(player)
		local p = pending[player]
		if p and p.model then
			p.model:Destroy()
		end
		pending[player] = nil
		nextDropAt[player] = nil
		kingBonus[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.2)
			tick()
		end
	end)
end

return CloudService
