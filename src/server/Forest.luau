-- Генерация карты «Лес»: холмы, горы, пещеры, деревья и камни.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Geometry = require(ReplicatedStorage.Shared.Geometry)

local Forest = { ready = false }

local ORIGIN = Config.FOREST_ORIGIN
local SIZE = Config.FOREST_SIZE
local HALF = SIZE / 2
local VOX = 4
local LAYERS = 40 -- 40 * 4 = 160 студов высоты
local SEED = 1337
local TREE_COUNT = 360
local ROCK_COUNT = 280
local CAVE_COUNT = 6

local terrain = Workspace.Terrain
local caveMouths = {} -- мировые позиции входов в пещеры

-- Поляны (x, z относительно центра карты)
local MEADOWS = {
	Vector2.new(-140, 90),
	Vector2.new(120, -110),
	Vector2.new(-95, -135),
	Vector2.new(150, 115),
}

local function inMeadow(x, z, extra)
	for _, m in MEADOWS do
		local dx, dz = x - m.X, z - m.Y
		if dx * dx + dz * dz < (34 + extra) ^ 2 then
			return true
		end
	end
	return false
end

local rayParams
local function rayGround(x, z)
	if not rayParams then
		rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Include
		rayParams.FilterDescendantsInstances = { terrain }
	end
	return Workspace:Raycast(
		Vector3.new(ORIGIN.X + x, ORIGIN.Y + 220, ORIGIN.Z + z),
		Vector3.new(0, -300, 0),
		rayParams
	)
end

-- Высота рельефа в точке (x, z) относительно центра карты
local function heightAt(x, z)
	local nx, nz = x / SIZE, z / SIZE
	local h = 12
	h += math.noise(nx * 3.1 + 11.3, nz * 3.1 + 7.7) * 22 -- холмы
	h += math.noise(nx * 8.7 + 3.1, nz * 8.7 + 1.9) * 7 -- бугорки
	h += math.noise(nx * 22 + 5.5, nz * 22 + 9.9) * 2 -- мелкая неровность

	-- горы внутри карты
	local m = math.max(0, math.noise(nx * 2.0 + 40.2, nz * 2.0 + 31.7) - 0.08)
	h += m * m * 650

	-- горная стена по краю карты
	local edge = math.max(math.abs(nx), math.abs(nz)) * 2
	local b = math.clamp((edge - 0.72) / 0.28, 0, 1)
	-- горы по краю: острые вершины разной высоты, не упираются в потолок (иначе плоские плато)
	h += b * b * (58 + math.noise(nx * 7 + 2.2, nz * 7 + 8.8) * 46)

	-- ровная поляна в центре
	local d = math.sqrt(x * x + z * z)
	local s = 1 - math.clamp((d - 20) / 40, 0, 1)
	s = s * s * (3 - 2 * s)
	h += (15 - h) * s

	-- поляны: пологие места среди холмов
	for _, m in MEADOWS do
		local md = math.sqrt((x - m.X) ^ 2 + (z - m.Y) ^ 2)
		local ms = 1 - math.clamp((md - 28) / 36, 0, 1)
		ms = ms * ms * (3 - 2 * ms)
		h += (13 - h) * ms * 0.9
	end

	return math.clamp(h, 5, 156)
end

local function surfaceMaterial(h, slope, x, z)
	if h > 88 then
		return Enum.Material.Snow
	elseif h > 70 or slope > 1.0 then
		return Enum.Material.Rock
	elseif slope > 0.65 and h > 20 then
		return Enum.Material.Slate
	end
	local n = math.noise(x * 0.05 + 3.3, z * 0.05 + 6.6)
	if n > 0.22 then
		return Enum.Material.Ground
	elseif n > 0.05 then
		return Enum.Material.LeafyGrass
	end
	return Enum.Material.LeafyGrass
end

