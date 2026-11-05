-- Катсцена: игроки едут в закрытом фургоне вместе с лесником (его покачивает в дороге),
-- лесник говорит с ними, потом выходит, открывает двери, показывает на лес — и телепорт.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Forest = require(script.Parent.Forest)

local Cutscene = {}

-- Клиент сообщает, что земля в лесу у него уже загрузилась (иначе персонаж проваливается и умирает)
local terrainReady = {}
Remotes.ClientReady.OnServerEvent:Connect(function(player)
	terrainReady[player] = true
end)

-- Размеры фургона (локальные координаты: +X — вперёд, +Z — вправо, Y — вверх)
local FLOOR_TOP = 3.0
local REAR = -10 -- задний край фургона (двери)
local FRONT = 8.5 -- передняя стенка фургона (за ней кабина)
local BOX_H = 8.5 -- высота фургона внутри
local HALF_W = 6.25 -- половина ширины фургона
local DOOR_LEN = 6.25 -- ширина одной створки
local DOOR_H = 8.4
local FORESTER_X = REAR + 2.6 -- лесник стоит у дверей лицом к ребятам

local LINES = {
	"Так, ребята…",
	"Хочу вам сказать одну важную вещь.",
	"Этот лес очень опасный.",
	"Будьте осторожны.",
	"Я вас предупредил.",
}

local function camera(players, stageName, partName)
	for _, pl in players do
		if pl.Parent == Players then
			Remotes.CutsceneFx:FireClient(pl, "Camera", stageName, partName)
		end
	end
end

-- Вид от первого лица (можно крутить головой) и блокировка управления на время сцены
local function firstPerson(players, on, lookAt)
	for _, pl in players do
		if pl.Parent == Players then
			Remotes.CutsceneFx:FireClient(pl, "FirstPerson", on, lookAt)
			Remotes.CutsceneFx:FireClient(pl, "Controls", not on)
		end
	end
end

local function fade(players, toBlack, duration)
	for _, pl in players do
		if pl.Parent == Players then
			Remotes.CutsceneFx:FireClient(pl, "Fade", toBlack, duration)
		end
	end
end

local function subtitle(players, text, duration)
	for _, pl in players do
		if pl.Parent == Players then
			Remotes.CutsceneFx:FireClient(pl, "Subtitle", text, duration)
		end
	end
end

local function charParts(pl)
	local char = pl.Character
	if not char then
		return nil
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	if hum and root and hum.Health > 0 then
		return char, hum, root
	end
	return nil
end

