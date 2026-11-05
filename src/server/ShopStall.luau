-- Прилавок магазина (из присланного генератора ShopStall), поставленный в лобби.
-- Строится вокруг точки (0,0,0) лицом в -Z, потом переносится в нужное место.
-- Жёлтое кольцо перед прилавком: зашёл в него — открывается магазин (это делает клиент).
local Players = game:GetService("Players")

local ShopStall = {}

ShopStall.RING_LOCAL = Vector3.new(0, 0.13, -5.2) -- центр кольца в координатах прилавка
ShopStall.RING_RADIUS = 3.0

function ShopStall.build(parent, targetCF)
	local model = Instance.new("Model")
	model.Name = "ShopStall"
	model.Parent = parent

	local function part(name, size, cf, color, material, shape)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.Wood
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if shape then
			p.Shape = shape
		end
		p.Parent = model
		return p
	end

	local function pointLight(parentPart, color, brightness, range)
		local l = Instance.new("PointLight")
		l.Color = color
		l.Brightness = brightness
		l.Range = range
		l.Shadows = true
		l.Parent = parentPart
	end

	local wood = Color3.fromRGB(112, 65, 38)
	local darkWood = Color3.fromRGB(75, 43, 29)
	local trim = Color3.fromRGB(151, 91, 51)
	local stone = Color3.fromRGB(135, 130, 119)
	local stoneDark = Color3.fromRGB(91, 88, 82)
	local red = Color3.fromRGB(170, 38, 42)
	local redLight = Color3.fromRGB(205, 57, 59)
	local gold = Color3.fromRGB(255, 190, 48)
	local ropeColor = Color3.fromRGB(190, 143, 83)

	-- прилавок из камня и дерева
	part("StoneCounterBase", Vector3.new(16, 2.2, 2.2), CFrame.new(0, 2.0, 0), stone, Enum.Material.Slate)
	part("FrontWoodPanel", Vector3.new(15.6, 1.0, 0.22), CFrame.new(0, 2.05, -1.17), wood, Enum.Material.WoodPlanks)
	part("CounterTop", Vector3.new(16.5, 0.38, 2.7), CFrame.new(0, 3.28, 0), trim, Enum.Material.WoodPlanks)
	part("CounterFrontTrim", Vector3.new(16.2, 0.18, 0.16), CFrame.new(0, 2.62, -1.32), darkWood, Enum.Material.Wood)
	for x = -6, 6, 2 do
		part("StoneBlock", Vector3.new(1.85, 0.72, 0.12), CFrame.new(x, 1.95, -1.32), stoneDark, Enum.Material.Slate)
		part("StoneBlockUpper", Vector3.new(1.85, 0.55, 0.12), CFrame.new(x + 1, 2.55, -1.32), stone, Enum.Material.Slate)
	end

	-- задняя стенка и полки
	part("BackWall", Vector3.new(15.5, 5.1, 0.45), CFrame.new(0, 5.65, 2.15), darkWood, Enum.Material.WoodPlanks)
	for y = 4.7, 6.2, 1.5 do
		part("Shelf", Vector3.new(13.5, 0.22, 1.0), CFrame.new(0, y, 1.35), trim, Enum.Material.WoodPlanks)
	end
	for _, x in { -6.3, 6.3 } do
		part("ShelfSupport", Vector3.new(0.25, 2.3, 0.25), CFrame.new(x, 5.4, 1.35), wood, Enum.Material.Wood)
	end

	-- стойки и навес
	for _, x in { -7.2, 7.2 } do
		for z = -0.8, 2.0, 2.8 do
			part("RoofPost", Vector3.new(0.48, 6.8, 0.48), CFrame.new(x, 4.3, z), darkWood, Enum.Material.Wood)
		end
	end
	part("RoofBeamFront", Vector3.new(15.2, 0.55, 0.55), CFrame.new(0, 7.45, -0.7), wood, Enum.Material.Wood)
	part("RoofBeamBack", Vector3.new(15.2, 0.55, 0.55), CFrame.new(0, 7.45, 2.1), wood, Enum.Material.Wood)
	part("CanopyTop", Vector3.new(16.4, 0.35, 4.6), CFrame.new(0, 7.85, 0.7), red, Enum.Material.SmoothPlastic)
	for i = -4, 4 do
		local c = (i % 2 == 0) and redLight or Color3.fromRGB(235, 225, 215)
		part("CanopyStripe", Vector3.new(1.78, 0.22, 4.35), CFrame.new(i * 1.8, 7.99, 0.7), c, Enum.Material.SmoothPlastic)
	end
	part("AwningFront", Vector3.new(16.4, 0.9, 0.28), CFrame.new(0, 7.35, -1.62), redLight, Enum.Material.SmoothPlastic)

	-- вывеска
	local sign = part("SignBoard", Vector3.new(7.2, 1.55, 0.35), CFrame.new(0, 8.95, -1.75), wood, Enum.Material.WoodPlanks)
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.CanvasSize = Vector2.new(800, 180)
	signGui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "МАГАЗИН"
	label.TextColor3 = Color3.fromRGB(255, 245, 225)
	label.TextStrokeTransparency = 0.25
	label.TextStrokeColor3 = red
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = signGui

	-- фонари
	for _, x in { -6.3, 6.3 } do
		local lamp = part("Lantern", Vector3.new(0.75, 0.95, 0.75), CFrame.new(x, 5.7, -1.2), gold, Enum.Material.Neon)
		pointLight(lamp, Color3.fromRGB(255, 185, 75), 1.2, 12)
		part("LanternCap", Vector3.new(0.95, 0.16, 0.95), CFrame.new(x, 6.25, -1.2), darkWood, Enum.Material.Wood)
	end

	-- товары на полках
	local goods = {
		{ Color3.fromRGB(140, 75, 220), Enum.Material.Neon },
		{ Color3.fromRGB(55, 170, 235), Enum.Material.Glass },
		{ Color3.fromRGB(235, 75, 75), Enum.Material.SmoothPlastic },
		{ Color3.fromRGB(245, 180, 45), Enum.Material.Metal },
		{ Color3.fromRGB(75, 190, 105), Enum.Material.Neon },
	}
	for i = 1, 10 do
		local x = -5.8 + (i - 1) * 1.28
		local g = goods[((i - 1) % #goods) + 1]
		local bottle = part("DisplayItem", Vector3.new(0.58, 0.9, 0.58), CFrame.new(x, 5.25, 0.9), g[1], g[2], Enum.PartType.Cylinder)
		bottle.Orientation = Vector3.new(0, 0, 90)
	end
	for i = 1, 6 do
		local x = -4.8 + (i - 1) * 1.9
		part("GiftBox", Vector3.new(0.85, 0.75, 0.75), CFrame.new(x, 6.65, 1.0), (i % 2 == 0) and redLight or gold, Enum.Material.SmoothPlastic)
		part("GiftRibbon", Vector3.new(0.12, 0.78, 0.78), CFrame.new(x, 6.65, 0.59), Color3.fromRGB(255, 240, 190), Enum.Material.SmoothPlastic)
	end

	-- боковые флажки
	for _, x in { -7.65, 7.65 } do
		part("BannerPole", Vector3.new(0.16, 2.7, 0.16), CFrame.new(x, 5.4, -0.8), darkWood, Enum.Material.Wood)
		part("RedBanner", Vector3.new(1.15, 1.8, 0.12), CFrame.new(x, 5.25, -0.9), red, Enum.Material.Fabric)
	end

	-- канаты-ограждения по бокам
	for side = -1, 1, 2 do
		local x = side * 9.4
		for z = -3.4, 1.0, 4.4 do
			part("RopePost", Vector3.new(0.48, 1.65, 0.48), CFrame.new(x, 0.85, z), wood, Enum.Material.Wood)
			part("PostCap", Vector3.new(0.62, 0.18, 0.62), CFrame.new(x, 1.72, z), trim, Enum.Material.Wood)
		end
		local rope = part("QueueRope", Vector3.new(0.18, 0.18, 4.4), CFrame.new(x, 1.15, -1.2), ropeColor, Enum.Material.Fabric, Enum.PartType.Cylinder)
		rope.Orientation = Vector3.new(90, 0, 0)
	end

	-- жёлтое кольцо перед прилавком (24 сегмента)
	local ringCenter = ShopStall.RING_LOCAL
	local ringRadius = ShopStall.RING_RADIUS
	for i = 1, 24 do
		local a = (i - 1) * (math.pi * 2 / 24)
		local b = i * (math.pi * 2 / 24)
		local mid = (a + b) / 2
		local segmentLength = 2 * ringRadius * math.sin((b - a) / 2) + 0.08
		local segment = part(
			"InteractionRingSegment",
			Vector3.new(segmentLength, 0.10, 0.16),
			CFrame.new(ringCenter + Vector3.new(math.cos(mid) * ringRadius, 0, math.sin(mid) * ringRadius)) * CFrame.Angles(0, -mid, 0),
			gold,
			Enum.Material.Neon
		)
		segment.Transparency = 0.32
		segment.CanCollide = false
	end

	-- переносим прилавок на место
	model.WorldPivot = CFrame.new()
	model:PivotTo(targetCF)
	model.PrimaryPart = model:FindFirstChild("StoneCounterBase")

	-- продавец за прилавком (вместо зелёной метки)
	pcall(function()
		local desc = Instance.new("HumanoidDescription")
		desc.HeadColor = Color3.fromRGB(234, 190, 150)
		desc.TorsoColor = Color3.fromRGB(240, 236, 226)
		desc.LeftArmColor = Color3.fromRGB(240, 236, 226)
		desc.RightArmColor = Color3.fromRGB(240, 236, 226)
		desc.LeftLegColor = Color3.fromRGB(60, 62, 70)
		desc.RightLegColor = Color3.fromRGB(60, 62, 70)
		local rig = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
		rig.Name = "Продавец"
		local hum = rig:FindFirstChildOfClass("Humanoid")
		hum.DisplayName = "Продавец"
		local root = rig:FindFirstChild("HumanoidRootPart")
		root.Anchored = true
		rig.Parent = model
		local pos = targetCF:PointToWorldSpace(Vector3.new(0, 3, 1.0))
		rig:PivotTo(CFrame.lookAt(pos, pos + targetCF.LookVector))
		-- красный фартук
		local torso = rig:FindFirstChild("UpperTorso")
		if torso then
			local apron = Instance.new("Part")
			apron.Name = "Apron"
			apron.Size = Vector3.new(1.6, 1.5, 0.12)
			apron.Color = red
			apron.Material = Enum.Material.Fabric
			apron.CanCollide = false
			apron.Massless = true
			apron.CFrame = torso.CFrame * CFrame.new(0, -0.3, -0.55)
			apron.Parent = rig
			local w = Instance.new("WeldConstraint")
			w.Part0 = torso
			w.Part1 = apron
			w.Parent = apron
		end
	end)

	return model
end

return ShopStall
