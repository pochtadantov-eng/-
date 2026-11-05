-- Интерфейс в мультяшном стиле: кнопки «Магазин» и «Усиления» слева (в лобби),
-- монеты, создание лобби по центру, таймер отправки, затемнение и субтитры катсцены.
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
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local FONT = Enum.Font.FredokaOne
local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)
local PANEL = Color3.fromRGB(30, 30, 38)
local CARD = Color3.fromRGB(205, 206, 214)
local GREEN = Color3.fromRGB(70, 200, 90)
local BLUE = Color3.fromRGB(60, 140, 240)
local RED = Color3.fromRGB(225, 40, 40)
local GRAY = Color3.fromRGB(78, 80, 92)
local ORANGE = Color3.fromRGB(250, 160, 40)
local MAGENTA = Color3.fromRGB(215, 70, 215)
local YELLOW = Color3.fromRGB(255, 221, 60)

-- ===== Помощники стиля =====
local function corner(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 14)
	c.Parent = inst
end

local function outline(inst, thickness, color)
	local s = Instance.new("UIStroke")
	s.Color = color or BLACK
	s.Thickness = thickness or 3
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = inst
end

local function shine(inst)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(175, 175, 175))
	g.Rotation = 90
	g.Parent = inst
end

local function text(parent, str, pos, size, textSize, color)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = pos
	l.Size = size
	l.Font = FONT
	l.TextSize = textSize or 22
	l.TextColor3 = color or WHITE
	l.TextStrokeColor3 = BLACK
	l.TextStrokeTransparency = 0
	l.Text = str
	l.Parent = parent
	return l
end

-- толстая чёрная обводка букв, как в популярных играх
local function chunky(label, thickness)
	label.TextStrokeTransparency = 1
	local st = Instance.new("UIStroke")
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	st.Color = BLACK
	st.Thickness = thickness or 3
	st.LineJoinMode = Enum.LineJoinMode.Round
	st.Parent = label
	return label
end

local function button(parent, str, pos, size, color, textSize)
	local b = Instance.new("TextButton")
	b.Position = pos
	b.Size = size
	b.BackgroundColor3 = color
	b.AutoButtonColor = true
	b.Font = FONT
	b.TextSize = textSize or 24
	b.TextColor3 = WHITE
	b.TextStrokeColor3 = BLACK
	b.TextStrokeTransparency = 0
	b.Text = str
	b.Parent = parent
	corner(b, 12)
	outline(b, 3)
	shine(b)
	return b
end

local function frame(parent, size, anchor, pos, color)
	local f = Instance.new("Frame")
	f.Size = size
	f.AnchorPoint = anchor
	f.Position = pos
	f.BackgroundColor3 = color or PANEL
	f.Parent = parent
	corner(f, 18)
	outline(f, 4)
	return f
end

-- Окно в стиле «Магазин еды»: цветная шапка, заголовок, красный крестик
local function windowFrame(title, headerColor)
	local w = frame(gui, UDim2.fromOffset(780, 440), Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.52))
	w.Visible = false
	w.ZIndex = 20
	local scale = Instance.new("UISizeConstraint")
	scale.MaxSize = Vector2.new(780, 440)
	scale.Parent = w

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 64)
	header.BackgroundColor3 = headerColor
	header.Parent = w
	corner(header, 16)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(headerColor, headerColor:Lerp(BLACK, 0.25))
	g.Rotation = 90
	g.Parent = header
	local t = text(header, title, UDim2.fromOffset(22, 0), UDim2.new(1, -100, 1, 0), 34)
	t.TextXAlignment = Enum.TextXAlignment.Left

	local close = button(header, "✕", UDim2.new(1, -62, 0, 8), UDim2.fromOffset(50, 48), RED, 30)
	close.Activated:Connect(function()
		w.Visible = false
	end)

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(16, 78)
	list.Size = UDim2.new(1, -32, 1, -92)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 8
	list.ScrollingDirection = Enum.ScrollingDirection.X
	list.AutomaticCanvasSize = Enum.AutomaticSize.X
	list.CanvasSize = UDim2.new()
	list.Parent = w
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 16)
	layout.Parent = list
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingLeft = UDim.new(0, 4)
	pad.Parent = list

	return w, list
end

