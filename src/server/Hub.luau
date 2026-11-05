-- Общее лобби: компактная площадь за высокой каменной стеной, современный фонтан,
-- дорожки, лавочки, 4 круга с невидимыми барьерами. За стеной — дорога с тоннелями
-- на концах (машины уезжают в тоннель), дальше пригород и горы.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")

local Config = require(ReplicatedStorage.Shared.Config)
local Forest = require(script.Parent.Forest)
local Scenery = require(script.Parent.Scenery)

local Hub = { pads = {} }

local terrain = Workspace.Terrain
local rng = Random.new(2024)

local WALL_R = 64 -- каменная стена лобби
local ROAD_Z = Config.ROAD_Z
local TUNNEL_X = Config.TUNNEL_X
local ROAD_HALF = TUNNEL_X + 60
local FOUNTAIN = Vector3.new(0, 0, 10)
local SPAWN = Vector3.new(0, 0, 42)
local PAD_Z = -24
local PI2 = math.pi * 2

local STONE = Color3.fromRGB(150, 146, 138)
local STONE_LIGHT = Color3.fromRGB(205, 200, 190)
local DARK_METAL = Color3.fromRGB(34, 36, 40)
local WOOD = Color3.fromRGB(150, 104, 66)

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

local function box(parent, size, pos, color, material)
	return mk(parent, Enum.PartType.Block, size, CFrame.new(pos), color, material)
end

-- Вертикальный цилиндр (pos — середина)
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

local function noCollide(p)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

-- Место занято дорожкой/площадкой? (чтобы не ставить туда деревья)
local function onPath(x, z)
	if math.abs(x) < 6 and z > PAD_Z and z < SPAWN.Z + 10 then
		return true
	end
	if math.abs(z - FOUNTAIN.Z) < 5 then
		return true
	end
	if math.abs(x) < 47 and z > PAD_Z - 15 and z < PAD_Z + 15 then
		return true
	end
	local dx, dz = x - FOUNTAIN.X, z - FOUNTAIN.Z
	if dx * dx + dz * dz < 29 * 29 then
		return true
	end
	if math.abs(x - SPAWN.X) < 10 and math.abs(z - SPAWN.Z) < 10 then
		return true
	end
	return false
end

