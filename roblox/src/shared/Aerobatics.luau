--!strict
-- Авиашоу: фигуры пилотажа. Те же правила, что в веб-версии (tools/web_acro.py):
-- бочка (полный оборот по крену через «вверх ногами»), петля (оборот по тангажу через вертикаль и спину),
-- перевёрнутый полёт 5 с. Только в воздухе выше 300 ft над землёй; очки начисляет сервер.
local Aerobatics = {}

Aerobatics.TRICKS = {
	roll = { title = "Бочка", pts = 150, gap = 3 },
	loop = { title = "Петля", pts = 250, gap = 6 },
	inverted = { title = "Перевёрнутый полёт", pts = 120, gap = 8 },
}
Aerobatics.FLIGHT_CAP = 3000

export type State = { prev: CFrame?, roll: number, pitch: number, rIdle: number, pIdle: number, inv: number, invDone: boolean, rInv: boolean, pUp: boolean, pInv: boolean }

function Aerobatics.new(): State
	return { prev = nil, roll = 0, pitch = 0, rIdle = 0, pIdle = 0, inv = 0, invDone = false, rInv = false, pUp = false, pInv = false }
end

local function reset(s: State)
	s.roll, s.pitch, s.inv = 0, 0, 0
	s.rInv, s.pUp, s.pInv = false, false, false
end

function Aerobatics.step(s: State, att: CFrame, dt: number, ok: boolean): string?
	local prev = s.prev
	local cur = att.Rotation
	s.prev = cur
	if not ok or not prev or dt <= 0 then
		reset(s)
		return nil
	end
	local axis, ang = prev:ToObjectSpace(cur):ToAxisAngle()
	if ang > math.pi then
		ang -= 2 * math.pi
	end
	local dRoll, dPitch = 0, 0
	if ang == ang and axis.X == axis.X and math.abs(ang) > 1e-7 then
		dRoll, dPitch = axis.Z * ang, axis.X * ang
	end
	local up, look = cur.UpVector, cur.LookVector
	s.rIdle = if math.abs(dRoll) / dt < 0.52 then s.rIdle + dt else 0
	if s.rIdle > 1.5 then
		s.roll, s.rInv = 0, false
	end
	s.pIdle = if math.abs(dPitch) / dt < 0.14 then s.pIdle + dt else 0
	if s.pIdle > 3 then
		s.pitch, s.pUp, s.pInv = 0, false, false
	end
	s.roll += dRoll
	s.pitch += dPitch
	if up.Y < -0.5 then
		s.rInv, s.pInv = true, true
	end
	if math.abs(look.Y) > 0.85 then
		s.pUp = true
	end
	if math.abs(s.pitch) >= 5.76 and s.pUp and s.pInv then
		reset(s)
		return "loop"
	end
	if math.abs(s.roll) >= 5.93 and s.rInv then
		s.roll, s.rInv = 0, false
		return "roll"
	end
	if up.Y < -0.6 then
		s.inv += dt
	else
		s.inv = 0
		if up.Y > 0.3 then
			s.invDone = false
		end
	end
	if s.inv >= 5 and not s.invDone then
		s.invDone = true
		return "inverted"
	end
	return nil
end

return Aerobatics