local function generateTerrain()
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(74, 122, 54))
	terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(96, 158, 66))
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(96, 76, 52))
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(112, 112, 116))
	terrain:SetMaterialColor(Enum.Material.Slate, Color3.fromRGB(90, 96, 100))

	local N = SIZE // VOX
	local H = table.create(N)
	for i = 1, N do
		local col = table.create(N)
		local x = (i - 0.5) * VOX - HALF
		for k = 1, N do
			col[k] = heightAt(x, (k - 0.5) * VOX - HALF)
		end
		H[i] = col
	end

	local function hs(i, k)
		return H[math.clamp(i, 1, N)][math.clamp(k, 1, N)]
	end

	-- материал поверхности для каждой колонки
	local M = table.create(N)
	for i = 1, N do
		local col = table.create(N)
		local x = (i - 0.5) * VOX - HALF
		for k = 1, N do
			local gx = (hs(i + 1, k) - hs(i - 1, k)) / (2 * VOX)
			local gz = (hs(i, k + 1) - hs(i, k - 1)) / (2 * VOX)
			local slope = math.sqrt(gx * gx + gz * gz)
			col[k] = surfaceMaterial(H[i][k], slope, x, (k - 0.5) * VOX - HALF)
		end
		M[i] = col
	end

	local CHUNK = 16
	for z0 = 0, N - 1, CHUNK do
		local mats = table.create(N)
		local occs = table.create(N)
		for i = 1, N do
			local mx = table.create(LAYERS)
			local ox = table.create(LAYERS)
			for j = 1, LAYERS do
				local mz = table.create(CHUNK)
				local oz = table.create(CHUNK)
				local y0 = (j - 1) * VOX
				for c = 1, CHUNK do
					local k = z0 + c
					local h = H[i][k]
					local occ = math.clamp((h - y0) / VOX, 0, 1)
					if occ <= 0 then
						mz[c] = Enum.Material.Air
						oz[c] = 0
					else
						local sm = M[i][k]
						if h - y0 > 9 then
							if sm == Enum.Material.Rock or sm == Enum.Material.Snow or sm == Enum.Material.Slate then
								mz[c] = Enum.Material.Rock
							else
								mz[c] = Enum.Material.Ground
							end
						else
							mz[c] = sm
						end
						oz[c] = occ
					end
				end
				mx[j] = mz
				ox[j] = oz
			end
			mats[i] = mx
			occs[i] = ox
		end

		local min = Vector3.new(ORIGIN.X - HALF, ORIGIN.Y, ORIGIN.Z - HALF + z0 * VOX)
		local max = min + Vector3.new(SIZE, LAYERS * VOX, CHUNK * VOX)
		terrain:WriteVoxels(Region3.new(min, max), VOX, mats, occs)
		task.wait()
	end

	return H, N
end

-- Мини-пещеры: туннель, уходящий горизонтально в склон холма
local function carveCaves(H, N)
	local rng = Random.new(SEED + 1)
	local made, tries = 0, 0
	local folder = Instance.new("Folder")
	folder.Name = "CaveLights"
	folder.Parent = Workspace

	while made < CAVE_COUNT and tries < 4000 do
		tries += 1
		local i = rng:NextInteger(8, N - 7)
		local k = rng:NextInteger(8, N - 7)
		local h = H[i][k]
		if h > 26 and h < 85 then
			local gx = (H[i + 1][k] - H[i - 1][k]) / (2 * VOX)
			local gz = (H[i][k + 1] - H[i][k - 1]) / (2 * VOX)
			local g = math.sqrt(gx * gx + gz * gz)
			if g > 0.35 then
				local dir = Vector3.new(gx, 0, gz).Unit -- в гору
				local x = (i - 0.5) * VOX - HALF
				local z = (k - 0.5) * VOX - HALF
				local base = ORIGIN + Vector3.new(x, h, z)
				for s = 0, 6 do
					local c = base + dir * (s * 5 - 2) + Vector3.new(0, 3.5, 0)
					terrain:FillBall(c, 6.5, Enum.Material.Air)
				end

				local lamp = Instance.new("Part")
				lamp.Anchored = true
				lamp.CanCollide = false
				lamp.CanQuery = false
				lamp.Transparency = 1
				lamp.Size = Vector3.one
				lamp.Position = base + dir * 16 + Vector3.new(0, 4, 0)
				local light = Instance.new("PointLight")
				light.Range = 22
				light.Brightness = 1.2
				light.Color = Color3.fromRGB(255, 190, 120)
				light.Parent = lamp
				lamp.Parent = folder

				table.insert(caveMouths, base)
				made += 1
				task.wait()
			end
		end
	end
