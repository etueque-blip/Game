--!strict
-- Те же PlaneConfigs, что и в HTML-полигоне Sky Pilot (1 stud/s = 1 kt, 1 stud = 1.69 ft).
local WHITE = Color3.fromHex("f3f5f8")
local GREY = Color3.fromHex("c4c8ce")

export type Config = {
	id: string, name: string, cls: string,
	length: number, diameter: number, span: number, chord: number,
	wing: string, wingPos: number, sweep: number, dihedral: number,
	engines: string, engineD: number?, engineLen: number?,
	tail: string, hstabSpan: number, finHeight: number, finSweep: number,
	gearLen: number, gearHeight: number,
	fixedGear: boolean?, windows: boolean?, winglets: boolean?, hump: boolean?, canopy: boolean?, noFlaps: boolean?,
	thrust: number, maxKts: number, stallKts: number, vrKts: number, flapMaxKts: number,
	pitchRate: number, rollRate: number, yawRate: number, turnBoost: number,
	groundSteer: number, brakeDecel: number, stallSink: number, maxRotate: number,
	ceilingFt: number, maxTouchdownFpm: number,
	colors: { body: Color3, accent: Color3, tail: Color3, engine: Color3 },
}

local PLANES: { [string]: any } = {
	C172 = { name = "Sparrow S1", cls = "Лёгкий учебный", length = 29, diameter = 6, span = 39, chord = 5.5, wing = "high", wingPos = 0.38, sweep = 0, dihedral = 2, engines = "prop", tail = "conventional", hstabSpan = 13, finHeight = 8, finSweep = 35, gearLen = 3, fixedGear = true, thrust = 4.6, maxKts = 125, stallKts = 48, vrKts = 55, flapMaxKts = 85, pitchRate = 0.7, rollRate = 1.4, yawRate = 0.45, turnBoost = 2.5, groundSteer = 0.9, brakeDecel = 6, stallSink = 30, maxRotate = 12, ceilingFt = 14000, maxTouchdownFpm = 1100,
		colors = { body = WHITE, accent = Color3.fromHex("1e50aa"), tail = Color3.fromHex("1e50aa"), engine = GREY } },
	LEAR75 = { name = "Swift 75", cls = "Частный джет", length = 63, diameter = 7, span = 55, chord = 8, wing = "low", wingPos = 0.52, sweep = 14, dihedral = 3, engines = "tail2", engineD = 3.2, engineLen = 8, tail = "T", hstabSpan = 22, finHeight = 12, finSweep = 45, gearLen = 3, windows = true, winglets = true, thrust = 7.5, maxKts = 465, stallKts = 100, vrKts = 115, flapMaxKts = 200, pitchRate = 0.55, rollRate = 1.3, yawRate = 0.35, turnBoost = 2.3, groundSteer = 0.6, brakeDecel = 8, stallSink = 45, maxRotate = 14, ceilingFt = 51000, maxTouchdownFpm = 1100,
		colors = { body = WHITE, accent = Color3.fromHex("c81e28"), tail = Color3.fromHex("c81e28"), engine = GREY } },
	G650 = { name = "Aurora LX", cls = "Частный джет (люкс)", length = 108, diameter = 9.5, span = 108, chord = 13, wing = "low", wingPos = 0.5, sweep = 32, dihedral = 4, engines = "tail2", engineD = 5, engineLen = 13, tail = "T", hstabSpan = 36, finHeight = 20, finSweep = 48, gearLen = 4, windows = true, winglets = true, thrust = 7, maxKts = 500, stallKts = 105, vrKts = 120, flapMaxKts = 210, pitchRate = 0.5, rollRate = 1.1, yawRate = 0.3, turnBoost = 2.2, groundSteer = 0.55, brakeDecel = 8, stallSink = 50, maxRotate = 14, ceilingFt = 51000, maxTouchdownFpm = 1150,
		colors = { body = WHITE, accent = Color3.fromHex("142346"), tail = Color3.fromHex("142346"), engine = GREY } },
	GL7500 = { name = "Meridian 7000", cls = "Частный джет (люкс)", length = 121, diameter = 10, span = 113, chord = 14, wing = "low", wingPos = 0.5, sweep = 33, dihedral = 4, engines = "tail2", engineD = 5.3, engineLen = 14, tail = "T", hstabSpan = 38, finHeight = 21, finSweep = 48, gearLen = 4.2, windows = true, winglets = true, thrust = 6.9, maxKts = 510, stallKts = 108, vrKts = 125, flapMaxKts = 210, pitchRate = 0.48, rollRate = 1.05, yawRate = 0.3, turnBoost = 2.2, groundSteer = 0.55, brakeDecel = 8, stallSink = 50, maxRotate = 14, ceilingFt = 51000, maxTouchdownFpm = 1150,
		colors = { body = WHITE, accent = Color3.fromHex("780a1e"), tail = Color3.fromHex("780a1e"), engine = GREY } },
	B737 = { name = "Skyliner 200", cls = "Авиалайнер", length = 141, diameter = 13.5, span = 128, chord = 20, wing = "low", wingPos = 0.47, sweep = 25, dihedral = 6, engines = "wing2", engineD = 7, engineLen = 13, tail = "conventional", hstabSpan = 50, finHeight = 28, finSweep = 38, gearLen = 5, windows = true, winglets = true, thrust = 5.9, maxKts = 470, stallKts = 125, vrKts = 145, flapMaxKts = 230, pitchRate = 0.4, rollRate = 0.9, yawRate = 0.25, turnBoost = 2, groundSteer = 0.5, brakeDecel = 8, stallSink = 55, maxRotate = 12, ceilingFt = 41000, maxTouchdownFpm = 1200,
		colors = { body = WHITE, accent = Color3.fromHex("005ac8"), tail = Color3.fromHex("003ca0"), engine = GREY } },
	B787 = { name = "Skyliner 900", cls = "Широкофюзеляжный", length = 224, diameter = 20, span = 214, chord = 30, wing = "low", wingPos = 0.47, sweep = 32, dihedral = 7, engines = "wing2", engineD = 11, engineLen = 20, tail = "conventional", hstabSpan = 75, finHeight = 42, finSweep = 40, gearLen = 7, windows = true, thrust = 5.7, maxKts = 490, stallKts = 128, vrKts = 150, flapMaxKts = 230, pitchRate = 0.35, rollRate = 0.75, yawRate = 0.2, turnBoost = 2, groundSteer = 0.45, brakeDecel = 8, stallSink = 60, maxRotate = 12, ceilingFt = 43000, maxTouchdownFpm = 1200,
		colors = { body = WHITE, accent = Color3.fromHex("008c96"), tail = Color3.fromHex("0a285a"), engine = GREY } },
	B747 = { name = "Titan 4", cls = "Четырёхмоторный гигант", length = 272, diameter = 23, span = 244, chord = 36, wing = "low", wingPos = 0.46, sweep = 37, dihedral = 7, engines = "wing4", engineD = 10, engineLen = 19, tail = "conventional", hstabSpan = 82, finHeight = 50, finSweep = 42, gearLen = 8, windows = true, hump = true, thrust = 5.1, maxKts = 495, stallKts = 135, vrKts = 160, flapMaxKts = 230, pitchRate = 0.3, rollRate = 0.65, yawRate = 0.18, turnBoost = 2, groundSteer = 0.4, brakeDecel = 8, stallSink = 65, maxRotate = 11, ceilingFt = 43000, maxTouchdownFpm = 1250,
		colors = { body = WHITE, accent = Color3.fromHex("d22828"), tail = Color3.fromHex("b4141e"), engine = GREY } },
	F16 = { name = "Striker X", cls = "Истребитель", length = 54, diameter = 5.5, span = 35, chord = 14, wing = "mid", wingPos = 0.6, sweep = 40, dihedral = 0, engines = "jet1", engineD = 4, tail = "conventional", hstabSpan = 20, finHeight = 12, finSweep = 45, gearLen = 2.5, canopy = true, noFlaps = true, thrust = 22, maxKts = 800, stallKts = 115, vrKts = 140, flapMaxKts = 9999, pitchRate = 1.5, rollRate = 4, yawRate = 0.5, turnBoost = 6, groundSteer = 0.6, brakeDecel = 10, stallSink = 40, maxRotate = 15, ceilingFt = 50000, maxTouchdownFpm = 1500,
		colors = { body = Color3.fromHex("8e98a3"), accent = Color3.fromHex("6b737d"), tail = Color3.fromHex("78808a"), engine = Color3.fromHex("3c3c41") } },
}

local ORDER = { "C172", "LEAR75", "G650", "GL7500", "B737", "B787", "B747", "F16" }

for id, c in PLANES do
	c.id = id
	c.gearHeight = c.diameter * 0.5 + c.gearLen
end

return {
	PLANES = PLANES :: { [string]: Config },
	ORDER = ORDER,
	-- Звук двигателя: вставьте сюда id своего звука (rbxassetid://...), пусто = без звука
	ENGINE_SOUND_ID = "",
}
