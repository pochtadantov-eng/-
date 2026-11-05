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

-- Картинка из Roblox по ID (rbxassetid). Возвращает nil, если ID не задан.
local function iconImage(parent, id, size, pos)
	if id == nil or tostring(id) == "" then
		return nil
	end
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Image = "rbxassetid://" .. tostring(id)
	img.ScaleType = Enum.ScaleType.Fit
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.Position = pos or UDim2.fromScale(0.5, 0.46)
	img.Size = size or UDim2.fromScale(0.8, 0.8)
	img.ZIndex = 3
	img.Parent = parent
	return img
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
if not iconImage(money, Config.UI_ICONS.money, UDim2.fromOffset(72, 72), UDim2.fromOffset(38, 38)) then
	local moneyIcon = text(money, "💵", UDim2.fromOffset(0, 0), UDim2.fromOffset(76, 76), 60)
	moneyIcon.TextStrokeTransparency = 1
end

-- ===== Здоровье (над деньгами): сердце, красная полоска, цифры =====
game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
local hp = Instance.new("Frame")
hp.BackgroundTransparency = 1
hp.Position = UDim2.new(0, 22, 1, -170)
hp.Size = UDim2.fromOffset(330, 64)
hp.Parent = gui
if not iconImage(hp, Config.UI_ICONS.health, UDim2.fromOffset(60, 60), UDim2.fromOffset(32, 32)) then
	local heart = text(hp, "❤️", UDim2.fromOffset(0, 0), UDim2.fromOffset(64, 64), 50)
	heart.TextStrokeTransparency = 1
end
local barBack = Instance.new("Frame")
barBack.Position = UDim2.fromOffset(72, 12)
barBack.Size = UDim2.fromOffset(250, 40)
barBack.BackgroundColor3 = Color3.fromRGB(40, 20, 24)
barBack.Parent = hp
corner(barBack, 12)
outline(barBack, 4)
local barFill = Instance.new("Frame")
barFill.Size = UDim2.fromScale(1, 1)
barFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
barFill.Parent = barBack
corner(barFill, 12)
local fillGrad = Instance.new("UIGradient")
fillGrad.Color = ColorSequence.new(Color3.fromRGB(255, 90, 90), Color3.fromRGB(200, 20, 30))
fillGrad.Rotation = 90
fillGrad.Parent = barFill
local hpText = text(barBack, "100", UDim2.new(), UDim2.fromScale(1, 1), 28)
hpText.ZIndex = 3
hpText.TextStrokeTransparency = 1
local hpStroke = Instance.new("UIStroke")
hpStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
hpStroke.Thickness = 3
hpStroke.Parent = hpText

local hpConn
local function watchHealth(char)
	if hpConn then
		hpConn:Disconnect()
	end
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then
		return
	end
	local function update()
		local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
		TweenService:Create(barFill, TweenInfo.new(0.25), { Size = UDim2.fromScale(ratio, 1) }):Play()
		hpText.Text = string.format("%d / %d", math.ceil(hum.Health), math.ceil(hum.MaxHealth))
	end
	hpConn = hum.HealthChanged:Connect(update)
	update()
end
player.CharacterAdded:Connect(watchHealth)
if player.Character then
	task.spawn(watchHealth, player.Character)
end
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
side.Size = UDim2.fromOffset(124, 300)
side.Parent = gui

-- Иконка корзины из фигур (эмодзи корзины в Roblox рисуется серым)
local function basketIcon(parent)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.47)
	holder.Size = UDim2.fromScale(0.72, 0.62)
	holder.ZIndex = 3
	holder.Parent = parent

	local handle = Instance.new("Frame")
	handle.BackgroundTransparency = 1
	handle.AnchorPoint = Vector2.new(0.5, 0)
	handle.Position = UDim2.fromScale(0.5, 0)
	handle.Size = UDim2.fromScale(0.62, 0.75)
	handle.ZIndex = 3
	handle.Parent = holder
	corner(handle, 100)
	outline(handle, 7, Color3.fromRGB(60, 62, 72))

	local body = Instance.new("Frame")
	body.AnchorPoint = Vector2.new(0.5, 1)
	body.Position = UDim2.fromScale(0.5, 1)
	body.Size = UDim2.fromScale(1, 0.56)
	body.BackgroundColor3 = Color3.fromRGB(232, 46, 58)
	body.ZIndex = 4
	body.Parent = holder
	corner(body, 10)
	outline(body, 3)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 190, 190))
	g.Rotation = 90
	g.Parent = body
	for i = 0, 2 do
		local slot = Instance.new("Frame")
		slot.AnchorPoint = Vector2.new(0.5, 0.5)
		slot.Position = UDim2.fromScale(0.25 + i * 0.25, 0.58)
		slot.Size = UDim2.fromScale(0.1, 0.5)
		slot.BackgroundColor3 = Color3.fromRGB(150, 20, 30)
		slot.ZIndex = 5
		slot.Parent = body
		corner(slot, 4)
	end
	local rim = Instance.new("Frame")
	rim.AnchorPoint = Vector2.new(0.5, 0.5)
	rim.Position = UDim2.fromScale(0.5, 0.02)
	rim.Size = UDim2.fromScale(1.1, 0.24)
	rim.BackgroundColor3 = Color3.fromRGB(255, 92, 100)
	rim.ZIndex = 6
	rim.Parent = body
	corner(rim, 6)
	outline(rim, 3)