end

local function nearCave(worldPos)
	for _, m in caveMouths do
		local dx, dz = worldPos.X - m.X, worldPos.Z - m.Z
		if dx * dx + dz * dz < 22 * 22 then
			return true
		end
	end
	return false
end

local function setPart(part, collide)
	part.Anchored = true
	part.CanCollide = collide
	part.CanTouch = false
	part.CanQuery = collide
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

-- Дерево: ель, дуб или берёза. cf — точка на земле.
function Forest.makeTree(cf, scale, rng)
	rng = rng or Random.new()
	local model = Instance.new("Model")
	model.Name = "Tree"

	local function addPart(shape, size, rel, color, material, collide)
		local p = Instance.new("Part")
		p.Shape = shape
		p.Size = size
		p.CFrame = cf * rel
		p.Color = color
		p.Material = material
		setPart(p, collide)
		p.Parent = model
		return p
	end

	-- мягкий овал (сплюснутая сфера) для хвои и листвы
	local function blob(size, rel, color)
		local p = addPart(Enum.PartType.Block, size, rel, color, Enum.Material.SmoothPlastic, false)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
		return p
	end

	local function trunk(height, thickness, color)
		return addPart(
			Enum.PartType.Cylinder,
			Vector3.new(height, thickness, thickness),
			CFrame.new(0, height / 2 - 1, 0) * CFrame.Angles(0, 0, math.rad(90)),
			color,
			Enum.Material.Wood,
			true
		)
	end

	local kind = rng:NextNumber()
	local shade = rng:NextInteger(-10, 12)
	local function tone(r, g, b)
		return Color3.fromRGB(math.clamp(r + shade, 0, 255), math.clamp(g + shade, 0, 255), math.clamp(b + shade, 0, 255))
	end
	local function sphere(d, rel, color)
		return addPart(Enum.PartType.Ball, Vector3.one * d, rel, color, Enum.Material.SmoothPlastic, false)
	end

	if kind < 0.55 then
		-- ель: три гранёных конуса друг над другом (аккуратный low-poly)
		local trunkH = 4.5 * scale
		trunk(trunkH + 2 * scale, 1.2 * scale, Color3.fromRGB(92, 64, 42))
		local turn = rng:NextNumber(0, math.pi)
		local tiers = {
			{ r = 5.2, y = 2.6, h = 6.5, c = tone(38, 98, 56) },
			{ r = 4.0, y = 6.0, h = 5.6, c = tone(44, 110, 62) },
			{ r = 2.7, y = 9.2, h = 4.8, c = tone(52, 122, 68) },
		}
		for i, t in tiers do
			local base = (cf * CFrame.new(0, t.y * scale, 0)).Position
			Geometry.cone(model, base, t.r * scale, t.h * scale, 6, t.c, Enum.Material.SmoothPlastic, turn + i * 0.4)
		end
	elseif kind < 0.85 then
		-- лиственное: прямой ствол и крона из трёх крупных шаров
		local h = 6 * scale
		trunk(h + 1, 1.5 * scale, Color3.fromRGB(104, 74, 48))
		local y = h + 2.2 * scale
		sphere(7.4 * scale, CFrame.new(0, y, 0), tone(78, 150, 60))
		sphere(5.4 * scale, CFrame.new(2.6 * scale, y - 1.0 * scale, 0.8 * scale), tone(70, 140, 56))
		sphere(5.0 * scale, CFrame.new(-2.2 * scale, y - 0.6 * scale, -1.4 * scale), tone(86, 160, 66))
	else
		-- берёза: светлый ствол с тёмными полосками, лёгкая вытянутая крона
		local h = 8 * scale
		trunk(h + 1, 0.9 * scale, Color3.fromRGB(238, 236, 228))
		for k = 1, 3 do
			local mark = addPart(
				Enum.PartType.Cylinder,
				Vector3.new(0.25 * scale, 0.95 * scale, 0.95 * scale),
				CFrame.new(0, k * 2.1 * scale, 0) * CFrame.Angles(0, 0, math.rad(90)),
				Color3.fromRGB(40, 40, 40),
				Enum.Material.SmoothPlastic,
				false
			)
			mark.Transparency = 0.2
		end
		sphere(5.2 * scale, CFrame.new(0, h + 1.2 * scale, 0), tone(130, 186, 78))
		sphere(4.0 * scale, CFrame.new(0.6 * scale, h + 3.6 * scale, -0.4 * scale), tone(140, 196, 84))
	end

	return model
