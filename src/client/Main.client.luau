-- Интерфейс лобби: создание (по центру экрана), таймер, пропуск ожидания,
-- затемнение, субтитры и ожидание загрузки земли в лесу.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage.Shared:WaitForChild("Remotes"))

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "LobbyGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10
gui.Parent = player:WaitForChild("PlayerGui")

local BG = Color3.fromRGB(20, 24, 34)
local BG2 = Color3.fromRGB(34, 40, 56)
local GREEN = Color3.fromRGB(56, 190, 98)
local BLUE = Color3.fromRGB(70, 130, 235)
local GRAY = Color3.fromRGB(62, 70, 90)
local RED = Color3.fromRGB(220, 70, 70)
local ORANGE = Color3.fromRGB(245, 155, 50)

local function corner(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 12)
	c.Parent = inst
end

local function stroke(inst, color, transparency, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.new(1, 1, 1)
	s.Transparency = transparency or 0.85
	s.Thickness = thickness or 1.5
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
end

local function gradient(inst, c1, c2, rotation)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(c1, c2)
	g.Rotation = rotation or 90
	g.Parent = inst
end

local function makeLabel(parent, text, pos, size, textSize, color)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = pos
	l.Size = size
	l.Font = Enum.Font.GothamBold
	l.TextSize = textSize or 18
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.Text = text
	l.Parent = parent
	return l
end

local function makeButton(parent, text, pos, size, color)
	local b = Instance.new("TextButton")
	b.Position = pos
	b.Size = size
	b.BackgroundColor3 = color
	b.AutoButtonColor = true
	b.Font = Enum.Font.GothamBold
	b.TextSize = 18
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	b.Parent = parent
	corner(b, 12)
	stroke(b, Color3.new(1, 1, 1), 0.8, 1)
	gradient(b, Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190), 90)
	return b
end

local function makePanel(size, anchor, pos)
	local f = Instance.new("Frame")
	f.Size = size
	f.AnchorPoint = anchor
	f.Position = pos
	f.BackgroundColor3 = BG
	f.BackgroundTransparency = 0.05
	f.Visible = false
	f.Parent = gui
	corner(f, 20)
	stroke(f, Color3.new(1, 1, 1), 0.88, 2)
	gradient(f, BG2, BG, 90)
	return f
end

-- ===== Создание лобби: по центру экрана =====
local setup = makePanel(UDim2.fromOffset(400, 430), Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5))
makeLabel(setup, "Создание лобби", UDim2.fromOffset(0, 16), UDim2.new(1, 0, 0, 34), 26)
makeLabel(setup, "Выбери карту и сколько игроков зайдёт", UDim2.fromOffset(0, 50), UDim2.new(1, 0, 0, 20), 14, Color3.fromRGB(170, 180, 200))

makeLabel(setup, "КАРТА", UDim2.fromOffset(28, 90), UDim2.new(1, -56, 0, 20), 13, Color3.fromRGB(150, 160, 185)).TextXAlignment = Enum.TextXAlignment.Left
local selectedMap = Config.MAPS[1].id
local mapButtons = {}
local mapRow = Instance.new("Frame")
mapRow.BackgroundTransparency = 1
mapRow.Position = UDim2.fromOffset(28, 114)
mapRow.Size = UDim2.new(1, -56, 0, 50)
mapRow.Parent = setup
local mapLayout = Instance.new("UIListLayout")
mapLayout.FillDirection = Enum.FillDirection.Horizontal
mapLayout.Padding = UDim.new(0, 10)
mapLayout.Parent = mapRow

local function refreshMaps()
	for id, b in mapButtons do
		b.BackgroundColor3 = (id == selectedMap) and BLUE or GRAY
	end
end
for _, m in Config.MAPS do
	local b = makeButton(mapRow, "🌲  " .. m.name, UDim2.new(), UDim2.fromOffset(150, 50), GRAY)
	b.Activated:Connect(function()
		selectedMap = m.id
		refreshMaps()
	end)
	mapButtons[m.id] = b
end
refreshMaps()

makeLabel(setup, "КОЛИЧЕСТВО ИГРОКОВ", UDim2.fromOffset(28, 186), UDim2.new(1, -56, 0, 20), 13, Color3.fromRGB(150, 160, 185)).TextXAlignment = Enum.TextXAlignment.Left
local selectedSize = math.clamp(4, Config.MIN_PLAYERS, Config.MAX_PLAYERS)
local minus = makeButton(setup, "–", UDim2.fromOffset(80, 214), UDim2.fromOffset(56, 56), GRAY)
local plus = makeButton(setup, "+", UDim2.fromOffset(264, 214), UDim2.fromOffset(56, 56), GRAY)
minus.TextSize = 30
plus.TextSize = 30
local sizeLabel = makeLabel(setup, tostring(selectedSize), UDim2.fromOffset(140, 214), UDim2.fromOffset(120, 56), 38)
minus.Activated:Connect(function()
	selectedSize = math.max(Config.MIN_PLAYERS, selectedSize - 1)
	sizeLabel.Text = tostring(selectedSize)
end)
plus.Activated:Connect(function()
	selectedSize = math.min(Config.MAX_PLAYERS, selectedSize + 1)
	sizeLabel.Text = tostring(selectedSize)
end)

local createBtn = makeButton(setup, "Создать лобби", UDim2.fromOffset(28, 300), UDim2.new(1, -56, 0, 56), GREEN)
createBtn.TextSize = 22
local leaveSetup = makeButton(setup, "Выйти", UDim2.fromOffset(28, 368), UDim2.new(1, -56, 0, 42), RED)
createBtn.Activated:Connect(function()
	Remotes.LobbyAction:FireServer("Create", selectedMap, selectedSize)
end)
leaveSetup.Activated:Connect(function()
	Remotes.LobbyAction:FireServer("Leave")
end)

