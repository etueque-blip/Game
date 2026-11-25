--!strict
-- «Мозг» бота: по положению своего самолёта и цели выдаёт ввод для FlightPhysics
-- (тот же ввод, что у игрока: p — на себя, r — крен вправо, y — педали, throttle).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local World = require(ReplicatedStorage:WaitForChild("CarrierStrike"):WaitForChild("World"))

local Bots = {}

local function clamp(v: number, a: number, b: number): number
	return math.min(b, math.max(a, v))
end

-- dir — куда хотим лететь (мировой вектор); skill 0..1 — резкость манёвров
function Bots.steer(f: any, dir: Vector3, skill: number): any
	local att: CFrame = f.att
	local pos: Vector3 = f.pos
	-- безопасность: низко над водой/землёй — вверх, слишком высоко — вниз
	local ground = math.max(World.groundAt(pos.X, pos.Z), World.SEA)
	local ahead = pos + att.LookVector * math.max(f.speed, 200) * 2.5
	local groundAhead = math.max(World.groundAt(ahead.X, ahead.Z), World.SEA)
	local floor = math.max(ground, groundAhead) + 380
	-- у воды не пикируем круче ~25°
	if pos.Y < floor + 1500 and dir.Y < -0.42 then
		local flat = Vector3.new(dir.X, 0, dir.Z)
		flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(att.LookVector.X, 0, att.LookVector.Z).Unit
		dir = (flat * 0.9 + Vector3.new(0, -0.42, 0)).Unit
	end
	-- прогноз высоты через 3 с по вертикальной скорости
	local predY = pos.Y + math.min(f.vel.Y, 0) * 3
	if predY < floor then
		local flat = Vector3.new(dir.X, 0, dir.Z)
		flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(att.LookVector.X, 0, att.LookVector.Z).Unit
		dir = (flat + Vector3.new(0, 1.2 + (floor - pos.Y) / 200, 0)).Unit
	elseif pos.Y > 7000 then
		dir = (dir + Vector3.new(0, -0.6, 0)).Unit
	end
	-- граница карты: разворот к центру
	if math.abs(pos.X) > World.SIZE * 0.92 or math.abs(pos.Z) > World.SIZE * 0.92 then
		dir = (Vector3.new(-pos.X, 0, -pos.Z).Unit + Vector3.new(0, 0.1, 0)).Unit
	end

	local ld = att:VectorToObjectSpace(dir)
	-- крен: развернуть «пол» самолёта так, чтобы цель оказалась над головой
	local rollErr = math.atan2(ld.X, math.max(ld.Y, 0.05) + (if ld.Z < 0 then -ld.Z * 0.35 else 0))
	local bank = math.asin(clamp(-att.RightVector.Y, -1, 1))
	-- почти по курсу: выравниваем крыло (без лишнего крена)
	local offAxis = math.acos(clamp(-ld.Z, -1, 1))
	if offAxis < math.rad(8) then
		rollErr = -bank * 0.8 + ld.X * 2
	end
	local r = clamp(rollErr * (1.4 + skill), -1, 1)
	local pitchErr = math.atan2(ld.Y, math.max(-ld.Z, 0.15))
	local p = clamp(pitchErr * (2 + skill * 2), -0.5, 1)
	if ld.Z > 0 then
		p = 1 -- цель сзади: тянем на себя
	end
	-- тяга: ниже сваливания — форсаж, иначе крейсер
	local thr = if f.speed < f.cfg.stallKts * 1.5 then 1 else 0.85
	return { p = p, r = r, y = clamp(ld.X * 2, -1, 1) * 0.3, throttle = thr }
end

-- упреждение: куда целиться, чтобы снаряды/самолёт встретили цель
function Bots.lead(from: Vector3, to: Vector3, tvel: Vector3, speed: number): Vector3
	local t = (to - from).Magnitude / math.max(speed, 1)
	return to + tvel * math.min(t, 3)
end

return Bots
