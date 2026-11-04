--!strict
-- Инструкция по полёту для конкретного самолёта: цифры считаются из его характеристик
-- (те же формулы, что в веб-версии).
local FlightPhysics = require(script.Parent:WaitForChild("FlightPhysics"))

local Guide = {}

local function r5(v: number): number
	return math.floor(v / 5 + 0.5) * 5
end

function Guide.steps(c: any): { { string } }
	local flapsTo = if c.noFlaps then "без закрылков" else "закрылки 1–2 (F)"
	local v2 = r5(c.vrKts * 1.15)
	local flapsUp = r5(c.vrKts + 35)
	local cruiseAlt = math.floor(c.ceilingFt * 0.8 / 1000 + 0.5) * 1000
	local cruiseSpd = r5(c.maxKts * 0.8)
	local stall3 = c.stallKts * (if c.noFlaps then 1 else 0.79)
	local vapp = r5(stall3 * 1.3)
	local climb = if c.maxKts < 200 then "700–900" else "1500–2500"
	local gMax, gMin, fbw = FlightPhysics.limits(c)
	local gearMax = FlightPhysics.gearMaxKts(c)
	local limitText = string.format("Перегрузка от %+.1f до %+.1f G (индикатор G справа). %s Не быстрее %d kt%s%s.", gMax, gMin,
		if fbw
			then "Fly-by-wire не даст превысить предел, но на большой скорости штурвал всё равно тяни плавно."
			else "Защиты нет: резкий рывок штурвала на большой скорости повреждает самолёт, ×1,5 предела — разрушение.",
		c.maxKts,
		if c.noFlaps then "" else string.format(", закрылки — до %d kt", c.flapMaxKts),
		if c.fixedGear or gearMax >= 9999 then "" else string.format(", шасси выпускать до %d kt", gearMax))
	return {
		{ "1. Взлёт", string.format("Отпусти тормоз (пробел), %s, тяга 100%% (Shift). На %d kt плавно тяни на себя (S) до 8–10°, не больше %d°.", flapsTo, c.vrKts, c.maxRotate) },
		{ "2. Набор", string.format("После отрыва — шасси (G). Держи %d kt, вертикальная %s ft/min. Выше %d kt убери закрылки (R).", v2, climb, flapsUp) },
		{ "3. Крейсер", string.format("Эшелон около %s ft, скорость %d kt. Включи навигацию (N) и автопилот (P) — он сам долетит.", tostring(cruiseAlt), cruiseSpd) },
		{ "4. Снижение", "За 30–40 км до аэропорта снижайся 1500–2000 ft/min, уменьши тягу (Ctrl). Слишком быстро — интерцепторы (X). Набери 2000–3000 ft к 12 км." },
		{ "5. Заход", string.format("Скорость захода %d kt, %s, шасси выпущено. Держи ILS «на глиссаде ✓» (вертикальная ~700 ft/min).", vapp, if c.noFlaps then "без закрылков" else string.format("закрылки 3 (не быстрее %d kt)", c.flapMaxKts)) },
		{ "6. Посадка", string.format("Касание мягче 600 ft/min (лучше 250, лимит %d). После касания — тяга 0 (Z), интерцепторы (X), реверс (T), тормоз (B). У земли самолёт «держит» эффект земли — плавно выравнивай.", c.maxTouchdownFpm) },
		{ "7. Пределы", limitText },
	}
end

return Guide
