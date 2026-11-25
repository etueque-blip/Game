--!strict
-- Carrier Strike: карта — океан, два авианосца и пять островов-баз.
-- Это же описание использует физика полёта (groundAt / hitsObstacle / runwayAt),
-- сервер (строит мир по этим данным) и клиент (карта, точки появления).
local World = {}

World.FT = 1.69 -- футов в одном studs (как в Sky Pilot)
World.SEA = 0 -- уровень моря
World.SIZE = 9500 -- половина стороны зоны боя; дальше — предупреждение и урон
World.lastHit = nil :: string?

-- ===== авианосцы
World.DECK_H = 46 -- высота полётной палубы над водой
World.DECK_W = 150
World.DECK_L = 660
export type Carrier = { id: string, team: string, name: string, cf: CFrame }
World.CARRIERS = {
	{ id = "CV_BLUE", team = "Blue", name = "Авианосец «Синих»", cf = CFrame.new(0, 0, 7000) },
	{ id = "CV_RED", team = "Red", name = "Авианосец «Красных»", cf = CFrame.new(0, 0, -7000) * CFrame.Angles(0, math.pi, 0) },
} :: { Carrier }
-- надстройка («остров») по правому борту, в координатах авианосца (нос корабля — -Z)
World.TOWER = { x0 = 52, x1 = 74, z0 = -60, z1 = 40, h = 95 }

function World.carrierOf(team: string): Carrier
	for _, c in World.CARRIERS do
		if c.team == team then
			return c
		end
	end
	return World.CARRIERS[1]
end

-- ===== острова (базы, которые можно захватывать)
export type Island = {
	id: string, name: string, x: number, z: number, r: number, h: number, yaw: number,
	owner: string, hills: { { number } }, -- холм: {вдоль полосы, поперёк полосы, радиус, высота}
}
World.BEACH = 140
World.RUNWAY_LEN = 1100
World.RUNWAY_W = 70
World.ISLANDS = {
	{ id = "A", name = "Альфа", x = -2600, z = 3000, r = 760, h = 26, yaw = 20, owner = "Blue", hills = { { -150, -400, 300, 260 }, { 250, 380, 220, 160 } } },
	{ id = "B", name = "Браво", x = 3000, z = 1600, r = 720, h = 30, yaw = -35, owner = "", hills = { { 100, 400, 280, 300 } } },
	{ id = "C", name = "Центр", x = 0, z = 0, r = 900, h = 34, yaw = 90, owner = "", hills = { { 0, 520, 360, 420 }, { 150, -500, 260, 240 } } },
	{ id = "D", name = "Дельта", x = -3000, z = -1600, r = 720, h = 28, yaw = 145, owner = "", hills = { { -100, -400, 280, 300 } } },
	{ id = "E", name = "Эхо", x = 2600, z = -3000, r = 760, h = 26, yaw = 200, owner = "Red", hills = { { 150, 400, 300, 260 }, { -250, -380, 220, 160 } } },
} :: { Island }
World.CAPTURE_R = 1500 -- радиус зоны захвата
World.CAPTURE_ALT = 700 -- выше этой высоты над островом базу не захватить

function World.islandById(id: string): Island?
	for _, i in World.ISLANDS do
		if i.id == id then
			return i
		end
	end
	return nil
end

-- направление полосы острова (единичный вектор в плоскости XZ)
function World.runwayDir(i: Island): Vector3
	local a = math.rad(i.yaw)
	return Vector3.new(math.sin(a), 0, -math.cos(a))
end

-- центр холма в мировых координатах
function World.hillPos(i: Island, hl: { number }): Vector3
	local dir = World.runwayDir(i)
	local side = Vector3.new(-dir.Z, 0, dir.X)
	return Vector3.new(i.x, i.h, i.z) + dir * hl[1] + side * hl[2]
end

-- ===== высота поверхности; -math.huge = открытое море (садиться некуда)
local function deckLocal(c: Carrier, x: number, z: number): Vector3
	return c.cf:PointToObjectSpace(Vector3.new(x, 0, z))
end

local function islandH(i: Island, x: number, z: number): number
	local dx, dz = x - i.x, z - i.z
	local d = math.sqrt(dx * dx + dz * dz)
	if d > i.r + World.BEACH then
		return -math.huge
	end
	local h = if d <= i.r then i.h else 3
	local dir = World.runwayDir(i)
	local along = dx * dir.X + dz * dir.Z
	local side = -dx * dir.Z + dz * dir.X
	for _, hl in i.hills do
		local hx, hz = (along - hl[1]) / hl[3], (side - hl[2]) / hl[3]
		local e = 1 - (hx * hx + hz * hz)
		if e > 0 then
			h = math.max(h, i.h + hl[4] * math.sqrt(e))
		end
	end
	return h
