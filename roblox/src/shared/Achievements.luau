--!strict
-- Достижения: общий список для сервера (проверка, сохранение, награда) и клиента (экран, уведомления).
-- Тот же список — в веб-версии (tools/web_premium.py, ACH_JS).
local Achievements = {}

export type Ach = { id: string, icon: string, title: string, desc: string, reward: number, client: boolean? }

Achievements.LIST = {
	{ id = "first_flight", icon = "✈", title = "Первый полёт", desc = "Оторвись от полосы", reward = 100, client = true },
	{ id = "soft", icon = "🪶", title = "Мягкая посадка", desc = "Сядь мягче 250 ft/min", reward = 200 },
	{ id = "butter", icon = "🧈", title = "Как по маслу", desc = "Сядь мягче 80 ft/min", reward = 500 },
	{ id = "center", icon = "🎯", title = "Точно по оси", desc = "Сядь не дальше 2 м от оси полосы", reward = 300, client = true },
	{ id = "route", icon = "🧳", title = "Рейс выполнен", desc = "Долети до аэропорта назначения в режиме рейсов", reward = 500 },
	{ id = "ten", icon = "🔟", title = "Десять посадок", desc = "Соверши 10 посадок", reward = 500 },
	{ id = "airports", icon = "🌍", title = "Все аэропорты", desc = "Сядь во всех 8 аэропортах", reward = 2000 },
	{ id = "high", icon = "🛰", title = "Стратосфера", desc = "Поднимись выше 35 000 ft", reward = 300, client = true },
	{ id = "night", icon = "🌙", title = "Ночной пилот", desc = "Посади самолёт ночью", reward = 400 },
	{ id = "race", icon = "🏁", title = "Гонщик", desc = "Пройди все кольца гонки", reward = 500 },
	{ id = "ace", icon = "⚡", title = "Ас", desc = "Выдержи 8 G на F-16", reward = 400, client = true },
	{ id = "heavy", icon = "🐘", title = "Тяжеловес", desc = "Посади Airbus A380 или Boeing 747", reward = 300 },
	{ id = "photographer", icon = "📸", title = "Фотограф", desc = "Сними 10 достопримечательностей в фото-режиме", reward = 1000 },
	{ id = "one_engine", icon = "🔥", title = "Один мотор", desc = "Посади самолёт с отказавшим двигателем", reward = 600, client = true },
} :: { Ach }

Achievements.BY_ID = {} :: { [string]: Ach }
for _, a in Achievements.LIST do
	Achievements.BY_ID[a.id] = a
end

return Achievements
