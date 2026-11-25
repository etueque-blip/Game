--!strict
-- Ввод: клавиатура, мышь, геймпад и сенсор → ввод физики + оружие.
local UserInputService = game:GetService("UserInputService")

local Controls = {}

local ONCE: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.F] = "missile", [Enum.KeyCode.X] = "flare", [Enum.KeyCode.G] = "gear", [Enum.KeyCode.V] = "cam",
	[Enum.KeyCode.C] = "mouse", [Enum.KeyCode.M] = "menu", [Enum.KeyCode.Z] = "idle", [Enum.KeyCode.K] = "cine",
	-- геймпад
	[Enum.KeyCode.ButtonX] = "missile", [Enum.KeyCode.ButtonB] = "flare", [Enum.KeyCode.ButtonY] = "gear",
	[Enum.KeyCode.ButtonSelect] = "cam", [Enum.KeyCode.ButtonStart] = "menu",
}

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
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			onAction("missile")
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

	function self.firing(): boolean
		if ui.touch.fire then
			return true
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			return true
		end
		if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) and not UserInputService:GetFocusedTextBox() then
			-- клики по меню не считаются выстрелом: меню скрыто во время полёта
			return true
		end
		if UserInputService.GamepadEnabled and UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonR1) then
			return true
		end
		return false
	end

	function self.read(): any
		local kp = math.max(key(Enum.KeyCode.S), key(Enum.KeyCode.Down)) - math.max(key(Enum.KeyCode.W), key(Enum.KeyCode.Up))
		local kr = math.max(key(Enum.KeyCode.D), key(Enum.KeyCode.Right)) - math.max(key(Enum.KeyCode.A), key(Enum.KeyCode.Left))
		local ky = key(Enum.KeyCode.E) - key(Enum.KeyCode.Q)
		local thrUp = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		local thrDn = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
		local brakes = UserInputService:IsKeyDown(Enum.KeyCode.B) or ui.touch.brake

		local t = ui.touch
		local p = kp + expo(t.y)
		local r = kr + expo(t.x)
		local y = ky

		if UserInputService.GamepadEnabled then
			for _, s in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
				local kc = s.KeyCode
				if kc == Enum.KeyCode.Thumbstick1 then
					p += expo(-dz(s.Position.Y, 0.12))
					r += expo(dz(s.Position.X, 0.12))
				elseif kc == Enum.KeyCode.Thumbstick2 then
					y += dz(s.Position.X, 0.2)
				elseif kc == Enum.KeyCode.ButtonR2 and s.Position.Z > 0.25 then
					thrUp = true
				elseif kc == Enum.KeyCode.ButtonL2 and s.Position.Z > 0.25 then
					thrDn = true
				end
			end
			if UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonL1) then
				brakes = true
			end
		end

		if self.mouseYoke then
			local cam = workspace.CurrentCamera
			local m = UserInputService:GetMouseLocation()
			local vs = cam.ViewportSize
			local span = math.min(vs.X, vs.Y) * 0.32
			p += expo(dz(math.clamp((m.Y - vs.Y / 2) / span, -1, 1), 0.05))
			r += expo(dz(math.clamp((m.X - vs.X / 2) / span, -1, 1), 0.05))
		end

		local input = { p = p, r = r, y = y, thrUp = thrUp, thrDn = thrDn, brakes = brakes, throttle = t.throttle }
		t.throttle = nil
		return input
	end

	return self
end

return Controls
