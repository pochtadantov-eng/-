local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Hub = require(script.Parent.Hub)
local Forest = require(script.Parent.Forest)
local LobbyService = require(script.Parent.LobbyService)
local Economy = require(script.Parent.Economy)
local Config = require(ReplicatedStorage.Shared.Config)

-- Плавная ходьба и бег: меняем анимации в стандартном скрипте Animate персонажа
local function applyAnimations(char)
	local animate = char:WaitForChild("Animate", 10)
	if not animate then
		return
	end
	local function set(folderName, animName, id)
		if id == nil or id == "" then
			return
		end
		local folder = animate:WaitForChild(folderName, 5)
		local anim = folder and folder:WaitForChild(animName, 5)
		if anim then
			anim.AnimationId = "rbxassetid://" .. id
		end
	end
	set("walk", "WalkAnim", Config.WALK_ANIM_ID)
	set("run", "RunAnim", Config.RUN_ANIM_ID)
end

-- Камеру нельзя отдалять слишком далеко: мир не должен выглядеть «островом в пустоте»
game:GetService("StarterPlayer").CameraMaxZoomDistance = 60

local function onPlayer(player)
	player.CameraMaxZoomDistance = 60
	player.CharacterAdded:Connect(function(char)
		task.spawn(applyAnimations, char)
		-- на крутые склоны не забраться: персонаж с них соскальзывает
		local hum = char:WaitForChild("Humanoid", 10)
		if hum then
			hum.MaxSlopeAngle = 46
		end
	end)
	if player.Character then
		task.spawn(applyAnimations, player.Character)
	end
end
Players.PlayerAdded:Connect(onPlayer)
for _, pl in Players:GetPlayers() do
	onPlayer(pl)
end

Economy.start()

-- Солнечный день в «игрушечном» стиле: мягкие тени, яркие сочные цвета, лёгкая дымка
Lighting.ClockTime = 14
Lighting.GeographicLatitude = 30
Lighting.Brightness = 2.6
Lighting.ExposureCompensation = 0
Lighting.Ambient = Color3.fromRGB(120, 125, 135)
Lighting.OutdoorAmbient = Color3.fromRGB(150, 155, 165)
Lighting.EnvironmentDiffuseScale = 1
Lighting.EnvironmentSpecularScale = 0.5
Lighting.ShadowSoftness = 0.6

local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.14
atmosphere.Offset = 0.2
atmosphere.Color = Color3.fromRGB(205, 220, 240)
atmosphere.Decay = Color3.fromRGB(160, 180, 210)
atmosphere.Glare = 0.2
atmosphere.Haze = 0.5
atmosphere.Parent = Lighting

local sky = Instance.new("Sky")
sky.Parent = Lighting

local sunRays = Instance.new("SunRaysEffect")
sunRays.Intensity = 0.04
sunRays.Spread = 0.7
sunRays.Parent = Lighting

local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.12
bloom.Size = 18
bloom.Threshold = 2.4
bloom.Parent = Lighting

local color = Instance.new("ColorCorrectionEffect")
color.Saturation = 0.25
color.Contrast = 0.04
color.Brightness = 0.02
color.TintColor = Color3.fromRGB(255, 250, 242)
color.Parent = Lighting

-- Травинки на траве выключаются только в Studio (Workspace -> Terrain -> Decoration),
-- из скрипта Roblox это менять не даёт, поэтому пробуем осторожно и не падаем.
pcall(function()
	Workspace.Terrain.Decoration = false
end)

local clouds = Instance.new("Clouds")
clouds.Cover = 0.45
clouds.Density = 0.55
clouds.Parent = Workspace.Terrain

-- Лес генерируется в фоне, пока строится хаб и игроки в нём
task.spawn(function()
	local ok, err = xpcall(Forest.generate, debug.traceback)
	if not ok then
		warn("[Forest] ошибка генерации леса:\n" .. tostring(err))
	end
end)

local ok, result = xpcall(Hub.build, debug.traceback)
if not ok then
	warn("[Hub] ошибка постройки лобби:\n" .. tostring(result))
	result = require(script.Parent.Hub).pads
end
LobbyService.start(result)
