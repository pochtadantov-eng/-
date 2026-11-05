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

local function buildStage(stage, origin, padId)
	local rng = Random.new(padId * 77)
	newPart(stage, "Ground", Vector3.new(1000, 1, 170), CFrame.new(origin + Vector3.new(300, -0.5, 0)), Color3.fromRGB(70, 112, 56), Enum.Material.SmoothPlastic)
	newPart(stage, "Road", Vector3.new(700, 0.2, 22), CFrame.new(origin + Vector3.new(300, 0.1, 0)), Color3.fromRGB(70, 68, 66), Enum.Material.SmoothPlastic)

	-- тропинка в густой лес от места остановки (по ней выходят игроки)
	local stop = Config.DRIVE_DISTANCE
	local pathPts = {}
	local px, pz = stop + REAR - 9, -11
	for _ = 0, 16 do
		table.insert(pathPts, Vector2.new(px, pz))
		px += rng:NextNumber(-2.2, 2.2)
		pz -= 5
	end
	for i = 1, #pathPts - 1 do
		local p1 = origin + Vector3.new(pathPts[i].X, 0.1, pathPts[i].Y)
		local p2 = origin + Vector3.new(pathPts[i + 1].X, 0.1, pathPts[i + 1].Y)
		local seg = newPart(stage, "Path", Vector3.new(4.4, 0.1, (p2 - p1).Magnitude + 1.4), CFrame.lookAt((p1 + p2) / 2, p2), Color3.fromRGB(104, 80, 56), Enum.Material.SmoothPlastic)
		seg.CanQuery = false
	end
	local function nearPath(x, z)
		for _, p in pathPts do
			local dx, dz = x - p.X, z - p.Y
			if dx * dx + dz * dz < 40 then
				return true
			end
		end
		return false
	end

	local function tree(x, z)
		if nearPath(x, z) then
			return
		end
		local cf = CFrame.new(origin + Vector3.new(x, 0, z)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		Forest.makeTree(cf, rng:NextNumber(1.0, 1.7), rng).Parent = stage
	end
	for side = -1, 1, 2 do
		for _ = 1, 40 do
			tree(rng:NextNumber(-40, 640), side * rng:NextNumber(18, 70))
		end
	end
	-- густой лес вокруг тропинки
	for _ = 1, 90 do
		tree(stop + rng:NextNumber(-80, 40), -rng:NextNumber(15, 85))
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
		local side = add("Side", Vector3.new(boxLen, BOX_H, 0.5), Vector3.new(boxMidX, midY, sz * (HALF_W + 0.25)), green, Enum.Material.SmoothPlastic)
		add("Stripe", Vector3.new(boxLen + 0.1, 0.7, 0.12), Vector3.new(boxMidX, FLOOR_TOP + 2.2, sz * (HALF_W + 0.56)), yellow, Enum.Material.SmoothPlastic, false)
		local sg = Instance.new("SurfaceGui")
		sg.Face = sz == 1 and Enum.NormalId.Back or Enum.NormalId.Front
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 30
		sg.Parent = side
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		t.Position = UDim2.fromScale(0.5, 0.42)
		t.Size = UDim2.fromScale(0.8, 0.22)
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

local function walkTo(fr, pos, timeout)
	if fr.walk then
		fr.walk:Play(0.2)
	end
	fr.hum:MoveTo(pos)
	local t0 = os.clock()
	while os.clock() - t0 < timeout do
		local root = fr.hum.RootPart
		if not root then
			break
		end
		local dx, dz = root.Position.X - pos.X, root.Position.Z - pos.Z
		if dx * dx + dz * dz < 1.2 then
			break
		end
		task.wait(0.05)
	end
	if fr.walk then
		fr.walk:Stop(0.25)
	end
end

-- плавный поворот лесника лицом в направлении dir
local function turnTo(fr, dir, duration)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude < 1e-3 then
		return
	end
	local root = fr.root
	local pos = root.Position
	root.Anchored = true
	local tw = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
		CFrame = CFrame.lookAt(pos, pos + flat.Unit),
	})
	tw:Play()
	tw.Completed:Wait()
	root.Anchored = false
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

