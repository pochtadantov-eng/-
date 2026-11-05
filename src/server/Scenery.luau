-- Задний фон хаба: пригород из домов, высотки подальше и горы по горизонту.
-- Всё стоит далеко от забора, чтобы край мира нигде не было видно.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Geometry = require(ReplicatedStorage.Shared.Geometry)

local Scenery = {}

local ROAD_Z = Config.ROAD_Z
local PI2 = math.pi * 2
local HOUSE_SCALE = 2
local TUNNEL_HILL_X = 272

local WALL_COLORS = {
	Color3.fromRGB(238, 226, 205),
	Color3.fromRGB(224, 205, 178),
	Color3.fromRGB(205, 220, 228),
	Color3.fromRGB(226, 190, 170),
	Color3.fromRGB(190, 205, 180),
	Color3.fromRGB(244, 240, 232),
	Color3.fromRGB(176, 120, 96), -- кирпич
}
local ROOF_COLORS = {
	Color3.fromRGB(150, 68, 52),
	Color3.fromRGB(72, 74, 82),
	Color3.fromRGB(104, 76, 56),
	Color3.fromRGB(58, 74, 100),
}
local DOOR_COLORS = {
	Color3.fromRGB(110, 60, 40),
	Color3.fromRGB(40, 70, 110),
	Color3.fromRGB(150, 40, 40),
	Color3.fromRGB(50, 90, 60),
}
local WHITE = Color3.fromRGB(246, 246, 242)

