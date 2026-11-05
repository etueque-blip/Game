--!strict
-- Комфорт пассажиров: 100% в начале полёта, падает от крутых кренов, перегрузки, резкой вертикальной,
-- тряски и жёсткой посадки; в спокойном полёте понемногу восстанавливается.
-- Та же логика — в веб-версии (tools/web_premium.py, PAX_JS).
local Comfort = {}

-- сколько пассажиров на борту (0 — у истребителя)
function Comfort.passengers(c: any): number
	if c.id == "F16" then
		return 0
	elseif c.engines == "prop" then
		return 3
	elseif c.engines == "turboprop2" then
		return 70
	elseif c.length < 130 and c.diameter < 11 then
		return math.max(6, math.round(c.length * 0.12))
	end
	local k = if c.diameter < 16 then 1.3 else 1.35
	return math.round(c.length * k * (if c.doubleDeck then 1.5 else 1))
end

-- шаг в воздухе: bankDeg — крен, gload — перегрузка, vsFpm — вертикальная, buffet — тряска 0..1
function Comfort.step(v: number, dt: number, bankDeg: number, gload: number, vsFpm: number, buffet: number): number
	local pen = math.max(0, math.abs(bankDeg) - 30) * 0.05
		+ math.max(0, math.abs(gload - 1) - 0.35) * 10
		+ (if math.abs(vsFpm) > 3000 then 1.2 else 0)
		+ buffet * 5
	local nv = v - pen * dt
	if pen == 0 then
		nv += 0.15 * dt
	end
	return math.clamp(nv, 0, 100)
end

-- штраф за касание
function Comfort.touchdown(v: number, fpm: number): number
	return math.clamp(v - math.max(0, fpm - 350) / 25, 0, 100)
end

-- оценка 1–5 звёзд
function Comfort.stars(v: number): number
	return if v >= 90 then 5 elseif v >= 70 then 4 elseif v >= 50 then 3 elseif v >= 30 then 2 else 1
end

function Comfort.starsText(v: number): string
	local n = Comfort.stars(v)
	return string.rep("★", n) .. string.rep("☆", 5 - n)
end

return Comfort
