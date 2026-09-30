local Shared = game:GetService("ReplicatedStorage").Shared
local Expect = require(script.Parent.Expect)
local BaseLayout = require(Shared.BaseLayout)

return {
	{ "every garden gate faces the middle", function()
		for i = 1, BaseLayout.COUNT do
			Expect.truthy(BaseLayout.gate(i).Position.Magnitude < BaseLayout.center(i).Magnitude, "gate closer to middle")
		end
	end },
	{ "cloud, seat, drop spot and podiums lie in their garden", function()
		for i = 1, BaseLayout.COUNT do
			Expect.eq(BaseLayout.baseAt(BaseLayout.seat(i).Position + Vector3.new(0, 1, 0)), i)
			Expect.eq(BaseLayout.baseAt(BaseLayout.drop(i).Position + Vector3.new(0, 1, 0)), i)
			Expect.eq(BaseLayout.baseAt(BaseLayout.cloud(i).Position), i)
			Expect.eq(BaseLayout.baseAt(BaseLayout.spawnPoint(i)), i)
			for k = 1, BaseLayout.PODIUMS do
				Expect.eq(BaseLayout.baseAt(BaseLayout.podium(i, k).Position + Vector3.new(0, 1, 0)), i)
			end
		end
		Expect.eq(BaseLayout.baseAt(Vector3.new(0, 3, 0)), nil)
	end },
}
