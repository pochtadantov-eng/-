-- Построение произвольных треугольников из двух клиньев (классический приём EgoMoose).
-- Из треугольников собираем конусы (ели), фронтоны крыш и прочие гладкие формы.
local Geometry = {}

local function newWedge(color, material, thickness)
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.CanTouch = false
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.Color = color
	w.Material = material or Enum.Material.SmoothPlastic
	w.Size = Vector3.new(thickness, 1, 1)
	return w
end

-- Треугольник a-b-c (Vector3 в мировых координатах)
function Geometry.triangle(parent, a, b, c, color, material, thickness, collide)
	thickness = thickness or 0.1
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b

	local cross = ac:Cross(ab)
	if cross.Magnitude < 1e-6 then
		return nil
	end
	local right = cross.Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))

	local w1 = newWedge(color, material, thickness)
	w1.Size = Vector3.new(thickness, height, math.abs(ab:Dot(back)))
	w1.CFrame = CFrame.fromMatrix((a + b) / 2, right, up, back)
	w1.CanCollide = collide == true
	w1.Parent = parent

	local w2 = newWedge(color, material, thickness)
	w2.Size = Vector3.new(thickness, height, math.abs(ac:Dot(back)))
	w2.CFrame = CFrame.fromMatrix((a + c) / 2, -right, up, -back)
	w2.CanCollide = collide == true
	w2.Parent = parent
	return w1, w2
end

-- Гранёный конус: основание в точке base (центр), вершина над ним
function Geometry.cone(parent, base, radius, height, sides, color, material, turn)
	turn = turn or 0
	local apex = base + Vector3.new(0, height, 0)
	local ring = table.create(sides)
	for i = 1, sides do
		local a = turn + (i / sides) * math.pi * 2
		ring[i] = base + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
	end
	for i = 1, sides do
		local p1 = ring[i]
		local p2 = ring[i % sides + 1]
		-- грани чуть разного оттенка — так low-poly выглядит объёмнее
		local tint = (i % 2 == 0) and color or color:Lerp(Color3.new(0, 0, 0), 0.08)
		Geometry.triangle(parent, apex, p1, p2, tint, material, 0.15, false)
	end
end

return Geometry