local function pick(rng, list)
	return list[rng:NextInteger(1, #list)]
end

local function mk(parent, size, cf, color, material, transparency, reflectance)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.Reflectance = reflectance or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanTouch = false
	p.Parent = parent
	return p
end

-- ===== Обычный дом с двускатной крышей =====
local function house(parent, cf, rng)
	local W = rng:NextNumber(14, 20) -- по X
	local D = rng:NextNumber(11, 15) -- по Z, фасад смотрит в +Z
	local floors = rng:NextInteger(1, 2)
	local floorH = 5.2
	local wallH = floors * floorH
	local wallColor = pick(rng, WALL_COLORS)
	local isBrick = wallColor == WALL_COLORS[7]
	local wallMat = isBrick and Enum.Material.SmoothPlastic or Enum.Material.SmoothPlastic
	local roofColor = pick(rng, ROOF_COLORS)

	local m = Instance.new("Model")
	m.Name = "House"
	m.Parent = parent

	local function part(size, rel, color, material, transparency, reflectance)
		return mk(m, size, cf * rel, color, material, transparency, reflectance)
	end

	-- фундамент и стены
	part(Vector3.new(W + 0.8, 0.7, D + 0.8), CFrame.new(0, 0.35, 0), Color3.fromRGB(150, 150, 146), Enum.Material.Concrete)
	part(Vector3.new(W, wallH, D), CFrame.new(0, 0.7 + wallH / 2, 0), wallColor, wallMat)
	local top = 0.7 + wallH

	-- крыша: две наклонные плиты, коньком вдоль X
	local s = D / 2 + 0.9
	local theta = math.rad(rng:NextNumber(26, 34))
	local L = s / math.cos(theta)
	local RH = s * math.tan(theta)
	for _, side in { 1, -1 } do
		part(
			Vector3.new(W + 1.8, 0.4, L + 0.2),
			CFrame.new(0, top + RH / 2 + 0.2, side * s / 2) * CFrame.Angles(side * theta, 0, 0),
			roofColor,
			Enum.Material.SmoothPlastic
		)
	end
	part(Vector3.new(W + 1.9, 0.35, 0.6), CFrame.new(0, top + RH + 0.4, 0), roofColor:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.SmoothPlastic)

	-- фронтоны: ровные треугольники под скатами крыши
	for _, sx in { -1, 1 } do
		local x = sx * (W / 2 - 0.15)
		Geometry.triangle(
			m,
			cf:PointToWorldSpace(Vector3.new(x, top, -s)),
			cf:PointToWorldSpace(Vector3.new(x, top, s)),
			cf:PointToWorldSpace(Vector3.new(x, top + RH, 0)),
			wallColor,
			wallMat,
			0.3,
			true
		)
	end

	-- окна на фасаде, дверь по центру первого этажа
	local nW = math.max(2, math.floor(W / 5.5))
	local doorIndex = math.ceil(nW / 2)
	local doorColor = pick(rng, DOOR_COLORS)
	for f = 1, floors do
		local y = 0.7 + (f - 0.5) * floorH + 0.3
		for i = 1, nW do
			local x = -W / 2 + (i - 0.5) * (W / nW)
			if f == 1 and i == doorIndex then
				part(Vector3.new(2.3, 3.7, 0.2), CFrame.new(x, 0.7 + 1.85, D / 2 + 0.05), WHITE)
				part(Vector3.new(1.8, 3.3, 0.25), CFrame.new(x, 0.7 + 1.65, D / 2 + 0.12), doorColor, Enum.Material.WoodPlanks)
				local knob = part(Vector3.new(0.3, 0.3, 0.3), CFrame.new(x + 0.6, 0.7 + 1.6, D / 2 + 0.3), Color3.fromRGB(215, 175, 70), Enum.Material.Metal)
				knob.Shape = Enum.PartType.Ball
				part(Vector3.new(3.4, 0.35, 1.9), CFrame.new(x, 0.55, D / 2 + 1.0), Color3.fromRGB(170, 170, 166), Enum.Material.Concrete)
			else
				part(Vector3.new(2.5, 2.7, 0.2), CFrame.new(x, y, D / 2 + 0.05), WHITE)
				part(Vector3.new(2.0, 2.2, 0.25), CFrame.new(x, y, D / 2 + 0.1), Color3.fromRGB(95, 135, 170), Enum.Material.Glass, 0.15, 0.25)
				part(Vector3.new(2.8, 0.22, 0.6), CFrame.new(x, y - 1.4, D / 2 + 0.25), WHITE)
			end
		end
		-- боковые окна
		for _, sx in { -1, 1 } do
			part(Vector3.new(0.2, 2.7, 2.5), CFrame.new(sx * (W / 2 + 0.05), y, 0), WHITE)
			part(Vector3.new(0.25, 2.2, 2.0), CFrame.new(sx * (W / 2 + 0.1), y, 0), Color3.fromRGB(95, 135, 170), Enum.Material.Glass, 0.15, 0.25)
		end
	end

	-- труба
	part(Vector3.new(1.6, RH + 2.4, 1.6), CFrame.new(W / 2 - 2.6, top + (RH + 2.4) / 2, 0), Color3.fromRGB(150, 82, 62), Enum.Material.SmoothPlastic)
	part(Vector3.new(2.0, 0.3, 2.0), CFrame.new(W / 2 - 2.6, top + RH + 2.5, 0), Color3.fromRGB(110, 110, 112), Enum.Material.Concrete)

	-- гараж
	if rng:NextNumber() < 0.55 then
		local gx = -(W / 2 + 3.6)
		part(Vector3.new(7.2, 4.4, D - 2), CFrame.new(gx, 0.7 + 2.2, -1), wallColor, wallMat)
		part(Vector3.new(7.8, 0.4, D - 1.4), CFrame.new(gx, 0.7 + 4.6, -1), roofColor:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.SmoothPlastic)
		part(Vector3.new(5.6, 3.3, 0.15), CFrame.new(gx, 0.7 + 1.65, D / 2 - 2 + 0.1), Color3.fromRGB(225, 225, 222), Enum.Material.Metal)
		for k = 1, 3 do
			part(Vector3.new(5.6, 0.1, 0.1), CFrame.new(gx, 0.7 + k * 0.85, D / 2 - 2 + 0.2), Color3.fromRGB(150, 150, 150), Enum.Material.Metal)
		end
		part(Vector3.new(6, 0.15, 14), CFrame.new(gx, 0.08, D / 2 - 2 + 7), Color3.fromRGB(160, 160, 158), Enum.Material.Concrete)
	end

	-- кусты у фасада
	for _, bx in { -W * 0.32, W * 0.32 } do
		local bush = part(Vector3.new(2.6, 2.2, 2.6), CFrame.new(bx, 1.1, D / 2 + 1.6), Color3.fromRGB(58 + rng:NextInteger(0, 24), 118 + rng:NextInteger(0, 20), 56), Enum.Material.Grass)
		bush.Shape = Enum.PartType.Ball
		bush.CanCollide = false
	end

	-- весь дом в 2 раза больше (персонаж ростом ~5 студов, дверь теперь ~7)
	m.WorldPivot = cf
	m:ScaleTo(HOUSE_SCALE)
	return (W + 8) * HOUSE_SCALE
end

-- ===== Высотка: бетонный корпус и полосы окон =====
local function tower(parent, cf, rng)
	local W = rng:NextNumber(24, 36)
	local D = rng:NextNumber(22, 32)
	local H = rng:NextNumber(40, 95)
	local m = Instance.new("Model")
	m.Name = "Tower"
	m.Parent = parent

	local function part(size, rel, color, material, transparency, reflectance)
		return mk(m, size, cf * rel, color, material, transparency, reflectance)
	end

	local body = pick(rng, {
		Color3.fromRGB(205, 200, 192),
		Color3.fromRGB(186, 178, 168),
		Color3.fromRGB(222, 214, 200),
		Color3.fromRGB(160, 168, 178),
	})
	part(Vector3.new(W, H, D), CFrame.new(0, H / 2, 0), body, Enum.Material.Concrete)
	local floors = math.floor(H / 4.5)
	for f = 1, floors - 1 do
		part(Vector3.new(W + 0.3, 2.1, D + 0.3), CFrame.new(0, f * 4.5, 0), Color3.fromRGB(70, 96, 125), Enum.Material.SmoothPlastic, 0, 0.3)
	end
	part(Vector3.new(W + 0.8, 1.2, D + 0.8), CFrame.new(0, H + 0.6, 0), body:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.Concrete)
	part(Vector3.new(W * 0.35, 3.2, D * 0.35), CFrame.new(rng:NextNumber(-W / 6, W / 6), H + 2.8, 0), Color3.fromRGB(120, 120, 124), Enum.Material.Metal)
end

-- Возвращает список позиций (x, z), где стоят дома — деревья их обходят
function Scenery.buildTown(parent, rng)
	local folder = Instance.new("Folder")
	folder.Name = "Town"
	folder.Parent = parent

	local spots = {}
	local function blocked(x, z, roadMargin, hillMargin)
		if math.abs(z - ROAD_Z) < roadMargin then
			return true
		end
		for _, sx in { -1, 1 } do
			local dx, dz = x - sx * TUNNEL_HILL_X, z - ROAD_Z
			if dx * dx + dz * dz < hillMargin * hillMargin then
				return true
			end
		end
		return false
	end

	-- кольца больших домов (стена лобби на 64, первые дома с 150)
	for _, r in { 150, 225, 300 } do
		local count = math.floor(PI2 * r / 78)
		for i = 0, count - 1 do
			local a = (i / count) * PI2 + rng:NextNumber(-0.03, 0.03)
			local rr = r + rng:NextNumber(-6, 6)
			local x, z = math.cos(a) * rr, math.sin(a) * rr
			if not blocked(x, z, 62, 135) then
				local pos = Vector3.new(x, 0, z)
				local cf = CFrame.lookAt(pos, pos * 2) * CFrame.Angles(0, rng:NextNumber(-0.15, 0.15), 0)
				house(folder, cf, rng)
				table.insert(spots, Vector2.new(x, z))
			end
		end
		task.wait()
	end

	-- высотки подальше, но до гор
	for _, r in { 385, 435 } do
		local count = math.floor(PI2 * r / 80)
		for i = 0, count - 1 do
			local a = (i / count) * PI2 + rng:NextNumber(-0.05, 0.05)
			local x, z = math.cos(a) * r, math.sin(a) * r
			if not blocked(x, z, 45, 150) then
				local pos = Vector3.new(x, 0, z)
				tower(folder, CFrame.lookAt(pos, pos * 2), rng)
				table.insert(spots, Vector2.new(x, z))
			end
		end
		task.wait()
	end

	return spots
end

-- ===== Горы по горизонту =====
function Scenery.buildMountains(terrain, rng)
	-- кольцо гор далеко за высотками (высотки до ~460, горы начинаются с ~490)
	local n = 30
	for i = 1, n do
		local a = (i / n) * PI2 + rng:NextNumber(-0.04, 0.04)
		local r = rng:NextNumber(95, 130)
		local dist = 620 + rng:NextNumber(-10, 25)
		local pos = Vector3.new(math.cos(a) * dist, -35 + rng:NextNumber(-8, 8), math.sin(a) * dist)
		terrain:FillBall(pos, r, Enum.Material.Rock)
		terrain:FillBall(pos + Vector3.new(0, r * 0.95, 0), r * 0.32, Enum.Material.Snow)
	end
	terrain:SetMaterialColor(Enum.Material.Snow, Color3.fromRGB(240, 244, 250))
end

return Scenery
