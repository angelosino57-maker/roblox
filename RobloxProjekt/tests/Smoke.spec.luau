local Expect = require(script.Parent.Expect)

return {
	{ "runner works", function()
		Expect.eq(1 + 1, 2)
	end },
	{ "errors are caught", function()
		Expect.errors(function()
			error("boom")
		end)
	end },
}
