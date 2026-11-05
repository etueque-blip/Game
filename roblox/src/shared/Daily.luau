--!strict
-- Ежедневные задания: три задания на каждый день (UTC), одинаковые для всех игроков.
-- Тот же генератор — в веб-версии (tools/web_premium.py, DAILY_JS): Park–Miller, целые до 2^53.
local PlaneConfigs = require(script.Parent:WaitForChild("PlaneConfigs"))

local Daily = {}

Daily.AIRPORTS = { "A", "B", "C", "D", "E", "F", "G", "H" }
Daily.CODES = { A = "SKP", B = "MTV", C = "LNW", D = "DXC", E = "TSE", F = "ISB", G = "RYD", H = "SKD" }
Daily.CITIES = {
	{ "Дубай", 5500, -7500, 1700 }, { "Лондон", -4000, 12500, 1300 }, { "Ташкент", 10500, 3000, 1200 },
	{ "Стамбул", -20500, 20500, 1300 }, { "Эр-Рияд", 21000, 20500, 1300 }, { "Самарканд", -21000, -20500, 1200 },
}
Daily.PLANES = { "C172", "LEAR75", "G650", "GL7500", "B737", "A220", "A320", "B787", "A330", "A350", "B777", "B747", "A380" }

export type Task = { id: string, kind: string, target: string, text: string, reward: number, x: number?, z: number?, r: number? }

-- ключ дня: ГГГГММДД (UTC)
function Daily.dateKey(t: any?): number
	local d = t or os.date("!*t")
	return d.year * 10000 + d.month * 100 + d.day
end

function Daily.tasks(key: number): { Task }
	local s = key % 2147483647
	if s == 0 then
		s = 1
	end
	local function nxt(): number
		s = (s * 16807) % 2147483647
		return s
	end
	for _ = 1, 3 do
		nxt()
	end
	local ap = Daily.AIRPORTS[nxt() % #Daily.AIRPORTS + 1]
	local city = Daily.CITIES[nxt() % #Daily.CITIES + 1]
	local plane = Daily.PLANES[nxt() % #Daily.PLANES + 1]
	local pc = PlaneConfigs.PLANES[plane]
	return {
		{ id = "land_" .. ap, kind = "land", target = ap, text = "Посадка в аэропорту " .. Daily.CODES[ap] .. " (" .. ap .. ")", reward = 300 },
		{ id = "over_" .. city[1], kind = "over", target = city[1], text = "Пролети над городом " .. city[1] .. " ниже 3000 ft", reward = 250, x = city[2], z = city[3], r = city[4] },
		{ id = "soft_" .. plane, kind = "soft", target = plane, text = "Мягкая посадка (мягче 200 ft/min) на " .. (if pc then pc.name else plane), reward = 400 },
	}
end

return Daily
