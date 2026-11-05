-- Логика кругов: кто владелец, кто может зайти, создание лобби, таймер, запуск.
--
-- Состояния круга:
--   empty     — никого нет, зайти может первый (он станет владельцем)
--   setup     — владелец внутри и выбирает карту/число игроков; барьер закрыт для всех
--   open      — лобби создано, пока есть свободные места, другие могут зайти
--   countdown — лобби заполнено, идёт таймер (владелец может пропустить)
--   running   — поездка и игра, круг занят
--
-- Барьер: у тех, кто внутри круга, особая коллизионная группа «PadMemberN», которая
-- не пускает их через стенку барьера. Выйти можно только кнопкой «Выйти».
-- Для остальных стенка твёрдая, кроме состояний empty и open (есть места).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Cutscene = require(script.Parent.Cutscene)

local LobbyService = {}

local pads = {}
local memberPad = {} -- [Player] = pad

local COLORS = {
	empty = Color3.fromRGB(90, 220, 120),
	setup = Color3.fromRGB(255, 220, 90),
	open = Color3.fromRGB(80, 160, 255),
	countdown = Color3.fromRGB(255, 150, 60),
	running = Color3.fromRGB(230, 70, 70),
}

local function mapName(id)
	for _, m in Config.MAPS do
		if m.id == id then
			return m.name
		end
	end
	return tostring(id)
end

local function isValidMap(id)
	for _, m in Config.MAPS do
		if m.id == id then
			return true
		end
	end
	return false
end

local function setGroup(player, name)
	local char = player.Character
	if not char then
		return
	end
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = name
		end
	end
end

local YELLOW = Color3.fromRGB(255, 221, 60)
local WHITE = Color3.fromRGB(255, 255, 255)
local RED_TEXT = Color3.fromRGB(255, 110, 100)

