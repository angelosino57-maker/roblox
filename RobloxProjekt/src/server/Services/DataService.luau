local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileStore = require(ServerScriptService.Vendor.ProfileStore)
local Template = require(script.Parent.Parent.ProfileTemplate)
local Migrate = require(game:GetService("ReplicatedStorage").Shared.Migrate)

local DataService = {}

local store
local profiles = {}
local loadedCallbacks = {}
local removingCallbacks = {}

local function runCallbacks(list, player, data)
	for _, callback in list do
		local ok, err = pcall(callback, player, data)
		if not ok then
			warn("[DataService] Callback-Fehler: " .. tostring(err))
		end
	end
end

function DataService.onLoaded(callback)
	table.insert(loadedCallbacks, callback)
end

function DataService.onRemoving(callback)
	table.insert(removingCallbacks, callback)
end

function DataService.get(player: Player)
	local profile = profiles[player]
	return profile and profile.Data
end

-- Münzen gutschreiben (zählt auch für den Himmelsbaum) und dem Client sofort melden.
function DataService.addCoins(player: Player, amount: number)
	local data = DataService.get(player)
	if data == nil or amount <= 0 then
		return
	end
	data.coins += amount
	data.totalEarned += amount
	local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
	local coins = remotes and remotes:FindFirstChild("Coins")
	if coins then
		coins:FireClient(player, math.floor(data.coins))
	end
end

function DataService.save(player: Player)
	local profile = profiles[player]
	if profile then
		profile:Save()
	end
end

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync("Player_" .. player.UserId, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if profile == nil then
		player:Kick("Dein Spielstand konnte nicht geladen werden. Bitte versuche es gleich nochmal.")
		return
	end

	profile:AddUserId(player.UserId)
	-- Reconcile füllt fehlende Felder mit Template-Werten (inkl. version = 2), deshalb vorher migrieren.
	Migrate.run(profile.Data)
	profile:Reconcile()
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Dein Spielstand wurde in einem anderen Server geöffnet.")
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	if profile.Data.seed == 0 then
		profile.Data.seed = Random.new():NextInteger(1, 2 ^ 31 - 1)
	end
	profiles[player] = profile
	runCallbacks(loadedCallbacks, player, profile.Data)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile == nil then
		return
	end
	runCallbacks(removingCallbacks, player, profile.Data)
	profile.Data.lastOnline = os.time()
	profile:EndSession()
end

function DataService.start()
	ProfileStore.SetConstant("AUTO_SAVE_PERIOD", 60)
	store = ProfileStore.New("PlayerData_v1", Template)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return DataService
