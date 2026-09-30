local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ClientState = {}

local changed = Instance.new("BindableEvent")
ClientState.current = nil
ClientState.changed = changed.Event

function ClientState.start()
	Remotes.State.OnClientEvent:Connect(function(snapshot)
		ClientState.current = snapshot
		changed:Fire(snapshot)
	end)
	Remotes.State:FireServer()
end

return ClientState
