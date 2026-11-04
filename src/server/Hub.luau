-- Общее лобби: круглая площадь с фонтаном, забор по кругу, дорога за забором,
-- 4 круга-площадки с барьерами. Земля сделана террейном, поэтому всё гладкое.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")

local Config = require(ReplicatedStorage.Shared.Config)
local Forest = require(script.Parent.Forest)
local Scenery = require(script.Parent.Scenery)

local Hub = { pads = {} }

local terrain = Workspace.Terrain
local rng = Random.new(2024)

local PLAZA_R = 78
local FENCE_R = 100
local WALL_R = 108
local ROAD_Z = Config.ROAD_Z
local PI2 = math.pi * 2

local WOOD = Color3.fromRGB(122, 86, 54)
local STONE = Color3.fromRGB(205, 205, 200)

local function mk(parent, shape, size, cf, color, material)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Вертикальный цилиндр (center — середина)
local function cyl(parent, height, diameter, pos, color, material)
	return mk(
		parent,
		Enum.PartType.Cylinder,
		Vector3.new(height, diameter, diameter),
		CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material
	)
end

local function ball(parent, diameter, pos, color, material)
	return mk(parent, Enum.PartType.Ball, Vector3.one * diameter, CFrame.new(pos), color, material)
end

local function polar(radius, angle)
	return Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

-- ===== Земля =====
local function buildTerrain()
	-- основная трава (большая, чтобы край мира был за горами)
	terrain:FillBlock(CFrame.new(0, -8, -60), Vector3.new(1000, 16, 800), Enum.Material.Grass)

	-- круглая площадь и пятно у фонтана
	terrain:FillCylinder(CFrame.new(0, -2, 0), 4, PLAZA_R, Enum.Material.Pavement)
	terrain:FillCylinder(CFrame.new(0, -2, 22), 4, 17, Enum.Material.Concrete)

	-- дорога и тротуары
	terrain:FillBlock(CFrame.new(0, -2, ROAD_Z), Vector3.new(960, 4, 24), Enum.Material.Asphalt)
	terrain:FillBlock(CFrame.new(0, -2, ROAD_Z + 15), Vector3.new(960, 4, 6), Enum.Material.Pavement)
	terrain:FillBlock(CFrame.new(0, -2, ROAD_Z - 15), Vector3.new(960, 4, 6), Enum.Material.Pavement)

	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(86, 140, 62))
	terrain:SetMaterialColor(Enum.Material.Pavement, Color3.fromRGB(176, 170, 160))
	terrain:SetMaterialColor(Enum.Material.Concrete, Color3.fromRGB(205, 200, 192))
	terrain:SetMaterialColor(Enum.Material.Asphalt, Color3.fromRGB(58, 58, 62))
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(118, 116, 120))

	Scenery.buildMountains(terrain, rng)
end

-- ===== Забор по кругу с воротами =====
local function buildFence(folder)
	local fence = Instance.new("Folder")
	fence.Name = "Fence"
	fence.Parent = folder

	local n = 84
	local prev
	local gateAngle = math.pi / 2
	for i = 0, n do
		local a = (i / n) * PI2
		local diff = math.abs(math.atan2(math.sin(a - gateAngle), math.cos(a - gateAngle)))
		local inGate = diff < math.rad(8)
		local pos = polar(FENCE_R, a)
		if not inGate and i < n then
			cyl(fence, 4.4, 0.9, pos + Vector3.new(0, 2.2, 0), WOOD, Enum.Material.Wood)
			-- шарик на столбе
			ball(fence, 1.1, pos + Vector3.new(0, 4.7, 0), WOOD, Enum.Material.Wood)
		end
		if prev and not inGate and not prev.inGate then
			local mid = (pos + prev.pos) / 2
			local len = (pos - prev.pos).Magnitude
			local dir = (pos - prev.pos).Unit
			for _, y in { 1.5, 3.2 } do
				local center = mid + Vector3.new(0, y, 0)
				mk(
					fence,
					Enum.PartType.Cylinder,
					Vector3.new(len, 0.4, 0.4),
					CFrame.lookAt(center, center + dir) * CFrame.Angles(0, math.rad(90), 0),
					WOOD,
					Enum.Material.Wood
				)
			end
		end
		prev = { pos = pos, inGate = inGate }
	end

	-- Невидимая стена снаружи, чтобы никто не ушёл за пределы
	local walls = 48
	for i = 0, walls - 1 do
		local a = (i / walls) * PI2
		local pos = polar(WALL_R, a) + Vector3.new(0, 25, 0)
		local chord = 2 * WALL_R * math.sin(math.pi / walls) + 1
		local w = mk(fence, Enum.PartType.Block, Vector3.new(chord, 50, 1), CFrame.lookAt(pos, pos + polar(1, a)), Color3.new(), Enum.Material.SmoothPlastic)
		w.Transparency = 1
		w.CanQuery = false
	end
