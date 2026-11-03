--!strict
-- Камеры: сзади (плавная), кабина, орбита. Плюс облёт аэропорта в ангаре.
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("SkyPilot")
local World = require(Shared:WaitForChild("World"))

local CameraRig = {}
CameraRig.NAMES = { "сзади", "кабина", "орбита" }

function CameraRig.new(ui: any)
	local self: any = { mode = 1, orbit = { yaw = 0.6, pitch = 0.25, dist = 100 } }
	local cam = workspace.CurrentCamera
	local camRot = CFrame.identity
	local dragging = false
	local lastPos: Vector3? = nil
	local rng = Random.new()

	UserInputService.InputBegan:Connect(function(i, processed)
		if self.mode ~= 3 then
			return
		end
		if i.UserInputType == Enum.UserInputType.MouseButton2 or (i.UserInputType == Enum.UserInputType.Touch and not processed) then
			dragging = true
			lastPos = i.Position
		end
	end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton2 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = false
			lastPos = nil
		end
	end)
	UserInputService.InputChanged:Connect(function(i, processed)
		if self.mode ~= 3 then
			return
		end
		if i.UserInputType == Enum.UserInputType.MouseWheel and not processed then
			self.orbit.dist = math.clamp(self.orbit.dist * (if i.Position.Z < 0 then 1.1 else 0.9), 20, 3000)
		elseif dragging and lastPos and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			if ui.isTouchingControls() then
				return
			end
			local d = i.Position - lastPos
			lastPos = i.Position
			self.orbit.yaw -= d.X * 0.008
			self.orbit.pitch = math.clamp(self.orbit.pitch + d.Y * 0.006, -0.2, 1.3)
		end
	end)

	function self.cycle(): string
		self.mode = self.mode % 3 + 1
		return CameraRig.NAMES[self.mode]
	end

	function self.reset(att: CFrame, cfg: any)
		camRot = att
		self.orbit.dist = cfg.length * 1.2 + 40
	end

	-- pose — фактическое положение модели (то, что рисуется), cfg — конфиг
	function self.update(dt: number, pose: CFrame, cfg: any, speed: number, onGround: boolean, crashed: boolean)
		cam.CameraType = Enum.CameraType.Scriptable
		cam.FieldOfView = 66 + math.clamp(speed / cfg.maxKts, 0, 1) * 14
		local base = pose.Position
		local att = pose.Rotation
		if self.mode == 1 or crashed then
			camRot = camRot:Lerp(att, math.min(1, dt * 4))
			local back = cfg.length * 0.8 + 32
			local upOff = cfg.diameter * 1.25 + cfg.length * 0.09 + 6
			local eye = base + camRot * Vector3.new(0, upOff, back)
			local target = base + camRot * Vector3.new(0, upOff * 0.3, -cfg.length * 0.4)
			if onGround and speed > 30 then
				eye += Vector3.new(0, (rng:NextNumber() - 0.5) * math.min(0.6, speed / 400), 0)
			end
			local gmin = World.groundAt(eye.X, eye.Z)
			if eye.Y < gmin + 3 then
				eye = Vector3.new(eye.X, gmin + 3, eye.Z)
			end
			cam.CFrame = CFrame.lookAt(eye, target, camRot.UpVector)
		elseif self.mode == 2 then
			local eye = pose * Vector3.new(0, cfg.diameter * 0.36, -cfg.length * 0.5 - 1.5)
			cam.CFrame = CFrame.new(eye) * att
			camRot = att
		else
			local o = self.orbit
			local off = Vector3.new(math.sin(o.yaw) * math.cos(o.pitch), math.sin(o.pitch), math.cos(o.yaw) * math.cos(o.pitch)) * o.dist
			cam.CFrame = CFrame.lookAt(base + off, base)
			camRot = att
		end
	end

	-- медленный облёт аэропорта (ангар / ожидание)
	function self.idle(t: number)
		cam.CameraType = Enum.CameraType.Scriptable
		cam.FieldOfView = 66
		local a = t / 14
		local eye = Vector3.new(math.sin(a) * 900 + 650, 90 + math.sin(a * 0.7) * 30, math.cos(a) * 900 + 300)
		cam.CFrame = CFrame.lookAt(eye, Vector3.new(680, 20, 300))
	end

	function self.release()
		cam.CameraType = Enum.CameraType.Custom
		cam.FieldOfView = 70
	end

	return self
end

return CameraRig
