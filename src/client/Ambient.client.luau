-- Атмосфера на клиенте: музыка, птицы в небе и машины на дороге за забором.
-- Всё считается локально у игрока и ничего не нагружает сервер.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local rng = Random.new()

-- высота земли в хабе (сервер меряет её лучом после постройки)
while Workspace:GetAttribute("HubGroundY") == nil do
	task.wait(0.2)
end
local HUB_Y = Workspace:GetAttribute("HubGroundY")

-- ===== Зона, где сейчас игрок =====
local function currentZone()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return "hub"
	end
	local x = root.Position.X
	if x > 2000 then
		return "forest"
	elseif x < -2000 then
		return "stage"
	end
	return "hub"
end

-- ===== Музыка =====
local function makeSound(id, volume)
	if id == nil or tostring(id) == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. tostring(id)
	s.Looped = true
	s.Volume = 0
	s.Parent = SoundService
	s:Play()
	return { sound = s, volume = volume }
end

local hubMusic = makeSound(Config.HUB_MUSIC_ID, 0.45)
local forestMusic = makeSound(Config.FOREST_MUSIC_ID, 0.45)

local function fadeTo(track, on)
	if not track then
		return
	end
	local target = on and track.volume or 0
	if math.abs(track.sound.Volume - target) > 0.01 and not track.tween then
		track.tween = TweenService:Create(track.sound, TweenInfo.new(1.5), { Volume = target })
		track.tween.Completed:Once(function()
			track.tween = nil
		end)
		track.tween:Play()
	end
end

-- Дымка: в лесу густая (дальние края растворяются, мир не выглядит островом), в лобби лёгкая
local Lighting = game:GetService("Lighting")
local FOG = {
	hub = { Density = 0.14, Haze = 0.5, Offset = 0.2, Color = Color3.fromRGB(205, 220, 240) },
	stage = { Density = 0.3, Haze = 1.2, Offset = 0.1, Color = Color3.fromRGB(205, 220, 230) },
	forest = { Density = 0.46, Haze = 2.2, Offset = 0.05, Color = Color3.fromRGB(190, 205, 200) },
}
local lastZone

task.spawn(function()
	while true do
		local zone = currentZone()
		fadeTo(hubMusic, zone == "hub")
		fadeTo(forestMusic, zone == "forest")
		if zone ~= lastZone then
			lastZone = zone
			local atm = Lighting:FindFirstChildOfClass("Atmosphere")
			if atm and FOG[zone] then
				TweenService:Create(atm, TweenInfo.new(1.5), FOG[zone]):Play()
			end
		end
		task.wait(0.5)
	end
end)

-- ===== Птицы =====
local function bodyPart(parent, shape, size, color)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Shape = shape
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

local birdFolder = Instance.new("Folder")
birdFolder.Name = "Birds"
birdFolder.Parent = Workspace

local function blob(parent, size, color)
	local p = bodyPart(parent, Enum.PartType.Block, size, color)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- Небольшие птицы: тело-овал, голова, клюв, хвост и крылья из двух частей
