-- Gärten: Zuteilung an Spieler, Schild am Eingang, Positionsabfragen.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseLayout = require(ReplicatedStorage.Shared.BaseLayout)
local DataService = require(script.Parent.DataService)
local WorldBuilder = require(script.Parent.Parent.WorldBuilder)

local PlotService = {}

local plots = {}
local byPlayer = {}

local function hrpOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function teleportHome(player: Player)
	local plot = byPlayer[player]
	local character = player.Character
	if plot and character then
		character:PivotTo(CFrame.lookAt(BaseLayout.spawnPoint(plot.index), BaseLayout.cloud(plot.index).Position))
	end
end

local function assign(player: Player)
	for _, plot in plots do
		if plot.owner == nil then
			plot.owner = player
			plot.sign.Text = "☁️ " .. player.DisplayName
			byPlayer[player] = plot
			player:SetAttribute("Base", plot.index)
			player.CharacterAdded:Connect(function()
				task.defer(teleportHome, player)
			end)
			teleportHome(player)
			return
		end
	end
	player:Kick("Server voll – bitte einem anderen Server beitreten.")
end

local function release(player: Player)
	local plot = byPlayer[player]
	if plot then
		plot.owner = nil
		plot.sign.Text = "Frei"
		byPlayer[player] = nil
	end
end

function PlotService.getPlot(player: Player)
	return byPlayer[player]
end

function PlotService.plots()
	return plots
end

PlotService.hrpOf = hrpOf
PlotService.teleportHome = teleportHome

function PlotService.start()
	local world = WorldBuilder.ensure()
	for index = 1, BaseLayout.COUNT do
		local folder = world.Bases:WaitForChild("Base" .. index)
		plots[index] = { index = index, folder = folder, owner = nil, sign = folder.Sign.BillboardGui.TextLabel }
	end
	DataService.onLoaded(assign)
	DataService.onRemoving(release)
end

return PlotService