local function refreshVisual(p)
	local text, color
	if p.state == "empty" then
		text, color = "Свободно", WHITE
	elseif p.state == "setup" then
		text, color = string.format("%d/%d", #p.members, p.previewSize or Config.DEFAULT_PLAYERS), YELLOW
	elseif p.state == "open" then
		text, color = string.format("%d/%d", #p.members, p.size), YELLOW
	elseif p.state == "countdown" then
		local left = math.max(0, math.ceil(p.countdownEnd - Workspace:GetServerTimeNow()))
		text, color = string.format("Отправка через %d", left), YELLOW
	else
		text, color = "В игре", RED_TEXT
	end
	p.info.label.Text = text
	p.info.label.TextColor3 = color

	local mode
	if p.state == "empty" then
		mode = "hidden"
	elseif p.state == "open" and #p.members < p.size then
		mode = "open"
	else
		mode = "blocked"
	end
	local key = mode .. p.state
	if p.barrierKey ~= key then
		p.barrierKey = key
		p.info.setBarrier(mode, COLORS[p.state])
	end
end

local function sendState(player)
	if player.Parent ~= Players then
		return
	end
	local p = memberPad[player]
	if not p then
		Remotes.LobbyState:FireClient(player, { state = "none" })
		return
	end
	Remotes.LobbyState:FireClient(player, {
		state = p.state,
		padId = p.info.id,
		isOwner = p.owner == player,
		map = p.map,
		mapName = p.map and mapName(p.map) or nil,
		size = p.size,
		count = #p.members,
		countdownEnd = p.countdownEnd,
	})
end

local function broadcast(p)
	for _, m in p.members do
		sendState(m)
	end
end

local function resetPad(p)
	p.owner = nil
	p.members = {}
	p.state = "empty"
	p.map = nil
	p.size = 0
	p.previewSize = nil
	p.countdownEnd = nil
	refreshVisual(p)
end

-- Выставляет игрока за границу круга (радиально от центра)
local function pushOut(player, p)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local c = p.info.center
	local dir = Vector3.new(root.Position.X - c.X, 0, root.Position.Z - c.Z)
	if dir.Magnitude < 0.1 then
		dir = Vector3.new(0, 0, 1)
	end
	local target = c + dir.Unit * (p.info.radius + 4) + Vector3.new(0, root.Position.Y, 0)
	root.CFrame = CFrame.new(target) * root.CFrame.Rotation
	root.AssemblyLinearVelocity = Vector3.zero
end

local function inside(p, pos, margin)
	local c = p.info.center
	local dx, dz = pos.X - c.X, pos.Z - c.Z
	local r = p.info.radius + margin
	return dx * dx + dz * dz <= r * r and math.abs(pos.Y - c.Y) < 8
end

local function startCountdown(p)
	p.state = "countdown"
	p.countdownEnd = Workspace:GetServerTimeNow() + Config.COUNTDOWN
end

local function removeMember(player)
	local p = memberPad[player]
	if not p or p.state == "running" then
		return
	end

	local idx = table.find(p.members, player)
	if idx then
		table.remove(p.members, idx)
	end
	memberPad[player] = nil
	setGroup(player, "Default")
	sendState(player)

	if player == p.owner then
		-- Владелец ушёл — лобби распускается, остальных выставляем из круга
		local others = table.clone(p.members)
		for _, m in others do
			memberPad[m] = nil
			setGroup(m, "Default")
			sendState(m)
			pushOut(m, p)
		end
		resetPad(p)
	else
		if p.state == "countdown" then
			-- Кто-то вышел, лобби уже не полное — таймер отменяется
			p.state = "open"
			p.countdownEnd = nil
		end
		broadcast(p)
		refreshVisual(p)
	end
end

local function join(p, player)
	table.insert(p.members, player)
	memberPad[player] = p
	setGroup(player, "PadMember" .. p.info.id)
	if p.state == "empty" then
		p.owner = player
		p.state = "setup"
	elseif p.state == "open" and #p.members >= p.size then
		startCountdown(p)
	end
	broadcast(p)
	refreshVisual(p)
end

local function begin(p)
	if p.state ~= "open" and p.state ~= "countdown" then
		return
	end
	p.state = "running"
	p.countdownEnd = nil
	local roster = table.clone(p.members)
	local map = p.map
	refreshVisual(p)
	broadcast(p)

	task.spawn(function()
		local ok, err = pcall(Cutscene.run, p.info.id, roster, map)
		if not ok then
			warn("[Cutscene] ошибка: " .. tostring(err))
			for _, m in roster do
				if m.Parent == Players then
					Remotes.CutsceneFx:FireClient(m, "Loading", false)
					Remotes.CutsceneFx:FireClient(m, "Fade", false, 0.5)
					task.spawn(function()
						m:LoadCharacter()
					end)
				end
			end
		end
		Cutscene.cleanup(p.info.id)
		for _, m in roster do
			memberPad[m] = nil
			setGroup(m, "Default")
			sendState(m)
		end
		resetPad(p)
	end)
end

local function step()
	for _, player in Players:GetPlayers() do
		local cur = memberPad[player]
		if not (cur and cur.state == "running") then
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not root or not hum or hum.Health <= 0 then
				if cur then
					removeMember(player)
				end
			else
				if cur and not inside(cur, root.Position, 1) then
					-- запасной вариант: если игрок всё же оказался вне круга
					removeMember(player)
					cur = nil
				end
				if not cur then
					for _, p in pads do
						if inside(p, root.Position, -1) then
							if p.state == "empty" then
								join(p, player)
							elseif p.state == "open" and #p.members < p.size then
								join(p, player)
							else
								pushOut(player, p)
							end
							break
						end
					end
				end
			end
		end
	end

	local now = Workspace:GetServerTimeNow()
	for _, p in pads do
		if p.state == "countdown" then
			if now >= p.countdownEnd then
				begin(p)
			else
				refreshVisual(p)
			end
		end
	end
end

function LobbyService.start(hubPads)
	for _, info in hubPads do
		local p = {
			info = info,
			owner = nil,
			members = {},
			state = "empty",
			map = nil,
			size = 0,
			countdownEnd = nil,
			barrierKey = nil,
		}
		table.insert(pads, p)
		refreshVisual(p)
	end

	Remotes.LobbyAction.OnServerEvent:Connect(function(player, action, a, b)
		local p = memberPad[player]
		if not p or p.state == "running" then
			return
		end

		if action == "Create" then
			if p.owner ~= player or p.state ~= "setup" then
				return
			end
			if typeof(a) ~= "string" or not isValidMap(a) then
				return
			end
			local size = math.clamp(math.floor(tonumber(b) or Config.MIN_PLAYERS), Config.MIN_PLAYERS, Config.MAX_PLAYERS)
			p.map = a
			p.size = size
			p.state = "open"
			if #p.members >= size then
				startCountdown(p)
			end
			broadcast(p)
			refreshVisual(p)
		elseif action == "Preview" then
			-- владелец крутит «+ / –», надпись над кругом сразу показывает 1/N
			if p.owner == player and p.state == "setup" then
				p.previewSize = math.clamp(math.floor(tonumber(a) or Config.DEFAULT_PLAYERS), Config.MIN_PLAYERS, Config.MAX_PLAYERS)
				refreshVisual(p)
			end
		elseif action == "StartNow" then
			if p.owner == player then
				begin(p)
			end
		elseif action == "Leave" then
			removeMember(player)
			pushOut(player, p)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeMember(player)
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then
			return
		end
		acc = 0
		step()
	end)
end

return LobbyService