-- (плечо и кисть), машут и периодически парят.
local birds = {}
local birdColors = {
	{ Color3.fromRGB(48, 48, 52), Color3.fromRGB(30, 30, 34) }, -- ворона
	{ Color3.fromRGB(235, 236, 238), Color3.fromRGB(120, 124, 132) }, -- чайка
	{ Color3.fromRGB(112, 84, 60), Color3.fromRGB(70, 52, 38) }, -- воробей
	{ Color3.fromRGB(96, 104, 118), Color3.fromRGB(60, 66, 78) }, -- голубь
}
for i = 1, 14 do
	local c = birdColors[rng:NextInteger(1, #birdColors)]
	local model = Instance.new("Model")
	model.Name = "Bird" .. i
	model.Parent = birdFolder
	birds[i] = {
		body = blob(model, Vector3.new(0.55, 0.5, 1.4), c[1]),
		head = blob(model, Vector3.new(0.42, 0.42, 0.46), c[1]),
		beak = bodyPart(model, Enum.PartType.Block, Vector3.new(0.1, 0.08, 0.3), Color3.fromRGB(230, 160, 40)),
		tail = bodyPart(model, Enum.PartType.Block, Vector3.new(0.45, 0.05, 0.55), c[2]),
		wingInL = bodyPart(model, Enum.PartType.Block, Vector3.new(0.9, 0.05, 0.55), c[1]),
		wingInR = bodyPart(model, Enum.PartType.Block, Vector3.new(0.9, 0.05, 0.55), c[1]),
		wingOutL = bodyPart(model, Enum.PartType.Block, Vector3.new(0.85, 0.04, 0.4), c[2]),
		wingOutR = bodyPart(model, Enum.PartType.Block, Vector3.new(0.85, 0.04, 0.4), c[2]),
		-- половина кружит над лобби, половина над лесом (не за игроком)
		home = i % 2 == 0 and Vector3.new(0, HUB_Y, -10) or (Config.FOREST_ORIGIN + Vector3.new(0, 20, 0)),
		radius = rng:NextNumber(25, 70),
		height = rng:NextNumber(30, 55),
		speed = rng:NextNumber(0.25, 0.45) * (rng:NextNumber() < 0.5 and -1 or 1),
		phase = rng:NextNumber(0, math.pi * 2),
	}
end


-- ===== Машины на дороге =====
local BLOCK, BALL, CYL = Enum.PartType.Block, Enum.PartType.Ball, Enum.PartType.Cylinder
local GLASS = Color3.fromRGB(28, 38, 50)
local BLACK = Color3.fromRGB(22, 22, 25)
local GRAY = Color3.fromRGB(52, 54, 60)
local CHROME = Color3.fromRGB(205, 208, 214)

-- Машина: +X вперёд, Y вверх, Z вправо. Возвращает части и их локальные CFrame.
local function buildCar(kind, color)
	local model = Instance.new("Model")
	model.Name = "Car"
	local parts, locals, wheels = {}, {}, {}

	local function add(shape, size, rel, col, material, transparency, reflectance)
		local p = bodyPart(model, shape, size, col)
		p.Material = material or Enum.Material.SmoothPlastic
		p.Transparency = transparency or 0
		p.Reflectance = reflectance or 0
		table.insert(parts, p)
		table.insert(locals, rel)
		return #parts
	end
	local function box(size, pos, col, material, transparency, reflectance)
		return add(BLOCK, size, CFrame.new(pos), col, material, transparency, reflectance)
	end
	-- плита вдоль отрезка (x1,y1)-(x2,y2) в плоскости XY: стёкла, стойки
	local function plate(x1, y1, x2, y2, width, thick, z, col, material, transparency, reflectance)
		local dx, dy = x2 - x1, y2 - y1
		local len = math.sqrt(dx * dx + dy * dy)
		return add(
			BLOCK,
			Vector3.new(len, thick, width),
			CFrame.new((x1 + x2) / 2, (y1 + y2) / 2, z) * CFrame.Angles(0, 0, math.atan2(dy, dx)),
			col,
			material,
			transparency,
			reflectance
		)
	end
	local paint = Enum.Material.SmoothPlastic
	local gloss = 0.18

	local function wheelSet(positions, radius)
		for _, w in positions do
			local base = CFrame.new(w.x, radius, w.z) * CFrame.Angles(0, math.rad(90), 0)
			-- тёмная арка вокруг колеса (не вращается)
			add(CYL, Vector3.new(0.15, radius * 2 + 0.7, radius * 2 + 0.7), CFrame.new(w.x, radius, w.z * 1.03) * CFrame.Angles(0, math.rad(90), 0), BLACK)
			local tire = add(CYL, Vector3.new(1.1, radius * 2, radius * 2), base, BLACK, Enum.Material.SmoothPlastic)
			local rim = add(CYL, Vector3.new(1.15, radius * 1.3, radius * 1.3), base, CHROME, Enum.Material.Metal, 0, 0.35)
			local hub = add(CYL, Vector3.new(1.2, radius * 0.4, radius * 0.4), base, GRAY, Enum.Material.Metal)
			local mark = add(BLOCK, Vector3.new(1.17, 0.22, radius * 1.15), base, Color3.fromRGB(90, 92, 98), Enum.Material.Metal)
			table.insert(wheels, { tire, rim, hub, mark })
		end
	end

	local function lightsAndPlates(frontX, rearX, lightY, tailY)
		for _, sz in { -1, 1 } do
			box(Vector3.new(0.12, 0.7, 1.7), Vector3.new(frontX - 0.05, lightY, sz * 2.1), GRAY, Enum.Material.Metal)
			box(Vector3.new(0.16, 0.45, 1.35), Vector3.new(frontX + 0.02, lightY, sz * 2.1), Color3.fromRGB(255, 252, 235), Enum.Material.Neon)
			box(Vector3.new(0.16, 0.5, 1.9), Vector3.new(rearX - 0.02, tailY, sz * 2.0), Color3.fromRGB(215, 30, 35), Enum.Material.Neon)
		end
		box(Vector3.new(0.1, 0.6, 1.6), Vector3.new(frontX + 0.35, 1.4, 0), Color3.fromRGB(240, 240, 235))
		box(Vector3.new(0.1, 0.6, 1.6), Vector3.new(rearX - 0.35, 1.4, 0), Color3.fromRGB(240, 240, 235))
	end

	if kind == "sedan" then
		box(Vector3.new(13.2, 0.4, 5.2), Vector3.new(0, 0.95, 0), BLACK) -- днище
		box(Vector3.new(14.2, 1.6, 6.0), Vector3.new(0, 1.9, 0), color, paint, 0, gloss)
		box(Vector3.new(4.8, 0.5, 5.8), Vector3.new(4.8, 2.95, 0), color, paint, 0, gloss) -- капот
		box(Vector3.new(3.6, 0.5, 5.8), Vector3.new(-5.2, 2.95, 0), color, paint, 0, gloss) -- багажник
		box(Vector3.new(6.2, 0.5, 5.8), Vector3.new(-0.5, 2.95, 0), color, paint, 0, gloss) -- линия окон
		-- остекление
		plate(2.6, 3.2, 0.9, 5.0, 5.2, 0.12, 0, GLASS, Enum.Material.Glass, 0.1, 0.35)
		plate(-3.0, 3.2, -1.8, 5.0, 5.2, 0.12, 0, GLASS, Enum.Material.Glass, 0.1, 0.35)
		box(Vector3.new(2.7, 0.3, 5.5), Vector3.new(-0.45, 5.1, 0), color, paint, 0, gloss) -- крыша
		for _, sz in { -1, 1 } do
			local z = sz * 2.8
			box(Vector3.new(4.8, 0.9, 0.1), Vector3.new(-0.2, 3.65, z), GLASS, Enum.Material.Glass, 0.1, 0.35)
			box(Vector3.new(3.0, 0.85, 0.1), Vector3.new(-0.4, 4.52, z), GLASS, Enum.Material.Glass, 0.1, 0.35)
			plate(2.6, 3.2, 0.9, 5.0, 0.3, 0.25, z, color, paint, 0, gloss) -- A-стойка
			plate(-3.0, 3.2, -1.8, 5.0, 0.3, 0.25, z, color, paint, 0, gloss) -- C-стойка
			box(Vector3.new(0.3, 1.8, 0.14), Vector3.new(-0.4, 4.1, z), BLACK) -- B-стойка
			box(Vector3.new(0.5, 0.35, 0.5), Vector3.new(1.9, 3.6, sz * 3.3), color, paint, 0, gloss) -- зеркало
			box(Vector3.new(9.5, 0.22, 0.1), Vector3.new(0, 1.2, sz * 3.03), GRAY, Enum.Material.Metal) -- порог
			box(Vector3.new(0.06, 1.5, 0.06), Vector3.new(1.7, 2.1, sz * 3.02), BLACK) -- швы дверей
			box(Vector3.new(0.06, 1.5, 0.06), Vector3.new(-1.9, 2.1, sz * 3.02), BLACK)
			box(Vector3.new(0.5, 0.12, 0.1), Vector3.new(0.5, 2.7, sz * 3.03), CHROME, Enum.Material.Metal) -- ручки
		end
		box(Vector3.new(0.7, 1.1, 6.0), Vector3.new(7.15, 1.5, 0), GRAY, Enum.Material.Metal) -- бампер
		box(Vector3.new(0.7, 1.1, 6.0), Vector3.new(-7.15, 1.5, 0), GRAY, Enum.Material.Metal)
		box(Vector3.new(0.15, 0.7, 3.2), Vector3.new(7.45, 2.3, 0), BLACK) -- решётка
		box(Vector3.new(0.12, 0.12, 3.4), Vector3.new(7.47, 2.72, 0), CHROME, Enum.Material.Metal, 0, 0.4)
		lightsAndPlates(7.25, -7.25, 2.75, 2.85)
		local pos = {}
		for _, wx in { -4.4, 4.6 } do
			for _, wz in { -2.85, 2.85 } do
				table.insert(pos, { x = wx, z = wz })
			end
		end
		wheelSet(pos, 1.5)
	elseif kind == "suv" then
		box(Vector3.new(13.2, 0.4, 5.4), Vector3.new(0, 1.15, 0), BLACK)
		box(Vector3.new(14.2, 1.9, 6.2), Vector3.new(0, 2.2, 0), color, paint, 0, gloss)
		box(Vector3.new(3.8, 0.5, 6.0), Vector3.new(5.2, 3.4, 0), color, paint, 0, gloss) -- капот
		box(Vector3.new(9.8, 0.5, 6.0), Vector3.new(-2.1, 3.4, 0), color, paint, 0, gloss)
		plate(3.3, 3.6, 1.8, 5.6, 5.4, 0.12, 0, GLASS, Enum.Material.Glass, 0.1, 0.35)
		plate(-7.0, 3.6, -6.7, 5.6, 5.4, 0.12, 0, GLASS, Enum.Material.Glass, 0.1, 0.35)
		box(Vector3.new(8.3, 0.3, 5.7), Vector3.new(-2.45, 5.75, 0), color, paint, 0, gloss) -- крыша
		box(Vector3.new(7.4, 0.14, 0.2), Vector3.new(-2.5, 6.0, 1.9), BLACK) -- рейлинги
		box(Vector3.new(7.4, 0.14, 0.2), Vector3.new(-2.5, 6.0, -1.9), BLACK)
		for _, sz in { -1, 1 } do
			local z = sz * 2.95
			box(Vector3.new(9.4, 1.0, 0.1), Vector3.new(-1.9, 4.1, z), GLASS, Enum.Material.Glass, 0.1, 0.35)
			box(Vector3.new(7.6, 0.9, 0.1), Vector3.new(-2.1, 5.1, z), GLASS, Enum.Material.Glass, 0.1, 0.35)
			plate(3.3, 3.6, 1.8, 5.6, 0.3, 0.25, z, color, paint, 0, gloss)
			box(Vector3.new(0.3, 2.0, 0.14), Vector3.new(-1.6, 4.6, z), BLACK)
			box(Vector3.new(0.3, 2.0, 0.14), Vector3.new(-4.4, 4.6, z), BLACK)
			box(Vector3.new(0.5, 0.35, 0.5), Vector3.new(2.5, 4.0, sz * 3.4), color, paint, 0, gloss)
			box(Vector3.new(9.5, 0.25, 0.1), Vector3.new(0, 1.3, sz * 3.13), GRAY, Enum.Material.Metal)
			box(Vector3.new(0.06, 1.6, 0.06), Vector3.new(1.4, 2.3, sz * 3.12), BLACK)
			box(Vector3.new(0.06, 1.6, 0.06), Vector3.new(-2.8, 2.3, sz * 3.12), BLACK)
		end
		box(Vector3.new(0.7, 1.2, 6.2), Vector3.new(7.15, 1.6, 0), GRAY, Enum.Material.Metal)
		box(Vector3.new(0.7, 1.2, 6.2), Vector3.new(-7.15, 1.6, 0), GRAY, Enum.Material.Metal)
		box(Vector3.new(0.15, 0.8, 3.4), Vector3.new(7.45, 2.6, 0), BLACK)
		lightsAndPlates(7.25, -7.25, 3.0, 3.1)
		local pos = {}
		for _, wx in { -4.5, 4.7 } do
			for _, wz in { -2.95, 2.95 } do
				table.insert(pos, { x = wx, z = wz })
			end
		end
		wheelSet(pos, 1.65)
	else -- грузовик с фургоном
		box(Vector3.new(15, 0.5, 5.4), Vector3.new(0, 1.9, 0), BLACK, Enum.Material.Metal) -- рама
		box(Vector3.new(4.4, 3.5, 6.0), Vector3.new(5.4, 3.95, 0), color, paint, 0, gloss) -- кабина
		plate(7.6, 4.6, 6.9, 6.0, 5.4, 0.12, 0, GLASS, Enum.Material.Glass, 0.1, 0.35)
		box(Vector3.new(0.3, 0.8, 6.0), Vector3.new(7.55, 3.3, 0), color, paint, 0, gloss)
		box(Vector3.new(2.4, 1.3, 0.1), Vector3.new(5.6, 4.7, 3.03), GLASS, Enum.Material.Glass, 0.1, 0.35)
		box(Vector3.new(2.4, 1.3, 0.1), Vector3.new(5.6, 4.7, -3.03), GLASS, Enum.Material.Glass, 0.1, 0.35)
		box(Vector3.new(9.4, 5.0, 6.4), Vector3.new(-2.6, 5.0, 0), Color3.fromRGB(236, 236, 232), paint, 0, 0.1) -- фургон
		for k = -3, 3 do
			box(Vector3.new(0.14, 4.6, 6.46), Vector3.new(-2.6 + k * 1.3, 5.0, 0), Color3.fromRGB(205, 205, 200), paint)
		end
		box(Vector3.new(9.4, 0.5, 6.5), Vector3.new(-2.6, 7.6, 0), Color3.fromRGB(215, 215, 210), paint)
		box(Vector3.new(9.4, 0.8, 6.5), Vector3.new(-2.6, 3.0, 0), color, paint, 0, gloss) -- цветная полоса
		for _, sz in { -1, 1 } do
			box(Vector3.new(0.6, 0.5, 0.9), Vector3.new(7.0, 5.2, sz * 3.5), GRAY, Enum.Material.Metal) -- зеркала
			box(Vector3.new(6, 0.25, 0.1), Vector3.new(0, 2.3, sz * 3.03), GRAY, Enum.Material.Metal)
		end
		box(Vector3.new(0.8, 1.2, 6.2), Vector3.new(7.9, 2.0, 0), GRAY, Enum.Material.Metal)
		box(Vector3.new(0.6, 1.0, 6.4), Vector3.new(-7.4, 2.0, 0), GRAY, Enum.Material.Metal)
		box(Vector3.new(0.15, 0.9, 3.4), Vector3.new(8.1, 3.0, 0), BLACK)
		lightsAndPlates(8.05, -7.7, 3.4, 2.7)
		local pos = {}
		for _, wx in { 5.4, -1.6, -5.0 } do
			for _, wz in { -2.9, 2.9 } do
				table.insert(pos, { x = wx, z = wz })
			end
		end
		wheelSet(pos, 1.75)
	end

	model.Parent = birdFolder
	return { model = model, parts = parts, locals = locals, wheels = wheels }
end

local carColors = {
	Color3.fromRGB(176, 178, 184), -- серебристый
	Color3.fromRGB(28, 30, 34), -- чёрный
	Color3.fromRGB(238, 238, 240), -- белый
	Color3.fromRGB(30, 54, 98), -- тёмно-синий
	Color3.fromRGB(140, 28, 34), -- бордовый
	Color3.fromRGB(80, 84, 92), -- графит
	Color3.fromRGB(34, 70, 56), -- тёмно-зелёный
	Color3.fromRGB(190, 160, 110), -- песочный
}

-- машины разворачиваются внутри тоннелей на концах дороги
local LANE_LENGTH = Config.CAR_WRAP_X * 2
local cars = {}
local function addLane(dir, laneZ, speed, count)
	for i = 1, count do
		local roll = rng:NextNumber()
		local kind = roll < 0.5 and "sedan" or (roll < 0.8 and "suv" or "truck")
		local car = buildCar(kind, carColors[rng:NextInteger(1, #carColors)])
		car.dir = dir
		car.laneZ = laneZ
		car.speed = speed
		car.offset = (i / count) * LANE_LENGTH + rng:NextNumber(-25, 25)
		table.insert(cars, car)
	end
end
addLane(1, Config.ROAD_Z + 6, 30, 4)
addLane(-1, Config.ROAD_Z - 6, 26, 4)

-- ===== Обновление каждый кадр =====
local t0 = os.clock()
RunService.RenderStepped:Connect(function(dt)
	local t = os.clock() - t0
	local zone = currentZone()

	local parts, cframes = {}, {}
	local function put(part, cf)
		table.insert(parts, part)
		table.insert(cframes, cf)
	end
	for _, b in birds do
		local a = b.phase + t * b.speed
		local dir = b.speed > 0 and 1 or -1
		local pos = b.home + Vector3.new(math.cos(a) * b.radius, b.height + math.sin(t * 0.5 + b.phase) * 4, math.sin(a) * b.radius)
		local tangent = Vector3.new(-math.sin(a), 0, math.cos(a)) * dir
		-- крен внутрь поворота и лёгкий наклон носом при наборе высоты
		local cf = CFrame.lookAt(pos, pos + tangent) * CFrame.Angles(math.cos(t * 0.5 + b.phase) * 0.08, 0, -0.32 * dir)
		-- серия взмахов, потом парение
		local amp = math.clamp((math.sin(t * 0.6 + b.phase * 2) + 0.2) * 2, 0, 1)
		local flap = 0.12 + amp * math.sin(t * 11 + b.phase) * 0.7
		put(b.body, cf)
		put(b.head, cf * CFrame.new(0, 0.14, -0.78))
		put(b.beak, cf * CFrame.new(0, 0.1, -1.08))
		put(b.tail, cf * CFrame.new(0, 0.04, 0.9) * CFrame.Angles(math.rad(-8), 0, 0))
		for _, side in { 1, -1 } do
			local shoulder = cf * CFrame.new(side * 0.22, 0.1, -0.05) * CFrame.Angles(0, 0, side * flap)
			put(side == 1 and b.wingInR or b.wingInL, shoulder * CFrame.new(side * 0.45, 0, 0))
			put(
				side == 1 and b.wingOutR or b.wingOutL,
				shoulder * CFrame.new(side * 0.9, 0, 0) * CFrame.Angles(0, 0, side * flap * 0.6) * CFrame.new(side * 0.42, 0, 0.06)
			)
		end
	end
	Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)

	-- Машины ездят по кругу только пока мы в хабе
	if zone ~= "hub" then
		return
	end
	for _, car in cars do
		local travelled = car.offset + car.speed * t
		local x = (travelled % LANE_LENGTH) - LANE_LENGTH / 2
		local carCF = CFrame.new(car.dir * x, HUB_Y, car.laneZ)
		if car.dir == -1 then
			carCF = carCF * CFrame.Angles(0, math.pi, 0)
		end
		local spin = travelled / 1.2
		local cfs = table.create(#car.parts)
		for i, localCF in car.locals do
			cfs[i] = carCF * localCF
		end
		-- колёса крутятся
		for _, w in car.wheels do
			for _, idx in w do
				cfs[idx] = carCF * car.locals[idx] * CFrame.Angles(spin, 0, 0)
			end
		end
		Workspace:BulkMoveTo(car.parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)
