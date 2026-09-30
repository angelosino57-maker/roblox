local TestRunner = {}

function TestRunner.run(filter: string?): string
	local passed, failed = 0, 0
	local lines = {}
	local specs = {}
	for _, inst in script.Parent:GetDescendants() do
		if inst:IsA("ModuleScript") and inst.Name:match("%.spec$") then
			if filter == nil or inst.Name:find(filter, 1, true) then
				table.insert(specs, inst)
			end
		end
	end
	table.sort(specs, function(a, b)
		return a.Name < b.Name
	end)

	for _, spec in specs do
		local ok, cases = pcall(require, spec)
		if not ok then
			failed += 1
			table.insert(lines, "LOAD FAIL " .. spec.Name .. ": " .. tostring(cases))
			continue
		end
		for _, case in cases do
			local okCase, err = pcall(case[2])
			if okCase then
				passed += 1
			else
				failed += 1
				table.insert(lines, "FAIL " .. spec.Name .. " > " .. case[1] .. ": " .. tostring(err))
			end
		end
	end

	table.insert(lines, 1, string.format("%d passed, %d failed", passed, failed))
	return table.concat(lines, "\n")
end

return TestRunner
