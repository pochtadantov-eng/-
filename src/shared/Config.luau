local Config = {}

-- Лобби
Config.PAD_COUNT = 4
Config.PAD_RADIUS = 9
Config.MIN_PLAYERS = 1 -- 1 удобно для теста в одиночку; поставь 2+, когда захочешь
Config.MAX_PLAYERS = 6
Config.COUNTDOWN = 10 -- секунд до старта, когда лобби заполнено

-- Карты (пока одна)
Config.MAPS = {
	{ id = "forest", name = "Лес" },
}

-- Где в мире живут сцены (далеко от хаба, чтобы не пересекались)
Config.FOREST_ORIGIN = Vector3.new(3000, 0, 0) -- центр карты леса
Config.FOREST_SIZE = 512 -- сторона квадрата, должна делиться на 4
Config.STAGE_ORIGIN = Vector3.new(-3000, 0, 0) -- сцена с поездкой на машине

-- Поездка
Config.DRIVE_SECONDS = 12
Config.DRIVE_DISTANCE = 420

-- Хаб
Config.ROAD_Z = -135 -- дорога за забором, по ней ездят машины

-- Музыка. Вставь сюда ID трека из Roblox (только число), например 1234567890.
-- Пустая строка "" = без музыки. Как найти ID: Toolbox -> Audio -> выбери трек -> Copy Asset ID.
-- Roblox разрешает использовать только свои или бесплатные публичные треки.
Config.HUB_MUSIC_ID = ""
Config.FOREST_MUSIC_ID = ""

return Config
