-- Интерфейс лобби: создание, таймер, пропуск ожидания, затемнение и субтитры катсцены.
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

local DARK = Color3.fromRGB(24, 24, 28)
local GREEN = Color3.fromRGB(60, 180, 90)
local BLUE = Color3.fromRGB(70, 130, 230)
local GRAY = Color3.fromRGB(70, 70, 78)
local ORANGE = Color3.fromRGB(240, 150, 50)

local function corner(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 10)
	c.Parent = inst
end

local function makeLabel(parent, text, pos, size, textSize)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = pos
	l.Size = size
	l.Font = Enum.Font.GothamBold
	l.TextSize = textSize or 18
	l.TextColor3 = Color3.new(1, 1, 1)
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
	corner(b, 8)
	return b
end

local function makePanel(size, anchor, pos)
	local f = Instance.new("Frame")
	f.Size = size
	f.AnchorPoint = anchor
	f.Position = pos
	f.BackgroundColor3 = DARK
	f.BackgroundTransparency = 0.1
	f.Visible = false
	f.Parent = gui
	corner(f, 14)
	return f
end

-- ===== Панель создания лобби (только владелец круга) =====
local setup = makePanel(UDim2.fromOffset(320, 310), Vector2.new(0, 0.5), UDim2.new(0, 20, 0.5, 0))
makeLabel(setup, "Создание лобби", UDim2.fromOffset(0, 10), UDim2.new(1, 0, 0, 30), 22)
makeLabel(setup, "Карта", UDim2.fromOffset(0, 50), UDim2.new(1, 0, 0, 22), 16)

local selectedMap = Config.MAPS[1].id
local mapButtons = {}
local mapRow = Instance.new("Frame")
mapRow.BackgroundTransparency = 1
mapRow.Position = UDim2.fromOffset(20, 76)
mapRow.Size = UDim2.new(1, -40, 0, 40)
mapRow.Parent = setup
local mapLayout = Instance.new("UIListLayout")
mapLayout.FillDirection = Enum.FillDirection.Horizontal
mapLayout.Padding = UDim.new(0, 8)
mapLayout.Parent = mapRow

local function refreshMaps()
	for id, b in mapButtons do
		b.BackgroundColor3 = (id == selectedMap) and BLUE or GRAY
	end
end
for _, m in Config.MAPS do
	local b = makeButton(mapRow, m.name, UDim2.new(), UDim2.fromOffset(120, 40), GRAY)
	b.Activated:Connect(function()
		selectedMap = m.id
		refreshMaps()
	end)
	mapButtons[m.id] = b
end
refreshMaps()

makeLabel(setup, "Количество игроков", UDim2.fromOffset(0, 128), UDim2.new(1, 0, 0, 22), 16)
local selectedSize = math.clamp(4, Config.MIN_PLAYERS, Config.MAX_PLAYERS)
local minus = makeButton(setup, "–", UDim2.fromOffset(60, 154), UDim2.fromOffset(46, 46), GRAY)
local plus = makeButton(setup, "+", UDim2.fromOffset(214, 154), UDim2.fromOffset(46, 46), GRAY)
local sizeLabel = makeLabel(setup, tostring(selectedSize), UDim2.fromOffset(110, 154), UDim2.fromOffset(100, 46), 28)
minus.Activated:Connect(function()
	selectedSize = math.max(Config.MIN_PLAYERS, selectedSize - 1)
	sizeLabel.Text = tostring(selectedSize)
end)
plus.Activated:Connect(function()
	selectedSize = math.min(Config.MAX_PLAYERS, selectedSize + 1)
	sizeLabel.Text = tostring(selectedSize)
end)

local createBtn = makeButton(setup, "Создать лобби", UDim2.fromOffset(20, 216), UDim2.new(1, -40, 0, 46), GREEN)
local leaveSetup = makeButton(setup, "Выйти из круга", UDim2.fromOffset(20, 268), UDim2.new(1, -40, 0, 32), GRAY)
createBtn.Activated:Connect(function()
	Remotes.LobbyAction:FireServer("Create", selectedMap, selectedSize)
end)
leaveSetup.Activated:Connect(function()
	Remotes.LobbyAction:FireServer("Leave")
end)

-- ===== Панель ожидания (лобби создано) =====
local lobby = makePanel(UDim2.fromOffset(340, 150), Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -30))
local info = makeLabel(lobby, "", UDim2.fromOffset(0, 10), UDim2.new(1, 0, 0, 50), 20)
info.TextWrapped = true
local startNow = makeButton(lobby, "Начать сейчас", UDim2.fromOffset(20, 68), UDim2.new(1, -40, 0, 36), ORANGE)
local leaveLobby = makeButton(lobby, "Выйти из круга", UDim2.fromOffset(20, 108), UDim2.new(1, -40, 0, 32), GRAY)
startNow.Activated:Connect(function()
	Remotes.LobbyAction:FireServer("StartNow")
end)
leaveLobby.Activated:Connect(function()
	Remotes.LobbyAction:FireServer("Leave")
end)

-- ===== Таймер сверху =====
local timerFrame = makePanel(UDim2.fromOffset(300, 110), Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 20))
local timerLabel = makeLabel(timerFrame, "", UDim2.fromOffset(0, 8), UDim2.new(1, 0, 0, 50), 34)
local skipBtn = makeButton(timerFrame, "Пропустить ожидание", UDim2.fromOffset(20, 64), UDim2.new(1, -40, 0, 36), ORANGE)
skipBtn.Activated:Connect(function()
	Remotes.LobbyAction:FireServer("StartNow")
end)

-- ===== Затемнение и субтитры =====
local fadeFrame = Instance.new("Frame")
fadeFrame.Size = UDim2.fromScale(1, 1)
fadeFrame.BackgroundColor3 = Color3.new(0, 0, 0)
fadeFrame.BackgroundTransparency = 1
fadeFrame.BorderSizePixel = 0
fadeFrame.ZIndex = 100
fadeFrame.Parent = gui

local subtitleLabel = Instance.new("TextLabel")
subtitleLabel.AnchorPoint = Vector2.new(0.5, 1)
subtitleLabel.Position = UDim2.new(0.5, 0, 1, -70)
subtitleLabel.Size = UDim2.fromOffset(520, 50)
subtitleLabel.BackgroundColor3 = Color3.new(0, 0, 0)
subtitleLabel.BackgroundTransparency = 0.35
subtitleLabel.TextColor3 = Color3.new(1, 1, 1)
subtitleLabel.Font = Enum.Font.GothamBold
subtitleLabel.TextSize = 24
subtitleLabel.Visible = false
subtitleLabel.ZIndex = 50
subtitleLabel.Parent = gui
corner(subtitleLabel, 10)

local subtitleToken = 0
Remotes.CutsceneFx.OnClientEvent:Connect(function(kind, a, b)
	if kind == "Fade" then
		TweenService:Create(fadeFrame, TweenInfo.new(b or 0.5), { BackgroundTransparency = a and 0 or 1 }):Play()
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
	end
end)

-- ===== Состояние лобби =====
local state = { state = "none" }

local function render()
	local s = state.state
	setup.Visible = s == "setup" and state.isOwner
	lobby.Visible = s == "open"
	timerFrame.Visible = s == "countdown"
	skipBtn.Visible = state.isOwner == true

	if s == "open" then
		info.Text = string.format("Лобби: %s\nИгроков: %d / %d", state.mapName or "?", state.count or 0, state.size or 0)
		startNow.Visible = state.isOwner == true
		leaveLobby.Position = state.isOwner and UDim2.fromOffset(20, 108) or UDim2.fromOffset(20, 68)
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
