--!strict
-- Порт FlightClient.step / physicsStep из Sky Pilot 1:1.
-- Единицы: 1 stud/s = 1 kt, высота в футах = Y * FT, G = 19 stud/s².
local World = require(script.Parent.World)

local FT = World.FT
local G = 19

local FlightPhysics = {}
FlightPhysics.FT = FT
FlightPhysics.G = G

export type Input = {
	p: number, r: number, y: number,
	thrUp: boolean?, thrDn: boolean?, brakes: boolean?,
	throttle: number?, -- абсолютная тяга (слайдер, автопилот)
}

export type Event = { type: string, text: string, good: boolean?, fpm: number?, grade: string?, airport: string? }

export type Flight = {
	cfg: any, mode: string,
	pos: Vector3, att: CFrame,
	speed: number, throttle: number, flaps: number, gear: boolean,
	brakes: boolean, reverse: boolean,
	inP: number, inR: number, inY: number,
	vyExtra: number, lastVelY: number, vel: Vector3,
	onGround: boolean, airTime: number, crashed: boolean, crashReason: string?,
	events: { Event }, dbg: { [string]: number },
}

local function clamp(v: number, a: number, b: number): number
	return math.min(b, math.max(a, v))
end
FlightPhysics.clamp = clamp

function FlightPhysics.new(cfg: any, spawnCF: CFrame, air: boolean): Flight
	local speed = air and math.floor(cfg.maxKts * 0.6) or 0
	return {
		cfg = cfg, mode = air and "air" or "runway",
		pos = spawnCF.Position, att = spawnCF.Rotation,
		speed = speed, throttle = air and 0.7 or 0, flaps = 0, gear = (cfg.fixedGear == true) or not air,
		brakes = false, reverse = false,
		inP = 0, inR = 0, inY = 0,
		vyExtra = 0, lastVelY = 0, vel = spawnCF.LookVector * speed,
		onGround = not air, airTime = 0, crashed = false, crashReason = nil,
		events = {}, dbg = { agl = 0, lift = 1, eff = 1, stall = cfg.stallKts, thrust = 0, drag = 0, accel = 0, thrustMul = 1 },
	}
end

local function crash(f: Flight, reason: string)
	f.crashed = true
	f.crashReason = reason
	table.insert(f.events, { type = "crash", text = reason })
end