-- ===== Земля, дорога, холмы с тоннелями =====
local function buildTerrain()
	terrain:FillBlock(CFrame.new(0, -8, 0), Vector3.new(1400, 16, 1400), Enum.Material.Grass)

	-- холмы на концах дороги, в них тоннели
	for _, sx in { -1, 1 } do
		local c = Vector3.new(sx * 272, -22, ROAD_Z)
		terrain:FillBall(c, 72, Enum.Material.Grass)
		terrain:FillBall(c + Vector3.new(sx * 34, 8, -44), 56, Enum.Material.Grass)
		terrain:FillBall(c + Vector3.new(sx * 24, 0, 52), 60, Enum.Material.Grass)
		terrain:FillBlock(CFrame.new(sx * (TUNNEL_X + 50), 8.5, ROAD_Z), Vector3.new(100, 19, 32), Enum.Material.Rock)
		terrain:FillBlock(CFrame.new(sx * (TUNNEL_X + 50), 7.5, ROAD_Z), Vector3.new(100, 15, 27), Enum.Material.Air)
	end

	-- дорога и тротуары (заходят внутрь тоннелей)
	terrain:FillBlock(CFrame.new(0, -2, ROAD_Z), Vector3.new(ROAD_HALF * 2, 4, 24), Enum.Material.Asphalt)
	terrain:FillBlock(CFrame.new(0, -2, ROAD_Z + 15), Vector3.new(ROAD_HALF * 2, 4, 6), Enum.Material.Pavement)
	terrain:FillBlock(CFrame.new(0, -2, ROAD_Z - 15), Vector3.new(ROAD_HALF * 2, 4, 6), Enum.Material.Pavement)

	-- лобби: кольцевая дорожка, клумба, дорожки, площадка у кругов, площадка у спавна
	terrain:FillCylinder(CFrame.new(FOUNTAIN + Vector3.new(0, -2, 0)), 4, 27, Enum.Material.Pavement)
	terrain:FillCylinder(CFrame.new(FOUNTAIN + Vector3.new(0, -2, 0)), 4, 21, Enum.Material.Grass)
	terrain:FillBlock(CFrame.new(0, -2, (SPAWN.Z + FOUNTAIN.Z) / 2), Vector3.new(8, 4, SPAWN.Z - FOUNTAIN.Z), Enum.Material.Pavement)
	terrain:FillBlock(CFrame.new(0, -2, FOUNTAIN.Z), Vector3.new(118, 4, 7), Enum.Material.Pavement)
	terrain:FillBlock(CFrame.new(0, -2, (FOUNTAIN.Z + PAD_Z) / 2), Vector3.new(8, 4, FOUNTAIN.Z - PAD_Z), Enum.Material.Pavement)
	terrain:FillBlock(CFrame.new(0, -2, PAD_Z), Vector3.new(84, 4, 26), Enum.Material.Pavement)
	for i = 1, Config.PAD_COUNT do
		local x = (i - (Config.PAD_COUNT + 1) / 2) * 22
		terrain:FillCylinder(CFrame.new(x, -2, PAD_Z), 4, 12.5, Enum.Material.Pavement)
	end
	terrain:FillBlock(CFrame.new(SPAWN.X, -2, SPAWN.Z), Vector3.new(16, 4, 16), Enum.Material.Pavement)
	terrain:FillCylinder(CFrame.new(FOUNTAIN + Vector3.new(0, -2, 0)), 4, 15, Enum.Material.Concrete)

	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(86, 140, 62))
	terrain:SetMaterialColor(Enum.Material.Pavement, Color3.fromRGB(186, 180, 170))
	terrain:SetMaterialColor(Enum.Material.Concrete, Color3.fromRGB(214, 210, 202))
	terrain:SetMaterialColor(Enum.Material.Asphalt, Color3.fromRGB(52, 52, 56))
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(118, 116, 120))

	Scenery.buildMountains(terrain, rng)
end

-- ===== Высокая каменная стена по кругу (гладкая, со скруглённым верхом) =====
local function buildWall(folder)
	local wall = Instance.new("Folder")
	wall.Name = "StoneWall"
	wall.Parent = folder

	local n = 56
	local height = 9
	local chord = 2 * WALL_R * math.sin(math.pi / n) + 0.4
	for i = 0, n - 1 do
		local a = (i / n) * PI2
		local pos = polar(WALL_R, a)
		local cf = CFrame.lookAt(pos, pos + polar(1, a)) -- локальная X идёт вдоль стены
		mk(wall, Enum.PartType.Block, Vector3.new(chord, height, 2.2), cf * CFrame.new(0, height / 2, 0), STONE, Enum.Material.SmoothPlastic)
		-- скруглённый верх (лежачий цилиндр вдоль стены)
		mk(wall, Enum.PartType.Cylinder, Vector3.new(chord + 0.1, 2.8, 2.8), cf * CFrame.new(0, height, 0), STONE_LIGHT, Enum.Material.SmoothPlastic)
		-- скруглённый низ-цоколь
		mk(wall, Enum.PartType.Cylinder, Vector3.new(chord + 0.1, 2.0, 2.0), cf * CFrame.new(0, 0.6, 0), STONE_LIGHT, Enum.Material.SmoothPlastic)
		-- невидимое продолжение вверх: перепрыгнуть нельзя
		local inv = mk(wall, Enum.PartType.Block, Vector3.new(chord, 30, 2), cf * CFrame.new(0, height + 16, 0), Color3.new(), Enum.Material.SmoothPlastic)
		inv.Transparency = 1
		inv.CanQuery = false
		if i % 4 == 0 then
			cyl(wall, height + 2.5, 3.8, pos + Vector3.new(0, (height + 2.5) / 2, 0), STONE, Enum.Material.SmoothPlastic)
			ball(wall, 3.6, pos + Vector3.new(0, height + 2.6, 0), STONE_LIGHT, Enum.Material.SmoothPlastic)
			noCollide(ball(wall, 1.4, pos + Vector3.new(0, height + 4.6, 0), Color3.fromRGB(255, 236, 190), Enum.Material.Neon))
		end
	end
