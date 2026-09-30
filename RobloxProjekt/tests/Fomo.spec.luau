local Shared = game:GetService("ReplicatedStorage").Shared
local Expect = require(script.Parent.Expect)
local Fomo = require(Shared.Fomo)

return {
	{ "event cycle: calm, warning, active", function()
		Expect.eq(Fomo.eventAt(1000, 1000, 1).phase, "calm")
		Expect.eq(Fomo.eventAt(1000 + Fomo.CALM + 1, 1000, 1).phase, "warning")
		local active = Fomo.eventAt(1000 + Fomo.CALM + Fomo.WARNING + 1, 1000, 1)
		Expect.eq(active.phase, "active")
		Expect.eq(active.phaseEndsAt, 1000 + Fomo.CYCLE)
		Expect.eq(Fomo.eventAt(1000 + Fomo.CYCLE, 1000, 1).phase, "calm")
	end },
	{ "same event within a cycle, deterministic per seed", function()
		local a = Fomo.eventAt(1010, 1000, 5).event.id
		Expect.eq(Fomo.eventAt(1000 + Fomo.CYCLE - 1, 1000, 5).event.id, a)
		Expect.eq(Fomo.eventAt(1010, 1000, 5).event.id, a)
	end },
}
