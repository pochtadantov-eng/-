-- Общее лобби: площадка, спавн и 4 круга, в которые заходят игроки.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Hub = { pads = {} }

local function makePart(parent, name, size, position, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Position = position
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function Hub.build()
	local folder = Instance.new("Folder")
	folder.Name = "Hub"
	folder.Parent = Workspace

	makePart(folder, "Ground", Vector3.new(260, 2, 200), Vector3.new(0, -1, 0), Color3.fromRGB(86, 140, 76), Enum.Material.Grass)
	makePart(folder, "Plaza", Vector3.new(190, 0.2, 50), Vector3.new(0, 0.1, -30), Color3.fromRGB(150, 150, 156), Enum.Material.Concrete)

	-- Невидимые стены по краям, чтобы никто не упал с площадки
	local walls = {
		{ Vector3.new(260, 40, 2), Vector3.new(0, 20, -100) },
		{ Vector3.new(260, 40, 2), Vector3.new(0, 20, 100) },
		{ Vector3.new(2, 40, 200), Vector3.new(-130, 20, 0) },
		{ Vector3.new(2, 40, 200), Vector3.new(130, 20, 0) },
	}
	for i, w in walls do
		local wall = makePart(folder, "Wall" .. i, w[1], w[2], Color3.new(), Enum.Material.SmoothPlastic)
		wall.Transparency = 1
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.Position = Vector3.new(0, 0.5, 35)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 0.6
	spawn.Color = Color3.fromRGB(255, 255, 255)
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = folder

	local radius = Config.PAD_RADIUS
	for i = 1, Config.PAD_COUNT do
		local x = (i - (Config.PAD_COUNT + 1) / 2) * 30
		local z = -30

		local pad = Instance.new("Part")
		pad.Name = "Pad" .. i
		pad.Shape = Enum.PartType.Cylinder
		pad.Anchored = true
		pad.CanCollide = false
		pad.Material = Enum.Material.Neon
		pad.Color = Color3.fromRGB(90, 220, 120)
		pad.Size = Vector3.new(0.3, radius * 2, radius * 2)
		pad.CFrame = CFrame.new(x, 0.35, z) * CFrame.Angles(0, 0, math.rad(90))
		pad.Parent = folder

		local anchor = Instance.new("Part")
		anchor.Name = "LabelAnchor" .. i
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(1, 1, 1)
		anchor.Position = Vector3.new(x, 9, z)
		anchor.Parent = folder

		local gui = Instance.new("BillboardGui")
		gui.Adornee = anchor
		gui.Size = UDim2.fromOffset(240, 72)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 140
		gui.Parent = anchor

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.new(0, 0, 0)
		label.BackgroundTransparency = 0.4
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Font = Enum.Font.GothamBold
		label.TextSize = 20
		label.TextWrapped = true
		label.Text = ""
		label.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = label

		table.insert(Hub.pads, {
			id = i,
			center = Vector3.new(x, 0, z),
			radius = radius,
			part = pad,
			label = label,
		})
	end

	return Hub.pads
end

return Hub
