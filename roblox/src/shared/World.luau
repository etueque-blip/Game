--!strict
-- Данные мира. Один и тот же модуль используют сервер (строит визуал) и клиент (физика),
-- поэтому рельеф, полосы и здания всегда совпадают с тем, что видно на экране.
local PlaneConfigs = require(script.Parent.PlaneConfigs)

local World = {}

World.FT = 1.69
World.SIZE = 24576 -- половина стороны мира, за краем — пропасть

local rng = Random.new(2026)
local function R(a: number, b: number): number
	return a + (b - a) * rng:NextNumber()
end

export type Airport = {
	id: string, code: string, region: string, cx: number, cz: number, rot: number, L: number, W: number,
	south: string, north: string, title: string, parked: { { any } },
}

World.AIRPORTS = {
	{ id = "A", code = "SKP", region = "ЦЕНТР", cx = 0, cz = 0, rot = 0, L = 5000, W = 200, south = "36", north = "18", title = "SKYPORT INTERNATIONAL",
		parked = { { "B787", 380 }, { "B747", 700 }, { "B737", -400 }, { "G650", -620 }, { "C172", -760 }, { "LEAR75", -880 } } },
	{ id = "B", code = "MTV", region = "ГОРЫ", cx = 14000, cz = -16000, rot = 1, L = 4500, W = 200, south = "27", north = "09", title = "MOUNTAIN VIEW AIRPORT",
		parked = { { "B737", -400 }, { "GL7500", -620 }, { "B787", 420 } } },
	{ id = "C", code = "LNW", region = "ЛОНДОН", cx = -9000, cz = 15500, rot = 0, L = 4500, W = 200, south = "36", north = "18", title = "LONDON WEST",
		parked = { { "A320", -400 }, { "A350", 420 }, { "LEAR75", -650 } } },
	{ id = "D", code = "DXC", region = "ДУБАЙ", cx = 11500, cz = -9000, rot = 0, L = 4500, W = 200, south = "36", north = "18", title = "DUBAI COAST",
		parked = { { "A380", 450 }, { "B787", -420 }, { "G650", -700 } } },
	{ id = "E", code = "TSE", region = "ТАШКЕНТ", cx = 14500, cz = 6500, rot = 0, L = 4500, W = 200, south = "36", north = "18", title = "TASHKENT EAST",
		parked = { { "A320", -400 }, { "B787", 420 }, { "C172", -700 } } },
} :: { Airport }

-- Локальные координаты аэропорта (полоса вдоль локальной Z) -> мир
function World.apToWorld(ap: Airport, lx: number, lz: number): (number, number)
	if ap.rot == 1 then
		return ap.cx + lz, ap.cz - lx
	end
	return ap.cx + lx, ap.cz + lz
end

-- Поворот аэропорта вокруг Y (для CFrame построек)
function World.apYaw(ap: Airport): number
	return ap.rot == 1 and math.pi / 2 or 0
end

function World.apCFrame(ap: Airport, lx: number, y: number, lz: number): CFrame
	local x, z = World.apToWorld(ap, lx, lz)
	return CFrame.new(x, y, z) * CFrame.Angles(0, World.apYaw(ap), 0)
end

-- Плоские площадки: полосы, рулёжки, перроны, город
World.flatRects = {} :: { { x0: number, x1: number, z0: number, z1: number, h: number, kind: string, ap: string? } }
local function addLocalRect(ap: Airport, lx0: number, lx1: number, lz0: number, lz1: number, h: number, kind: string)
	local ax, az = World.apToWorld(ap, lx0, lz0)
	local bx, bz = World.apToWorld(ap, lx1, lz1)
	table.insert(World.flatRects, {
		x0 = math.min(ax, bx), x1 = math.max(ax, bx), z0 = math.min(az, bz), z1 = math.max(az, bz),
		h = h, kind = kind, ap = ap.id,
	})
