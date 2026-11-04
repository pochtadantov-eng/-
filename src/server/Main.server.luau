local Lighting = game:GetService("Lighting")

local Hub = require(script.Parent.Hub)
local Forest = require(script.Parent.Forest)
local LobbyService = require(script.Parent.LobbyService)

-- Освещение
Lighting.ClockTime = 15
Lighting.Brightness = 2.5
Lighting.Ambient = Color3.fromRGB(90, 100, 110)
Lighting.OutdoorAmbient = Color3.fromRGB(110, 120, 130)
local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.28
atmosphere.Offset = 0.1
atmosphere.Color = Color3.fromRGB(199, 210, 225)
atmosphere.Parent = Lighting

local pads = Hub.build()
LobbyService.start(pads)

-- Лес генерируется в фоне, пока игроки в хабе
task.spawn(Forest.generate)
