local Shared = game:GetService("ReplicatedStorage").Shared
local Expect = require(script.Parent.Expect)
local Tutorial = require(Shared.Tutorial)

local function data()
	return { equipped = {}, stats = { drops = 0, kept = 0, skipped = 0, upgrades = 0 } }
end

return {
	{ "starts at step 1", function()
		local step = Tutorial.current(data())
		Expect.eq(step.index, 1)
		Expect.eq(step.total, #Tutorial.STEPS)
	end },
	{ "advances with progress", function()
		local d = data()
		d.stats.drops = 1
		Expect.eq(Tutorial.current(d).index, 2)
		d.stats.kept = 1
		Expect.eq(Tutorial.current(d).index, 3)
		d.equipped = { "a" }
		Expect.eq(Tutorial.current(d).index, 4)
		d.stats.upgrades = 1
		Expect.eq(Tutorial.current(d).index, 5)
		d.equipped = { "a", "b", "c" }
		Expect.eq(Tutorial.current(d), nil)
	end },
}
