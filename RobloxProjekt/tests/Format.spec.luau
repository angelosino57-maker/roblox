local Shared = game:GetService("ReplicatedStorage").Shared
local Expect = require(script.Parent.Expect)
local Format = require(Shared.Format)

return {
	{ "short number format", function()
		Expect.eq(Format.short(0), "0")
		Expect.eq(Format.short(999.7), "999")
		Expect.eq(Format.short(1000), "1K")
		Expect.eq(Format.short(1234), "1.23K")
		Expect.eq(Format.short(56700), "56.7K")
		Expect.eq(Format.short(123456789), "123M")
		Expect.eq(Format.short(2.5e9), "2.5B")
		Expect.eq(Format.short(210000), "210K")
		Expect.eq(Format.short(100000), "100K")
		Expect.eq(Format.short(20000), "20K")
	end },
}