end

local function iconText(parent, glyph)
	local ic = text(parent, glyph, UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.92), 70)
	ic.TextStrokeTransparency = 1
	ic.ZIndex = 3
	return ic
end

-- Тёмная скруглённая плитка как в примере: светлая внутренняя рамка, крупная иконка
-- и золотая подпись с толстой обводкой, налезающая на нижний край
local function sideButton(drawIcon, label, y, window)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(112, 112)
	b.Position = UDim2.fromOffset(4, y)
	b.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	b.Text = ""
	b.AutoButtonColor = false
	b.Parent = side
	corner(b, 26)
	outline(b, 4)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(Color3.fromRGB(84, 86, 98), Color3.fromRGB(40, 42, 50))
	g.Rotation = 90
	g.Parent = b

	local bevel = Instance.new("Frame")
	bevel.Size = UDim2.new(1, -12, 1, -12)
	bevel.Position = UDim2.fromOffset(6, 6)
	bevel.BackgroundTransparency = 1
	bevel.ZIndex = 2
	bevel.Parent = b
	corner(bevel, 21)
	outline(bevel, 2.5, Color3.fromRGB(128, 130, 144))

	drawIcon(b)

	local lbl = text(b, label, UDim2.new(0, -20, 1, -28), UDim2.new(1, 40, 0, 40), 32)
	lbl.ZIndex = 8
	chunky(lbl, 3.5)
	local lg = Instance.new("UIGradient")
	lg.Color = ColorSequence.new(Color3.fromRGB(255, 238, 120), Color3.fromRGB(255, 150, 30))
	lg.Rotation = 90
	lg.Parent = lbl

	-- лёгкая анимация нажатия
	local scale = Instance.new("UIScale")
	scale.Parent = b
	b.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.06 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	b.Activated:Connect(function()
		scale.Scale = 0.92
		TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		local open = not window.Visible
		boostsWindow.Visible = false
		shopWindow.Visible = false
		window.Visible = open
	end)
	return b
end
sideButton(function(parent)
	if not iconImage(parent, Config.UI_ICONS.shop) then
		basketIcon(parent)
	end
end, "Магазин", 0, shopWindow)
sideButton(function(parent)
	if not iconImage(parent, Config.UI_ICONS.boosts) then
		iconText(parent, "⚡")
	end
end, "Усиления", 150, boostsWindow)

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

-- Кинокамера катсцены: следует за невидимой точкой (внутри фургона или снаружи)
local cutCamConn
local cutCamToken = 0
local function setCutsceneCamera(stageName, partName)
	cutCamToken += 1
	local mine = cutCamToken
	if cutCamConn then
		cutCamConn:Disconnect()
		cutCamConn = nil
	end
	local cam = workspace.CurrentCamera
	if not stageName then
		cam.CameraType = Enum.CameraType.Custom
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			cam.CameraSubject = hum
		end
		return
	end
	task.spawn(function()
		local part
		local t0 = os.clock()
		while not part and os.clock() - t0 < 5 do
			local stage = workspace:FindFirstChild(stageName)
			part = stage and stage:FindFirstChild(partName, true)
			if not part then
				task.wait(0.1)
			end
		end
		if not part or mine ~= cutCamToken then
			return
		end
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = part.CFrame
		cutCamConn = RunService.RenderStepped:Connect(function(dt)
			if part.Parent then
				cam.CFrame = cam.CFrame:Lerp(part.CFrame, math.clamp(dt * 10, 0, 1))
			end
		end)
	end)
end

local subtitleToken = 0
Remotes.CutsceneFx.OnClientEvent:Connect(function(kind, a, b)
	if kind == "Camera" then
		setCutsceneCamera(a, b)
	elseif kind == "Fade" then
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
