-- Катсцена: игроки едут в кузове грузовика с лесником, потом затемнение и телепорт в лес.
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

-- Размеры грузовика (локальные координаты: +X — вперёд, +Z — вправо, Y — вверх)
local FLOOR_TOP = 3.0
local REAR = -9 -- задний край кузова
local HALF_W = 7 -- половина ширины кузова
local DOOR_LEN = 7
local DOOR_H = 3
local SEAT_RADIUS = 4.5

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
	newPart(stage, "Ground", Vector3.new(1000, 1, 170), CFrame.new(origin + Vector3.new(300, -0.5, 0)), Color3.fromRGB(80, 128, 62), Enum.Material.Grass)
	newPart(stage, "Road", Vector3.new(700, 0.2, 22), CFrame.new(origin + Vector3.new(300, 0.1, 0)), Color3.fromRGB(88, 84, 80), Enum.Material.Asphalt)

	for side = -1, 1, 2 do
		for _ = 1, 45 do
			local x = rng:NextNumber(-40, 640)
			local z = side * rng:NextNumber(18, 70)
			local cf = CFrame.new(origin + Vector3.new(x, 0, z)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			Forest.makeTree(cf, rng:NextNumber(0.9, 1.5), rng).Parent = stage
		end
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

	local green = Color3.fromRGB(46, 88, 62)
	local wood = Color3.fromRGB(128, 92, 58)

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

	local floor = add("Floor", Vector3.new(18, 1, 14), Vector3.new(0, 2.5, 0), wood, Enum.Material.WoodPlanks)
	add("WallL", Vector3.new(18, DOOR_H, 0.6), Vector3.new(0, FLOOR_TOP + DOOR_H / 2, -6.7), wood, Enum.Material.Wood)
	add("WallR", Vector3.new(18, DOOR_H, 0.6), Vector3.new(0, FLOOR_TOP + DOOR_H / 2, 6.7), wood, Enum.Material.Wood)
	add("WallF", Vector3.new(0.6, DOOR_H, 14), Vector3.new(8.7, FLOOR_TOP + DOOR_H / 2, 0), wood, Enum.Material.Wood)
	-- кабина: низ, верх с окнами, фары, решётка, бампер
	add("CabLower", Vector3.new(6.4, 2.6, 13.6), Vector3.new(12.2, 3.3, 0), green, Enum.Material.SmoothPlastic)
	add("CabUpper", Vector3.new(4.6, 2.6, 13.2), Vector3.new(11.3, 5.9, 0), green, Enum.Material.SmoothPlastic)
	add("CabRoof", Vector3.new(4.9, 0.4, 13.5), Vector3.new(11.3, 7.35, 0), green:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.SmoothPlastic)
	add("Stripe", Vector3.new(6.5, 0.35, 13.7), Vector3.new(12.2, 4.6, 0), Color3.fromRGB(235, 200, 60), Enum.Material.SmoothPlastic)
	local glassColor = Color3.fromRGB(40, 60, 80)
	local ws = add("Windshield", Vector3.new(0.2, 2.0, 12.2), Vector3.new(13.65, 5.9, 0), glassColor, Enum.Material.Glass, false)
	ws.Transparency = 0.25
	ws.Reflectance = 0.3
	for _, sz in { -1, 1 } do
		local sw = add("SideWindow", Vector3.new(3.6, 1.8, 0.2), Vector3.new(11.3, 5.9, sz * 6.65), glassColor, Enum.Material.Glass, false)
		sw.Transparency = 0.25
		add("Headlight", Vector3.new(0.3, 0.9, 1.8), Vector3.new(15.45, 3.6, sz * 4.8), Color3.fromRGB(255, 248, 220), Enum.Material.Neon, false)
		add("Mirror", Vector3.new(0.6, 0.8, 0.4), Vector3.new(13.2, 6.0, sz * 7.2), Color3.fromRGB(30, 30, 34), Enum.Material.SmoothPlastic, false)
	end
	add("Grille", Vector3.new(0.3, 1.6, 6), Vector3.new(15.45, 3.4, 0), Color3.fromRGB(25, 25, 28), Enum.Material.SmoothPlastic, false)
	add("Bumper", Vector3.new(0.8, 0.8, 14), Vector3.new(15.6, 2.0, 0), Color3.fromRGB(55, 58, 64), Enum.Material.SmoothPlastic, false)
	for _, wx in { -5, 12 } do
		for _, wz in { -7.8, 7.8 } do
			local wheel = add("Wheel", Vector3.new(1.2, 3.2, 3.2), Vector3.new(wx, 1.6, wz), Color3.fromRGB(25, 25, 25), Enum.Material.SmoothPlastic, false)
			wheel.Shape = Enum.PartType.Cylinder
			wheel.CFrame = baseCF * CFrame.new(wx, 1.6, wz) * CFrame.Angles(0, math.rad(90), 0)
		end
	end

	-- Сиденья по кругу (кроме сектора у задних дверей)
	local seats = {}
	for i = 1, seatCount do
		local deg = 0
		if seatCount > 1 then
			deg = -140 + (i - 1) * 280 / (seatCount - 1)
		end
		local rad = math.rad(deg)
		local lp = Vector3.new(SEAT_RADIUS * math.cos(rad), FLOOR_TOP + 0.3, SEAT_RADIUS * math.sin(rad))
		local seat = Instance.new("Seat")
		seat.Name = "Seat" .. i
		seat.Size = Vector3.new(2, 0.6, 2)
		seat.Color = Color3.fromRGB(70, 50, 36)
		seat.Material = Enum.Material.Wood
		seat.TopSurface = Enum.SurfaceType.Smooth
		seat.BottomSurface = Enum.SurfaceType.Smooth
		seat.CFrame = baseCF * CFrame.lookAt(lp, Vector3.new(0, lp.Y, 0))
		seat.Anchored = false
		seat.Parent = model
		local w = Instance.new("WeldConstraint")
		w.Part0 = base
		w.Part1 = seat
		w.Parent = seat
		seats[i] = seat
	end

	-- Задние двери (две створки)
	local doors = {}
	for _, side in { 1, -1 } do
		local d = add(
			side == 1 and "DoorR" or "DoorL",
			Vector3.new(0.5, DOOR_H, DOOR_LEN),
			Vector3.new(REAR, FLOOR_TOP + DOOR_H / 2, side * DOOR_LEN / 2),
			green,
			Enum.Material.Metal
		)
		table.insert(doors, { part = d, side = side })
	end

	model.Parent = stage
	return { model = model, base = base, floor = floor, seats = seats, doors = doors }
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
	rig.Parent = stage

	local base = truck.base.CFrame
	local pos = base:PointToWorldSpace(Vector3.new(0, FLOOR_TOP + 3, 0))
	rig:PivotTo(CFrame.lookAt(pos, pos + base.XVector))

	-- Шляпа
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
	end

	local root = rig:FindFirstChild("HumanoidRootPart")
	local weld = Instance.new("WeldConstraint")
	weld.Name = "RideWeld"
	weld.Part0 = truck.floor
	weld.Part1 = root
	weld.Parent = root

	return { rig = rig, hum = hum, root = root, weld = weld }
end

local function walkTo(hum, pos, timeout)
	hum:MoveTo(pos)
	local t0 = os.clock()
	while os.clock() - t0 < timeout do
		local root = hum.RootPart
		if not root then
			return
		end
		local dx, dz = root.Position.X - pos.X, root.Position.Z - pos.Z
		if dx * dx + dz * dz < 2.25 then
			return
		end
		task.wait(0.1)
	end
end

local function say(forester, players, text)
	subtitle(players, "Лесник: " .. text, 3.5)
	local head = forester and forester.rig:FindFirstChild("Head")
	if head then
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(200, 50)
		gui.StudsOffset = Vector3.new(0, 3, 0)
		gui.AlwaysOnTop = true
		gui.Adornee = head
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.new(1, 1, 1)
		label.TextColor3 = Color3.new(0, 0, 0)
		label.Font = Enum.Font.GothamBold
		label.TextSize = 24
		label.Text = text
		label.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = label
		gui.Parent = head
		Debris:AddItem(gui, 3.5)
	end
end

local function openDoors(truck, baseCF)
	for _, d in truck.doors do
		local w = d.part:FindFirstChildOfClass("WeldConstraint")
		if w then
			w:Destroy()
		end
		d.part.Anchored = true
	end

	local T = 1.4
	local t0 = os.clock()
	repeat
		local a = math.clamp((os.clock() - t0) / T, 0, 1)
		local e = TweenService:GetValue(a, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		for _, d in truck.doors do
			local hinge = baseCF * CFrame.new(REAR, FLOOR_TOP + DOOR_H / 2, d.side * HALF_W)
			d.part.CFrame = hinge
				* CFrame.Angles(0, d.side * math.rad(90) * e, 0)
				* CFrame.new(0, 0, -d.side * DOOR_LEN / 2)
		end
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

	-- 2. Рассаживаем игроков
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

	task.wait(0.4)
	fade(players, false, 0.8)
	task.wait(0.8)

	-- 3. Едем по дороге
	local t0 = os.clock()
	local T = Config.DRIVE_SECONDS
	repeat
		local a = math.clamp((os.clock() - t0) / T, 0, 1)
		local e = TweenService:GetValue(a, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		truck.model:PivotTo(startCF + Vector3.new(Config.DRIVE_DISTANCE * e, 0, 0))
		for _, r in riders do
			local _, hum = charParts(r.player)
			if hum and hum.SeatPart ~= r.seat then
				r.seat:Sit(hum) -- на случай, если игрока что-то выбило с сиденья
			end
		end
		RunService.Heartbeat:Wait()
	until a >= 1

	-- 4. Приехали: лесник открывает двери и зовёт всех наружу
	task.wait(1.2)
	local baseCF = truck.base.CFrame
	if forester then
		forester.weld:Destroy()
		pcall(function()
			forester.root:SetNetworkOwner(nil)
		end)
		walkTo(forester.hum, baseCF:PointToWorldSpace(Vector3.new(REAR + 2.5, FLOOR_TOP + 3, 0)), 6)
	end
	openDoors(truck, baseCF)
	say(forester, players, "Выходите!")
	if forester then
		walkTo(forester.hum, baseCF:PointToWorldSpace(Vector3.new(REAR - 6, 0, 0)), 6)
		local pos = forester.root.Position
		forester.root.CFrame = CFrame.lookAt(pos, pos + baseCF.XVector)
	end
	task.wait(2.5)

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