-- ===== Лобби создано: ожидание игроков =====
local lobby = makePanel(UDim2.fromOffset(380, 190), Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -30))
local info = makeLabel(lobby, "", UDim2.fromOffset(0, 14), UDim2.new(1, 0, 0, 56), 22)
info.TextWrapped = true
local startNow = makeButton(lobby, "Начать сейчас", UDim2.fromOffset(24, 80), UDim2.new(1, -48, 0, 44), ORANGE)
local leaveLobby = makeButton(lobby, "Выйти", UDim2.fromOffset(24, 132), UDim2.new(1, -48, 0, 40), RED)
startNow.Activated:Connect(function()
	Remotes.LobbyAction:FireServer("StartNow")
end)
leaveLobby.Activated:Connect(function()
	Remotes.LobbyAction:FireServer("Leave")
end)

-- ===== Таймер сверху =====
local timerFrame = makePanel(UDim2.fromOffset(320, 120), Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 24))
local timerLabel = makeLabel(timerFrame, "", UDim2.fromOffset(0, 10), UDim2.new(1, 0, 0, 50), 36)
local skipBtn = makeButton(timerFrame, "Пропустить ожидание", UDim2.fromOffset(24, 68), UDim2.new(1, -48, 0, 40), ORANGE)
skipBtn.Activated:Connect(function()
	Remotes.LobbyAction:FireServer("StartNow")
end)

-- ===== Затемнение, субтитры, «Загрузка» =====
local fadeFrame = Instance.new("Frame")
fadeFrame.Size = UDim2.fromScale(1, 1)
fadeFrame.BackgroundColor3 = Color3.new(0, 0, 0)
fadeFrame.BackgroundTransparency = 1
fadeFrame.BorderSizePixel = 0
fadeFrame.ZIndex = 100
fadeFrame.Parent = gui

local loadingLabel = Instance.new("TextLabel")
loadingLabel.AnchorPoint = Vector2.new(0.5, 0.5)
loadingLabel.Position = UDim2.fromScale(0.5, 0.5)
loadingLabel.Size = UDim2.fromOffset(400, 50)
loadingLabel.BackgroundTransparency = 1
loadingLabel.Text = "Загрузка леса…"
loadingLabel.TextColor3 = Color3.new(1, 1, 1)
loadingLabel.Font = Enum.Font.GothamBold
loadingLabel.TextSize = 26
loadingLabel.Visible = false
loadingLabel.ZIndex = 101
loadingLabel.Parent = gui

local subtitleLabel = Instance.new("TextLabel")
subtitleLabel.AnchorPoint = Vector2.new(0.5, 1)
subtitleLabel.Position = UDim2.new(0.5, 0, 1, -70)
subtitleLabel.Size = UDim2.fromOffset(520, 54)
subtitleLabel.BackgroundColor3 = Color3.new(0, 0, 0)
subtitleLabel.BackgroundTransparency = 0.35
subtitleLabel.TextColor3 = Color3.new(1, 1, 1)
subtitleLabel.Font = Enum.Font.GothamBold
subtitleLabel.TextSize = 26
subtitleLabel.Visible = false
subtitleLabel.ZIndex = 50
subtitleLabel.Parent = gui
corner(subtitleLabel, 14)

local subtitleToken = 0
Remotes.CutsceneFx.OnClientEvent:Connect(function(kind, a, b)
	if kind == "Fade" then
		TweenService:Create(fadeFrame, TweenInfo.new(b or 0.5), { BackgroundTransparency = a and 0 or 1 }):Play()
	elseif kind == "Loading" then
		loadingLabel.Visible = a == true
	elseif kind == "Subtitle" then
		subtitleToken += 1
		local mine = subtitleToken
		subtitleLabel.Text = tostring(a)
		subtitleLabel.Visible = true
		task.delay(b or 3, function()
			if mine == subtitleToken then
				subtitleLabel.Visible = false
			end
		end)
	elseif kind == "WaitTerrain" then
		-- Ждём, пока у нас загрузится земля в точке появления, и сообщаем серверу.
		-- Без этого персонаж проваливается сквозь ещё не загруженную землю и умирает.
		task.spawn(function()
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = { workspace.Terrain }
			local t0 = os.clock()
			while os.clock() - t0 < 20 do
				local hit = workspace:Raycast(a + Vector3.new(0, 300, 0), Vector3.new(0, -600, 0), params)
				if hit then
					break
				end
				task.wait(0.25)
			end
			task.wait(0.6)
			Remotes.ClientReady:FireServer()
		end)
	end
end)

-- ===== Состояние лобби =====
local state = { state = "none" }

local function render()
	local s = state.state
	setup.Visible = s == "setup" and state.isOwner == true
	lobby.Visible = s == "open"
	timerFrame.Visible = s == "countdown"
	skipBtn.Visible = state.isOwner == true

	if s == "open" then
		info.Text = string.format("Лобби: %s\nИгроков: %d / %d", state.mapName or "?", state.count or 0, state.size or 0)
		startNow.Visible = state.isOwner == true
		leaveLobby.Position = state.isOwner and UDim2.fromOffset(24, 132) or UDim2.fromOffset(24, 90)
		lobby.Size = state.isOwner and UDim2.fromOffset(380, 190) or UDim2.fromOffset(380, 150)
	end
end

Remotes.LobbyState.OnClientEvent:Connect(function(newState)
	state = newState
	render()
end)

RunService.RenderStepped:Connect(function()
	if state.state == "countdown" and state.countdownEnd then
		local left = math.max(0, math.ceil(state.countdownEnd - workspace:GetServerTimeNow()))
		timerLabel.Text = "Старт через " .. left
	end
end)

render()
