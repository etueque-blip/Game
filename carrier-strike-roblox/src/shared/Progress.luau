--!strict
-- Прогресс игрока: цены самолётов, раскраски, уровни, награды, ежедневные награды и задания.
-- Общий для сервера (начисляет) и клиента (показывает). Все цифры можно менять здесь.
local Progress = {}

-- самолёт: цена в монетах и нужный уровень
Progress.JETS = {
	F16 = { cost = 0, level = 1 },
	MIG29 = { cost = 0, level = 1 },
	FA18 = { cost = 600, level = 2 },
	RAFALE = { cost = 1200, level = 4 },
	SU33 = { cost = 2000, level = 6 },
	F35 = { cost = 3500, level = 8 },
} :: { [string]: { cost: number, level: number } }

-- раскраски: корпус и второй цвет; киль всегда цвета команды, чтобы своих было видно
Progress.PAINTS = {
	{ id = "team", cost = 0, level = 1 },
	{ id = "camo", cost = 300, level = 2, body = Color3.fromRGB(96, 110, 82), accent = Color3.fromRGB(70, 80, 60) },
	{ id = "desert", cost = 500, level = 3, body = Color3.fromRGB(196, 174, 128), accent = Color3.fromRGB(150, 128, 90) },
	{ id = "arctic", cost = 700, level = 4, body = Color3.fromRGB(232, 238, 244), accent = Color3.fromRGB(150, 170, 190) },
	{ id = "night", cost = 900, level = 5, body = Color3.fromRGB(34, 38, 46), accent = Color3.fromRGB(20, 22, 28) },
	{ id = "shark", cost = 1500, level = 7, body = Color3.fromRGB(120, 132, 146), accent = Color3.fromRGB(200, 40, 40) },
	{ id = "neon", cost = 2500, level = 10, body = Color3.fromRGB(30, 30, 40), accent = Color3.fromRGB(0, 230, 255) },
	{ id = "gold", cost = 0, level = 1, vip = true, body = Color3.fromRGB(214, 172, 60), accent = Color3.fromRGB(150, 110, 30) },
}
function Progress.paint(id: string): any?
	for _, p in Progress.PAINTS do
		if p.id == id then
			return p
		end
	end
	return nil
end

-- уровень: чтобы дойти до уровня L, нужно 250·(L−1)·L/2 опыта (250, 750, 1500, 2500 …)
function Progress.xpFor(level: number): number
	return 125 * (level - 1) * level
end
function Progress.levelOf(xp: number): (number, number, number)
	local l = 1
	while Progress.xpFor(l + 1) <= xp and l < 100 do
		l += 1
	end
	local base = Progress.xpFor(l)
	return l, xp - base, Progress.xpFor(l + 1) - base
end

-- награды {монеты, опыт}
Progress.REWARD = {
	kill = { 50, 100 },
	assist = { 20, 40 },
	capture = { 40, 80 },
	win = { 150, 250 },
	loss = { 50, 80 },
	mvp = { 100, 100 },
	landing = { 15, 20 }, -- посадка на свою палубу
} :: { [string]: { number } }
-- серия сбитий без смерти → бонус
Progress.STREAK = { [3] = 50, [5] = 100, [8] = 200, [12] = 400 } :: { [number]: number }

-- ежедневная награда за вход (7 дней подряд, потом по кругу)
Progress.DAILY = { 100, 150, 200, 250, 300, 400, 750 }

-- ежедневные задания: каждый день 3 из списка
Progress.QUESTS = {
	{ id = "kills", n = 5, reward = 200 },
	{ id = "caps", n = 2, reward = 200 },
	{ id = "sorties", n = 4, reward = 150 },
	{ id = "msl", n = 3, reward = 200 },
	{ id = "gun", n = 3, reward = 200 },
	{ id = "wins", n = 1, reward = 250 },
	{ id = "deck", n = 2, reward = 150 },
	{ id = "assists", n = 3, reward = 150 },
}
function Progress.quest(id: string): any?
	for _, q in Progress.QUESTS do
		if q.id == id then
			return q
		end
	end
	return nil
end
function Progress.day(): number
	return os.time() // 86400
end
function Progress.week(): number
	return (os.time() + 3 * 86400) // (7 * 86400) -- неделя с понедельника
end
-- одинаковый набор заданий на день для игрока (без случайности, чтобы не «перекручивать»)
function Progress.questsFor(day: number, userId: number): { string }
	local rng = Random.new(day * 7919 + userId % 100003)
	local pool = {}
	for _, q in Progress.QUESTS do
		table.insert(pool, q.id)
	end
	local out = {}
	for _ = 1, 3 do
		local i = rng:NextInteger(1, #pool)
		table.insert(out, pool[i])
		table.remove(pool, i)
	end
	return out
end

return Progress
