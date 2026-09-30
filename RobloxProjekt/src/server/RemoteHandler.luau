-- Gemeinsamer Ablauf für Client-Anfragen: Rate-Limit → Handler → bei Erfolg Snapshot,
-- sonst verständliche Meldung. Handler geben (ok: boolean, reason: string?) zurück.
local RateLimiter = require(script.Parent.RateLimiter)
local DataService = require(script.Parent.Services.DataService)
local StateService = require(script.Parent.Services.StateService)

local RemoteHandler = {}

function RemoteHandler.connect(remote: RemoteEvent, handler, reasons: { [string]: string }?, perSecond: number?)
	local limiter = RateLimiter.new(perSecond or 5)
	remote.OnServerEvent:Connect(function(player, ...)
		if not limiter:allow(player) then
			return
		end
		local ok, reason = handler(player, ...)
		if ok then
			StateService.push(player)
		elseif reasons and typeof(reason) == "string" and reasons[reason] then
			StateService.notify(player, reasons[reason])
		end
	end)
	DataService.onRemoving(function(player)
		limiter:forget(player)
	end)
end

return RemoteHandler