end

-- ===== Ворота у спавна =====
local function buildGate(folder)
	local gate = Instance.new("Folder")
	gate.Name = "Gate"
	gate.Parent = folder
	for _, sx in { -9, 9 } do
		cyl(gate, 11, 2.2, Vector3.new(sx, 5.5, FENCE_R), STONE, Enum.Material.Marble)
		ball(gate, 3, Vector3.new(sx, 11.5, FENCE_R), STONE, Enum.Material.Marble)
	end
	local beam = mk(gate, Enum.PartType.Block, Vector3.new(22, 2.2, 2.2), CFrame.new(0, 12.4, FENCE_R), Color3.fromRGB(60, 80, 62), Enum.Material.Wood)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 40
		sg.Parent = beam
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Text = "ЛЕС"
		t.TextColor3 = Color3.fromRGB(255, 236, 190)
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		t.Parent = sg
	end
end

-- ===== Фонтан =====
local function buildFountain(folder)
	local f = Instance.new("Folder")
	f.Name = "Fountain"
	f.Parent = folder
	local c = Vector3.new(0, 0, 22)

	cyl(f, 1.6, 15, c + Vector3.new(0, 0.8, 0), STONE, Enum.Material.Marble)
	local water = cyl(f, 0.4, 13.4, c + Vector3.new(0, 1.5, 0), Color3.fromRGB(70, 150, 210), Enum.Material.Glass)
	water.Transparency = 0.35
	water.CanCollide = false
	cyl(f, 5, 2.4, c + Vector3.new(0, 3.5, 0), STONE, Enum.Material.Marble)
	cyl(f, 0.8, 6.5, c + Vector3.new(0, 6, 0), STONE, Enum.Material.Marble)
	local bowl = cyl(f, 0.3, 5.6, c + Vector3.new(0, 6.5, 0), Color3.fromRGB(70, 150, 210), Enum.Material.Glass)
	bowl.Transparency = 0.35
	bowl.CanCollide = false

	local emitterPart = mk(f, Enum.PartType.Block, Vector3.one, CFrame.new(c + Vector3.new(0, 7, 0)), Color3.new(), Enum.Material.SmoothPlastic)
	emitterPart.Transparency = 1
	emitterPart.CanCollide = false
	emitterPart.CanQuery = false
	local pe = Instance.new("ParticleEmitter")
	pe.Rate = 90
	pe.Lifetime = NumberRange.new(1.0, 1.4)
	pe.Speed = NumberRange.new(14, 18)
	pe.SpreadAngle = Vector2.new(18, 18)
	pe.Acceleration = Vector3.new(0, -34, 0)
	pe.Size = NumberSequence.new(0.5, 0.3)
	pe.Transparency = NumberSequence.new(0.2, 0.8)
	pe.Color = ColorSequence.new(Color3.fromRGB(200, 230, 255))
	pe.LightEmission = 0.4
	pe.Parent = emitterPart
end

-- ===== Фонари и скамейки =====
local function buildLamps(folder)
	local f = Instance.new("Folder")
	f.Name = "Lamps"
	f.Parent = folder
	for i = 0, 15 do
		local a = (i / 16) * PI2 + 0.1
		local pos = polar(70, a)
		cyl(f, 9, 0.5, pos + Vector3.new(0, 4.5, 0), Color3.fromRGB(40, 44, 48), Enum.Material.Metal)
		local head = ball(f, 1.6, pos + Vector3.new(0, 9.3, 0), Color3.fromRGB(255, 240, 200), Enum.Material.Neon)
		head.CanCollide = false
		local light = Instance.new("PointLight")
		light.Range = 24
		light.Brightness = 0.8
		light.Color = Color3.fromRGB(255, 235, 190)
		light.Parent = head
	end
end