end

-- ===== Современный фонтан: круглый бассейн, два яруса, каскад и дуги струй =====
local function buildFountain(folder)
	local f = Instance.new("Folder")
	f.Name = "Fountain"
	f.Parent = folder
	local c = FOUNTAIN
	local granite = Color3.fromRGB(64, 68, 76)
	local marble = Color3.fromRGB(242, 240, 236)
	local waterColor = Color3.fromRGB(70, 175, 215)

	local function water(height, diameter, y)
		local w = cyl(f, height, diameter, c + Vector3.new(0, y, 0), waterColor, Enum.Material.Glass)
		w.Transparency = 0.25
		w.Reflectance = 0.3
		w.CanCollide = false
		return w
	end

	-- бассейн: тёмное дно, вода, скруглённый белый бортик
	cyl(f, 1.0, 20, c + Vector3.new(0, 0.5, 0), granite, Enum.Material.SmoothPlastic)
	noCollide(cyl(f, 0.1, 19.2, c + Vector3.new(0, 1.02, 0), Color3.fromRGB(110, 230, 255), Enum.Material.Neon))
	water(0.3, 18.8, 1.1)
	local n = 40
	local chord = 2 * 9.6 * math.sin(math.pi / n) + 0.15
	for i = 0, n - 1 do
		local a = (i / n) * PI2
		local pos = c + polar(9.6, a) + Vector3.new(0, 1.3, 0)
		mk(f, Enum.PartType.Cylinder, Vector3.new(chord, 1.2, 1.2), CFrame.lookAt(pos, pos + polar(1, a)), marble, Enum.Material.SmoothPlastic)
	end

	-- нижний ярус с водой сверху, верхняя чаша
	cyl(f, 2.6, 7, c + Vector3.new(0, 1.3, 0), granite, Enum.Material.SmoothPlastic)
	water(0.15, 6.4, 2.65)
	cyl(f, 1.8, 2.6, c + Vector3.new(0, 3.5, 0), marble, Enum.Material.SmoothPlastic)
	cyl(f, 0.5, 4.8, c + Vector3.new(0, 4.6, 0), marble, Enum.Material.SmoothPlastic)
	water(0.12, 4.2, 4.86)

	-- подсветка под водой
	for i = 0, 3 do
		local lp = noCollide(mk(f, Enum.PartType.Block, Vector3.one * 0.4, CFrame.new(c + polar(6, i * math.pi / 2) + Vector3.new(0, 1.1, 0)), Color3.new(), Enum.Material.SmoothPlastic))
		lp.Transparency = 1
		local light = Instance.new("PointLight")
		light.Range = 12
		light.Brightness = 1.5
		light.Color = Color3.fromRGB(120, 220, 255)
		light.Parent = lp
	end

	local function jet(pos, dir, rate, speed, size, life)
		local e = noCollide(mk(f, Enum.PartType.Block, Vector3.one * 0.4, CFrame.lookAt(pos, pos + dir), Color3.new(), Enum.Material.SmoothPlastic))
		e.Transparency = 1
		local pe = Instance.new("ParticleEmitter")
		pe.EmissionDirection = Enum.NormalId.Front
		pe.Rate = rate
		pe.Lifetime = NumberRange.new(life or 0.9, (life or 0.9) + 0.2)
		pe.Speed = NumberRange.new(speed, speed + 1.5)
		pe.SpreadAngle = Vector2.new(2, 2)
		pe.Acceleration = Vector3.new(0, -34, 0)
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size or 0.3), NumberSequenceKeypoint.new(1, (size or 0.3) * 1.8) })
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.8, 0.5), NumberSequenceKeypoint.new(1, 1) })
		pe.Color = ColorSequence.new(Color3.fromRGB(225, 245, 255))
		pe.LightEmission = 0.35
		pe.Parent = e
	end
	-- центральная высокая струя
	jet(c + Vector3.new(0, 5, 0), Vector3.new(0, 1, 0), 80, 17, 0.4, 1.0)
	-- каскад с нижнего яруса
	for i = 0, 7 do
		local a = (i / 8) * PI2
		jet(c + polar(3.4, a) + Vector3.new(0, 2.7, 0), (polar(1, a) + Vector3.new(0, 0.3, 0)).Unit, 30, 3, 0.35, 0.6)
	end
	-- дуги от бортика к центру
	for i = 0, 11 do
		local a = (i / 12) * PI2
		jet(c + polar(8.8, a) + Vector3.new(0, 1.4, 0), (-polar(1, a) * 0.55 + Vector3.new(0, 1, 0)).Unit, 35, 11, 0.28, 0.9)
	end
