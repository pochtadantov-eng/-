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

local function onPlayer(player)
	player.CharacterAdded:Connect(function(char)
		task.spawn(applyAnimations, char)
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

-- Солнечный день
Lighting.ClockTime = 14
Lighting.GeographicLatitude = 35
Lighting.Brightness = 3
Lighting.ExposureCompensation = 0.2
Lighting.Ambient = Color3.fromRGB(95, 105, 115)
Lighting.OutdoorAmbient = Color3.fromRGB(120, 130, 140)
Lighting.EnvironmentDiffuseScale = 1
Lighting.EnvironmentSpecularScale = 1

local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.2
atmosphere.Offset = 0.15
atmosphere.Color = Color3.fromRGB(199, 215, 235)
atmosphere.Decay = Color3.fromRGB(150, 170, 200)
atmosphere.Glare = 0.3
atmosphere.Haze = 0.6
atmosphere.Parent = Lighting

local sky = Instance.new("Sky")
sky.Parent = Lighting

local sunRays = Instance.new("SunRaysEffect")
sunRays.Intensity = 0.12
sunRays.Spread = 0.8
sunRays.Parent = Lighting

local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.3
bloom.Size = 24
bloom.Threshold = 1.8
bloom.Parent = Lighting

local color = Instance.new("ColorCorrectionEffect")
color.Saturation = 0.12
color.Contrast = 0.06
color.Parent = Lighting

local clouds = Instance.new("Clouds")
clouds.Cover = 0.5
clouds.Density = 0.6
clouds.Parent = Workspace.Terrain

-- Лес генерируется в фоне, пока строится хаб и игроки в нём
task.spawn(Forest.generate)

local pads = Hub.build()
LobbyService.start(pads)