local function point(fr)
	if not fr or not fr.shoulder then
		return
	end
	TweenService:Create(fr.shoulder, TweenInfo.new(0.6, Enum.EasingStyle.Back), {
		C0 = fr.shoulder.C0 * CFrame.Angles(math.rad(88), 0, 0),
	}):Play()
end

local function say(forester, players, text, duration)
	duration = duration or 3
	subtitle(players, "Лесник: " .. text, duration)
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

-- открыть одну створку (side = 1 правая, -1 левая)
local function openDoor(truck, side, baseCF, duration)
	local door
	for _, d in truck.doors do
		if d.side == side then
			door = d
		end
	end
	if not door then
		return
	end
	local w = door.part:FindFirstChildOfClass("WeldConstraint")
	if w then
		w:Destroy()
	end
	door.part.Anchored = true
	local t0 = os.clock()
	repeat
		local a = math.clamp((os.clock() - t0) / duration, 0, 1)
		local e = TweenService:GetValue(a, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local hinge = baseCF * CFrame.new(REAR - 0.2, FLOOR_TOP + DOOR_H / 2, side * HALF_W)
		door.part.CFrame = hinge * CFrame.Angles(0, side * math.rad(95) * e, 0) * CFrame.new(0, 0, -side * DOOR_LEN / 2)
		RunService.Heartbeat:Wait()
	until a >= 1
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

function Cutscene.run(padId, players, mapId)
	local origin = Config.STAGE_ORIGIN + Vector3.new(0, 0, padId * 200)

	-- 1. Затемнение и переход на сцену
	fade(players, true, 0.6)
	task.wait(0.8)

	local stage = Instance.new("Folder")
	stage.Name = "Stage" .. padId
	stage.Parent = Workspace

	buildStage(stage, origin, padId)
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
			hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
			table.insert(riders, r)
			seatRider(r)
		end
	end

	task.wait(0.6)
	local lookAt = forester and forester.rig:FindFirstChild("Head") and forester.rig.Head.Position or truck.base.CFrame:PointToWorldSpace(Vector3.new(FORESTER_X, FLOOR_TOP + 4.5, 0))
	firstPerson(players, true, lookAt)
	fade(players, false, 0.8)
	task.wait(0.8)

	-- 3. Едем; лесник говорит с ребятами
	local talkDone = false
	task.spawn(function()
		task.wait(1.5)
		for i, line in LINES do
			lookAround(forester, (i % 2 == 0) and 0.5 or -0.5)
			say(forester, players, line, 3.1)
			task.wait(3.4)
		end
		lookAround(forester, 0)
		talkDone = true
	end)

	local t0 = os.clock()
	local T = Config.DRIVE_SECONDS
	repeat
		local t = os.clock() - t0
		local a = math.clamp(t / T, 0, 1)
		local e = TweenService:GetValue(a, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		-- покачивание: сильнее на скорости, затихает к остановке
		local k = 0.3 + 0.7 * math.sin(a * math.pi)
		local sway = CFrame.new(0, math.abs(math.sin(t * 3.1)) * 0.07 * k, 0)
			* CFrame.Angles(
				(math.sin(t * 2.3) * 0.02 + math.sin(t * 5.7) * 0.007) * k,
				0,
				math.sin(t * 1.7) * 0.012 * k
			)
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

	-- дослушиваем лесника
	local waitTalk = os.clock()
	while not talkDone and os.clock() - waitTalk < 10 do
		task.wait(0.1)
	end

	-- 4. Лесник оборачивается, открывает одну дверь, выходит, открывает вторую, показывает на лес
	task.wait(0.6)
	local baseCF = truck.base.CFrame
	local function at(x, z)
		return baseCF:PointToWorldSpace(Vector3.new(x, 0, z))
	end
	if forester then
		forester.weld:Destroy()
		pcall(function()
			forester.root:SetNetworkOwner(nil)
		end)
		turnTo(forester, -baseCF.XVector, 0.9)
		walkTo(forester, at(REAR + 1.3, -2.8), 4)
		turnTo(forester, -baseCF.XVector, 0.3)
	end
	openDoor(truck, -1, baseCF, 1.1)

	if forester then
		walkTo(forester, at(REAR - 2.6, -2.8), 4)
		task.wait(0.3)
		turnTo(forester, baseCF.XVector, 0.6)
	end
	openDoor(truck, 1, baseCF, 1.1)
	if forester then
		walkTo(forester, at(REAR - 8.5, -2.8), 4)
		walkTo(forester, at(REAR - 13, -7), 4)
		turnTo(forester, -baseCF.ZVector, 0.6)
		point(forester)
	end
	task.wait(0.4)
	say(forester, players, "Выходим!", 2.6)
	task.wait(1.2)

	-- игроки сами встают и плавно выходят из фургона на тропинку (смотреть можно по сторонам)
	local n = #riders
	for i, r in riders do
		local char, hum, root = charParts(r.player)
		if char then
			local sw = r.seat:FindFirstChild("SeatWeld")
			if sw then
				sw:Destroy()
			end
			hum.Sit = false
			local sp = baseCF:PointToObjectSpace(r.seat.Position)
			local lane = math.clamp((i - (n + 1) / 2) * 1.3, -3, 3)
			local route = {
				at(sp.X, lane * 0.4),
				at(REAR + 1.2, lane),
				at(REAR - 8, lane),
				at(REAR - 9, -12 + lane * 0.5),
				at(REAR - 9.5, -19 + lane * 0.5),
			}
			task.delay((i - 1) * 0.35, function()
				if r.player.Parent == Players then
					Remotes.CutsceneFx:FireClient(r.player, "AutoWalk", route, 7)
				end
			end)
		end
	end
	task.wait(7.5)

	-- 5. Затемнение и телепорт в лес
	fade(players, true, 0.8)
	task.wait(1.0)
	for _, pl in players do
		if pl.Parent == Players then
			Remotes.CutsceneFx:FireClient(pl, "Loading", true)
		end
	end

	Forest.waitUntilReady()
	local spawns = Forest.spawnPoints(#riders)
	for i, r in riders do
		local char, hum, root = charParts(r.player)
		if char then
			local sw = r.seat:FindFirstChild("SeatWeld")
			if sw then
				sw:Destroy()
			end
			hum.Sit = false
			hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
			hum.JumpPower = r.jumpPower
			hum.JumpHeight = r.jumpHeight
			char:PivotTo(spawns[i])
			root.AssemblyLinearVelocity = Vector3.zero
			root.Anchored = true -- держим на месте, пока клиент не загрузит землю
			terrainReady[r.player] = nil
			Remotes.CutsceneFx:FireClient(r.player, "WaitTerrain", spawns[i].Position)
		end
	end

	local waitStart = os.clock()
	while os.clock() - waitStart < 25 do
		local all = true
		for _, r in riders do
			if r.player.Parent == Players and not terrainReady[r.player] then
				all = false
			end
		end
		if all then
			break
		end
		task.wait(0.2)
	end

	for _, r in riders do
		local _, _, root = charParts(r.player)
		if root then
			root.Anchored = false
		end
		terrainReady[r.player] = nil
	end

	task.wait(0.4)
	firstPerson(players, false)
	for _, pl in players do
		if pl.Parent == Players then
			Remotes.CutsceneFx:FireClient(pl, "Loading", false)
		end
	end
	fade(players, false, 1.0)
end

function Cutscene.cleanup(padId)
	local stage = Workspace:FindFirstChild("Stage" .. padId)
	if stage then
		stage:Destroy()
	end
end

return Cutscene