end

-- ===== Лавочки и фонари =====
local function bench(parent, cf)
	local concrete = Color3.fromRGB(200, 196, 188)
	for _, sx in { -2.4, 2.4 } do
		mk(parent, Enum.PartType.Block, Vector3.new(0.8, 1.4, 1.9), cf * CFrame.new(sx, 0.7, 0), concrete, Enum.Material.Concrete)
	end
	for k = -1, 1 do
		mk(parent, Enum.PartType.Block, Vector3.new(6, 0.22, 0.55), cf * CFrame.new(0, 1.52, k * 0.62), WOOD, Enum.Material.WoodPlanks)
	end
	for k = 0, 1 do
		mk(parent, Enum.PartType.Block, Vector3.new(6, 0.5, 0.18), cf * CFrame.new(0, 2.1 + k * 0.65, 1.0) * CFrame.Angles(math.rad(-12), 0, 0), WOOD, Enum.Material.WoodPlanks)
	end
	for _, sx in { -2.4, 2.4 } do
		mk(parent, Enum.PartType.Block, Vector3.new(0.18, 1.7, 0.18), cf * CFrame.new(sx, 2.25, 1.05), DARK_METAL, Enum.Material.Metal)
	end
end

local function lamp(parent, pos, armDir)
	cyl(parent, 9, 0.45, pos + Vector3.new(0, 4.5, 0), DARK_METAL, Enum.Material.Metal)
	local armEnd = pos + armDir * 1.6 + Vector3.new(0, 9, 0)
	mk(parent, Enum.PartType.Block, Vector3.new(0.3, 0.3, 1.9), CFrame.lookAt(pos + armDir * 0.8 + Vector3.new(0, 9, 0), armEnd), DARK_METAL, Enum.Material.Metal)
	local head = box(parent, Vector3.new(1.4, 0.35, 1.4), armEnd - Vector3.new(0, 0.15, 0), DARK_METAL, Enum.Material.Metal)
	local glow = box(parent, Vector3.new(1.1, 0.1, 1.1), armEnd - Vector3.new(0, 0.36, 0), Color3.fromRGB(255, 240, 205), Enum.Material.Neon)
	noCollide(glow)
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Range = 22
	light.Angle = 100
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 236, 200)
	light.Parent = glow
	return head
end

local function buildFurniture(folder)
	local f = Instance.new("Folder")
	f.Name = "Furniture"
	f.Parent = folder

	-- лавочки на кольцевой дорожке, лицом к фонтану
	for _, deg in { 30, 60, 120, 150, 210, 240, 300, 330 } do
		local pos = FOUNTAIN + polar(24.6, math.rad(deg))
		bench(f, CFrame.lookAt(pos, Vector3.new(FOUNTAIN.X, 0, FOUNTAIN.Z)))
	end

	-- фонари вдоль дорожек и вокруг кольца
	for _, deg in { 0, 90, 180, 270 } do
		local a = math.rad(deg + 45)
		local pos = FOUNTAIN + polar(28.2, a)
		lamp(f, pos, -polar(1, a))
	end
	for _, x in { -44, 0, 44 } do
		lamp(f, Vector3.new(x, 0, PAD_Z - 14), Vector3.new(0, 0, 1))
	end
end

