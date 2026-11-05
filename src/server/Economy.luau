-- Монеты и покупка усилений. Пока без сохранения между заходами (DataStore добавим позже).
-- Монеты и купленные предметы хранятся в атрибутах игрока: Coins, Boost_<id>.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Economy = {}

local function findBoost(id)
	for _, b in Config.BOOSTS do
		if b.id == id then
			return b
		end
	end
	return nil
end

local function setup(player)
	if player:GetAttribute("Coins") == nil then
		player:SetAttribute("Coins", Config.START_COINS)
	end
end

function Economy.start()
	Players.PlayerAdded:Connect(setup)
	for _, pl in Players:GetPlayers() do
		setup(pl)
	end

	Remotes.Shop.OnServerEvent:Connect(function(player, action, id)
		if action ~= "BuyBoost" or typeof(id) ~= "string" then
			return
		end
		local item = findBoost(id)
		if not item then
			return
		end
		local coins = player:GetAttribute("Coins") or 0
		if coins < item.price then
			Remotes.Shop:FireClient(player, "Result", false, "Не хватает монет")
			return
		end
		player:SetAttribute("Coins", coins - item.price)
		local key = "Boost_" .. id
		player:SetAttribute(key, (player:GetAttribute(key) or 0) + 1)
		Remotes.Shop:FireClient(player, "Result", true, item.name .. " куплено!")
	end)
end

return Economy
