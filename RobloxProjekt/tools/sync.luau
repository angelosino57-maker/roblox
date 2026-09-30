-- Wird per MCP execute_luau (Edit) ausgeführt: holt alle Skripte vom lokalen
-- Server (tools/manifest.py + python3 -m http.server 34999) und legt sie in Studio an.
-- Skripte unter den verwalteten Wurzeln, die nicht mehr im Manifest stehen, werden gelöscht.
-- HTTP wird nur für die Dauer des Syncs eingeschaltet; das Spiel selbst bleibt ohne HTTP.
local HttpService = game:GetService("HttpService")
local BASE = "http://127.0.0.1:34999/"

local httpWas = HttpService.HttpEnabled
HttpService.HttpEnabled = true
local okManifest, manifestOrErr = pcall(function()
	return HttpService:JSONDecode(HttpService:GetAsync(BASE .. "manifest.json"))
end)
if not okManifest then
	HttpService.HttpEnabled = httpWas
	error("Manifest nicht erreichbar: " .. tostring(manifestOrErr))
end
local manifest = manifestOrErr

local function resolve(path: string): Instance
	local node: Instance = game
	for _, name in string.split(path, ".") do
		local child = node:FindFirstChild(name)
		if child == nil then
			if node == game then
				child = game:GetService(name)
			else
				child = Instance.new("Folder")
				child.Name = name
				child.Parent = node
			end
		end
		node = child
	end
	return node
end

local sources = {}
local okFetch, fetchErr = pcall(function()
	for _, s in manifest.scripts do
		sources[s.file] = HttpService:GetAsync(BASE .. s.file:gsub(" ", "%%20"))
	end
end)
HttpService.HttpEnabled = httpWas
if not okFetch then
	error("Datei nicht ladbar: " .. tostring(fetchErr))
end

local wanted = {}
local changed = 0
for _, s in manifest.scripts do
	local source = sources[s.file]
	local parent = resolve(s.parent)
	local script = parent:FindFirstChild(s.name)
	if script and script.ClassName ~= s.className then
		script:Destroy()
		script = nil
	end
	if script == nil then
		script = Instance.new(s.className)
		script.Name = s.name
		script.Parent = parent
	end
	if script.Source ~= source then
		script.Source = source
		changed += 1
	end
	wanted[script] = true
end

local removed = 0
for _, rootPath in manifest.roots do
	local root = resolve(rootPath)
	for _, inst in root:GetDescendants() do
		if inst:IsA("LuaSourceContainer") and not wanted[inst] then
			inst:Destroy()
			removed += 1
		end
	end
end

return string.format("%d Skripte, %d geändert, %d entfernt", #manifest.scripts, changed, removed)