-- ===== Клумбы, кусты, деревья =====
local function buildGreenery(folder, houseSpots)
	local f = Instance.new("Folder")
	f.Name = "Greenery"
	f.Parent = folder
	local flowerColors = {
		Color3.fromRGB(240, 90, 110),
		Color3.fromRGB(250, 220, 80),
		Color3.fromRGB(245, 245, 245),
		Color3.fromRGB(170, 120, 240),
		Color3.fromRGB(255, 150, 60),
	}

	local function bush(pos, d)
		local g = rng:NextInteger(0, 25)
		local b = mk(f, Enum.PartType.Block, Vector3.new(d, d * 0.75, d), CFrame.new(pos + Vector3.new(0, d * 0.32, 0)), Color3.fromRGB(52 + g, 112 + g, 50), Enum.Material.Grass)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = b
		noCollide(b)
		return b
	end
	local function flower(pos)
		local fl = ball(f, 0.6, pos + Vector3.new(0, 0.35, 0), flowerColors[rng:NextInteger(1, #flowerColors)], Enum.Material.SmoothPlastic)
		noCollide(fl)
	end

	-- клумба-кольцо вокруг фонтана
	for i = 0, 59 do
		local a = (i / 60) * PI2
		local pos = FOUNTAIN + polar(rng:NextNumber(16, 20), a)
		if not (math.abs(pos.X) < 5 or math.abs(pos.Z - FOUNTAIN.Z) < 4.5) then
			if i % 3 == 0 then
				bush(pos, rng:NextNumber(1.6, 2.4))
			else
				flower(pos)
				flower(pos + Vector3.new(rng:NextNumber(-0.8, 0.8), 0, rng:NextNumber(-0.8, 0.8)))
			end
		end
	end

	-- живая изгородь вдоль стены изнутри
	for i = 0, 89 do
		local a = (i / 90) * PI2
		bush(polar(WALL_R - 3, a), rng:NextNumber(3, 4.2))
	end

	local function tree(x, z, scale)
		local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, rng:NextNumber(0, PI2), 0)
		Forest.makeTree(cf, scale or rng:NextNumber(0.9, 1.5), rng).Parent = f
	end

	-- деревья на газонах внутри лобби
	local placed = 0
	for _ = 1, 200 do
		if placed >= 16 then
			break
		end
		local pos = polar(rng:NextNumber(34, 56), rng:NextNumber(0, PI2))
		if not onPath(pos.X, pos.Z) then
			tree(pos.X, pos.Z, rng:NextNumber(0.9, 1.3))
			for _ = 1, 5 do
				flower(pos + Vector3.new(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4)))
			end
			placed += 1
		end
	end

	-- деревья снаружи: между стеной и домами, среди домов
	local function nearHouse(x, z)
		for _, h in houseSpots do
			local dx, dz = x - h.X, z - h.Y
			if dx * dx + dz * dz < 40 * 40 then
				return true
			end
		end
		return false
	end
	local function nearTunnelHill(x, z)
		for _, sx in { -1, 1 } do
			local dx, dz = x - sx * 272, z - ROAD_Z
			if dx * dx + dz * dz < 110 * 110 then
				return true
			end
		end
		return false
	end
	for _ = 1, 360 do
		local pos = polar(rng:NextNumber(70, 340), rng:NextNumber(0, PI2))
		if math.abs(pos.Z - ROAD_Z) > 24 and not nearHouse(pos.X, pos.Z) and not nearTunnelHill(pos.X, pos.Z) then
			tree(pos.X, pos.Z)
		end
	end
end

-- ===== Дорога: разметка, бордюры, фонари, порталы тоннелей =====
local function buildRoad(folder)
	local f = Instance.new("Folder")
	f.Name = "Road"
	f.Parent = folder
	local len = ROAD_HALF * 2
	local white = Color3.fromRGB(240, 240, 235)
	local yellow = Color3.fromRGB(245, 200, 40)

	for _, dz in { -0.35, 0.35 } do
		noCollide(box(f, Vector3.new(len, 0.1, 0.25), Vector3.new(0, 0.06, ROAD_Z + dz), yellow, Enum.Material.SmoothPlastic))
	end
	for _, dz in { -11.2, 11.2 } do
		noCollide(box(f, Vector3.new(len, 0.1, 0.35), Vector3.new(0, 0.06, ROAD_Z + dz), white, Enum.Material.SmoothPlastic))
	end
	for _, dz in { -12.3, 12.3, -18.2, 18.2 } do
		box(f, Vector3.new(len, 0.5, 0.6), Vector3.new(0, 0.25, ROAD_Z + dz), STONE_LIGHT, Enum.Material.Concrete)
	end

	-- уличные фонари вдоль дороги
	for x = -TUNNEL_X + 16, TUNNEL_X - 16, 32 do
		lamp(f, Vector3.new(x, 0, ROAD_Z + 16.5), Vector3.new(0, 0, -1))
		lamp(f, Vector3.new(x + 16, 0, ROAD_Z - 16.5), Vector3.new(0, 0, 1))
	end

	-- порталы тоннелей
	for _, sx in { -1, 1 } do
		local x = sx * (TUNNEL_X - 1)
		for _, dz in { -14.5, 14.5 } do
			box(f, Vector3.new(3, 16, 3), Vector3.new(x, 8, ROAD_Z + dz), STONE, Enum.Material.SmoothPlastic)
		end
		box(f, Vector3.new(3.4, 3.6, 32.4), Vector3.new(x, 17.4, ROAD_Z), STONE, Enum.Material.SmoothPlastic)
		box(f, Vector3.new(3.6, 0.6, 33), Vector3.new(x, 19.4, ROAD_Z), STONE_LIGHT, Enum.Material.Concrete)
	end
end

-- ===== Круги-площадки с невидимыми барьерами =====
local function ensureGroup(name)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(name)
	end)