local function buildBenches(folder)
	local f = Instance.new("Folder")
	f.Name = "Benches"
	f.Parent = folder
	for i = 0, 11 do
		local a = (i / 12) * PI2 + 0.26
		local pos = polar(74.5, a)
		if pos.Z < 85 then
			local look = CFrame.lookAt(pos, Vector3.new(0, 0, 0))
			mk(f, Enum.PartType.Block, Vector3.new(5.5, 0.4, 1.8), look * CFrame.new(0, 1.5, 0), WOOD, Enum.Material.WoodPlanks)
			mk(f, Enum.PartType.Block, Vector3.new(5.5, 1.4, 0.3), look * CFrame.new(0, 2.5, 0.8) * CFrame.Angles(math.rad(-10), 0, 0), WOOD, Enum.Material.WoodPlanks)
			for _, sx in { -2.4, 2.4 } do
				mk(f, Enum.PartType.Block, Vector3.new(0.4, 1.5, 1.4), look * CFrame.new(sx, 0.75, 0), Color3.fromRGB(40, 44, 48), Enum.Material.Metal)
			end
		end
	end
end

-- ===== Зелень: кусты, цветы, деревья =====
local function buildGreenery(folder, houseSpots)
	local f = Instance.new("Folder")
	f.Name = "Greenery"
	f.Parent = folder
	local flowerColors = {
		Color3.fromRGB(240, 90, 90),
		Color3.fromRGB(250, 220, 80),
		Color3.fromRGB(245, 245, 245),
		Color3.fromRGB(170, 120, 240),
		Color3.fromRGB(255, 150, 60),
	}

	for _ = 1, 90 do
		local a = rng:NextNumber(0, PI2)
		local r = rng:NextNumber(81, 97)
		local pos = polar(r, a)
		if not (pos.Z > 82 and math.abs(pos.X) < 16) then
			local d = rng:NextNumber(3, 5)
			local g = rng:NextInteger(0, 25)
			local bush = ball(f, d, pos + Vector3.new(0, d * 0.35, 0), Color3.fromRGB(50 + g, 110 + g, 50), Enum.Material.Grass)
			bush.CanCollide = false
			for _ = 1, 3 do
				local off = Vector3.new(rng:NextNumber(-2, 2), 0.4, rng:NextNumber(-2, 2))
				local fl = ball(f, 0.7, pos + off + Vector3.new(0, d * 0.5, 0), flowerColors[rng:NextInteger(1, #flowerColors)], Enum.Material.SmoothPlastic)
				fl.CanCollide = false
			end
		end
	end

	-- деревья внутри и снаружи забора
	local function tree(x, z)
		local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, rng:NextNumber(0, PI2), 0)
		Forest.makeTree(cf, rng:NextNumber(0.9, 1.6), rng).Parent = f
	end
	for _ = 1, 22 do
		local pos = polar(rng:NextNumber(84, 95), rng:NextNumber(0, PI2))
		if not (pos.Z > 80 and math.abs(pos.X) < 18) then
			tree(pos.X, pos.Z)
		end
	end
	local function nearHouse(x, z)
		for _, h in houseSpots do
			local dx, dz = x - h.X, z - h.Y
			if dx * dx + dz * dz < 24 * 24 then
				return true
			end
		end
		return false
	end
	for _ = 1, 70 do
		local pos = polar(rng:NextNumber(110, 145), rng:NextNumber(0, PI2))
		if math.abs(pos.Z - ROAD_Z) > 30 then
			tree(pos.X, pos.Z)
		end
	end
	for _ = 1, 260 do
		local pos = polar(rng:NextNumber(150, 330), rng:NextNumber(0, PI2))
		if math.abs(pos.Z - ROAD_Z) > 30 and not nearHouse(pos.X, pos.Z) then
			tree(pos.X, pos.Z)
		end
	end
end

-- ===== Разметка дороги =====
local function buildRoadMarkings(folder)
	local f = Instance.new("Folder")
	f.Name = "Road"
	f.Parent = folder
	local white = Color3.fromRGB(240, 240, 235)
	for x = -470, 470, 14 do
		mk(f, Enum.PartType.Block, Vector3.new(6, 0.1, 0.5), CFrame.new(x, 0.06, ROAD_Z), white, Enum.Material.SmoothPlastic).CanCollide = false
	end
	for _, dz in { -11, 11 } do
		mk(f, Enum.PartType.Block, Vector3.new(960, 0.1, 0.4), CFrame.new(0, 0.06, ROAD_Z + dz), white, Enum.Material.SmoothPlastic).CanCollide = false
	end
end

-- ===== Круги-площадки с барьерами =====
local function ensureGroup(name)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(name)
	end)
end

local function buildPads(folder)
	local radius = Config.PAD_RADIUS
	local segments = 36

	for i = 1, Config.PAD_COUNT do
		local x = (i - (Config.PAD_COUNT + 1) / 2) * 30
		local z = -30

		local barrierGroup = "Barrier" .. i
		ensureGroup(barrierGroup)
		ensureGroup("PadMember" .. i)

		local rim = mk(
			folder,
			Enum.PartType.Cylinder,
			Vector3.new(0.35, radius * 2 + 2, radius * 2 + 2),
			CFrame.new(x, 0.3, z) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(245, 245, 240),
			Enum.Material.Marble
		)
		rim.Name = "PadRim" .. i
		rim.CanCollide = false

		local pad = mk(
			folder,
			Enum.PartType.Cylinder,
			Vector3.new(0.3, radius * 2, radius * 2),
			CFrame.new(x, 0.35, z) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(90, 220, 120),
			Enum.Material.Neon
		)
		pad.Name = "Pad" .. i
		pad.CanCollide = false

		-- Барьер: кольцо из сегментов вокруг круга
		local barrier = Instance.new("Folder")
		barrier.Name = "Barrier" .. i
		barrier.Parent = folder
		local segParts = {}
		local br = radius + 0.6
		local chord = 2 * br * math.sin(math.pi / segments) + 0.25
		for s = 0, segments - 1 do
			local a = (s / segments) * PI2
			local pos = Vector3.new(x, 7, z) + polar(br, a)
			local seg = mk(
				barrier,
				Enum.PartType.Block,
				Vector3.new(chord, 14, 0.5),
				CFrame.lookAt(pos, pos + polar(1, a)),
				Color3.fromRGB(120, 200, 255),
				Enum.Material.Neon
			)
			seg.Transparency = 1
			seg.CanQuery = false
			seg.CanTouch = false
			seg.CollisionGroup = barrierGroup
			table.insert(segParts, seg)
		end
		PhysicsService:CollisionGroupSetCollidable(barrierGroup, "Default", false)

		local anchor = mk(folder, Enum.PartType.Block, Vector3.one, CFrame.new(x, 11, z), Color3.new(), Enum.Material.SmoothPlastic)
		anchor.Name = "LabelAnchor" .. i
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.Transparency = 1

		local gui = Instance.new("BillboardGui")
		gui.Adornee = anchor
		gui.Size = UDim2.fromOffset(240, 72)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 150
		gui.Parent = anchor

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.fromRGB(18, 22, 30)
		label.BackgroundTransparency = 0.25
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Font = Enum.Font.GothamBold
		label.TextSize = 20
		label.TextWrapped = true
		label.Text = ""
		label.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 14)
		corner.Parent = label
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(255, 255, 255)
		stroke.Transparency = 0.8
		stroke.Parent = label

		-- mode: "hidden" (круг свободен), "open" (можно зайти), "blocked" (занят)
		local function setBarrier(mode, color)
			-- стенка невидима всегда, меняется только то, пропускает ли она посторонних
			for _, seg in segParts do
				seg.Transparency = 1
			end
			PhysicsService:CollisionGroupSetCollidable(barrierGroup, "Default", mode == "blocked")
		end

		table.insert(Hub.pads, {
			id = i,
			center = Vector3.new(x, 0, z),
			radius = radius,
			part = pad,
			label = label,
			setBarrier = setBarrier,
		})
	end
end

-- Пол-страховка и точка появления создаются первыми, пока строится остальное
local function buildSafety(folder)
	local floor = cyl(folder, 1, WALL_R * 2 + 4, Vector3.new(0, -0.5, 0), Color3.new(), Enum.Material.SmoothPlastic)
	floor.Name = "SafetyFloor"
	floor.Transparency = 1
	floor.CanQuery = false

	-- Невидимая точка появления у ворот (никакой платформы)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 0.2, 6)
	spawn.CFrame = CFrame.new(0, 0.1, 50)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.Parent = folder
end

function Hub.build()
	local folder = Instance.new("Folder")
	folder.Name = "Hub"
	folder.Parent = Workspace

	buildSafety(folder)
	buildTerrain()
	local houseSpots = Scenery.buildTown(folder, rng)
	buildFence(folder)
	buildGate(folder)
	buildFountain(folder)
	buildLamps(folder)
	buildBenches(folder)
	buildGreenery(folder, houseSpots)
	buildRoadMarkings(folder)
	buildPads(folder)

	return Hub.pads
end

return Hub
