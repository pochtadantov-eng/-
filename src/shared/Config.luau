local Config = {}

-- Лобби
Config.PAD_COUNT = 4
Config.PAD_RADIUS = 8
Config.MIN_PLAYERS = 1 -- 1 удобно для теста в одиночку; поставь 2+, когда захочешь
Config.MAX_PLAYERS = 6
Config.DEFAULT_PLAYERS = 4
Config.COUNTDOWN = 10 -- секунд до отправки, когда лобби заполнено

-- Карты (пока одна)
Config.MAPS = {
	{ id = "forest", name = "Лес", icon = "🌲" },
}

-- Где в мире живут сцены (далеко от хаба, чтобы не пересекались)
Config.FOREST_ORIGIN = Vector3.new(3000, 0, 0) -- центр карты леса
Config.FOREST_SIZE = 512 -- сторона квадрата, должна делиться на 4
Config.STAGE_ORIGIN = Vector3.new(-3000, 0, 0) -- сцена с поездкой на машине

-- Поездка
Config.DRIVE_SECONDS = 12
Config.DRIVE_DISTANCE = 420

-- Хаб
Config.ROAD_Z = -92 -- дорога за стеной, по ней ездят машины
Config.TUNNEL_X = 204 -- въезды в тоннели на концах дороги (машины исчезают внутри)
Config.CAR_WRAP_X = 262 -- где внутри тоннеля машина «перескакивает» на другой конец

-- Музыка. Вставь сюда ID трека из Roblox (только число), например 1234567890.
-- Пустая строка "" = без музыки. Как найти ID: Toolbox -> Audio -> выбери трек -> Copy Asset ID.
Config.HUB_MUSIC_ID = ""
Config.FOREST_MUSIC_ID = ""

-- Анимации ходьбы и бега (официальные паки Roblox, R15).
-- Сейчас стоит пак Rthro — плавный и естественный.
-- Другие варианты (ходьба / бег):
--   Stylish   616146177 / 616140816
--   Cartoony  742640026 / 742638842
--   Ninja     656121766 / 656118852
--   Superhero 616122287 / 616117076
--   Mage      707897309 / 707861613
-- Пустая строка "" = стандартная анимация Roblox.
Config.WALK_ANIM_ID = "2510202577"
Config.RUN_ANIM_ID = "2510198475"

-- Экономика (пока без сохранения между заходами)
Config.START_COINS = 500

-- Усиления для выживания (покупаются в лобби, работать начнут в самом режиме)
Config.BOOSTS = {
	{ id = "flashlight", name = "Фонарик", icon = "🔦", rarity = "Обычный", price = 50, desc = "Светит в тёмных пещерах" },
	{ id = "food", name = "Консервы", icon = "🥫", rarity = "Обычный", price = 40, desc = "Утоляют голод" },
	{ id = "medkit", name = "Аптечка", icon = "🩹", rarity = "Редкий", price = 90, desc = "Лечит раны" },
	{ id = "energy", name = "Энергетик", icon = "⚡", rarity = "Редкий", price = 70, desc = "Быстрее бег на 20 сек" },
	{ id = "compass", name = "Компас", icon = "🧭", rarity = "Эпический", price = 150, desc = "Ведёт обратно к лагерю" },
	{ id = "armor", name = "Бронежилет", icon = "🛡️", rarity = "Эпический", price = 220, desc = "Меньше урона" },
}

-- Магазин (скины, питомцы и т.п. — появятся позже)
Config.SHOP_SOON = {
	{ name = "Скины", icon = "👕" },
	{ name = "Питомцы", icon = "🐾" },
	{ name = "Наборы монет", icon = "💰" },
}

Config.RARITY_COLORS = {
	["Обычный"] = Color3.fromRGB(200, 200, 205),
	["Редкий"] = Color3.fromRGB(80, 160, 255),
	["Эпический"] = Color3.fromRGB(190, 90, 255),
}

return Config