end

local function buildPads(folder)
	local radius = Config.PAD_RADIUS
	local segments = 32

	for i = 1, Config.PAD_COUNT do
		local x = (i - (Config.PAD_COUNT + 1) / 2) * 22
		local z = PAD_Z

		local barrierGroup = "Barrier" .. i
		ensureGroup(barrierGroup)
		ensureGroup("PadMember" .. i)

		local rim = mk(
			folder,
			Enum.PartType.Cylinder,
			Vector3.new(0.3, radius * 2 + 1.6, radius * 2 + 1.6),
			CFrame.new(x, 0.3, z) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(245, 245, 240),
			Enum.Material.Marble
		)
		rim.Name = "PadRim" .. i
		noCollide(rim)

		local pad = mk(
			folder,
			Enum.PartType.Cylinder,
			Vector3.new(0.3, radius * 2, radius * 2),
			CFrame.new(x, 0.38, z) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(255, 205, 40),
			Enum.Material.Neon
		)
		pad.Name = "Pad" .. i
		noCollide(pad)
		pad.Transparency = 0.15
		local glow = Instance.new("PointLight")
		glow.Range = 14
		glow.Brightness = 1.2
		glow.Color = pad.Color
		glow.Parent = pad

		-- пунктирное белое кольцо вокруг круга
		for d = 0, 19 do
			local a = (d / 20) * PI2
			local pos = Vector3.new(x, 0.55, z) + polar(radius + 0.4, a)
			local dash = mk(folder, Enum.PartType.Block, Vector3.new(1.5, 0.1, 0.4), CFrame.lookAt(pos, pos + polar(1, a)), Color3.new(1, 1, 1), Enum.Material.Neon)
			noCollide(dash)
		end

		-- невидимый барьер: кольцо из сегментов
		local barrier = Instance.new("Folder")
		barrier.Name = "Barrier" .. i
		barrier.Parent = folder
		local br = radius + 0.6
		local chord = 2 * br * math.sin(math.pi / segments) + 0.25
		for s = 0, segments - 1 do
			local a = (s / segments) * PI2
			local pos = Vector3.new(x, 7, z) + polar(br, a)
			local seg = mk(barrier, Enum.PartType.Block, Vector3.new(chord, 14, 0.5), CFrame.lookAt(pos, pos + polar(1, a)), Color3.new(), Enum.Material.SmoothPlastic)
			seg.Transparency = 1
			seg.CanQuery = false
			seg.CanTouch = false
			seg.CollisionGroup = barrierGroup
		end
		PhysicsService:CollisionGroupSetCollidable(barrierGroup, "Default", false)

		-- надпись над кругом (размер в студах, чтобы соседние не налезали)
		local anchor = box(folder, Vector3.one, Vector3.new(x, 8, z), Color3.new(), Enum.Material.SmoothPlastic)
		anchor.Name = "LabelAnchor" .. i
		anchor.Transparency = 1
		noCollide(anchor)

		local gui = Instance.new("BillboardGui")
		gui.Adornee = anchor
		gui.Size = UDim2.new(16, 0, 4, 0)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 400
		gui.LightInfluence = 0
		gui.Brightness = 2
		gui.Parent = anchor

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Text = ""
		label.Parent = gui
		-- неоновое свечение вокруг букв
		local glowStroke = Instance.new("UIStroke")
		glowStroke.Name = "Glow"
		glowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		glowStroke.Thickness = 3
		glowStroke.Color = Color3.fromRGB(255, 160, 0)
		glowStroke.Parent = label

		local function setBarrier(mode, color)
			pad.Color = color
			glow.Color = color
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
	local floor = cyl(folder, 1, WALL_R * 2 + 6, Vector3.new(0, -0.5, 0), Color3.new(), Enum.Material.SmoothPlastic)
	floor.Name = "SafetyFloor"
	floor.Transparency = 1
	floor.CanQuery = false

	-- точка появления: светлая плита с подсвеченной рамкой
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 0.5, 10)
	spawn.CFrame = CFrame.new(SPAWN + Vector3.new(0, 0.25, 0))
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(236, 236, 232)
	spawn.Material = Enum.Material.Marble
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = folder
	for _, e in {
		{ Vector3.new(10.6, 0.2, 0.6), Vector3.new(0, 0, 5) },
		{ Vector3.new(10.6, 0.2, 0.6), Vector3.new(0, 0, -5) },
		{ Vector3.new(0.6, 0.2, 10.6), Vector3.new(5, 0, 0) },
		{ Vector3.new(0.6, 0.2, 10.6), Vector3.new(-5, 0, 0) },
	} do
		noCollide(box(folder, e[1], SPAWN + e[2] + Vector3.new(0, 0.55, 0), Color3.fromRGB(110, 200, 255), Enum.Material.Neon))
	end