end
for _, ap in World.AIRPORTS do
	local W, L = ap.W, ap.L
	addLocalRect(ap, -W / 2, W / 2, -L / 2, L / 2, 0.5, "runway")
	addLocalRect(ap, W / 2 + 220, W / 2 + 280, -L / 2, L / 2, 0.48, "taxi")
	for _, z in { -L / 2 + 150, 0, L / 2 - 150 } do
		addLocalRect(ap, W / 2, W / 2 + 220, z - 30, z + 30, 0.48, "taxi")
	end
	addLocalRect(ap, W / 2 + 280, W / 2 + 880, -1000, 1000, 0.49, "apron")
	addLocalRect(ap, W / 2 + 280, W / 2 + 880, -1500, -1000, 0.49, "apron")
end

-- Города (Дубай, Лондон, Ташкент) — данные из tools/gen_cities.py, общие с веб-версией
local CityData = require(script.Parent.CityData)
World.CityData = CityData
World.CITY = { x = 5500, z = -7500 } -- Дубай (для совместимости)
World.CITIES = {
	{ name = "DUBAI", x = 5500, z = -7500, r = 1700 },
	{ name = "LONDON", x = -4000, z = 12500, r = 1300 },
	{ name = "TASHKENT", x = 10500, z = 3000, r = 1200 },
}
for _, p in CityData.pads do
	table.insert(World.flatRects, { x0 = p[1], x1 = p[2], z0 = p[3], z1 = p[4], h = p[5], kind = "city" })
end

-- Горы: эллипсоиды (полуоси r, h, r), высота рельефа = максимум по всем.
-- Визуально строятся теми же эллипсоидами — физика и картинка совпадают точно.
export type Ellipsoid = { x: number, z: number, cy: number, a: number, b: number, snow: boolean }
World.peaks = {} :: { Ellipsoid }
for _, g in { { -13000, -9000, 9 }, { -15500, 9000, 8 }, { 12500, 14000, 8 }, { -4000, -20500, 6 }, { 20500, 2000, 6 } } do
	for _ = 1, g[3] do
		local x, z = g[1] + R(-2800, 2800), g[2] + R(-2800, 2800)
		local h, r = R(450, 1500), R(700, 1350)
		table.insert(World.peaks, { x = x, z = z, cy = 0, a = r, b = h, snow = false })
		if h > 950 then -- снежная шапка
			table.insert(World.peaks, { x = x, z = z, cy = h * 0.83, a = r * 0.55, b = h * 0.18, snow = true })
		end
	end
end

function World.terrainH(x: number, z: number): number
	local best = 0
	for _, e in World.peaks do
		local dx, dz = x - e.x, z - e.z
		local q = (dx * dx + dz * dz) / (e.a * e.a)
		if q < 1 then
			local h = e.cy + e.b * math.sqrt(1 - q)
			if h > best then
				best = h
			end
		end
	end
	return best
end

-- Препятствия (AABB) и здания города
export type Box = { min: Vector3, max: Vector3 }
World.obstacles = {} :: { Box }
for _, o in CityData.obstacles do
	table.insert(World.obstacles, { min = Vector3.new(o[1], o[2], o[3]), max = Vector3.new(o[4], o[5], o[6]) })
end

-- Постройки аэропорта в локальных координатах — общие для визуала и столкновений
function World.addLocalObstacle(ap: Airport, lx: number, lz: number, w: number, d: number, h: number)
	local ax, az = World.apToWorld(ap, lx - w / 2, lz - d / 2)
	local bx, bz = World.apToWorld(ap, lx + w / 2, lz + d / 2)
	table.insert(World.obstacles, {
		min = Vector3.new(math.min(ax, bx), 0, math.min(az, bz)),
		max = Vector3.new(math.max(ax, bx), h, math.max(az, bz)),
	})
end
for _, ap in World.AIRPORTS do
	local W = ap.W
	local tx = W / 2 + 950
	World.addLocalObstacle(ap, tx, 0, 160, 930, 63) -- терминал
	World.addLocalObstacle(ap, tx + 20, 560, 48, 48, 150) -- вышка
	World.addLocalObstacle(ap, W / 2 + 790, -1130, 170, 210, 135) -- ангары
	World.addLocalObstacle(ap, W / 2 + 790, -1370, 170, 210, 135)
	for _, p in ap.parked do
		local c = PlaneConfigs.PLANES[p[1]]
		local lx = W / 2 + 760 - c.length / 2
		World.addLocalObstacle(ap, lx, p[2], c.length, c.span, c.diameter + c.gearHeight + c.finHeight)
	end
