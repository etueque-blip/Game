--!strict
-- Автопилот: держит курс / высоту / скорость, выдавая обычный ввод штурвала.
-- Им пользуется игрок (клавиша P) и ИИ-трафик на сервере — одна и та же физика.
local World = require(script.Parent.World)
local FlightPhysics = require(script.Parent.FlightPhysics)

local clamp = FlightPhysics.clamp
local FT = World.FT

local Autopilot = {}

export type Target = { heading: number, altFt: number, speed: number, maxBank: number? }

local function wrap180(a: number): number
	return (a + 180) % 360 - 180
end
Autopilot.wrap180 = wrap180

function Autopilot.bearingDeg(from: Vector3, to: Vector3): number
	local d = to - from
	return (math.deg(math.atan2(d.X, -d.Z)) + 360) % 360
end

function Autopilot.compute(f: FlightPhysics.Flight, t: Target): FlightPhysics.Input
	local att = f.att
	local look, right, up = att.LookVector, att.RightVector, att.UpVector
	local hdg = World.headingDeg(look)
	local bankDeg = math.deg(math.atan2(-right.Y, up.Y))
	local pitchDeg = math.deg(math.asin(clamp(look.Y, -1, 1)))

	-- курс -> желаемый крен
	local maxBank = t.maxBank or 25
	local err = wrap180(t.heading - hdg)
	local wantBank = clamp(err * 1.2, -maxBank, maxBank)
	local r = clamp((wantBank - bankDeg) / 18, -1, 1)

	-- высота -> вертикальная скорость -> угол траектории
	local altFt = f.pos.Y * FT
	local wantFpm = clamp((t.altFt - altFt) * 2.5, -1800, 1800)
	local wantVy = wantFpm / 60 / FT
	local gammaDeg = math.deg(math.asin(clamp(wantVy / math.max(f.speed, 40), -0.35, 0.35)))
	local pathDeg = math.deg(math.asin(clamp(f.vel.Y / math.max(f.vel.Magnitude, 1), -1, 1)))
	local p = clamp((gammaDeg - pathDeg) / 4 + (gammaDeg - pitchDeg) / 10, -1, 1)

	-- скорость -> тяга
	-- упреждение: тяга, которая уравновешивает текущее сопротивление и набор высоты
	local c = f.cfg
	local avail = c.thrust * math.max(f.dbg.thrustMul or 1, 0.05)
	local ff = ((f.dbg.drag or 0) + FlightPhysics.G * look.Y) / avail
	local thr = clamp(ff + (t.speed - f.speed) * 0.03, 0, 1)
	return { p = p, r = r, y = 0, throttle = thr }
end

return Autopilot
