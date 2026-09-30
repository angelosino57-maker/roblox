-- Reihenfolge ist wichtig: onLoaded-Callbacks laufen in Registrierungsreihenfolge.
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Services = script.Parent.Services

local ORDER = {
	"DataService",
	"PlotService",
	"StateService",
	"FomoService",
	"CreatureService",
	"CloudService",
	"KingService",
}

for _, name in ORDER do
	require(Services[name]).start()
end

-- Nur in Studio: Tests per MCP laufen in einem eigenen Modul-Kontext und sehen die
-- laufenden Services sonst nicht. Die Brücke ruft Service-Funktionen im Spiel-Kontext auf.
if RunService:IsStudio() then
	local bridge = Instance.new("BindableFunction")
	bridge.Name = "DevBridge"
	bridge.OnInvoke = function(serviceName: string, methodName, ...)
		-- ("$set", player, {"coins"}, 1e6): Testdaten im Live-Profil setzen.
		if serviceName == "$set" then
			local path, value = ...
			local node = require(Services.DataService).get(methodName)
			for i = 1, #path - 1 do
				node = node[path[i]]
			end
			node[path[#path]] = value
			return true
		end
		return require(Services[serviceName])[methodName](...)
	end
	bridge.Parent = ServerStorage
end

print("[Brainrot-Wolke] Server gestartet")
