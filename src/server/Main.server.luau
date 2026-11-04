local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Hub = require(script.Parent.Hub)
local Forest = require(script.Parent.Forest)
local LobbyService = require(script.Parent.LobbyService)

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
atmosphere.Density = 0.25
atmosphere.Offset = 0.15
atmosphere.Color = Color3.fromRGB(199, 215, 235)
atmosphere.Decay = Color3.fromRGB(150, 170, 200)
atmosphere.Glare = 0.3
atmosphere.Haze = 0.6
atmosphere.Parent = Lighting

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

local pads = Hub.build()
LobbyService.start(pads)

-- Лес генерируется в фоне, пока игроки в хабе
task.spawn(Forest.generate)