end

function Hub.build()
	local folder = Instance.new("Folder")
	folder.Name = "Hub"
	folder.Parent = Workspace

	buildSafety(folder)
	buildTerrain()

	-- Поверхность террейна оказывается не ровно на y=0, поэтому меряем её лучом
	-- и ставим всё лобби ровно на землю (иначе круги, лавочки и колёса тонут).
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { terrain }
	local hit = Workspace:Raycast(Vector3.new(SPAWN.X, 120, SPAWN.Z), Vector3.new(0, -240, 0), params)
	local groundY = hit and hit.Position.Y or 0
	Workspace:SetAttribute("HubGroundY", groundY)
	-- спавн и страховочный пол поднимаем сразу
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame += Vector3.new(0, groundY, 0)
		end
	end
	local built = {}
	for _, d in folder:GetChildren() do
		built[d] = true
	end
	local houseSpots = Scenery.buildTown(folder, rng)
	buildWall(folder)
	buildFountain(folder)
	buildFurniture(folder)
	buildRoad(folder)
	buildGreenery(folder, houseSpots)
	buildPads(folder)

	for _, child in folder:GetChildren() do
		if not built[child] then
			for _, d in child:GetDescendants() do
				if d:IsA("BasePart") then
					d.CFrame += Vector3.new(0, groundY, 0)
				end
			end
			if child:IsA("BasePart") then
				child.CFrame += Vector3.new(0, groundY, 0)
			end
		end
	end
	for _, pad in Hub.pads do
		pad.center += Vector3.new(0, groundY, 0)
	end

	return Hub.pads
end

return Hub
