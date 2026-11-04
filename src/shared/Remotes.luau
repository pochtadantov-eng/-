-- Сервер создаёт RemoteEvent'ы при первом require, клиент ждёт их появления.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NAMES = { "LobbyAction", "LobbyState", "CutsceneFx" }

local folder
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in NAMES do
		local ev = Instance.new("RemoteEvent")
		ev.Name = name
		ev.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local Remotes = {}
for _, name in NAMES do
	Remotes[name] = folder:WaitForChild(name)
end

return Remotes