-- Карточка товара: название, редкость, большая иконка, описание, кнопка цены
local function itemCard(parent, name, rarity, icon, desc)
	local c = frame(parent, UDim2.fromOffset(220, 330), Vector2.zero, UDim2.new(), CARD)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(Color3.fromRGB(235, 236, 242), Color3.fromRGB(170, 172, 182))
	g.Rotation = 90
	g.Parent = c
	text(c, name, UDim2.fromOffset(0, 10), UDim2.new(1, 0, 0, 36), 30)
	text(c, rarity, UDim2.fromOffset(0, 44), UDim2.new(1, 0, 0, 22), 18, Config.RARITY_COLORS[rarity] or WHITE)
	local ic = text(c, icon, UDim2.fromOffset(0, 70), UDim2.new(1, 0, 0, 110), 84)
	ic.TextStrokeTransparency = 1
	local d = text(c, desc, UDim2.fromOffset(10, 184), UDim2.new(1, -20, 0, 40), 16)
	d.TextWrapped = true
	return c
end

-- ===== Деньги (слева снизу, как в примере: пачка купюр и зелёная сумма) =====
local money = Instance.new("Frame")
money.BackgroundTransparency = 1
money.Position = UDim2.new(0, 22, 1, -96)
money.Size = UDim2.fromOffset(320, 76)
money.Parent = gui
local moneyIcon = text(money, "💵", UDim2.fromOffset(0, 0), UDim2.fromOffset(76, 76), 60)
moneyIcon.TextStrokeTransparency = 1
local coinsLabel = chunky(text(money, "$0", UDim2.fromOffset(84, 0), UDim2.new(1, -84, 1, 0), 60, Color3.fromRGB(120, 255, 80)), 4)
coinsLabel.TextXAlignment = Enum.TextXAlignment.Left
local function refreshCoins()
	coinsLabel.Text = "$" .. tostring(player:GetAttribute("Coins") or 0)
end
player:GetAttributeChangedSignal("Coins"):Connect(refreshCoins)
refreshCoins()

-- ===== Всплывающее сообщение =====
local toast = text(gui, "", UDim2.new(0.5, -250, 0, 150), UDim2.fromOffset(500, 50), 32, YELLOW)
toast.Visible = false
toast.ZIndex = 60
local toastToken = 0
local function showToast(str, color)
	toastToken += 1
	local mine = toastToken
	toast.Text = str
	toast.TextColor3 = color or YELLOW
	toast.Visible = true
	task.delay(2, function()
		if mine == toastToken then
			toast.Visible = false
		end
	end)
end

-- ===== Окно «Усиления» =====
local boostsWindow, boostsList = windowFrame("Усиления", Color3.fromRGB(240, 140, 30))
local boostCounts = {}
for i, b in Config.BOOSTS do
	local card = itemCard(boostsList, b.name, b.rarity, b.icon, b.desc)
	card.LayoutOrder = i
	local owned = text(card, "", UDim2.fromOffset(0, 226), UDim2.new(1, 0, 0, 24), 18)
	boostCounts[b.id] = owned
	local buy = button(card, "💰 " .. b.price, UDim2.new(0, 14, 1, -70), UDim2.new(1, -28, 0, 54), RED, 30)
	buy.Activated:Connect(function()
		Remotes.Shop:FireServer("BuyBoost", b.id)
	end)
	local function refresh()
		owned.Text = "У тебя: " .. tostring(player:GetAttribute("Boost_" .. b.id) or 0)
	end
	player:GetAttributeChangedSignal("Boost_" .. b.id):Connect(refresh)
	refresh()
end

-- ===== Окно «Магазин» =====
local shopWindow, shopList = windowFrame("Магазин", MAGENTA)
for i, s in Config.SHOP_SOON do
	local card = itemCard(shopList, s.name, "Скоро", s.icon, "Появится в следующих обновлениях")
	card.LayoutOrder = i
	local soon = button(card, "Скоро", UDim2.new(0, 14, 1, -70), UDim2.new(1, -28, 0, 54), GRAY, 28)
	soon.AutoButtonColor = false
end

Remotes.Shop.OnClientEvent:Connect(function(kind, ok, message)
	if kind == "Result" then
		showToast(message, ok and Color3.fromRGB(120, 255, 120) or Color3.fromRGB(255, 110, 100))
	end
end)

-- ===== Кнопки слева: «Магазин» и ниже «Усиления» =====
local side = Instance.new("Frame")
side.BackgroundTransparency = 1
side.AnchorPoint = Vector2.new(0, 0.5)
side.Position = UDim2.new(0, 22, 0.5, -20)
side.Size = UDim2.fromOffset(120, 280)
side.Parent = gui

