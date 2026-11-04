-- Логика кругов: кто владелец, кто может зайти, создание лобби, таймер, запуск.
--
-- Состояния круга:
--   empty     — никого нет, зайти может первый (он станет владельцем)
--   setup     — владелец внутри и выбирает карту/число игроков; остальные не заходят
--   open      — лобби создано, пока есть свободные места, другие могут зайти
--   countdown — лобби заполнено, идёт таймер (владелец может пропустить)
--   running   — поездка и игра, круг занят
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

local function refreshVisual(p)
	local text
	if p.state == "empty" then
		text = "Свободно\nвстань в круг"
	elseif p.state == "setup" then
		text = p.owner.DisplayName .. "\nсоздаёт лобби…"
	elseif p.state == "open" then
		text = string.format("Лобби: %s\n%d / %d", mapName(p.map), #p.members, p.size)
	elseif p.state == "countdown" then
		local left = math.max(0, math.ceil(p.countdownEnd - Workspace:GetServerTimeNow()))
		text = string.format("Старт через %d", left)
	else
		text = "Игра идёт"
	end
	p.info.label.Text = text
	p.info.part.Color = COLORS[p.state]
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

local function inside(p, pos)
	local c = p.info.center
	local dx, dz = pos.X - c.X, pos.Z - c.Z
	return dx * dx + dz * dz <= p.info.radius ^ 2 and math.abs(pos.Y - c.Y) < 8
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
	sendState(player)

	if player == p.owner then
		-- Владелец ушёл — лобби распускается, остальных выставляем из круга
		local others = table.clone(p.members)
		for _, m in others do
			memberPad[m] = nil
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
				if cur and not inside(cur, root.Position) then
					removeMember(player)
					cur = nil
				end
				if not cur then
					for _, p in pads do
						if inside(p, root.Position) then
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