local function newPart(parent, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.Parent = parent
	return p
end

-- Карта, на которую приезжает фургон, и есть игровая карта: тёмный густой лес,
-- тропинка вглубь, в конце тропинки лагерь с костром. Края закрыты невидимыми стенами.
local function buildStage(stage, origin, seed)
	local rng = Random.new(seed * 77 + 1)
	newPart(stage, "Ground", Vector3.new(1000, 1, 170), CFrame.new(origin + Vector3.new(300, -0.5, 0)), Color3.fromRGB(62, 100, 50), Enum.Material.SmoothPlastic)
	newPart(stage, "Road", Vector3.new(700, 0.2, 22), CFrame.new(origin + Vector3.new(300, 0.1, 0)), Color3.fromRGB(70, 68, 66), Enum.Material.SmoothPlastic)

	local stop = Config.DRIVE_DISTANCE
	local minX, maxX = stop - 170, stop + 150

	-- тропинка от дороги вглубь леса
	local pathPts = {}
	local px, pz = stop + REAR - 9, -11
	for _ = 0, 14 do
		table.insert(pathPts, Vector2.new(px, pz))
		px += rng:NextNumber(-2.2, 2.2)
		pz -= 5
	end
	for i = 1, #pathPts - 1 do
		local p1 = origin + Vector3.new(pathPts[i].X, 0.1, pathPts[i].Y)
		local p2 = origin + Vector3.new(pathPts[i + 1].X, 0.1, pathPts[i + 1].Y)
		local seg = newPart(stage, "Path", Vector3.new(4.4, 0.1, (p2 - p1).Magnitude + 1.4), CFrame.lookAt((p1 + p2) / 2, p2), Color3.fromRGB(100, 78, 54), Enum.Material.SmoothPlastic)
		seg.CanQuery = false
	end
	local campPos = pathPts[#pathPts]

	local function blocked(x, z)
		for _, p in pathPts do
			local dx, dz = x - p.X, z - p.Y
			if dx * dx + dz * dz < 40 then
				return true
			end
		end
		local cx, cz = x - campPos.X, z - campPos.Y
		if cx * cx + cz * cz < 15 * 15 then
			return true
		end
		return math.abs(z) < 14 -- дорога и обочины
	end

	local function tree(x, z)
		if blocked(x, z) then
			return
		end
		local cf = CFrame.new(origin + Vector3.new(x, 0, z)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		Forest.makeTree(cf, rng:NextNumber(1.0, 1.8), rng).Parent = stage
	end
	-- вдоль всей дороги
	for side = -1, 1, 2 do
		for _ = 1, 30 do
			tree(rng:NextNumber(-40, minX), side * rng:NextNumber(16, 75))
		end
	end
	-- густой лес на игровой части
	for i = 1, 240 do
		tree(rng:NextNumber(minX + 4, maxX - 4), (i % 2 == 0 and 1 or -1) * rng:NextNumber(15, 82))
		if i % 40 == 0 then
			task.wait()
		end
	end
	-- камни и кусты
	for _ = 1, 40 do
		local x, z = rng:NextNumber(minX, maxX), (rng:NextNumber() < 0.5 and 1 or -1) * rng:NextNumber(15, 82)
		if not blocked(x, z) then
			Forest.makeRock(CFrame.new(origin + Vector3.new(x, 0, z)), rng:NextNumber(2, 6), rng).Parent = stage
		end
	end
	for _ = 1, 70 do
		local x, z = rng:NextNumber(minX, maxX), (rng:NextNumber() < 0.5 and 1 or -1) * rng:NextNumber(14, 82)
		if not blocked(x, z) then
			local d = rng:NextNumber(2.5, 4.5)
			local g = rng:NextInteger(0, 20)
			local bush = newPart(stage, "Bush", Vector3.one * d, CFrame.new(origin + Vector3.new(x, d * 0.3, z)), Color3.fromRGB(40 + g, 86 + g, 44), Enum.Material.SmoothPlastic)
			bush.Shape = Enum.PartType.Ball
			bush.CanCollide = false
		end
	end

	-- лагерь в конце тропинки: костёр, камни, брёвна, палатка
	local C = origin + Vector3.new(campPos.X, 0, campPos.Y)
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2
		local st = newPart(stage, "Stone", Vector3.one * 1.3, CFrame.new(C + Vector3.new(math.cos(a) * 2.4, 0.4, math.sin(a) * 2.4)), Color3.fromRGB(112, 112, 116), Enum.Material.SmoothPlastic)
		st.Shape = Enum.PartType.Ball
	end
	for i = 0, 2 do
		local log = newPart(stage, "FireLog", Vector3.new(4.4, 0.7, 0.7), CFrame.new(C + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, math.rad(60 * i), math.rad(14)), Color3.fromRGB(60, 40, 28), Enum.Material.Wood)
		log.Shape = Enum.PartType.Cylinder
		log.CanCollide = false
	end
	local firePart = newPart(stage, "Campfire", Vector3.one, CFrame.new(C + Vector3.new(0, 1.2, 0)), Color3.new(), Enum.Material.SmoothPlastic)
	firePart.Transparency = 1
	firePart.CanCollide = false
	local fire = Instance.new("Fire")
	fire.Size = 6
	fire.Heat = 10
	fire.Color = Color3.fromRGB(255, 160, 50)
	fire.SecondaryColor = Color3.fromRGB(220, 60, 20)
	fire.Parent = firePart
	local fireLight = Instance.new("PointLight")
	fireLight.Range = 34
	fireLight.Brightness = 2.4
	fireLight.Color = Color3.fromRGB(255, 150, 70)
	fireLight.Parent = firePart
	for _, a in { 0.5, 2.6, 4.4 } do
		local seat = newPart(stage, "LogSeat", Vector3.new(5, 1.1, 1.1), CFrame.new(C + Vector3.new(math.cos(a) * 6, 0.55, math.sin(a) * 6)) * CFrame.Angles(0, -(a + math.pi / 2), 0), Color3.fromRGB(110, 78, 50), Enum.Material.Wood)
		seat.Shape = Enum.PartType.Cylinder
	end
	local tentPos = C + Vector3.new(-10, 0, -4)
	local tcf = CFrame.lookAt(tentPos, Vector3.new(C.X, 0, C.Z))
	newPart(stage, "TentFloor", Vector3.new(7, 0.2, 8), tcf * CFrame.new(0, 0.1, 0), Color3.fromRGB(55, 50, 45), Enum.Material.Fabric)
	for _, side in { 1, -1 } do
		newPart(stage, "Tent", Vector3.new(5.44, 0.3, 8.4), tcf * CFrame.new(side * 1.75, 2.1, 0) * CFrame.Angles(0, 0, -side * math.rad(50)), Color3.fromRGB(205, 115, 50), Enum.Material.Fabric)
	end

	-- невидимые стены вокруг игровой части
	for _, spec in {
		{ Vector3.new((minX + maxX) / 2, 40, 84), Vector3.new(maxX - minX, 80, 2) },
		{ Vector3.new((minX + maxX) / 2, 40, -84), Vector3.new(maxX - minX, 80, 2) },
		{ Vector3.new(minX, 40, 0), Vector3.new(2, 80, 170) },
		{ Vector3.new(maxX, 40, 0), Vector3.new(2, 80, 170) },
	} do
		local w = newPart(stage, "Bound", spec[2], CFrame.new(origin + spec[1]), Color3.new(), Enum.Material.SmoothPlastic)
		w.Transparency = 1
		w.CanQuery = false
	end
end

local function buildTruck(stage, baseCF, seatCount)
	local model = Instance.new("Model")
	model.Name = "Truck"

	local base = newPart(model, "Base", Vector3.one, baseCF, Color3.new(), Enum.Material.SmoothPlastic)
	base.Transparency = 1
	base.CanCollide = false
	base.CanQuery = false
	model.PrimaryPart = base

	local green = Color3.fromRGB(52, 92, 64)
	local greenDark = green:Lerp(Color3.new(0, 0, 0), 0.25)
	local wood = Color3.fromRGB(128, 92, 58)
	local metal = Color3.fromRGB(60, 62, 68)
	local yellow = Color3.fromRGB(235, 200, 60)

	local function add(name, size, localPos, color, material, collide)
		local p = newPart(model, name, size, baseCF * CFrame.new(localPos), color, material)
		p.CanCollide = collide ~= false
		p.Anchored = false
		local w = Instance.new("WeldConstraint")
		w.Part0 = base
		w.Part1 = p
		w.Parent = p
		return p
	end

	local boxLen = FRONT - REAR
	local boxMidX = (FRONT + REAR) / 2
	local midY = FLOOR_TOP + BOX_H / 2

	local floor = add("Floor", Vector3.new(boxLen + 1.5, 1, HALF_W * 2 + 1), Vector3.new(boxMidX + 0.6, 2.5, 0), Color3.fromRGB(96, 92, 86), Enum.Material.DiamondPlate)

	-- закрытый фургон: бока, передняя стенка, потолок
	for _, sz in { -1, 1 } do
		local wz = sz * (HALF_W + 0.25)
		local lowH, winH = 3.4, 2.8 -- низ стены и высота окон (на уровне глаз сидящих)
		local upH = BOX_H - lowH - winH
		local side = add("SideLow", Vector3.new(boxLen, lowH, 0.5), Vector3.new(boxMidX, FLOOR_TOP + lowH / 2, wz), green, Enum.Material.SmoothPlastic)
		add("SideHigh", Vector3.new(boxLen, upH, 0.5), Vector3.new(boxMidX, FLOOR_TOP + lowH + winH + upH / 2, wz), green, Enum.Material.SmoothPlastic)
		for _, px in { REAR + 0.6, -5.3, -0.6, 4.1, FRONT - 0.6 } do
			add("Pillar", Vector3.new(1.2, winH, 0.5), Vector3.new(px, FLOOR_TOP + lowH + winH / 2, wz), greenDark, Enum.Material.SmoothPlastic)
		end
		local glass = add("Window", Vector3.new(boxLen, winH, 0.1), Vector3.new(boxMidX, FLOOR_TOP + lowH + winH / 2, wz), Color3.fromRGB(160, 190, 200), Enum.Material.Glass, false)
		glass.Transparency = 0.75
		add("Stripe", Vector3.new(boxLen + 0.1, 0.7, 0.12), Vector3.new(boxMidX, FLOOR_TOP + 2.2, sz * (HALF_W + 0.56)), yellow, Enum.Material.SmoothPlastic, false)
		local sg = Instance.new("SurfaceGui")
		sg.Face = sz == 1 and Enum.NormalId.Back or Enum.NormalId.Front
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 30
		sg.Parent = side
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		t.Position = UDim2.fromScale(0.5, 0.3)
		t.Size = UDim2.fromScale(0.7, 0.4)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.Text = "ЛЕСНАЯ СЛУЖБА"
		t.TextColor3 = yellow
		t.Parent = sg
		-- лавки вдоль стен
		add("Bench", Vector3.new(10.4, 0.5, 1.7), Vector3.new(-0.9, FLOOR_TOP + 1.4, sz * (HALF_W - 0.9)), wood, Enum.Material.WoodPlanks)
		add("BenchBase", Vector3.new(10.4, 1.4, 0.3), Vector3.new(-0.9, FLOOR_TOP + 0.7, sz * (HALF_W - 0.25)), metal, Enum.Material.Metal)
		-- поручень под потолком
		local rail = add("Rail", Vector3.new(boxLen - 2, 0.25, 0.25), Vector3.new(boxMidX, FLOOR_TOP + BOX_H - 1.2, sz * (HALF_W - 0.5)), Color3.fromRGB(180, 182, 188), Enum.Material.Metal, false)
		rail.Shape = Enum.PartType.Cylinder
	end
	add("FrontWall", Vector3.new(0.5, BOX_H, HALF_W * 2 + 1), Vector3.new(FRONT + 0.25, midY, 0), green, Enum.Material.SmoothPlastic)
	add("Roof", Vector3.new(boxLen + 0.6, 0.5, HALF_W * 2 + 1.2), Vector3.new(boxMidX, FLOOR_TOP + BOX_H + 0.25, 0), greenDark, Enum.Material.SmoothPlastic)

	-- тусклая лампа под потолком
	local lamp = add("CeilingLamp", Vector3.new(1.8, 0.25, 0.9), Vector3.new(boxMidX, FLOOR_TOP + BOX_H - 0.15, 0), Color3.fromRGB(255, 232, 180), Enum.Material.Neon, false)
	local light = Instance.new("PointLight")
	light.Range = 20
	light.Brightness = 1.3
	light.Color = Color3.fromRGB(255, 220, 170)
	light.Parent = lamp

	-- кабина
	add("CabLower", Vector3.new(6.4, 2.6, 13.6), Vector3.new(12.2, 3.3, 0), green, Enum.Material.SmoothPlastic)
	add("CabUpper", Vector3.new(4.6, 2.6, 13.2), Vector3.new(11.3, 5.9, 0), green, Enum.Material.SmoothPlastic)
	add("CabRoof", Vector3.new(4.9, 0.4, 13.5), Vector3.new(11.3, 7.35, 0), greenDark, Enum.Material.SmoothPlastic)
	add("CabStripe", Vector3.new(6.5, 0.35, 13.7), Vector3.new(12.2, 4.6, 0), yellow, Enum.Material.SmoothPlastic)
	local glassColor = Color3.fromRGB(40, 60, 80)
	local ws = add("Windshield", Vector3.new(0.2, 2.0, 12.2), Vector3.new(13.65, 5.9, 0), glassColor, Enum.Material.Glass, false)
	ws.Transparency = 0.25
	ws.Reflectance = 0.3
	for _, sz in { -1, 1 } do
		local sw = add("SideWindow", Vector3.new(3.6, 1.8, 0.2), Vector3.new(11.3, 5.9, sz * 6.65), glassColor, Enum.Material.Glass, false)
		sw.Transparency = 0.25
		add("Headlight", Vector3.new(0.3, 0.9, 1.8), Vector3.new(15.45, 3.6, sz * 4.8), Color3.fromRGB(255, 248, 220), Enum.Material.Neon, false)
		add("Mirror", Vector3.new(0.6, 0.8, 0.4), Vector3.new(13.2, 6.0, sz * 7.2), Color3.fromRGB(30, 30, 34), Enum.Material.SmoothPlastic, false)
		add("TailLight", Vector3.new(0.2, 0.8, 0.9), Vector3.new(REAR - 0.45, FLOOR_TOP + 0.4, sz * (HALF_W - 0.3)), Color3.fromRGB(220, 30, 30), Enum.Material.Neon, false)
	end
	add("Grille", Vector3.new(0.3, 1.6, 6), Vector3.new(15.45, 3.4, 0), Color3.fromRGB(25, 25, 28), Enum.Material.SmoothPlastic, false)
	add("Bumper", Vector3.new(0.8, 0.8, 14), Vector3.new(15.6, 2.0, 0), metal, Enum.Material.SmoothPlastic, false)
	add("RearStep", Vector3.new(1.4, 0.4, HALF_W * 2), Vector3.new(REAR - 0.8, 1.5, 0), metal, Enum.Material.DiamondPlate)

	for _, wx in { -6, 12 } do
		for _, wz in { -7.2, 7.2 } do
			local wheel = add("Wheel", Vector3.new(1.2, 3.2, 3.2), Vector3.new(wx, 1.6, wz), Color3.fromRGB(25, 25, 25), Enum.Material.SmoothPlastic, false)
			wheel.Shape = Enum.PartType.Cylinder
			wheel.CFrame = baseCF * CFrame.new(wx, 1.6, wz) * CFrame.Angles(0, math.rad(90), 0)
			for _, spec in { { 1.3, 2.0, Color3.fromRGB(190, 192, 198) }, { 1.4, 0.8, Color3.fromRGB(90, 92, 98) } } do
				local rim = add("Rim", Vector3.new(spec[1], spec[2], spec[2]), Vector3.new(wx, 1.6, wz), spec[3], Enum.Material.SmoothPlastic, false)
				rim.Shape = Enum.PartType.Cylinder
				rim.CFrame = wheel.CFrame
			end
		end
	end

	-- места на лавках: друг напротив друга, по 3 с каждой стороны
	local slots = {}
	for _, x in { 2.4, -0.9, -4.2 } do
		for _, sz in { -1, 1 } do
			table.insert(slots, { x = x, sz = sz })
		end
	end
	local seats = {}
	for i = 1, seatCount do
		local slot = slots[math.min(i, #slots)]
		local lp = Vector3.new(slot.x, FLOOR_TOP + 1.9, slot.sz * (HALF_W - 1.0))
		local seat = Instance.new("Seat")
		seat.Name = "Seat" .. i
		seat.Size = Vector3.new(1.8, 0.4, 1.6)
		seat.Color = Color3.fromRGB(60, 44, 34)
		seat.Material = Enum.Material.Fabric
		seat.TopSurface = Enum.SurfaceType.Smooth
		seat.BottomSurface = Enum.SurfaceType.Smooth
		seat.CFrame = baseCF * CFrame.lookAt(lp, Vector3.new(lp.X, lp.Y, 0))
		seat.Anchored = false
		seat.Parent = model
		local w = Instance.new("WeldConstraint")
		w.Part0 = base
		w.Part1 = seat
		w.Parent = seat
		seats[i] = seat
	end

	-- задние двери во всю высоту, с ручками
	local doors = {}
	for _, side in { 1, -1 } do
		local d = add(
			side == 1 and "DoorR" or "DoorL",
			Vector3.new(0.4, DOOR_H, DOOR_LEN),
			Vector3.new(REAR - 0.2, FLOOR_TOP + DOOR_H / 2, side * DOOR_LEN / 2),
			green,
			Enum.Material.SmoothPlastic
		)
		d:FindFirstChildOfClass("WeldConstraint").Name = "BaseWeld"
		local handle = newPart(model, "DoorHandle", Vector3.new(0.3, 1.3, 0.3), baseCF * CFrame.new(REAR - 0.5, FLOOR_TOP + 4, side * 0.8), Color3.fromRGB(40, 40, 44), Enum.Material.Metal)
		handle.Anchored = false
		handle.CanCollide = false
		local hw = Instance.new("WeldConstraint")
		hw.Part0 = d
		hw.Part1 = handle
		hw.Parent = handle
		table.insert(doors, { part = d, side = side })
	end

	-- камера внутри: у передней стенки, смотрит на лесника у дверей
	local camPos = Vector3.new(FRONT - 1.2, FLOOR_TOP + 6.3, 0)
	local camIn = add("CamInside", Vector3.one * 0.2, camPos, Color3.new(), Enum.Material.SmoothPlastic, false)
	camIn.Transparency = 1
	camIn.CanQuery = false
	camIn.CFrame = baseCF * CFrame.lookAt(camPos, Vector3.new(FORESTER_X, FLOOR_TOP + 3.6, 0))

	model.Parent = stage
	return { model = model, base = base, floor = floor, seats = seats, doors = doors }
end

-- Серьёзное лицо: брови к переносице, прямой рот, борода
local function seriousFace(head, rig)
	local old = head:FindFirstChild("face")
	if old then
		old:Destroy()
	end
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.CanvasSize = Vector2.new(100, 100)
	sg.Parent = head
	local function feature(size, pos, color, rotation, round)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Size = size
		f.Position = pos
		f.BackgroundColor3 = color
		f.BorderSizePixel = 0
		f.Rotation = rotation or 0
		f.Parent = sg
		if round then
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0.5, 0)
			c.Parent = f
		end
	end
	local dark = Color3.fromRGB(30, 24, 20)
	feature(UDim2.fromScale(0.11, 0.11), UDim2.fromScale(0.34, 0.45), dark, 0, true)
	feature(UDim2.fromScale(0.11, 0.11), UDim2.fromScale(0.66, 0.45), dark, 0, true)
	feature(UDim2.fromScale(0.24, 0.06), UDim2.fromScale(0.33, 0.32), Color3.fromRGB(70, 46, 30), 14)
	feature(UDim2.fromScale(0.24, 0.06), UDim2.fromScale(0.67, 0.32), Color3.fromRGB(70, 46, 30), -14)
	feature(UDim2.fromScale(0.3, 0.045), UDim2.fromScale(0.5, 0.7), dark, 0)

	local beard = Instance.new("Part")
	beard.Name = "Beard"
	beard.Size = Vector3.new(1.0, 0.55, 0.35)
	beard.Color = Color3.fromRGB(92, 62, 40)
	beard.Material = Enum.Material.SmoothPlastic
	beard.CanCollide = false
	beard.Massless = true
	beard.CFrame = head.CFrame * CFrame.new(0, -0.48, -0.48)
	beard.Parent = rig
	local bw = Instance.new("WeldConstraint")
	bw.Part0 = head
	bw.Part1 = beard
	bw.Parent = beard
end

-- Топор в правой руке: деревянное топорище, стальной обух и лезвие со светлой кромкой
local function giveAxe(rig)
	local hand = rig:FindFirstChild("RightHand")
	if not hand then
		return
	end
	local function piece(name, shape, size, rel, color, material, reflect)
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = shape
		p.Size = size
		p.Color = color
		p.Material = material
		p.Reflectance = reflect or 0
		p.CanCollide = false
		p.Massless = true
		p.CFrame = hand.CFrame * rel
		p.Parent = rig
		local w = Instance.new("Weld")
		w.Part0 = hand
		w.Part1 = p
		w.C0 = rel
		w.Parent = p
	end
	local grip = CFrame.new(0.15, 0.5, -0.35)
	piece("AxeHandle", Enum.PartType.Cylinder, Vector3.new(3.6, 0.28, 0.28), grip * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(122, 84, 52), Enum.Material.Wood)
	piece("AxeHead", Enum.PartType.Block, Vector3.new(0.22, 0.75, 1.0), grip * CFrame.new(0, 1.55, -0.45), Color3.fromRGB(84, 86, 92), Enum.Material.Metal, 0.1)
	piece("AxeBlade", Enum.PartType.Block, Vector3.new(0.16, 1.15, 0.28), grip * CFrame.new(0, 1.55, -1.05), Color3.fromRGB(218, 222, 230), Enum.Material.Metal, 0.35)
	piece("AxePoll", Enum.PartType.Block, Vector3.new(0.3, 0.5, 0.4), grip * CFrame.new(0, 1.55, 0.2), Color3.fromRGB(70, 72, 78), Enum.Material.Metal)
end

local function spawnForester(stage, truck)
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = Color3.fromRGB(226, 180, 140)
	desc.TorsoColor = Color3.fromRGB(150, 40, 40)
	desc.LeftArmColor = Color3.fromRGB(150, 40, 40)
	desc.RightArmColor = Color3.fromRGB(150, 40, 40)
	desc.LeftLegColor = Color3.fromRGB(70, 58, 44)
	desc.RightLegColor = Color3.fromRGB(70, 58, 44)

	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not rig then
		warn("[Cutscene] не удалось создать лесника: " .. tostring(rig))
		return nil
	end

	rig.Name = "Лесник"
	local hum = rig:FindFirstChildOfClass("Humanoid")
	hum.DisplayName = "Лесник"
	hum.WalkSpeed = 9
	hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	rig.Parent = stage

	-- стоит у дверей лицом к ребятам (к кабине)
	local base = truck.base.CFrame
	local pos = base:PointToWorldSpace(Vector3.new(FORESTER_X, FLOOR_TOP + 3, 0))
	rig:PivotTo(CFrame.lookAt(pos, pos + base.XVector))

	local head = rig:FindFirstChild("Head")
	if head then
		local hat = Instance.new("Part")
		hat.Name = "Hat"
		hat.Shape = Enum.PartType.Cylinder
		hat.Size = Vector3.new(0.4, 2.4, 2.4)
		hat.Color = Color3.fromRGB(40, 80, 50)
		hat.Material = Enum.Material.Fabric
		hat.CanCollide = false
		hat.Massless = true
		hat.CFrame = head.CFrame * CFrame.new(0, 0.7, 0) * CFrame.Angles(0, 0, math.rad(90))
		hat.Parent = rig
		local hw = Instance.new("WeldConstraint")
		hw.Part0 = head
		hw.Part1 = hat
		hw.Parent = hat

		local crown = Instance.new("Part")
		crown.Name = "HatCrown"
		crown.Size = Vector3.new(1.4, 0.7, 1.4)
		crown.Color = Color3.fromRGB(40, 80, 50)
		crown.Material = Enum.Material.Fabric
		crown.CanCollide = false
		crown.Massless = true
		crown.CFrame = head.CFrame * CFrame.new(0, 1.0, 0)
		crown.Parent = rig
		local cw = Instance.new("WeldConstraint")
		cw.Part0 = head
		cw.Part1 = crown
		cw.Parent = crown

		seriousFace(head, rig)
	end
	giveAxe(rig)

	-- анимация ходьбы для лесника
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = hum
	end
	local walkAnim = Instance.new("Animation")
	walkAnim.AnimationId = "rbxassetid://" .. ((Config.WALK_ANIM_ID ~= "" and Config.WALK_ANIM_ID) or "507777826")
	local okAnim, walkTrack = pcall(function()
		return animator:LoadAnimation(walkAnim)
	end)

	local root = rig:FindFirstChild("HumanoidRootPart")
	local weld = Instance.new("WeldConstraint")
	weld.Name = "RideWeld"
	weld.Part0 = truck.floor
	weld.Part1 = root
	weld.Parent = root

	local upperArm = rig:FindFirstChild("LeftUpperArm")
	return {
		rig = rig,
		hum = hum,
		root = root,
		weld = weld,
		walk = okAnim and walkTrack or nil,
		neck = head and head:FindFirstChild("Neck"),
		shoulder = upperArm and upperArm:FindFirstChild("LeftShoulder"),
	}
end

-- Лесник ходит «по рельсам»: корень закреплён и плавно едет к точке, ноги шагают
-- анимацией. Так он никогда не спотыкается и не падает. target — позиция корня.
local function walkTo(fr, target, speed)
	local root = fr.root
	root.Anchored = true
	local from = root.Position
	local dist = (target - from).Magnitude
	if dist < 0.05 then
		return
	end
	local flat = Vector3.new(target.X - from.X, 0, target.Z - from.Z)
	local look = flat.Magnitude > 0.05 and flat.Unit or root.CFrame.LookVector
	local startRot = root.CFrame.Rotation
	local endRot = CFrame.lookAt(Vector3.zero, look).Rotation
	if fr.walk then
		fr.walk:Play(0.15)
	end
	local T = dist / (speed or 7)
	local t0 = os.clock()
	repeat
		local a = math.clamp((os.clock() - t0) / T, 0, 1)
		root.CFrame = CFrame.new(from:Lerp(target, a)) * startRot:Lerp(endRot, math.clamp(a * 4, 0, 1))
		RunService.Heartbeat:Wait()
	until a >= 1
	if fr.walk then
		fr.walk:Stop(0.2)
	end
end

-- плавный поворот лесника лицом в направлении dir
local function turnTo(fr, dir, duration)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude < 1e-3 then
		return
	end
	local root = fr.root
	root.Anchored = true
	local pos = root.Position
	local tw = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
		CFrame = CFrame.lookAt(pos, pos + flat.Unit),
	})
	tw:Play()
	tw.Completed:Wait()
end

-- поворот головы (смотрит то на одну лавку, то на другую)
local neckBase = {}
local function lookAround(fr, yaw)
	if not fr or not fr.neck then
		return
	end
	neckBase[fr.neck] = neckBase[fr.neck] or fr.neck.C0
	TweenService:Create(fr.neck, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {
		C0 = neckBase[fr.neck] * CFrame.Angles(0, yaw, 0),
	}):Play()
end

local shoulderBase = {}
local function point(fr, up)
	if not fr or not fr.shoulder then
		return
	end
	shoulderBase[fr.shoulder] = shoulderBase[fr.shoulder] or fr.shoulder.C0
	TweenService:Create(fr.shoulder, TweenInfo.new(0.6, Enum.EasingStyle.Back), {
		C0 = up == false and shoulderBase[fr.shoulder] or shoulderBase[fr.shoulder] * CFrame.Angles(math.rad(88), 0, 0),
	}):Play()
end

local function say(forester, players, text, duration)
	duration = duration or 3
	print("[Cutscene] Лесник: " .. text)
	for _, pl in players do
		if pl.Parent == Players then
			pl:SetAttribute("DialogName", "Лесник")
			pl:SetAttribute("DialogText", text)
			pl:SetAttribute("DialogTime", duration)
			pl:SetAttribute("DialogId", (pl:GetAttribute("DialogId") or 0) + 1)
		end
	end
	local head = forester and forester.rig:FindFirstChild("Head")
	if head then
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(300, 64)
		gui.StudsOffset = Vector3.new(0, 3.2, 0)
		gui.AlwaysOnTop = true
		gui.Adornee = head
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		label.TextColor3 = Color3.fromRGB(20, 20, 24)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Text = text
		label.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 16)
		corner.Parent = label
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = label
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 10)
		pad.PaddingRight = UDim.new(0, 10)
		pad.PaddingTop = UDim.new(0, 6)
		pad.PaddingBottom = UDim.new(0, 6)
		pad.Parent = label
		gui.Parent = head
		Debris:AddItem(gui, duration)
	end
