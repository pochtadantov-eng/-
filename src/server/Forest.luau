-- Генерация карты «Лес»: холмы, горы, пещеры, деревья и камни.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Forest = { ready = false }

local ORIGIN = Config.FOREST_ORIGIN
local SIZE = Config.FOREST_SIZE
local HALF = SIZE / 2
local VOX = 4
local LAYERS = 40 -- 40 * 4 = 160 студов высоты
local SEED = 1337
local TREE_COUNT = 800
local ROCK_COUNT = 280
local CAVE_COUNT = 6

local terrain = Workspace.Terrain
local caveMouths = {} -- мировые позиции входов в пещеры

-- Высота рельефа в точке (x, z) относительно центра карты
local function heightAt(x, z)
	local nx, nz = x / SIZE, z / SIZE
	local h = 12
	h += math.noise(nx * 3.1 + 11.3, nz * 3.1 + 7.7) * 22 -- холмы
	h += math.noise(nx * 8.7 + 3.1, nz * 8.7 + 1.9) * 7 -- бугорки
	h += math.noise(nx * 22 + 5.5, nz * 22 + 9.9) * 2 -- мелкая неровность

	-- горы внутри карты
	local m = math.max(0, math.noise(nx * 2.0 + 40.2, nz * 2.0 + 31.7) - 0.08)
	h += m * m * 900

	-- горная стена по краю карты
	local edge = math.max(math.abs(nx), math.abs(nz)) * 2
	local b = math.clamp((edge - 0.72) / 0.28, 0, 1)
	h += b * b * (95 + math.noise(nx * 6 + 2.2, nz * 6 + 8.8) * 40)

	-- ровная поляна в центре
	local d = math.sqrt(x * x + z * z)
	local s = 1 - math.clamp((d - 20) / 40, 0, 1)
	s = s * s * (3 - 2 * s)
	h += (15 - h) * s

	return math.clamp(h, 5, 156)
end

local function surfaceMaterial(h, slope, x, z)
	if h > 100 then
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
	return Enum.Material.Grass
end

local function generateTerrain()
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(74, 122, 54))
	terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(62, 110, 48))
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

-- Дерево (сосна или лиственное). cf — точка на земле.
function Forest.makeTree(cf, scale, rng)
	rng = rng or Random.new()
	local model = Instance.new("Model")
	model.Name = "Tree"

	local pine = rng:NextNumber() < 0.6
	local trunkH = (pine and 12 or 9) * scale
	local shade = rng:NextNumber(-12, 12)

	local trunk = Instance.new("Part")
	trunk.Name = "Trunk"
	trunk.Material = Enum.Material.Wood
	trunk.Color = Color3.fromRGB(94, 66, 41)
	trunk.Size = Vector3.new(1.6 * scale, trunkH, 1.6 * scale)
	trunk.CFrame = cf * CFrame.new(0, trunkH / 2 - 1, 0)
	setPart(trunk, true)
	trunk.Parent = model

	local leafColor = Color3.fromRGB(34 + shade, 92 + shade, 48 + shade)

	if pine then
		local diameters = { 10, 8, 6, 3.6 }
		for i, d in diameters do
			local layer = Instance.new("Part")
			layer.Name = "Needles" .. i
			layer.Shape = Enum.PartType.Cylinder
			layer.Material = Enum.Material.Grass
			layer.Color = leafColor
			layer.Size = Vector3.new(3.2 * scale, d * scale, d * scale)
			layer.CFrame = cf * CFrame.new(0, trunkH * 0.45 + (i - 1) * 2.4 * scale, 0) * CFrame.Angles(0, 0, math.rad(90))
			setPart(layer, false)
			layer.Parent = model
		end
	else
		local offsets = { Vector3.new(0, 0, 0), Vector3.new(2.2, -1, 1), Vector3.new(-2, -0.8, -1.5) }
		for i, off in offsets do
			local ball = Instance.new("Part")
			ball.Name = "Crown" .. i
			ball.Shape = Enum.PartType.Ball
			ball.Material = Enum.Material.Grass
			ball.Color = leafColor
			local d = (i == 1 and 9 or 7) * scale
			ball.Size = Vector3.new(d, d, d)
			ball.CFrame = cf * CFrame.new(Vector3.new(0, trunkH + 2 * scale, 0) + off * scale)
			setPart(ball, false)
			ball.Parent = model
		end
	end

	return model
end

function Forest.makeRock(cf, size, rng)
	local rock = Instance.new("Part")
	rock.Name = "Rock"
	rock.Material = Enum.Material.Slate
	local g = rng:NextInteger(100, 128)
	rock.Color = Color3.fromRGB(g, g, g + 4)
	rock.Size = Vector3.new(size, size * rng:NextNumber(0.6, 1.0), size * rng:NextNumber(0.8, 1.3))
	rock.CFrame = cf
		* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.4, 0.4))
		* CFrame.new(0, size * 0.15, 0)
	setPart(rock, true)
	return rock
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
		if x * x + z * z > 30 * 30 then
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
		if x * x + z * z > 20 * 20 then
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
end

function Forest.generate()
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

-- Точки появления игроков на поляне в центре карты
function Forest.spawnPoints(count)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { terrain }

	local points = {}
	for i = 1, count do
		local angle = (i / count) * math.pi * 2
		local x = math.cos(angle) * 8
		local z = math.sin(angle) * 8
		local hit = Workspace:Raycast(
			Vector3.new(ORIGIN.X + x, ORIGIN.Y + 220, ORIGIN.Z + z),
			Vector3.new(0, -300, 0),
			params
		)
		local y = hit and hit.Position.Y or (ORIGIN.Y + 15)
		local pos = Vector3.new(ORIGIN.X + x, y + 4, ORIGIN.Z + z)
		points[i] = CFrame.lookAt(pos, Vector3.new(ORIGIN.X, pos.Y, ORIGIN.Z))
	end
	return points
end

return Forest
