-- 👑 König der Wolken: Wer auf dem Server am meisten pro Sekunde verdient, trägt die Krone (×1,5 Glück).
-- Jeder sieht seinen Platz und wen er als Nächstes schlagen muss; Überholen wird sofort gemeldet.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Cloud = require(Shared.Cloud)
local Format = require(Shared.Format)
local CloudConfig = require(Shared.Config.Cloud)
local DataService = require(script.Parent.DataService)
local StateService = require(script.Parent.StateService)
local CloudService = require(script.Parent.CloudService)

local KingService = {}

local UPDATE_EVERY = 2
local king -- Player
local lastRank = {} -- [player] = Platz

local function crownOn(player: Player)
	local head = player.Character and player.Character:FindFirstChild("Head")
	if head == nil or head:FindFirstChild("KingCrown") then
		return
	end
	local crown = Instance.new("Part")
	crown.Name = "KingCrown"
	crown.Size = Vector3.new(1.8, 1, 1.8)
	crown.Color = Color3.fromRGB(255, 205, 50)
	crown.Material = Enum.Material.Neon
	crown.CanCollide = false
	crown.Massless = true
	crown.CFrame = head.CFrame * CFrame.new(0, 1.3, 0)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = "rbxassetid://1078075"
	mesh.Scale = Vector3.new(1.4, 1.4, 1.4)
	mesh.Parent = crown
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = crown
	weld.Parent = crown
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = crown.Color
	sparkles.Parent = crown
	crown.Parent = head
end

local function crownOff(player: Player)
	local head = player.Character and player.Character:FindFirstChild("Head")
	local crown = head and head:FindFirstChild("KingCrown")
	if crown then
		crown:Destroy()
	end
end

-- Rangliste nach Einkommen pro Sekunde (höchstes zuerst).
function KingService.ranking(): { { player: Player, income: number } }
	local list = {}
	for _, p in Players:GetPlayers() do
		local data = DataService.get(p)
		if data then
			table.insert(list, { player = p, income = Cloud.totalIncome(data) })
		end
	end
	table.sort(list, function(a, b)
		return a.income > b.income
	end)
	return list
end

local function update()
	local ranking = KingService.ranking()
	local top = ranking[1]
	local newKing = if top and top.income > 0 then top.player else nil
	if newKing ~= king then
		if king and king.Parent then
			crownOff(king)
			CloudService.setKingBonus(king, nil)
			king:SetAttribute("King", false)
			StateService.notify(king, "😱 Du hast die KRONE verloren! Hol sie dir zurück!")
		end
		king = newKing
		if king then
			crownOn(king)
			CloudService.setKingBonus(king, CloudConfig.KING_LUCK)
			king:SetAttribute("King", true)
			for _, p in Players:GetPlayers() do
				StateService.notify(p, "👑 " .. king.DisplayName .. " ist jetzt KÖNIG DER WOLKEN (" .. Format.short(top.income) .. "/s)!")
			end
		end
	elseif king then
		crownOn(king) -- nach Respawn wieder aufsetzen
	end
	for rank, entry in ranking do
		local p = entry.player
		local ahead = ranking[rank - 1]
		p:SetAttribute("Rank", rank)
		p:SetAttribute("RankTotal", #ranking)
		p:SetAttribute("AheadName", if ahead then ahead.player.DisplayName else nil)
		p:SetAttribute("AheadIncome", if ahead then ahead.income else nil)
		local before = lastRank[p]
		if before and rank > before and ahead then
			StateService.notify(p, "⚠️ " .. ahead.player.DisplayName .. " hat dich überholt! (" .. Format.short(ahead.income) .. "/s) – jetzt Platz " .. rank)
		end
		lastRank[p] = rank
		local stats = p:FindFirstChild("leaderstats")
		if stats then
			stats["💰 pro Sek."].Value = Format.short(entry.income)
			stats["🏆 Platz"].Value = rank
		end
	end
end

function KingService.start()
	DataService.onLoaded(function(player)
		local stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		local income = Instance.new("StringValue")
		income.Name = "💰 pro Sek."
		income.Parent = stats
		local rank = Instance.new("IntValue")
		rank.Name = "🏆 Platz"
		rank.Parent = stats
		stats.Parent = player
	end)
	DataService.onRemoving(function(player)
		lastRank[player] = nil
		if king == player then
			king = nil
		end
	end)
	task.spawn(function()
		while true do
			task.wait(UPDATE_EVERY)
			update()
		end
	end)
end

return KingService
