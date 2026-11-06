--!strict
-- 🎯 Посадочный вызов: старт на заходе в 2,5 км от торца (≈ 450 ft, глиссада 3°), шасси и закрылки 2 выпущены,
-- скорость захода 1,3 × сваливания. Оценка посадки 0–100: вертикальная (до 50), ось полосы (до 30),
-- точка касания у посадочных знаков в 300 stud за торцом (до 20). Те же правила — в веб-версии (tools/web_challenge.py).
local World = require(script.Parent:WaitForChild("World"))

local Challenge = {}

function Challenge.airportOf(mode: string): string?
	return mode:match("^approach:(%u)$")
end

function Challenge.spawn(ap: any, cfg: any): CFrame
	local x, z = World.apToWorld(ap, 0, ap.L / 2 + 4800)
	return CFrame.new(x, 0.5 + cfg.gearHeight + 267, z) * CFrame.Angles(0, World.apYaw(ap), 0)
end

-- настройка полёта после FlightPhysics.new(..., true)
function Challenge.setup(f: any)
	local c = f.cfg
	f.flaps = if c.noFlaps then 0 else 2
	f.gear = true
	f.throttle = 0.45
	f.speed = math.round(c.stallKts * (1 - 0.07 * f.flaps) * 1.3)
	f.vel = f.att.LookVector * f.speed
end

-- расстояние (м) от точки касания до посадочных знаков
function Challenge.zoneM(ap: any, pos: Vector3): number
	local lz = if ap.rot == 1 then pos.X - ap.cx else pos.Z - ap.cz
	return math.abs(lz - (ap.L / 2 - 300)) * World.METERS_PER_STUD
end

function Challenge.score(fpm: number, offM: number?, zoneM: number): number
	local a = if fpm < 100 then 50 elseif fpm < 200 then 42 elseif fpm < 350 then 32 elseif fpm < 600 then 18 else 5
	local b = if offM == nil then 0 elseif offM < 2 then 30 elseif offM < 5 then 24 elseif offM < 10 then 16 elseif offM < 20 then 8 else 0
	local z = if zoneM < 30 then 20 elseif zoneM < 80 then 14 elseif zoneM < 150 then 8 else 0
	return a + b + z
end

return Challenge
