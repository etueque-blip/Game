--!strict
-- Палубные истребители и параметры оружия.
-- Формат самолёта — как PlaneConfigs из Sky Pilot (1 stud/s = 1 kt), плюс боевые поля:
-- hp (прочность), missiles (ракет на вылет), lockMul (насколько дольше по нему захват).
local B = { body = Color3.fromHex("8e98a3"), accent = Color3.fromHex("6b737d"), tail = Color3.fromHex("78808a"), engine = Color3.fromHex("3c3c41") }

local function jet(t: { [string]: any }): any
	local base = {
		cls = "Истребитель", diameter = 5.5, wing = "mid", wingPos = 0.6, sweep = 40, dihedral = 0,
		engines = "jet1", engineD = 4, tail = "conventional", hstabSpan = 20, finHeight = 12, finSweep = 45,
		gearLen = 2.5, canopy = true, noFlaps = true, flapMaxKts = 9999, yawRate = 0.5, turnBoost = 6,
		groundSteer = 0.6, brakeDecel = 10, stallSink = 40, maxRotate = 15, ceilingFt = 50000, maxTouchdownFpm = 1500,
		gMax = 9, gMin = -3, lockMul = 1, colors = B,
	}
	for k, v in t do
		base[k] = v
	end
	base.gearHeight = base.diameter * 0.5 + base.gearLen
	return base
end

local JETS: { [string]: any } = {
	F16 = jet({ name = "F-16C Fighting Falcon", role = "Манёвренный, быстрый", length = 54, span = 35, chord = 14, thrust = 22, maxKts = 800, stallKts = 115, vrKts = 140, pitchRate = 1.5, rollRate = 4, hp = 100, missiles = 4 }),
	FA18 = jet({ name = "F/A-18E Super Hornet", role = "Прочный, 6 ракет", length = 60, diameter = 6, span = 44, chord = 16, sweep = 30, thrust = 19, maxKts = 700, stallKts = 105, vrKts = 130, pitchRate = 1.6, rollRate = 3.2, hp = 125, missiles = 6, hstabSpan = 22, finHeight = 11,
		colors = { body = Color3.fromHex("7d8792"), accent = Color3.fromHex("5d6670"), tail = Color3.fromHex("6a737d"), engine = Color3.fromHex("33363b") } }),
	SU33 = jet({ name = "Су-33", role = "Тяжёлый, дальний", length = 72, diameter = 6.5, span = 48, chord = 18, sweep = 42, thrust = 21, maxKts = 760, stallKts = 112, vrKts = 138, pitchRate = 1.35, rollRate = 3, hp = 135, missiles = 6, hstabSpan = 26, finHeight = 14,
		colors = { body = Color3.fromHex("a9b6c2"), accent = Color3.fromHex("6c8296"), tail = Color3.fromHex("8a9cad"), engine = Color3.fromHex("3a3d42") } }),
	RAFALE = jet({ name = "Rafale M", role = "Самый вёрткий", length = 50, span = 36, chord = 18, sweep = 50, thrust = 22, maxKts = 740, stallKts = 108, vrKts = 132, pitchRate = 1.75, rollRate = 4.3, hp = 95, missiles = 4, hstabSpan = 10, finHeight = 12,
		colors = { body = Color3.fromHex("9aa1a8"), accent = Color3.fromHex("70777e"), tail = Color3.fromHex("848b92"), engine = Color3.fromHex("3a3a3e") } }),
	MIG29 = jet({ name = "МиГ-29К", role = "Быстрый набор", length = 57, diameter = 6, span = 40, chord = 16, thrust = 23.5, maxKts = 780, stallKts = 116, vrKts = 140, pitchRate = 1.5, rollRate = 3.6, hp = 105, missiles = 4, hstabSpan = 22,
		colors = { body = Color3.fromHex("8f9ea8"), accent = Color3.fromHex("5f7280"), tail = Color3.fromHex("77878f"), engine = Color3.fromHex("38393d") } }),
	F35 = jet({ name = "F-35C Lightning II", role = "Малозаметный: захват дольше", length = 52, diameter = 6, span = 43, chord = 17, sweep = 34, thrust = 20, maxKts = 680, stallKts = 110, vrKts = 135, pitchRate = 1.45, rollRate = 3.4, hp = 110, missiles = 4, lockMul = 1.8, hstabSpan = 20,
		colors = { body = Color3.fromHex("6e747a"), accent = Color3.fromHex("575c61"), tail = Color3.fromHex("63686d"), engine = Color3.fromHex("2f3134") } }),
}
for id, c in JETS do
	c.id = id
end

return {
	JETS = JETS,
	ORDER = { "F16", "FA18", "SU33", "RAFALE", "MIG29", "F35" },
	-- оружие
	GUN_RANGE = 2400, -- studs
	GUN_CONE = 3.2, -- градусов: попадание, если цель в этом конусе по курсу
	GUN_DMG = 6,
	GUN_RATE = 0.09, -- секунд между выстрелами
	MSL_RANGE = 7000,
	MSL_CONE = 24, -- градусов для захвата
	MSL_LOCK = 1.4, -- секунд держать цель для захвата
	MSL_SPEED = 1300,
	MSL_TURN = 2.4, -- рад/с
	MSL_DMG = 70,
	MSL_LIFE = 9,
	FLARES = 10,
	FLARE_TIME = 1.6,
	FLARE_CHANCE = 0.7, -- шанс увести ракету
	-- матч
	TICKETS = 250,
	BOTS_PER_TEAM = 4, -- боты добавляются, пока в команде мало живых игроков; 0 = без ботов
	BLEED_EVERY = 6, -- раз в N секунд команда с меньшим числом баз теряет очки
}
