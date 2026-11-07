--!strict
-- Фотоохота: достопримечательности городов (координаты — как в tools/gen_cities.py). Тот же список — tools/web_photohunt.py.
-- Засчитывается, если в фото-режиме объект ближе 1600 stud и в пределах 28° от центра кадра; +200 за каждую новую.
local Landmarks = {}

Landmarks.LIST = {
	{ id = "burj", name = "Бурдж-Халифа", city = "Дубай", x = 5500, y = 600, z = -7500 },
	{ id = "future", name = "Музей будущего", city = "Дубай", x = 6120, y = 40, z = -8060 },
	{ id = "aindubai", name = "Ain Dubai", city = "Дубай", x = 6400, y = 250, z = -8850 },
	{ id = "bigben", name = "Биг-Бен", city = "Лондон", x = -4760, y = 90, z = 12275 },
	{ id = "eye", name = "Лондонский глаз", city = "Лондон", x = -4560, y = 120, z = 12565 },
	{ id = "shard", name = "Шард", city = "Лондон", x = -3680, y = 300, z = 12854 },
	{ id = "tbridge", name = "Тауэрский мост", city = "Лондон", x = -3300, y = 40, z = 12619 },
	{ id = "tvtash", name = "Ташкентская телебашня", city = "Ташкент", x = 11100, y = 360, z = 3520 },
	{ id = "sofia", name = "Айя-София", city = "Стамбул", x = -21020, y = 60, z = 20800 },
	{ id = "blue", name = "Голубая мечеть", city = "Стамбул", x = -21020, y = 60, z = 20240 },
	{ id = "galata", name = "Галатская башня", city = "Стамбул", x = -19900, y = 60, z = 20080 },
	{ id = "kingdom", name = "Kingdom Centre", city = "Эр-Рияд", x = 20850, y = 300, z = 20350 },
	{ id = "masmak", name = "Крепость Масмак", city = "Эр-Рияд", x = 20480, y = 20, z = 20960 },
	{ id = "tvriyadh", name = "Телебашня Эр-Рияда", city = "Эр-Рияд", x = 21560, y = 160, z = 20000 },
	{ id = "registan", name = "Регистан", city = "Самарканд", x = -21000, y = 40, z = -20500 },
	{ id = "gur", name = "Гур-Эмир", city = "Самарканд", x = -20480, y = 50, z = -20080 },
	{ id = "bibi", name = "Биби-Ханым", city = "Самарканд", x = -21500, y = 50, z = -20030 },
}
Landmarks.RANGE = 1600
Landmarks.CONE = math.cos(math.rad(28))
Landmarks.REWARD = 200

Landmarks.BY_ID = {} :: { [string]: any }
for _, l in Landmarks.LIST do
	Landmarks.BY_ID[l.id] = l
end

-- какая достопримечательность «в кадре» камеры (или nil)
function Landmarks.inFrame(camCF: CFrame, have: { [string]: boolean }): any?
	local best, bestDot = nil, Landmarks.CONE
	for _, l in Landmarks.LIST do
		if not have[l.id] then
			local d = Vector3.new(l.x, l.y, l.z) - camCF.Position
			if d.Magnitude < Landmarks.RANGE then
				local dot = camCF.LookVector:Dot(d.Unit)
				if dot > bestDot then
					best, bestDot = l, dot
				end
			end
		end
	end
	return best
end

return Landmarks