end

-- Камень: один-три шара (у шара честная круглая коллизия — можно подойти вплотную)
function Forest.makeRock(cf, size, rng)
	local model = Instance.new("Model")
	model.Name = "Rock"
	local g = rng:NextInteger(110, 134)
	local base = Color3.fromRGB(g, g, g + 6)
	local count = size > 6 and 3 or rng:NextInteger(1, 2)
	for i = 1, count do
		local d = size * (i == 1 and 1 or rng:NextNumber(0.45, 0.7))
		local off = Vector3.zero
		if i > 1 then
			off = Vector3.new(rng:NextNumber(-0.5, 0.5) * size, -d * 0.1, rng:NextNumber(-0.5, 0.5) * size)
		end
		local p = Instance.new("Part")
		p.Name = "Stone"
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.one * d
		p.CFrame = cf * CFrame.new(off + Vector3.new(0, d * 0.22, 0))
		p.Color = base:Lerp(Color3.new(1, 1, 1), rng:NextNumber(0, 0.08))
		p.Material = Enum.Material.SmoothPlastic
		setPart(p, true)
		p.Parent = model
	end
	return model
end

local function placeProps()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { terrain }

	local folder = Instance.new("Folder")
	folder.Name = "ForestProps"
	folder.Parent = Workspace

	local rng = Random.new(SEED)
	local occupied = {}

	local function ground(x, z)
		return Workspace:Raycast(
			Vector3.new(ORIGIN.X + x, ORIGIN.Y + 220, ORIGIN.Z + z),
			Vector3.new(0, -300, 0),
			params
		)
	end

	local trees = 0
	for attempt = 1, TREE_COUNT * 4 do
		if trees >= TREE_COUNT then
			break
		end
		if attempt % 60 == 0 then
			task.wait()
		end
		local x = rng:NextNumber(-HALF + 8, HALF - 8)
		local z = rng:NextNumber(-HALF + 8, HALF - 8)
		if x * x + z * z > 30 * 30 and not inMeadow(x, z, 8) then
			local density = math.noise(x * 0.012 + 4.4, z * 0.012 + 1.3) + 0.55
			local key = math.floor(x / 7) .. "," .. math.floor(z / 7)
			if rng:NextNumber() < density and not occupied[key] then
				local hit = ground(x, z)
				if
					hit
					and hit.Normal.Y > 0.88
					and hit.Position.Y - ORIGIN.Y < 62
					and (hit.Material == Enum.Material.Grass or hit.Material == Enum.Material.LeafyGrass or hit.Material == Enum.Material.Ground)
					and not nearCave(hit.Position)
				then
					occupied[key] = true
					local cf = CFrame.new(hit.Position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
					Forest.makeTree(cf, rng:NextNumber(0.8, 1.5), rng).Parent = folder
					trees += 1
				end
			end
		end
	end

	local rocks = 0
	for attempt = 1, ROCK_COUNT * 4 do
		if rocks >= ROCK_COUNT then
			break
		end
		if attempt % 60 == 0 then
			task.wait()
		end
		local x = rng:NextNumber(-HALF + 8, HALF - 8)
		local z = rng:NextNumber(-HALF + 8, HALF - 8)
		if x * x + z * z > 20 * 20 and not inMeadow(x, z, 0) then
			local hit = ground(x, z)
			if hit and hit.Normal.Y > 0.5 and hit.Material ~= Enum.Material.Snow and not nearCave(hit.Position) then
				local size = rng:NextNumber(2.5, 7)
				if rng:NextNumber() < 0.1 then
					size = rng:NextNumber(10, 16) -- валуны
				end
				Forest.makeRock(CFrame.new(hit.Position), size, rng).Parent = folder
				rocks += 1
			end
		end
	end

	-- цветы на полянах
	local palette = {
		Color3.fromRGB(240, 90, 90),
		Color3.fromRGB(250, 220, 80),
		Color3.fromRGB(245, 245, 245),
		Color3.fromRGB(170, 120, 240),
		Color3.fromRGB(255, 150, 60),
	}
	for _, m in MEADOWS do
		for n = 1, 70 do
			if n % 25 == 0 then
				task.wait()
			end
			local a = rng:NextNumber(0, math.pi * 2)
			local r = math.sqrt(rng:NextNumber()) * 32
			local hit = ground(m.X + math.cos(a) * r, m.Y + math.sin(a) * r)
			if hit and hit.Normal.Y > 0.9 and hit.Material ~= Enum.Material.Snow then
				local flower = Instance.new("Part")
				flower.Shape = Enum.PartType.Ball
				flower.Size = Vector3.one * 0.7
				flower.Position = hit.Position + Vector3.new(0, 0.3, 0)
				flower.Color = palette[rng:NextInteger(1, #palette)]
				setPart(flower, false)
				flower.Parent = folder
			end
		end
	end

	Forest.buildCampsite(folder)
end

-- Невидимые стены внутри кольца гор: на дальние вершины не залезть и край карты не увидеть
local function buildBounds()
	local folder = Instance.new("Folder")
	folder.Name = "ForestBounds"
	folder.Parent = Workspace
	local inner = HALF - 40
	for _, spec in {
		{ Vector3.new(inner, 0, 0), Vector3.new(2, 600, SIZE) },
		{ Vector3.new(-inner, 0, 0), Vector3.new(2, 600, SIZE) },
		{ Vector3.new(0, 0, inner), Vector3.new(SIZE, 600, 2) },
		{ Vector3.new(0, 0, -inner), Vector3.new(SIZE, 600, 2) },
	} do
		local w = Instance.new("Part")
		w.Anchored = true
		w.Transparency = 1
		w.CanQuery = false
		w.CanTouch = false
		w.Size = spec[2]
		w.Position = ORIGIN + spec[1] + Vector3.new(0, 300, 0)
		w.Parent = folder
	end
end

function Forest.generate()
	buildBounds()
	local H, N = generateTerrain()
	carveCaves(H, N)
	placeProps()
	Forest.ready = true
end

function Forest.waitUntilReady()
	while not Forest.ready do
		task.wait(0.25)
	end
end

-- Лагерь в центре карты: костёр, брёвна-сиденья и две палатки
function Forest.buildCampsite(folder)
	local hit = rayGround(0, 0)
	local gy = hit and hit.Position.Y or (ORIGIN.Y + 15)
	local C = Vector3.new(ORIGIN.X, gy, ORIGIN.Z)

	local camp = Instance.new("Model")
	camp.Name = "Campsite"
	camp.Parent = folder

	local function add(shape, size, cf, color, material, collide)
		local p = Instance.new("Part")
		p.Shape = shape
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material
		setPart(p, collide ~= false)
		p.Parent = camp
		return p
	end

	-- камни вокруг костра
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2
		add(
			Enum.PartType.Ball,
			Vector3.one * (1.2 + (i % 3) * 0.25),
			CFrame.new(C + Vector3.new(math.cos(a) * 2.5, 0.4, math.sin(a) * 2.5)),
			Color3.fromRGB(118, 118, 122),
			Enum.Material.Slate
		)
	end

	-- поленья в огне
	for i = 0, 2 do
		add(
			Enum.PartType.Cylinder,
			Vector3.new(4.6, 0.7, 0.7),
			CFrame.new(C + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, math.rad(60 * i), math.rad(14)),
			Color3.fromRGB(60, 40, 28),
			Enum.Material.Wood,
			false
		)
	end

	-- огонь и свет
	local firePart = Instance.new("Part")
	firePart.Name = "Fire"
	firePart.Size = Vector3.one
	firePart.Position = C + Vector3.new(0, 1.2, 0)
	firePart.Transparency = 1
	setPart(firePart, false)
	firePart.Parent = camp
	local fire = Instance.new("Fire")
	fire.Size = 6
	fire.Heat = 10
	fire.Color = Color3.fromRGB(255, 160, 50)
	fire.SecondaryColor = Color3.fromRGB(220, 60, 20)
	fire.Parent = firePart
	local smoke = Instance.new("Smoke")
	smoke.Size = 3
	smoke.Opacity = 0.15
	smoke.RiseVelocity = 6
	smoke.Parent = firePart
	local light = Instance.new("PointLight")
	light.Range = 32
	light.Brightness = 2.2
	light.Color = Color3.fromRGB(255, 150, 70)
	light.Parent = firePart

	-- брёвна-сиденья вокруг костра
	for i = 0, 4 do
		local a = math.rad(20 + i * 62)
		add(
			Enum.PartType.Cylinder,
			Vector3.new(5, 1.1, 1.1),
			CFrame.new(C + Vector3.new(math.cos(a) * 6.2, 0.55, math.sin(a) * 6.2)) * CFrame.Angles(0, -(a + math.pi / 2), 0),
			Color3.fromRGB(110, 78, 50),
			Enum.Material.Wood
		)
	end

	-- палатки (лицом к костру)
	local function tent(offset, color)
		local pos = C + offset
		local cf = CFrame.lookAt(pos, Vector3.new(C.X, pos.Y, C.Z))
		add(Enum.PartType.Block, Vector3.new(7, 0.2, 8), cf * CFrame.new(0, 0.1, 0), Color3.fromRGB(55, 50, 45), Enum.Material.Fabric)
		for _, side in { 1, -1 } do
			add(
				Enum.PartType.Block,
				Vector3.new(5.44, 0.3, 8.4),
				cf * CFrame.new(side * 1.75, 2.1, 0) * CFrame.Angles(0, 0, -side * math.rad(50)),
				color,
				Enum.Material.Fabric
			)
		end
	end
	tent(Vector3.new(-15, 0, -7), Color3.fromRGB(215, 120, 50))
	tent(Vector3.new(14, 0, -10), Color3.fromRGB(70, 130, 175))
end

-- Точки появления игроков вокруг костра
function Forest.spawnPoints(count)
	local points = {}
	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + 0.4
		local x = math.cos(angle) * 9
		local z = math.sin(angle) * 9
		local hit = rayGround(x, z)
		local y = hit and hit.Position.Y or (ORIGIN.Y + 15)
		local pos = Vector3.new(ORIGIN.X + x, y + 4, ORIGIN.Z + z)
		points[i] = CFrame.lookAt(pos, Vector3.new(ORIGIN.X, pos.Y, ORIGIN.Z))
	end
	return points
end

return Forest