-- Тёмная скруглённая плитка с большой иконкой и подписью, налезающей на нижний край
local function sideButton(icon, label, y, labelColor, window)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(104, 104)
	b.Position = UDim2.fromOffset(4, y)
	b.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	b.Text = ""
	b.AutoButtonColor = true
	b.Parent = side
	corner(b, 24)
	outline(b, 4)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(Color3.fromRGB(78, 80, 92), Color3.fromRGB(36, 38, 46))
	g.Rotation = 90
	g.Parent = b

	local bevel = Instance.new("Frame")
	bevel.Size = UDim2.new(1, -12, 1, -12)
	bevel.Position = UDim2.fromOffset(6, 6)
	bevel.BackgroundTransparency = 1
	bevel.Parent = b
	corner(bevel, 19)
	outline(bevel, 2, Color3.fromRGB(120, 122, 136))

	local ic = text(b, icon, UDim2.fromOffset(0, -6), UDim2.new(1, 0, 1, 0), 64)
	ic.TextStrokeTransparency = 1
	chunky(text(b, label, UDim2.new(0, -16, 1, -26), UDim2.new(1, 32, 0, 36), 30, labelColor), 3)

	b.Activated:Connect(function()
		local open = not window.Visible
		boostsWindow.Visible = false
		shopWindow.Visible = false
		window.Visible = open
	end)
	return b
end
sideButton("🛒", "Магазин", 0, Color3.fromRGB(255, 190, 80), shopWindow)
sideButton("⚡", "Усиления", 140, Color3.fromRGB(255, 235, 90), boostsWindow)

-- ===== Создание лобби (по центру) =====
local setup = frame(gui, UDim2.fromOffset(420, 440), Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5))
setup.Visible = false
do
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 60)
	header.BackgroundColor3 = BLUE
	header.Parent = setup
	corner(header, 16)
	text(header, "Создание лобби", UDim2.new(), UDim2.fromScale(1, 1), 32)
end

text(setup, "Карта", UDim2.fromOffset(0, 72), UDim2.new(1, 0, 0, 28), 24, YELLOW)
local selectedMap = Config.MAPS[1].id
local mapButtons = {}
local mapRow = Instance.new("Frame")
mapRow.BackgroundTransparency = 1
mapRow.Position = UDim2.fromOffset(30, 104)
mapRow.Size = UDim2.new(1, -60, 0, 60)
mapRow.Parent = setup
local mapLayout = Instance.new("UIListLayout")
mapLayout.FillDirection = Enum.FillDirection.Horizontal
mapLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
mapLayout.Padding = UDim.new(0, 12)
mapLayout.Parent = mapRow
local function refreshMaps()
	for id, b in mapButtons do
		b.BackgroundColor3 = (id == selectedMap) and GREEN or GRAY
	end
end
for _, m in Config.MAPS do
	local b = button(mapRow, (m.icon or "") .. " " .. m.name, UDim2.new(), UDim2.fromOffset(170, 60), GRAY, 28)
	b.Activated:Connect(function()
		selectedMap = m.id
		refreshMaps()
	end)
	mapButtons[m.id] = b
end
refreshMaps()

text(setup, "Игроков", UDim2.fromOffset(0, 178), UDim2.new(1, 0, 0, 28), 24, YELLOW)
local selectedSize = math.clamp(Config.DEFAULT_PLAYERS, Config.MIN_PLAYERS, Config.MAX_PLAYERS)
local minus = button(setup, "–", UDim2.fromOffset(84, 212), UDim2.fromOffset(64, 64), GRAY, 40)
local plus = button(setup, "+", UDim2.fromOffset(272, 212), UDim2.fromOffset(64, 64), GRAY, 40)
local sizeLabel = text(setup, tostring(selectedSize), UDim2.fromOffset(150, 212), UDim2.fromOffset(120, 64), 52)
local function sendPreview()
	sizeLabel.Text = tostring(selectedSize)
	Remotes.LobbyAction:FireServer("Preview", selectedSize)
end
minus.Activated:Connect(function()
	selectedSize = math.max(Config.MIN_PLAYERS, selectedSize - 1)
	sendPreview()
end)
plus.Activated:Connect(function()
	selectedSize = math.min(Config.MAX_PLAYERS, selectedSize + 1)
	sendPreview()
end)

