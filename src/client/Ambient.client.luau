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

task.spawn(function()
	while true do
		local zone = currentZone()
		fadeTo(hubMusic, zone == "hub")
		fadeTo(forestMusic, zone == "forest")
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

local birds = {}
local birdColors = {
	Color3.fromRGB(60, 60, 66),
	Color3.fromRGB(235, 235, 235),
	Color3.fromRGB(150, 110, 80),
	Color3.fromRGB(90, 100, 120),
}
for i = 1, 14 do
	local color = birdColors[rng:NextInteger(1, #birdColors)]
	local model = Instance.new("Model")
	model.Name = "Bird" .. i
	model.Parent = birdFolder
	birds[i] = {
		body = bodyPart(model, Enum.PartType.Ball, Vector3.new(1.1, 1, 2.4), color),
		head = bodyPart(model, Enum.PartType.Ball, Vector3.new(0.75, 0.75, 0.75), color),
		beak = bodyPart(model, Enum.PartType.Block, Vector3.new(0.2, 0.2, 0.5), Color3.fromRGB(255, 170, 40)),
		wingL = bodyPart(model, Enum.PartType.Block, Vector3.new(2.8, 0.12, 1.3), color),
		wingR = bodyPart(model, Enum.PartType.Block, Vector3.new(2.8, 0.12, 1.3), color),
		radius = rng:NextNumber(30, 95),
		height = rng:NextNumber(35, 80),
		speed = rng:NextNumber(0.18, 0.4) * (rng:NextNumber() < 0.5 and -1 or 1),
		phase = rng:NextNumber(0, math.pi * 2),
	}
end

local center = Vector3.new(0, 0, 0)

-- ===== Машины на дороге =====
local function buildCar(kind, color)
	local model = Instance.new("Model")
	model.Name = "Car"
	local parts, locals, wheelIdx = {}, {}, {}

	local function add(shape, size, localCF, col, material, transparency)
		local p = bodyPart(model, shape, size, col)
		p.Material = material or Enum.Material.SmoothPlastic
		p.Transparency = transparency or 0
		table.insert(parts, p)
		table.insert(locals, localCF)
		return #parts
	end

	local glass = Color3.fromRGB(140, 185, 215)
	local dark = Color3.fromRGB(25, 25, 28)

	if kind == "sedan" then
		add(Enum.PartType.Block, Vector3.new(12, 1.8, 5.6), CFrame.new(0, 2.2, 0), color, Enum.Material.Metal)
		add(Enum.PartType.Block, Vector3.new(5.6, 1.7, 5), CFrame.new(-0.6, 3.95, 0), glass, Enum.Material.Glass, 0.25)
		add(Enum.PartType.Block, Vector3.new(5.8, 0.3, 5.2), CFrame.new(-0.6, 4.95, 0), color, Enum.Material.Metal)
		add(Enum.PartType.Ball, Vector3.new(0.7, 0.7, 0.7), CFrame.new(5.9, 2.5, 1.9), Color3.fromRGB(255, 250, 215), Enum.Material.Neon)
		add(Enum.PartType.Ball, Vector3.new(0.7, 0.7, 0.7), CFrame.new(5.9, 2.5, -1.9), Color3.fromRGB(255, 250, 215), Enum.Material.Neon)
		add(Enum.PartType.Ball, Vector3.new(0.6, 0.6, 0.6), CFrame.new(-5.9, 2.5, 1.9), Color3.fromRGB(230, 40, 40), Enum.Material.Neon)
		add(Enum.PartType.Ball, Vector3.new(0.6, 0.6, 0.6), CFrame.new(-5.9, 2.5, -1.9), Color3.fromRGB(230, 40, 40), Enum.Material.Neon)
		for _, wx in { -3.8, 3.8 } do
			for _, wz in { -2.9, 2.9 } do
				table.insert(wheelIdx, { x = wx, z = wz })
			end
		end
	else -- грузовик
		add(Enum.PartType.Block, Vector3.new(13, 1.2, 5.4), CFrame.new(0, 1.9, 0), dark, Enum.Material.Metal)
		add(Enum.PartType.Block, Vector3.new(4.2, 3.6, 5.6), CFrame.new(4.7, 3.9, 0), color, Enum.Material.Metal)
		add(Enum.PartType.Block, Vector3.new(0.2, 1.8, 4.6), CFrame.new(6.85, 4.4, 0), glass, Enum.Material.Glass, 0.25)
		add(Enum.PartType.Block, Vector3.new(8.6, 4.6, 5.8), CFrame.new(-2.4, 4.7, 0), Color3.fromRGB(235, 235, 232), Enum.Material.SmoothPlastic)
		add(Enum.PartType.Ball, Vector3.new(0.7, 0.7, 0.7), CFrame.new(6.9, 2.7, 1.9), Color3.fromRGB(255, 250, 215), Enum.Material.Neon)
		add(Enum.PartType.Ball, Vector3.new(0.7, 0.7, 0.7), CFrame.new(6.9, 2.7, -1.9), Color3.fromRGB(255, 250, 215), Enum.Material.Neon)
		for _, wx in { 4.8, -1.2, -4.6 } do
			for _, wz in { -2.9, 2.9 } do
				table.insert(wheelIdx, { x = wx, z = wz })
			end
		end
	end

	local wheels = {}
	for _, w in wheelIdx do
		local base = CFrame.new(w.x, 1.2, w.z) * CFrame.Angles(0, math.rad(90), 0)
		local tire = add(Enum.PartType.Cylinder, Vector3.new(0.9, 2.4, 2.4), base, dark, Enum.Material.SmoothPlastic)
		local rim = add(Enum.PartType.Cylinder, Vector3.new(0.95, 1.4, 1.4), base, Color3.fromRGB(190, 190, 195), Enum.Material.Metal)
		local mark = add(Enum.PartType.Block, Vector3.new(1.0, 0.25, 1.3), base, Color3.fromRGB(70, 70, 75), Enum.Material.Metal)
		table.insert(wheels, { tire, rim, mark })
	end

	model.Parent = birdFolder
	return { model = model, parts = parts, locals = locals, wheels = wheels }
end

local carColors = {
	Color3.fromRGB(200, 50, 50),
	Color3.fromRGB(50, 100, 200),
	Color3.fromRGB(230, 200, 60),
	Color3.fromRGB(240, 240, 240),
	Color3.fromRGB(60, 60, 66),
	Color3.fromRGB(50, 150, 90),
	Color3.fromRGB(230, 130, 40),
}

local LANE_LENGTH = 640
local cars = {}
local function addLane(dir, laneZ, speed, count)
	for i = 1, count do
		local kind = rng:NextNumber() < 0.28 and "truck" or "sedan"
		local car = buildCar(kind, carColors[rng:NextInteger(1, #carColors)])
		car.dir = dir
		car.laneZ = laneZ
		car.speed = speed
		car.offset = (i / count) * LANE_LENGTH + rng:NextNumber(-20, 20)
		table.insert(cars, car)
	end
end
addLane(1, Config.ROAD_Z + 6, 30, 5)
addLane(-1, Config.ROAD_Z - 6, 26, 5)

-- ===== Обновление каждый кадр =====
local t0 = os.clock()
RunService.RenderStepped:Connect(function(dt)
	local t = os.clock() - t0
	local zone = currentZone()

	-- Птицы кружат над тем местом, куда смотрит камера
	local focus = camera.Focus.Position
	center = center:Lerp(Vector3.new(focus.X, 0, focus.Z), math.clamp(dt * 2, 0, 1))
	local parts, cframes = {}, {}
	for _, b in birds do
		local a = b.phase + t * b.speed
		local pos = center + Vector3.new(math.cos(a) * b.radius, b.height + math.sin(t * 0.7 + b.phase) * 3, math.sin(a) * b.radius)
		local tangent = Vector3.new(-math.sin(a), 0, math.cos(a)) * (b.speed > 0 and 1 or -1)
		local cf = CFrame.lookAt(pos, pos + tangent) * CFrame.Angles(0, 0, math.sin(t * 0.7 + b.phase) * 0.15)
		local flap = math.sin(t * 9 + b.phase) * 0.7
		table.insert(parts, b.body)
		table.insert(cframes, cf)
		table.insert(parts, b.head)
		table.insert(cframes, cf * CFrame.new(0, 0.25, -1.3))
		table.insert(parts, b.beak)
		table.insert(cframes, cf * CFrame.new(0, 0.2, -1.8))
		table.insert(parts, b.wingR)
		table.insert(cframes, cf * CFrame.new(0.5, 0.1, 0) * CFrame.Angles(0, 0, flap) * CFrame.new(1.4, 0, 0))
		table.insert(parts, b.wingL)
		table.insert(cframes, cf * CFrame.new(-0.5, 0.1, 0) * CFrame.Angles(0, 0, -flap) * CFrame.new(-1.4, 0, 0))
	end
	Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)

	-- Машины ездят по кругу только пока мы в хабе
	if zone ~= "hub" then
		return
	end
	for _, car in cars do
		local travelled = car.offset + car.speed * t
		local x = (travelled % LANE_LENGTH) - LANE_LENGTH / 2
		local carCF = CFrame.new(car.dir * x, 0, car.laneZ)
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
