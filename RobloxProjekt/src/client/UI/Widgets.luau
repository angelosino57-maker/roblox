-- Gemeinsame UI-Bausteine für die Panels (schlicht; Design kommt später).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Widgets = {}

Widgets.ACTIVE = Color3.fromRGB(90, 170, 90)
Widgets.IDLE = Color3.fromRGB(70, 70, 90)

local openPanels = {} -- alle Panels; es ist immer nur eines offen
Widgets.onVisibilityChanged = nil -- function(anyOpen: boolean), z. B. HUD kompakt schalten

Widgets.BAR_WIDTH = 100
Widgets.BAR_GAP = 8

-- Button in der unteren Leiste an Position `slot` (1 = ganz links); Text mit Tastenhinweis.
function Widgets.barButton(parent, slot: number, text: string, key: Enum.KeyCode?, color: Color3, onClick)
	local b = Instance.new("TextButton")
	b.Name = "Toggle"
	b.Text = if key then text .. " (" .. key.Name .. ")" else text
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = color
	b.Size = UDim2.fromOffset(Widgets.BAR_WIDTH, 44)
	b.Position = UDim2.new(0, 12 + (slot - 1) * (Widgets.BAR_WIDTH + Widgets.BAR_GAP), 1, -60)
	b.Parent = parent
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = b
	b.Activated:Connect(onClick)
	if key then
		UserInputService.InputBegan:Connect(function(input, processed)
			if not processed and input.KeyCode == key then
				onClick()
			end
		end)
	end
	return b
end

local function notifyVisibility()
	if Widgets.onVisibilityChanged then
		local anyOpen = false
		for _, p in openPanels do
			if p.isVisible() then
				anyOpen = true
			end
		end
		Widgets.onVisibilityChanged(anyOpen)
	end
end

function Widgets.fmtTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function Widgets.button(parent, text: string, color: Color3, onClick)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.BackgroundColor3 = color
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.FredokaOne
	b.TextSize = 15
	b.Text = text
	b.Size = UDim2.fromOffset(84, 28)
	b.AutomaticSize = Enum.AutomaticSize.X
	b.Parent = parent
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = b
	b.Activated:Connect(onClick)
	return b
end

-- Zeilen-Builder für eine ScrollingFrame-Liste.
local function newLines(list: ScrollingFrame)
	local lines = {}
	local count = 0
	local timers = {}

	function lines.clear()
		for _, child in list:GetChildren() do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end
		count = 0
		timers = {}
	end

	function lines.row(text: string)
		local frame = Instance.new("Frame")
		frame.BackgroundTransparency = 0.7
		frame.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
		frame.Size = UDim2.new(1, -8, 0, 36)
		count += 1
		frame.LayoutOrder = count
		frame.Parent = list
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextSize = 15
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.Size = UDim2.new(1, -280, 1, 0)
		label.Position = UDim2.fromOffset(8, 0)
		label.Text = text
		label.Parent = frame
		local buttons = Instance.new("Frame")
		buttons.BackgroundTransparency = 1
		buttons.Size = UDim2.new(0, 270, 1, 0)
		buttons.Position = UDim2.new(1, -274, 0, 0)
		buttons.Parent = frame
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Padding = UDim.new(0, 4)
		layout.Parent = buttons
		return label, buttons
	end

	-- Zeile ohne Buttons: volle Breite, mit Umbruch (z. B. Wahrscheinlichkeiten).
	function lines.infoRow(text: string)
		local label = lines.row(text)
		label.Size = UDim2.new(1, -16, 1, 0)
		label.TextWrapped = true
		label.Parent.Size = UDim2.new(1, -8, 0, 52)
		return label
	end

	function lines.timerRow(prefix: string, readyAt: number)
		local label, buttons = lines.row(prefix)
		table.insert(timers, { label = label, prefix = prefix, readyAt = readyAt })
		return label, buttons
	end

	function lines.tick(now: number)
		for _, t in timers do
			t.label.Text = t.prefix .. Widgets.fmtTime(t.readyAt - now)
		end
	end

	return lines
end

-- config = { name, toggleText, toggleColor, slot, key?, tabs = {{id, label}}, render = function(lines, tabId) }
function Widgets.panel(config)
	local ui = { tab = config.tabs[1][1] }

	local gui = Instance.new("ScreenGui")
	gui.Name = config.name
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")


	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0.9, 0, 0.7, 0)
	panel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	panel.BackgroundTransparency = 0.1
	panel.Visible = false
	panel.Parent = gui
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(760, 460)
	sizeLimit.Parent = panel

	local tabBar = Instance.new("Frame")
	tabBar.Name = "Tabs"
	tabBar.BackgroundTransparency = 1
	tabBar.Size = UDim2.new(1, -16, 0, 34)
	tabBar.Position = UDim2.fromOffset(8, 8)
	tabBar.Parent = panel
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 6)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabBar

	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Size = UDim2.new(1, -16, 1, -56)
	list.Position = UDim2.fromOffset(8, 48)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollBarThickness = 6
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local lines = newLines(list)
	local tabButtons = {}

	function ui.render()
		if not panel.Visible then
			return
		end
		for id, b in tabButtons do
			b.BackgroundColor3 = if id == ui.tab then Widgets.ACTIVE else Widgets.IDLE
		end
		lines.clear()
		config.render(lines, ui.tab)
	end

	function ui.setTab(id: string)
		ui.tab = id
		ui.render()
	end

	function ui.setVisible(visible: boolean)
		if visible then
			for _, other in openPanels do
				if other ~= ui then
					other.setVisible(false)
				end
			end
		end
		panel.Visible = visible
		ui.render()
		notifyVisibility()
	end

	function ui.isVisible(): boolean
		return panel.Visible
	end

	for order, t in config.tabs do
		local b = Widgets.button(tabBar, t[2], Widgets.IDLE, function()
			ui.setTab(t[1])
		end)
		b.Name = "Tab_" .. t[1]
		b.LayoutOrder = order
		tabButtons[t[1]] = b
	end

	Widgets.barButton(gui, config.slot, config.toggleText, config.key, config.toggleColor, function()
		ui.setVisible(not panel.Visible)
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.5 then
			acc = 0
			lines.tick(workspace:GetServerTimeNow())
		end
	end)

	table.insert(openPanels, ui)
	return ui
end

return Widgets