local createBtn = button(setup, "Создать лобби", UDim2.fromOffset(30, 298), UDim2.new(1, -60, 0, 62), GREEN, 32)
local leaveSetup = button(setup, "Выйти", UDim2.fromOffset(30, 370), UDim2.new(1, -60, 0, 50), RED, 28)
createBtn.Activated:Connect(function()
	Remotes.LobbyAction:FireServer("Create", selectedMap, selectedSize)
end)
leaveSetup.Activated:Connect(function()
	Remotes.LobbyAction:FireServer("Leave")
end)

-- ===== Ожидание игроков (снизу) =====
local lobby = frame(gui, UDim2.fromOffset(400, 200), Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -28))
lobby.Visible = false
local info = text(lobby, "", UDim2.fromOffset(0, 12), UDim2.new(1, 0, 0, 64), 28)
info.TextWrapped = true
local startNow = button(lobby, "Начать сейчас", UDim2.fromOffset(26, 84), UDim2.new(1, -52, 0, 50), ORANGE, 28)
local leaveLobby = button(lobby, "Выйти", UDim2.fromOffset(26, 142), UDim2.new(1, -52, 0, 46), RED, 26)
startNow.Activated:Connect(function()
	Remotes.LobbyAction:FireServer("StartNow")
end)
leaveLobby.Activated:Connect(function()
	Remotes.LobbyAction:FireServer("Leave")
end)

-- ===== Таймер отправки (сверху) =====
local timerFrame = Instance.new("Frame")
timerFrame.BackgroundTransparency = 1
timerFrame.AnchorPoint = Vector2.new(0.5, 0)
timerFrame.Position = UDim2.new(0.5, 0, 0, 70)
timerFrame.Size = UDim2.fromOffset(420, 150)
timerFrame.Visible = false
timerFrame.Parent = gui
local skipBtn = button(timerFrame, "Пропустить", UDim2.fromOffset(90, 0), UDim2.fromOffset(240, 60), ORANGE, 30)
skipBtn.Activated:Connect(function()
	Remotes.LobbyAction:FireServer("StartNow")
end)

-- ===== Затемнение, субтитры, «Загрузка» =====
local fadeFrame = Instance.new("Frame")
fadeFrame.Size = UDim2.fromScale(1, 1)
fadeFrame.BackgroundColor3 = BLACK
fadeFrame.BackgroundTransparency = 1
fadeFrame.BorderSizePixel = 0
fadeFrame.ZIndex = 100
fadeFrame.Parent = gui

local loadingLabel = text(gui, "Загрузка леса…", UDim2.new(0.5, -200, 0.5, -25), UDim2.fromOffset(400, 50), 34)
loadingLabel.Visible = false
loadingLabel.ZIndex = 101

local subtitleLabel = text(gui, "", UDim2.new(0.5, -300, 1, -130), UDim2.fromOffset(600, 60), 36)
subtitleLabel.Visible = false
subtitleLabel.ZIndex = 50

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
	-- «Отправка через N» пишется только над кругом, на экране — лишь кнопка для владельца
	timerFrame.Visible = s == "countdown" and state.isOwner == true

	if s == "setup" and state.isOwner then
		-- сразу показать над кругом выбранное число игроков
		Remotes.LobbyAction:FireServer("Preview", selectedSize)
	end
	if s == "open" then
		info.Text = string.format("%s %s\n%d / %d", "Лобби:", state.mapName or "?", state.count or 0, state.size or 0)
		startNow.Visible = state.isOwner == true
		leaveLobby.Position = state.isOwner and UDim2.fromOffset(26, 142) or UDim2.fromOffset(26, 84)
		lobby.Size = state.isOwner and UDim2.fromOffset(400, 200) or UDim2.fromOffset(400, 142)
	end
	if s ~= "none" then
		boostsWindow.Visible = false
		shopWindow.Visible = false
	end
end

Remotes.LobbyState.OnClientEvent:Connect(function(newState)
	state = newState
	render()
end)

-- Кнопки слева и монеты видны только в лобби (не в поездке и не в лесу)
task.spawn(function()
	while true do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local inHub = root ~= nil and math.abs(root.Position.X) < 2000
		side.Visible = inHub
		money.Visible = inHub
		if not inHub then
			boostsWindow.Visible = false
			shopWindow.Visible = false
		end
		task.wait(0.5)
	end
end)

render()