function FlightPhysics.step(f: Flight, input: Input, dt: number)
	if f.crashed then
		return
	end
	dt = clamp(dt, 1 / 240, 1 / 20)
	local c = f.cfg
	local sm = math.min(1, dt * 6)
	f.inP += (clamp(input.p, -1, 1) - f.inP) * sm
	f.inR += (clamp(input.r, -1, 1) - f.inR) * sm
	f.inY += (clamp(input.y, -1, 1) - f.inY) * sm
	if input.throttle ~= nil then
		f.throttle = clamp(input.throttle, 0, 1)
	end
	if input.thrUp then
		f.throttle = math.min(1, f.throttle + dt * 0.45)
	end
	if input.thrDn then
		f.throttle = math.max(0, f.throttle - dt * 0.45)
	end
	f.brakes = input.brakes == true

	local pos = f.pos
	local gy = World.groundAt(pos.X, pos.Z)
	local agl = if gy == -math.huge then math.huge else pos.Y - c.gearHeight - gy
	local nowGround = agl <= 0.6
	local att = f.att
	local look = att.LookVector
	local right = att.RightVector
	local up = att.UpVector

	if pos.Y < -400 then
		return crash(f, "Самолёт упал за край мира")
	end

	if nowGround and not f.onGround then
		local fpm = math.floor(-f.lastVelY * 60 * FT)
		local bankDeg = math.deg(math.asin(clamp(-right.Y, -1, 1)))
		local pitchDeg = math.deg(math.asin(clamp(look.Y, -1, 1)))
		if not f.gear then
			return crash(f, "Посадка без шасси!")
		end
		if fpm > c.maxTouchdownFpm then
			return crash(f, string.format("Слишком жёсткая посадка: %d fpm (лимит %d)", fpm, c.maxTouchdownFpm))
		end
		if math.abs(bankDeg) > 20 or pitchDeg < -8 or up.Y < 0 then
			return crash(f, string.format("Удар крылом о землю (крен %d°, тангаж %d°)", math.round(bankDeg), math.round(pitchDeg)))
		end
		if f.speed > 15 and f.airTime > 1 then
			local grade = if fpm < 250 then "perfect" elseif fpm < 600 then "good" else "hard"
			local label = if grade == "perfect" then "Идеальная посадка!" elseif grade == "good" then "Хорошая посадка" else "Жёсткая посадка"
			table.insert(f.events, {
				type = "landing", text = string.format("%s  %d fpm", label, math.max(fpm, 0)),
				good = fpm < 600, fpm = math.max(fpm, 0), grade = grade, airport = World.runwayAt(pos.X, pos.Z, 20),
			})
		end
	end
	if not nowGround and f.onGround and f.speed > 20 then
		table.insert(f.events, { type = "takeoff", text = string.format("Отрыв на %d kt", math.round(f.speed)) })
	end
	f.onGround = nowGround
	f.airTime = if nowGround then 0 else f.airTime + dt
	if not nowGround then
		f.reverse = false
	end

	local stall = c.stallKts * (1 - 0.07 * f.flaps)
	local lift = clamp((f.speed - 0.6 * stall) / (0.4 * stall), 0, 1)
	local eff = clamp(f.speed / (stall * 1.1), 0.15, 1)
	local ceil = c.ceilingFt / FT
	local thrustMul = clamp((ceil - pos.Y) / (0.15 * ceil), 0.05, 1)
	local thrust = c.thrust * f.throttle * thrustMul
	if f.reverse then
		thrust = -c.thrust * 0.45 * f.throttle
	end
	local retractGear = f.gear and not c.fixedGear
	local dragK = c.thrust / (c.maxKts * c.maxKts)
	local dragMul = 1 + 0.12 * f.flaps + (if retractGear then 0.15 else 0)
	local vr = c.vrKts * (1 - 0.04 * f.flaps)
	local extra = (0.3 * f.flaps + (if retractGear then 0.4 else 0)) * (f.speed / c.vrKts) ^ 2
	local induced = if f.onGround then 0 else 1.2 * (c.stallKts / math.max(f.speed, 30)) ^ 2 * lift
	local drag = dragK * dragMul * f.speed * f.speed + extra + induced
	local accel = thrust - drag - G * look.Y
	if f.onGround and f.speed > 0 then
		accel -= 0.6
		if f.brakes then
			accel -= c.brakeDecel
		end
	end
	f.speed = math.max(0, f.speed + accel * dt)

	if f.onGround then
		local heading = math.atan2(-look.X, -look.Z)
		local pitch = math.asin(clamp(look.Y, -1, 1))
		local steer = clamp(f.inY + f.inR, -1, 1)
		local steerRate = c.groundSteer * clamp(f.speed / 12, 0, 1) / (1 + f.speed / 40)
		heading -= steer * steerRate * dt
		if f.speed >= vr and f.inP > 0.05 then
			pitch = clamp(pitch + c.pitchRate * 0.6 * f.inP * dt, 0, math.rad(c.maxRotate))
		else
			pitch = math.max(0, pitch - pitch * math.min(1, dt * 1.5))
		end
		att = CFrame.Angles(0, heading, 0) * CFrame.Angles(pitch, 0, 0)
	else
		local pr = c.pitchRate * eff * f.inP
		if lift < 1 then
			pr -= (1 - lift) * 0.9
		end
		local rr = -c.rollRate * eff * f.inR
		local yr = -c.yawRate * eff * f.inY
		att = att * CFrame.Angles(pr * dt, yr * dt, rr * dt)
		local bank = -att.RightVector.Y
		local omega = c.turnBoost * G * bank / math.max(f.speed, 60) * lift
		att = (CFrame.fromAxisAngle(Vector3.yAxis, -omega * dt) * att):Orthonormalize()
	end
	f.att = att
	look = att.LookVector
	up = att.UpVector

	local vel: Vector3
	if f.onGround then
		vel = look * f.speed
		local glue = if (f.inP > 0.05 and agl > 0 and f.speed >= vr) then 0 else -agl * 10
		vel += Vector3.new(0, glue, 0)
		f.vyExtra = 0
	else
		local sinkTarget = -(1 - lift) * c.stallSink - (1 - math.abs(up.Y)) * 12 * lift
		f.vyExtra += (sinkTarget - f.vyExtra) * math.min(1, dt * 1.5)
		vel = look * f.speed + Vector3.new(0, f.vyExtra, 0)
	end

	if f.speed > 20 then
		local dir = if f.onGround then Vector3.new(look.X, 0, look.Z) else vel
		if dir.Magnitude > 0.01 then
			dir = dir.Unit
			local len = c.length * 0.5 + f.speed * dt * 2
			for _, t in { 0.5, 0.75, 1 } do
				local p = pos + dir * (len * t)
				if World.hitsObstacle(p) then
					return crash(f, "Столкновение со зданием!")
				end
				if not f.onGround and p.Y < World.groundAt(p.X, p.Z) - 0.5 then
					return crash(f, "Столкновение с землёй / горой!")
				end
			end
		end
	end

	f.vel = vel
	f.lastVelY = vel.Y
	f.pos = pos + vel * dt
	f.dbg = { agl = agl, lift = lift, eff = eff, stall = stall, thrust = thrust, drag = drag, accel = accel, thrustMul = thrustMul }
end

-- Действия кнопок (шасси/закрылки/реверс). Возвращает текст подсказки и цвет.
function FlightPhysics.action(f: Flight, a: string): (string?, string?)
	if f.crashed then
		return nil, nil
	end
	local c = f.cfg
	if a == "gear" then
		if c.fixedGear then
			return "У этого самолёта шасси не убирается", nil
		elseif f.onGround and f.gear then
			return "Нельзя убрать шасси на земле", "amber"
		end
		f.gear = not f.gear
		return if f.gear then "Шасси выпущено" else "Шасси убрано", nil
	elseif a == "flapDn" or a == "flapUp" then
		if c.noFlaps then
			return "У истребителя нет закрылков", nil
		end
		f.flaps = clamp(f.flaps + (if a == "flapDn" then 1 else -1), 0, 3)
		return "Закрылки: " .. f.flaps, nil
	elseif a == "rev" then
		if f.onGround then
			f.reverse = not f.reverse
			return if f.reverse then "Реверс включён, добавь тягу" else "Реверс выключен", "amber"
		end
		return "Реверс только на земле", nil
	elseif a == "idle" then
		f.throttle = 0
	end
	return nil, nil
end

function FlightPhysics.pose(f: Flight): CFrame
	return CFrame.new(f.pos) * f.att
end

return FlightPhysics