end

World.LAKES = { { -6000, 5000, 1800 }, { 8000, 6000, 1500 }, { -9000, -3000, 1200 }, { 3000, -14000, 1600 }, { 18000, -6000, 2000 } }

function World.groundAt(x: number, z: number): number
	if math.abs(x) > World.SIZE or math.abs(z) > World.SIZE then
		return -math.huge
	end
	local h = World.terrainH(x, z)
	for _, r in World.flatRects do
		if x >= r.x0 and x <= r.x1 and z >= r.z0 and z <= r.z1 and r.h > h then
			h = r.h
		end
	end
	return h
end

-- Сетка для быстрого поиска препятствий (их больше тысячи)
local CELL = 256
local grid: { [number]: { Box } }? = nil
local function cellKey(ix: number, iz: number): number
	return ix * 4096 + iz
end
local function buildGrid()
	local g: { [number]: { Box } } = {}
	for _, o in World.obstacles do
		for ix = math.floor(o.min.X / CELL), math.floor(o.max.X / CELL) do
			for iz = math.floor(o.min.Z / CELL), math.floor(o.max.Z / CELL) do
				local k = cellKey(ix, iz)
				local list = g[k]
				if not list then
					list = {}
					g[k] = list
				end
				table.insert(list, o)
			end
		end
	end
	grid = g
end

function World.hitsObstacle(p: Vector3): boolean
	if not grid then
		buildGrid()
	end
	local list = (grid :: any)[cellKey(math.floor(p.X / CELL), math.floor(p.Z / CELL))]
	if not list then
		return false
	end
	for _, o in list do
		if p.X > o.min.X and p.X < o.max.X and p.Y > o.min.Y and p.Y < o.max.Y and p.Z > o.min.Z and p.Z < o.max.Z then
			return true
		end
	end
	return false
end

-- На какой полосе стоит точка (id аэропорта) или nil
function World.runwayAt(x: number, z: number, margin: number?): string?
	local m = margin or 0
	for _, r in World.flatRects do
		if r.kind == "runway" and x >= r.x0 - m and x <= r.x1 + m and z >= r.z0 - m and z <= r.z1 + m then
			return r.ap
		end
	end
	return nil
end

function World.airportById(id: string): Airport?
	for _, ap in World.AIRPORTS do
		if ap.id == id then
			return ap
		end
	end
	return nil
end

-- Точки старта на торцах полос: позиция + курс
function World.runwaySpawns(ap: Airport, cfg: any): { CFrame }
	local out = {}
	local y = 0.5 + cfg.gearHeight
	for _, e in { 1, -1 } do
		local lz = e * (ap.L / 2 - 140)
		local hLocal = e == 1 and 0 or math.pi -- e=1: смотрим на -Z (к центру полосы)
		local x, z = World.apToWorld(ap, 0, lz)
		table.insert(out, CFrame.new(x, y, z) * CFrame.Angles(0, hLocal + World.apYaw(ap), 0))
	end
	return out
end

-- Цели навигации (клавиша N): аэропорты и города
World.NAV = {}
for _, ap in World.AIRPORTS do
	table.insert(World.NAV, { name = ap.code .. " · " .. ap.title, x = ap.cx, z = ap.cz, airport = ap.id })
end
for _, c in {
	{ name = "ДУБАЙ", x = 5500, z = -7500 },
	{ name = "ЛОНДОН", x = -4000, z = 12500 },
	{ name = "ТАШКЕНТ", x = 10500, z = 3000 },
} do
	table.insert(World.NAV, c)
end
function World.navIndexForAirport(id: string): number
	for i, n in World.NAV do
		if n.airport == id then
			return i
		end
	end
	return 0
end
World.METERS_PER_STUD = 0.515

-- Компасный курс (0..360, по часовой) из направления взгляда
function World.headingDeg(look: Vector3): number
	return (math.deg(math.atan2(look.X, -look.Z)) + 360) % 360
end

return World