end

-- повернуть створку (side = 1 правая, -1 левая) от угла a0 до a1 (0 = закрыта, 1 = открыта)
local function swingDoor(truck, side, baseCF, a0, a1, duration)
	local door
	for _, d in truck.doors do
		if d.side == side then
			door = d
		end
	end
	if not door then
		return
	end
	local w = door.part:FindFirstChild("BaseWeld")
	if w then
		w:Destroy()
	end
	door.part.Anchored = true
	local t0 = os.clock()
	repeat
		local a = math.clamp((os.clock() - t0) / duration, 0, 1)
		local e = a0 + (a1 - a0) * TweenService:GetValue(a, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
		local hinge = baseCF * CFrame.new(REAR - 0.2, FLOOR_TOP + DOOR_H / 2, side * HALF_W)
		door.part.CFrame = hinge * CFrame.Angles(0, side * math.rad(95) * e, 0) * CFrame.new(0, 0, -side * DOOR_LEN / 2)
		RunService.Heartbeat:Wait()
	until a >= 1
	if a1 == 0 then
		-- закрыта: снова приваривается к фургону и едет вместе с ним
		door.part.Anchored = false
		local nw = Instance.new("WeldConstraint")
		nw.Name = "BaseWeld"
		nw.Part0 = truck.base
		nw.Part1 = door.part
		nw.Parent = door.part
	end
end

local function seatRider(r)
	local char, hum, root = charParts(r.player)
	if not char then
		return
	end
	char:PivotTo(r.seat.CFrame * CFrame.new(0, 3, 0))
	root.AssemblyLinearVelocity = Vector3.zero
	r.seat:Sit(hum)
end

-- Шаг сцены, который не должен ронять всю катсцену
local function safe(label, fn)
	local ok, err = pcall(fn)
	if not ok then
		warn("[Cutscene] шаг «" .. label .. "» не удался: " .. tostring(err))
	end
	return ok
end

local runCounter = 0
local building = {} -- [padId] = stage, пока идёт катсцена (для уборки при ошибке)

-- Карта живёт, пока на ней есть хоть кто-то из приехавших; потом удаляется
local function watchStage(stage, riders, origin)
	task.spawn(function()
		while stage.Parent do
			task.wait(3)
			local anyone = false
			for _, r in riders do
				local _, _, root = charParts(r.player)
				if root and math.abs(root.Position.X - origin.X) < 900 and math.abs(root.Position.Z - origin.Z) < 150 then
					anyone = true
				end
			end
			if not anyone then
				stage:Destroy()
			end
		end
	end)
end

function Cutscene.run(padId, players, mapId)
	runCounter += 1
	local slot = runCounter % 12
	local origin = Config.STAGE_ORIGIN + Vector3.new(0, 0, slot * 240)

	print("[Cutscene] старт, игроков: " .. #players)
	-- 1. Затемнение и переход на карту
	fade(players, true, 0.6)
	task.wait(0.8)

	local stage = Instance.new("Folder")
	stage.Name = "Stage" .. runCounter
	stage.Parent = Workspace
	building[padId] = stage

	buildStage(stage, origin, runCounter)
	local startCF = CFrame.new(origin)
	local truck = buildTruck(stage, startCF, #players)
	local forester = spawnForester(stage, truck)

	-- 2. Рассаживаем игроков на лавки
	local riders = {}
	for i, pl in players do
		local char, hum = charParts(pl)
		if char then
			local r = {
				player = pl,
				seat = truck.seats[i],
				jumpPower = hum.JumpPower,
				jumpHeight = hum.JumpHeight,
			}
			hum.JumpPower = 0
			hum.JumpHeight = 0
			table.insert(riders, r)
			seatRider(r)
		end
	end

	task.wait(0.6)
	local function foresterHead()
		local head = forester and forester.rig:FindFirstChild("Head")
		return head and head.Position or truck.base.CFrame:PointToWorldSpace(Vector3.new(FORESTER_X, FLOOR_TOP + 4.5, 0))
	end
	print("[Cutscene] игроки в фургоне, вид от первого лица")
	firstPerson(players, true, foresterHead())
	fade(players, false, 0.8)
	task.wait(0.8)

	-- 3. Едем, фургон покачивает; лесник говорит с ребятами
	local talkDone = false
	print("[Cutscene] едем, начинается диалог")
	task.spawn(function()
		task.wait(1.5)
		for i, line in LINES do
			safe("поворот головы", function()
				lookAround(forester, (i % 2 == 0) and 0.5 or -0.5)
			end)
			safe("реплика", function()
				say(forester, players, line, 3.1)
			end)
			task.wait(3.4)
		end
		safe("поворот головы", function()
			lookAround(forester, 0)
		end)
		talkDone = true
	end)

	local t0 = os.clock()
	local T = Config.DRIVE_SECONDS
	repeat
		local t = os.clock() - t0
		local a = math.clamp(t / T, 0, 1)
		local e = TweenService:GetValue(a, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		local k = 0.3 + 0.7 * math.sin(a * math.pi)
		local sway = CFrame.new(0, math.abs(math.sin(t * 3.1)) * 0.07 * k, 0)
			* CFrame.Angles((math.sin(t * 2.3) * 0.02 + math.sin(t * 5.7) * 0.007) * k, 0, math.sin(t * 1.7) * 0.012 * k)
		truck.model:PivotTo((startCF + Vector3.new(Config.DRIVE_DISTANCE * e, 0, 0)) * sway)
		for _, r in riders do
			local _, hum = charParts(r.player)
			if hum and hum.SeatPart ~= r.seat then
				r.seat:Sit(hum)
			end
		end
		RunService.Heartbeat:Wait()
	until a >= 1
	truck.model:PivotTo(startCF + Vector3.new(Config.DRIVE_DISTANCE, 0, 0))

	local waitTalk = os.clock()
	while not talkDone and os.clock() - waitTalk < 10 do
		task.wait(0.1)
	end

	-- 4. Лесник оборачивается, открывает одну дверь, выходит, открывает вторую, показывает в лес
	task.wait(0.6)
	local baseCF = truck.base.CFrame
	local function onFloor(x, z)
		return baseCF:PointToWorldSpace(Vector3.new(x, FLOOR_TOP + 3, z))
	end
	local function onGround(x, z)
		return baseCF:PointToWorldSpace(Vector3.new(x, 3.2, z))
	end
	print("[Cutscene] приехали, лесник выходит")
	safe("лесник выходит и открывает двери", function()
		if forester then
			forester.weld:Destroy()
			forester.root.Anchored = true
			turnTo(forester, -baseCF.XVector, 0.9)
			walkTo(forester, onFloor(REAR + 1.3, -2.8), 5)
			turnTo(forester, -baseCF.XVector, 0.3)
		end
		swingDoor(truck, -1, baseCF, 0, 1, 1.1)
		if forester then
			walkTo(forester, onFloor(REAR - 0.3, -2.8), 5)
			walkTo(forester, onGround(REAR - 2.6, -2.8), 4)
			task.wait(0.3)
			turnTo(forester, baseCF.XVector, 0.6)
		end
		swingDoor(truck, 1, baseCF, 0, 1, 1.1)
		if forester then
			walkTo(forester, onGround(REAR - 8.5, -2.8), 6)
			walkTo(forester, onGround(REAR - 13, -7), 6)
			turnTo(forester, -baseCF.ZVector, 0.6)
			point(forester, true)
		end
		task.wait(0.4)
	end)
	say(forester, players, "Выходим!", 2.4)
	task.wait(2.4)

	-- 5. Затемнение: игроки уже стоят снаружи у фургона, лесник — внутри у дверей
	fade(players, true, 0.6)
	task.wait(0.8)
	safe("лесник возвращается в фургон", function()
		if forester then
			point(forester, false)
			forester.root.CFrame = CFrame.lookAt(onFloor(REAR + 1.8, 0), onFloor(REAR - 5, 0))
		end
	end)
	print("[Cutscene] высаживаем игроков у фургона")
	for i, r in riders do
		safe("высадка игрока", function()
			local char, hum, root = charParts(r.player)
			if not char then
				return
			end
			local sw = r.seat:FindFirstChild("SeatWeld")
			if sw then
				sw:Destroy()
			end
			hum.Sit = false
			Remotes.CutsceneFx:FireClient(r.player, "Stand")
			task.wait(0.05)
			local row = math.floor((i - 1) / 3)
			local lane = ((i - 1) % 3 - 1) * 3.2
			local pos = onGround(REAR - 10 - row * 3, lane)
			char:PivotTo(CFrame.lookAt(pos, pos + baseCF.XVector))
			root.AssemblyLinearVelocity = Vector3.zero
		end)
	end
	firstPerson(players, true, foresterHead())
	task.wait(0.3)
	fade(players, false, 0.8)
	task.wait(1.2)

	-- 6. Лесник закрывает обе створки изнутри, фургон уезжает
	print("[Cutscene] лесник закрывает двери, фургон уезжает")
	safe("фургон уезжает", function()
		swingDoor(truck, 1, baseCF, 1, 0, 1.0)
		task.wait(0.2)
		swingDoor(truck, -1, baseCF, 1, 0, 1.0)
		task.wait(0.6)

		local rel = forester and baseCF:ToObjectSpace(forester.root.CFrame)
		local driveT = 6
		local t1 = os.clock()
		repeat
			local t = os.clock() - t1
			local a = math.clamp(t / driveT, 0, 1)
			local e = TweenService:GetValue(a, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			local sway = CFrame.Angles(math.sin(t * 2.6) * 0.015 * a, 0, 0)
			local cf = (baseCF + baseCF.XVector * 260 * e) * sway
			truck.model:PivotTo(cf)
			if forester then
				forester.root.CFrame = cf * rel
			end
			RunService.Heartbeat:Wait()
		until a >= 1
		truck.model:Destroy()
		if forester then
			forester.rig:Destroy()
		end
	end)
	if truck.model.Parent then
		truck.model:Destroy()
	end
	if forester and forester.rig.Parent then
		forester.rig:Destroy()
	end

	-- 7. Игра: обычная камера и управление
	for _, r in riders do
		local _, hum = charParts(r.player)
		if hum then
			hum.JumpPower = r.jumpPower
			hum.JumpHeight = r.jumpHeight
		end
	end
	firstPerson(players, false)
	print("[Cutscene] готово, игроки на карте")
	building[padId] = nil
	watchStage(stage, riders, origin)
end

function Cutscene.cleanup(padId)
	-- убираем только карту, которая так и не достроилась из-за ошибки
	local stage = building[padId]
	if stage then
		stage:Destroy()
		building[padId] = nil
	end
end

return Cutscene