end

function World.groundAt(x: number, z: number): number
	for _, c in World.CARRIERS do
		local l = deckLocal(c, x, z)
		if math.abs(l.X) <= World.DECK_W / 2 and math.abs(l.Z) <= World.DECK_L / 2 then
			return World.DECK_H
		end
	end
	local best = -math.huge
	for _, i in World.ISLANDS do
		local h = islandH(i, x, z)
		if h > best then
			best = h
		end
	end
	return best
end

-- препятствия: надстройка и борт авианосца, вода
function World.hitsObstacle(p: Vector3): boolean
	for _, c in World.CARRIERS do
		local l = c.cf:PointToObjectSpace(p)
		local t = World.TOWER
		if l.X >= t.x0 and l.X <= t.x1 and l.Z >= t.z0 and l.Z <= t.z1 and l.Y <= World.DECK_H + t.h then
			World.lastHit = "Врезался в надстройку авианосца!"
			return true
		end
		if math.abs(l.X) <= World.DECK_W / 2 + 4 and math.abs(l.Z) <= World.DECK_L / 2 + 4 and l.Y < World.DECK_H - 2 and l.Y > -10 then
			World.lastHit = "Врезался в борт авианосца!"
			return true
		end
	end
	if p.Y < World.SEA + 1.5 and World.groundAt(p.X, p.Z) == -math.huge then
		World.lastHit = "Упал в океан!"
		return true
	end
	World.lastHit = nil
	return false
end

function World.isWater(x: number, z: number): boolean
	return World.groundAt(x, z) == -math.huge
end

-- палуба или полоса под точкой: id авианосца / острова, иначе nil
function World.runwayAt(x: number, z: number, margin: number?): string?
	local m = margin or 0
	for _, c in World.CARRIERS do
		local l = deckLocal(c, x, z)
		if math.abs(l.X) <= World.DECK_W / 2 + m and math.abs(l.Z) <= World.DECK_L / 2 + m then
			return c.id
		end
	end
	for _, i in World.ISLANDS do
		local dir = World.runwayDir(i)
		local rel = Vector3.new(x - i.x, 0, z - i.z)
		local along = rel:Dot(dir)
		local side = rel:Dot(Vector3.new(-dir.Z, 0, dir.X))
		if math.abs(along) <= World.RUNWAY_LEN / 2 + m and math.abs(side) <= World.RUNWAY_W / 2 + m then
			return i.id
		end
	end
	return nil
end

-- ===== точки появления
-- id: "deck:<team>", "air:<team>", "base:<id>"
local DECK_SLOTS = { { -30, 250 }, { 0, 200 }, { -50, 160 }, { 20, 290 } }
function World.spawnCFrame(id: string, cfg: any, slot: number?): (CFrame?, boolean)
	local kind, arg = id:match("^(%a+):(%w+)$")
	local s = slot or 1
	if kind == "deck" and arg then
		local c = World.carrierOf(arg)
		local sl = DECK_SLOTS[(s - 1) % #DECK_SLOTS + 1]
		return c.cf * CFrame.new(sl[1], World.DECK_H + cfg.gearHeight, sl[2]), false
	elseif kind == "air" and arg then
		local c = World.carrierOf(arg)
		local off = (s - 1) % 4
		return c.cf * CFrame.new(-300 + off * 200, 1400 + off * 60, -1800), true
	elseif kind == "base" and arg then
		local i = World.islandById(arg)
		if not i then
			return nil, false
		end
		local dir = World.runwayDir(i)
		local side = Vector3.new(-dir.Z, 0, dir.X)
		local lane = ((s - 1) % 2 - 0.5) * 30
		local start = Vector3.new(i.x, i.h + cfg.gearHeight, i.z) - dir * (World.RUNWAY_LEN / 2 - 80 - ((s - 1) // 2) * 120) + side * lane
		return CFrame.lookAt(start, start + dir), false
	end
	return nil, false
end

function World.headingDeg(look: Vector3): number
	local h = math.deg(math.atan2(look.X, -look.Z))
	return (h + 360) % 360
end

World.TEAM_COLOR = {
	Blue = Color3.fromRGB(92, 200, 255),
	Red = Color3.fromRGB(255, 96, 86),
	[""] = Color3.fromRGB(200, 206, 214),
} :: { [string]: Color3 }
World.TEAM_NAME = { Blue = "Синие", Red = "Красные", [""] = "Нейтральная" } :: { [string]: string }

return World
