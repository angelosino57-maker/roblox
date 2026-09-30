local ServerScriptService = game:GetService("ServerScriptService")
local Expect = require(script.Parent.Expect)
local RateLimiter = require(ServerScriptService.Server.RateLimiter)

local function fakeClock()
	local t = 0
	return function()
		return t
	end, function(dt)
		t += dt
	end
end

return {
	{ "allows a burst up to max", function()
		local clock = fakeClock()
		local limiter = RateLimiter.new(3, clock)
		Expect.eq(limiter:allow("p"), true)
		Expect.eq(limiter:allow("p"), true)
		Expect.eq(limiter:allow("p"), true)
		Expect.eq(limiter:allow("p"), false)
	end },
	{ "refills over time", function()
		local clock, advance = fakeClock()
		local limiter = RateLimiter.new(2, clock)
		limiter:allow("p")
		limiter:allow("p")
		Expect.eq(limiter:allow("p"), false)
		advance(0.5) -- +1 token
		Expect.eq(limiter:allow("p"), true)
		Expect.eq(limiter:allow("p"), false)
	end },
	{ "keys are independent and forget resets", function()
		local clock = fakeClock()
		local limiter = RateLimiter.new(1, clock)
		Expect.eq(limiter:allow("a"), true)
		Expect.eq(limiter:allow("b"), true)
		Expect.eq(limiter:allow("a"), false)
		limiter:forget("a")
		Expect.eq(limiter:allow("a"), true)
	end },
}
