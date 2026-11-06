--!strict
-- Ввод: клавиатура, геймпад, сенсорный штурвал и мышь-штурвал -> общий ввод физики.
local UserInputService = game:GetService("UserInputService")

local Controls = {}

local ONCE: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.G] = "gear", [Enum.KeyCode.F] = "flapDn", [Enum.KeyCode.R] = "flapUp",
	[Enum.KeyCode.T] = "rev", [Enum.KeyCode.Z] = "idle", [Enum.KeyCode.V] = "cam",
	[Enum.KeyCode.M] = "hangar", [Enum.KeyCode.P] = "autopilot", [Enum.KeyCode.C] = "mouse", [Enum.KeyCode.N] = "nav", [Enum.KeyCode.Space] = "park", [Enum.KeyCode.I] = "guide", [Enum.KeyCode.X] = "spoiler", [Enum.KeyCode.K] = "map", [Enum.KeyCode.H] = "photo", [Enum.KeyCode.Y] = "smoke", [Enum.KeyCode.J] = "restart", [Enum.KeyCode.DPadRight] = "nav",
	-- геймпад
	[Enum.KeyCode.ButtonY] = "gear", [Enum.KeyCode.DPadUp] = "flapUp", [Enum.KeyCode.DPadDown] = "flapDn",
	[Enum.KeyCode.ButtonX] = "rev", [Enum.KeyCode.ButtonA] = "autopilot", [Enum.KeyCode.ButtonSelect] = "cam",
	-- без них с геймпада нельзя было снять стояночный тормоз на старте и выпустить интерцепторы
	[Enum.KeyCode.ButtonL3] = "park", [Enum.KeyCode.ButtonR3] = "smoke", [Enum.KeyCode.DPadLeft] = "spoiler",
}

-- экспонента: точность около центра, полный ход на краю
local function expo(v: number): number
	return v * (0.4 + 0.6 * v * v)
end

local function dz(v: number, d: number): number
	if math.abs(v) < d then
		return 0
	end
	return math.sign(v) * (math.abs(v) - d) / (1 - d)
end

function Controls.new(ui: any, onAction: (string) -> ())
	local self: any = { mouseYoke = false }

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local a = ONCE[input.KeyCode]
		if a then
			onAction(a)
		end
	end)

	local function key(k: Enum.KeyCode): number
		return if UserInputService:IsKeyDown(k) then 1 else 0
	end

	-- возвращает ввод и признак «пилот сам трогает штурвал» (для отключения автопилота)
	function self.read(): (any, boolean)
		local kp = math.max(key(Enum.KeyCode.S), key(Enum.KeyCode.Down)) - math.max(key(Enum.KeyCode.W), key(Enum.KeyCode.Up))
		local kr = math.max(key(Enum.KeyCode.D), key(Enum.KeyCode.Right)) - math.max(key(Enum.KeyCode.A), key(Enum.KeyCode.Left))
		local ky = key(Enum.KeyCode.E) - key(Enum.KeyCode.Q)
		local thrUp = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		local thrDn = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
		local brakes = UserInputService:IsKeyDown(Enum.KeyCode.B)

		local t = ui.touch
		local p = kp + expo(t.y)
		local r = kr + expo(t.x)
		local y = ky + t.rr - t.rl
		brakes = brakes or t.brake

		-- геймпад
		if UserInputService.GamepadEnabled then
			for _, s in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
				local kc = s.KeyCode
				if kc == Enum.KeyCode.Thumbstick1 then
					p += expo(-dz(s.Position.Y, 0.12))
					r += expo(dz(s.Position.X, 0.12))
				elseif kc == Enum.KeyCode.ButtonR2 and s.Position.Z > 0.25 then
					thrUp = true
				elseif kc == Enum.KeyCode.ButtonL2 and s.Position.Z > 0.25 then
					thrDn = true
				end
			end
			local gp = Enum.UserInputType.Gamepad1
			if UserInputService:IsGamepadButtonDown(gp, Enum.KeyCode.ButtonR1) then
				y += 1
			end
			if UserInputService:IsGamepadButtonDown(gp, Enum.KeyCode.ButtonL1) then
				y -= 1
			end
			if UserInputService:IsGamepadButtonDown(gp, Enum.KeyCode.ButtonB) then
				brakes = true
			end
		end

		-- мышь-штурвал: отклонение курсора от центра экрана
		if self.mouseYoke then
			local cam = workspace.CurrentCamera
			local m = UserInputService:GetMouseLocation()
			local vs = cam.ViewportSize
			local span = math.min(vs.X, vs.Y) * 0.32
			local mx = math.clamp((m.X - vs.X / 2) / span, -1, 1)
			local my = math.clamp((m.Y - vs.Y / 2) / span, -1, 1)
			p += expo(dz(my, 0.05))
			r += expo(dz(mx, 0.05))
		end

		local manual = math.abs(kp) + math.abs(kr) + math.abs(ky) > 0 or math.abs(t.x) + math.abs(t.y) > 0.3
		local input = { p = p, r = r, y = y, thrUp = thrUp, thrDn = thrDn, brakes = brakes, throttle = t.throttle }
		t.throttle = nil -- слайдер передаёт значение один раз за движение
		return input, manual
	end

	return self
end

return Controls
