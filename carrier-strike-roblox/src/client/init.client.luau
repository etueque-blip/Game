--!strict
-- Carrier Strike — клиент: меню вылета, локальная физика своего самолёта (как в Sky Pilot),
-- катапульта и тросы, пушка/ракеты/ловушки, метки, радар, камера.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("CarrierStrike")
local World = require(Shared:WaitForChild("World"))
local Jets = require(Shared:WaitForChild("Jets"))
local FlightPhysics = require(Shared:WaitForChild("FlightPhysics"))
local R = ReplicatedStorage:WaitForChild("CSRemotes")
local match = ReplicatedStorage:WaitForChild("CSMatch")

local Hud = require(script:WaitForChild("Hud"))
local Controls = require(script:WaitForChild("Controls"))
local CameraRig = require(script:WaitForChild("CameraRig"))
local Animator = require(script:WaitForChild("Animator"))

local function ev(name: string): RemoteEvent
	return R:WaitForChild(name) :: RemoteEvent
end
local SpawnR, StartedR, ReadyR, StateR = ev("Spawn"), ev("Started"), ev("Ready"), ev("State")
local GunR, MissileR, FlareR, CrashR = ev("Gun"), ev("Missile"), ev("Flare"), ev("Crash")
local RearmR, LeaveR, KilledR, NotifyR = ev("Rearm"), ev("Leave"), ev("Killed"), ev("Notify")
local FeedR, WarnR, HitR = ev("Feed"), ev("Warn"), ev("Hit")

local ui = Hud.new()
ui.setJets(Jets.ORDER, Jets.JETS)
local cameraRig = CameraRig.new(ui)

local function mySide(): string
	local t = player.Team
	local s = t and t:GetAttribute("Side")
	return if type(s) == "string" then s else "Blue"
end

-- персонаж в этой игре не ходит: только сидит в кабине
local controlsModule: any = nil
local function setCharacterControls(enabled: boolean)
	if not controlsModule then
		local ok, pm = pcall(function()
			return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript) :: any
		end)
		if ok and pm then
			controlsModule = pm:GetControls()
		end
	end
	if controlsModule then
		if enabled then
			controlsModule:Enable()
		else
			controlsModule:Disable()
		end
	end
end
task.spawn(setCharacterControls, false)

-- ===== состояние полёта
local flight: any = nil
local model: Model? = nil
local root: BasePart? = nil
local cfg: any = nil
local simulating = false
local parkBrake = false
local assist = false -- катапульта / ускоритель взлёта
local crashPose: CFrame? = nil
local deadUntil = 0
local lastSync = 0
local lastShot = 0
local lastRearm = 0
local lock = { target = nil :: Model?, t = 0 }
local incoming: { BasePart } = {}
local inMenu = true

-- ===== меню
local function refreshMenu()
	local side = mySide()
	ui.setTeam(side, World.TEAM_NAME[side])
	local list = {
		{ id = "deck:" .. side, title = "⚓ Палуба авианосца", sub = "Взлёт с катапульты: тяга 100% — и в небо", ok = true },
		{ id = "air:" .. side, title = "✈ В воздухе у авианосца", sub = "Сразу в бой, высота ~2 400 ft", ok = true },
	}
	for _, i in World.ISLANDS do
		local owner = match:GetAttribute("Owner_" .. i.id) or i.owner
		local ok = owner == side
		table.insert(list, {
			id = "base:" .. i.id, title = "◆ База «" .. i.name .. "»",
			sub = if ok then "Своя полоса на острове" elseif owner == "" then "Нейтральная — захвати, чтобы взлетать отсюда" else "У противника — отбей", ok = ok,
		})
	end
	ui.setSpawns(list)
end

local function refreshMatch()
	local b = match:GetAttribute("TicketsBlue") or 0
	local r = match:GetAttribute("TicketsRed") or 0
	ui.setTickets(b, r)
	local bases = {}
	local nb, nr = 0, 0
	for _, i in World.ISLANDS do
		local owner = match:GetAttribute("Owner_" .. i.id) or i.owner
		table.insert(bases, { id = i.id, owner = owner, cap = match:GetAttribute("Cap_" .. i.id) or 0 })
		if owner == "Blue" then
			nb += 1
		elseif owner == "Red" then
			nr += 1
		end
	end
	ui.setBases(bases)
	ui.setScoreLine(string.format("Синие %d · Красные %d   ·   базы %d : %d", b, r, nb, nr))
	if inMenu then
		refreshMenu()
	end
end
match.AttributeChanged:Connect(refreshMatch)
player:GetPropertyChangedSignal("Team"):Connect(refreshMenu)
refreshMatch()
refreshMenu()

ui.onLaunch(function(jetId: string, spawnId: string)
	SpawnR:FireServer(jetId, spawnId)
end)

-- ===== начало и конец вылета
local function stopFlight()
	flight, model, root, cfg, simulating, crashPose = nil, nil, nil, nil, false, nil
	assist, parkBrake = false, false
	lock.target, lock.t = nil, 0
	table.clear(incoming)
	Animator.setLocal(nil)
	ui.setFlying(false)
	ui.showMenu(true)
	inMenu = true
	refreshMenu()
end

local function die(text: string)
	if flight and not flight.crashed then
		flight.crashed = true
	end
	if flight then
		crashPose = FlightPhysics.pose(flight)
	end
	deadUntil = os.clock() + 4
	ui.showDead(text)
	task.delay(4, function()
		if os.clock() >= deadUntil - 0.05 then
			ui.showDead(nil)
			stopFlight()
		end
	end)
end

StartedR.OnClientEvent:Connect(function(m: Model, jetId: string, spawnCF: CFrame, air: boolean)
	local c = Jets.JETS[jetId]
	if not c or not m then
		return
	end
	cfg = c
	model = m
	root = m:WaitForChild("Root", 5) :: BasePart?
	local f = FlightPhysics.new(c, spawnCF, air)
	f.hard = false
	if air then
		f.speed = math.min(c.maxKts * 0.6, 430)
		f.vel = spawnCF.LookVector * f.speed
		f.throttle = 0.85
		f.gear = false
	end
	flight = f
	simulating = false
	crashPose = nil
	parkBrake = not air
	assist = false
	inMenu = false
	ui.showMenu(false)
	ui.showDead(nil)
	ui.setFlying(true)
	ui.setThrottleKnob(f.throttle)
	cameraRig.reset(spawnCF.Rotation, c)
	Animator.setLocal(m, f.gear, 0, f.throttle)
	setCharacterControls(false)
	if air then
		ui.toast("В воздухе! Ищи цели на радаре и в красных рамках", "accent")
	elseif World.runwayAt(spawnCF.Position.X, spawnCF.Position.Z, 5) == World.carrierOf(mySide()).id then
		ui.toast("Катапульта: тяга на 100% (Shift / ползунок) — разгонит сама", "accent")
	else
		ui.toast("Полоса базы: тяга на 100% — ускоритель взлёта разгонит", "accent")
	end
	ReadyR:FireServer(m)
end)

KilledR.OnClientEvent:Connect(function(text: string)
	if flight then
		die(text)
	end
end)
NotifyR.OnClientEvent:Connect(function(text: string, colr: string?)
	ui.toast(text, colr)
end)
FeedR.OnClientEvent:Connect(function(text: string, sideA: string?, _sideB: string?)
	ui.feed(text, World.TEAM_COLOR[sideA or ""] or Hud.C.text)
end)
HitR.OnClientEvent:Connect(function(_m: Model, kill: boolean)
	ui.hit(kill)
end)
WarnR.OnClientEvent:Connect(function(part: BasePart)
	table.insert(incoming, part)
end)

-- ===== цели
local function enemies(): { Model }
	local out = {}
	local folder = workspace:FindFirstChild("Planes")
	if not folder then
		return out
	end
	local side = mySide()
	for _, m in folder:GetChildren() do
		if m:IsA("Model") and m ~= model and m.Name ~= "Wreck" and m.PrimaryPart and m:GetAttribute("Side") ~= side and (m:GetAttribute("HP") or 0) > 0 then
			table.insert(out, m)
		end
	end
	return out
end

local function bestInCone(look: Vector3, from: Vector3, deg: number, range: number): Model?
	local best, bestA = nil, math.cos(math.rad(deg))
	for _, m in enemies() do
		local d = (m.PrimaryPart :: BasePart).Position - from
		local dist = d.Magnitude
		if dist < range and dist > 1 then
			local c = look:Dot(d / dist)
			if c > bestA then
				best, bestA = m, c
			end
		end
	end
	return best
end

-- ===== эффекты: трассеры и ловушки (только у себя на экране)
type Fx = { part: BasePart, vel: Vector3, t: number, life: number, grav: number }
local fx: { Fx } = {}
local fxFolder = Instance.new("Folder")
fxFolder.Name = "LocalFx"
fxFolder.Parent = workspace
local function addFx(size: Vector3, cf: CFrame, color: Color3, vel: Vector3, life: number, grav: number)
	if #fx > 160 then
		return
	end
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.CFrame = cf
	p.Parent = fxFolder
	table.insert(fx, { part = p, vel = vel, t = 0, life = life, grav = grav })
end
local function tracer(from: CFrame, speed: number)
	local dir = from.LookVector
	addFx(Vector3.new(0.35, 0.35, 26), from * CFrame.new(0, 0, -20), Color3.fromRGB(255, 214, 120), dir * (2600 + speed), 0.7, 0)
end
local function flaresFx(cf: CFrame)
	for k = 1, 6 do
		local side = if k % 2 == 0 then 1 else -1
		local v = cf.RightVector * side * (30 + k * 8) - cf.UpVector * 20 - cf.LookVector * 40
		addFx(Vector3.new(2.2, 2.2, 2.2), cf * CFrame.new(0, -2, 10), Color3.fromRGB(255, 236, 170), v, 1.8, 30)
	end
end
local seenFlare: { [Model]: number } = {}
local lastTracer: { [Model]: number } = {}

-- ===== действия (клавиши, геймпад и сенсорные кнопки — один обработчик)
local controls: any = nil
local function act(a: string)
	local f = flight
	if a == "cam" then
		ui.toast("Камера: " .. cameraRig.cycle())
		return
	end
	if not f or f.crashed then
		return
	end
	if a == "missile" then
		if lock.target and lock.t >= 0 then
			local need = Jets.MSL_LOCK * ((Jets.JETS[lock.target:GetAttribute("PlaneId") :: any] or {}).lockMul or 1)
			if lock.t >= need then
				if ((model and model:GetAttribute("Missiles")) or 0) > 0 then
					MissileR:FireServer(lock.target)
					lock.t = 0
					ui.toast("Пуск!", "amber")
				else
					ui.toast("Ракеты кончились — сядь на палубу или свою базу", "amber")
				end
				return
			end
		end
		ui.toast("Нет захвата: держи врага в рамке ~1.5 с", "amber")
	elseif a == "flare" then
		FlareR:FireServer()
	elseif a == "gear" then
		local text = FlightPhysics.action(f, "gear")
		if text then
			ui.toast(text)
		end
	elseif a == "mouse" then
		controls.mouseYoke = not controls.mouseYoke
		ui.toast(if controls.mouseYoke then "Мышь-штурвал включён (C)" else "Мышь-штурвал выключен")
	elseif a == "brake" then
		ui.touch.brake = not ui.touch.brake
		ui.toast(if ui.touch.brake then "Тормоз включён" else "Тормоз выключен")
	elseif a == "idle" then
		FlightPhysics.action(f, "idle")
		ui.setThrottleKnob(0)
	elseif a == "menu" then
		if f.onGround and f.speed < 25 then
			LeaveR:FireServer()
			stopFlight()
		else
			ui.toast("В меню — только на земле (палуба или своя база)", "amber")
		end
	end
end
controls = Controls.new(ui, act)
ui.onAction(function(a: string)
	if a ~= "gun" then
		act(a)
	end
end)

-- ===== физика: каждый шаг перед симуляцией Roblox
RunService.PreSimulation:Connect(function(dt)
	local f = flight
	local r = root
	if not f or f.crashed or not r or not model then
		return
	end
	if not simulating then
		if r.Anchored then
			return
		end
		simulating = true
	end
	if not model.Parent or model.Name == "Wreck" then
		die("Самолёт уничтожен")
		return
	end
	local input = controls.read()
	if input.throttle then
		ui.setThrottleKnob(input.throttle)
	end
	-- стояночный тормоз до полной тяги, затем катапульта / ускоритель
	if parkBrake then
		input.brakes = true
		if f.throttle >= 0.9 or (input.throttle and input.throttle >= 0.9) then
			parkBrake = false
			assist = true
			ui.toast("СТАРТ!", "accent")
		end
	end
	if assist and f.onGround and f.speed >= cfg.vrKts then
		input.p = math.max(input.p, 0.35) -- автоматический отрыв носа
	end
	FlightPhysics.step(f, input, dt)
	if assist then
		if f.onGround then
			f.speed = math.min(f.speed + 110 * dt, cfg.vrKts + 40)
		else
			assist = false
		end
	end
	-- аэрофинишёр: на палубе при малой тяге самолёт быстро тормозит
	if f.onGround and not assist and f.speed > 5 then
		local where = World.runwayAt(f.pos.X, f.pos.Z, 0)
		if where and where:sub(1, 3) == "CV_" and f.throttle < 0.5 then
			f.speed = math.max(0, f.speed - 70 * dt)
		end
	end
	if not f.crashed and f.pos.Y < World.SEA + 1 and World.isWater(f.pos.X, f.pos.Z) then
		f.crashed = true
		f.crashReason = "Упал в океан!"
	end
	if f.crashed then
		CrashR:FireServer(f.crashReason or "Крушение")
		die(f.crashReason or "Крушение")
		return
	end
	r.CFrame = FlightPhysics.pose(f)
	r.AssemblyLinearVelocity = f.vel
	r.AssemblyAngularVelocity = Vector3.zero
	Animator.setLocal(model, f.gear, f.flaps, f.throttle)
	Animator.setInputs(f.inP, f.inR, f.inY)
	local now = os.clock()
	if now - lastSync > 0.25 then
		lastSync = now
		StateR:FireServer(f.gear, f.throttle)
	end
end)

-- ===== кадр: камера, оружие, приборы
local function fmtDist(d: number): string
	local m = d * 0.515
	return if m >= 1000 then string.format("%.1f км", m / 1000) else string.format("%d м", math.round(m / 10) * 10)
end

RunService:BindToRenderStep("CarrierStrike", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local now = os.clock()
	Animator.step(dt, now)
	local cam = workspace.CurrentCamera
	local serverNow = workspace:GetServerTimeNow()

	-- эффекты
	for i = #fx, 1, -1 do
		local e = fx[i]
		e.t += dt
		if e.t >= e.life then
			e.part:Destroy()
			table.remove(fx, i)
		else
			e.vel -= Vector3.new(0, e.grav * dt, 0)
			e.part.CFrame = e.part.CFrame + e.vel * dt
			if e.grav > 0 then
				e.part.Transparency = e.t / e.life
			end
		end
	end
	-- чужие выстрелы и ловушки
	local folder = workspace:FindFirstChild("Planes")
	if folder then
		for _, m in folder:GetChildren() do
			if m:IsA("Model") and m.PrimaryPart and m.Name ~= "Wreck" then
				local fu = m:GetAttribute("FiringUntil")
				if m ~= model and type(fu) == "number" and fu > serverNow and now - (lastTracer[m] or 0) > 0.09 then
					lastTracer[m] = now
					tracer(m.PrimaryPart.CFrame, m.PrimaryPart.AssemblyLinearVelocity.Magnitude)
				end
				local fa = m:GetAttribute("FlareAt")
				if type(fa) == "number" and seenFlare[m] ~= fa then
					local first = seenFlare[m] == nil
					seenFlare[m] = fa
					if not first or serverNow - fa < 1 then
						flaresFx(m.PrimaryPart.CFrame)
					end
				end
			end
		end
	end

	local f = flight
	if not f then
		-- меню: облёт своего авианосца
		local c = World.carrierOf(mySide())
		local a = now / 16
		local center = c.cf.Position + Vector3.new(0, World.DECK_H + 20, 0)
		cam.CameraType = Enum.CameraType.Scriptable
		cam.FieldOfView = 60
		cam.CFrame = CFrame.lookAt(center + Vector3.new(math.sin(a) * 760, 210 + math.sin(a * 0.7) * 50, math.cos(a) * 760), center)
		return
	end
	if f.crashed then
		cameraRig.update(dt, crashPose or FlightPhysics.pose(f), f.cfg, 0, false, true)
		return
	end
	local pose = if root and simulating then (root :: BasePart).CFrame else FlightPhysics.pose(f)
	cameraRig.update(dt, pose, f.cfg, f.speed, f.onGround, false, f.buffet)

	-- пушка
	if simulating and controls.firing() and now - lastShot >= Jets.GUN_RATE then
		lastShot = now
		local t = bestInCone(f.att.LookVector, f.pos, Jets.GUN_CONE, Jets.GUN_RANGE)
		GunR:FireServer(t)
		tracer(FlightPhysics.pose(f) * CFrame.new(if math.random() < 0.5 then 1.5 else -1.5, 0, -f.cfg.length * 0.5), f.speed)
	end

	-- захват ракетой
	local cand = bestInCone(f.att.LookVector, f.pos, Jets.MSL_CONE, Jets.MSL_RANGE)
	if cand ~= lock.target then
		lock.target = cand
		lock.t = 0
	elseif cand then
		lock.t += dt
	end
	local lockInfo = nil
	if lock.target and lock.target.PrimaryPart then
		local sp, on = cam:WorldToViewportPoint(lock.target.PrimaryPart.Position)
		if on then
			local need = Jets.MSL_LOCK * ((Jets.JETS[lock.target:GetAttribute("PlaneId") :: any] or {}).lockMul or 1)
			lockInfo = { x = sp.X, y = sp.Y, k = math.clamp(lock.t / need, 0, 1), locked = lock.t >= need }
		end
	end

	-- метки и радар
	local side = mySide()
	local marks = {}
	local dots = {}
	local myPos = f.pos
	local att = f.att
	local RANGE = 9000
	if folder then
		for _, m in folder:GetChildren() do
			if m:IsA("Model") and m ~= model and m.PrimaryPart and m.Name ~= "Wreck" then
				local p = m.PrimaryPart.Position
				local s = m:GetAttribute("Side")
				local colr = World.TEAM_COLOR[s :: any] or Hud.C.text
				local dist = (p - myPos).Magnitude
				local sp, on = cam:WorldToViewportPoint(p)
				if on and dist < 14000 and #marks < 28 then
					local enemy = s ~= side
					table.insert(marks, { x = sp.X, y = sp.Y, color = colr, size = if enemy then 20 else 12, text = if enemy then fmtDist(dist) else "" })
				end
				local rel = att:VectorToObjectSpace(p - myPos)
				local v = Vector2.new(rel.X, rel.Z) / RANGE
				if v.Magnitude > 1 then
					v = v.Unit
				end
				table.insert(dots, { dx = v.X, dy = v.Y, color = colr, big = false })
			end
		end
	end
	for _, i in World.ISLANDS do
		local rel = att:VectorToObjectSpace(Vector3.new(i.x, myPos.Y, i.z) - myPos)
		local v = Vector2.new(rel.X, rel.Z) / RANGE
		if v.Magnitude > 1 then
			v = v.Unit
		end
		table.insert(dots, { dx = v.X, dy = v.Y, color = World.TEAM_COLOR[(match:GetAttribute("Owner_" .. i.id) or "") :: any] or Hud.C.text, big = true })
	end
	ui.setMarkers(marks)
	ui.setRadar(dots)

	-- предупреждения и подсказки
	local warn: string? = nil
	local nearest = math.huge
	for i = #incoming, 1, -1 do
		local p = incoming[i]
		if not p.Parent or p.Transparency >= 1 then
			table.remove(incoming, i)
		else
			nearest = math.min(nearest, (p.Position - myPos).Magnitude)
		end
	end
	if nearest < 9000 and (now % 0.5) < 0.33 then
		warn = "⚠ РАКЕТА " .. fmtDist(nearest) .. " — ЛОВУШКИ (X) И ВИРАЖ!"
	end
	local outside = math.abs(myPos.X) > World.SIZE or math.abs(myPos.Z) > World.SIZE
	if outside then
		warn = "ВНЕ ЗОНЫ БОЯ — РАЗВОРАЧИВАЙСЯ!"
	end
	local hp = (model and model:GetAttribute("HP") or 0) :: number
	local maxHp = (model and model:GetAttribute("MaxHP") or 100) :: number
	if not warn and hp < maxHp * 0.3 then
		warn = "КОРПУС ПОВРЕЖДЁН — НА РЕМОНТ (палуба / своя база)"
	end
	local info: string? = nil
	if parkBrake then
		info = "Тяга на 100% (Shift / ползунок) — старт"
	elseif f.onGround and f.speed < 15 then
		local where = World.runwayAt(myPos.X, myPos.Z, 10)
		local mine = where == World.carrierOf(side).id or (where ~= nil and match:GetAttribute("Owner_" .. where) == side)
		if mine then
			info = "Ремонт и перезарядка… · M — в меню"
			if now - lastRearm > 2 then
				lastRearm = now
				RearmR:FireServer()
			end
		end
	else
		for _, i in World.ISLANDS do
			local dx, dz = myPos.X - i.x, myPos.Z - i.z
			if dx * dx + dz * dz < World.CAPTURE_R * World.CAPTURE_R then
				local cap = (match:GetAttribute("Cap_" .. i.id) or 0) :: number
				local pct = math.floor(math.abs(cap) * 100)
				local whose = if cap >= 0 then "Синие" else "Красные"
				if myPos.Y < i.h + World.CAPTURE_ALT then
					info = string.format("Захват «%s»: %s %d%%", i.name, whose, pct)
				else
					info = string.format("База «%s»: снизься ниже %d ft для захвата", i.name, math.floor((i.h + World.CAPTURE_ALT) * World.FT))
				end
			end
		end
	end
	local vs = cam.ViewportSize
	local aim = cam:WorldToViewportPoint(f.pos + f.att.LookVector * 1500)
	ui.update({
		speed = f.speed, alt = (myPos.Y - World.SEA) * World.FT, thr = f.throttle, hp = hp, maxHp = maxHp,
		missiles = model and model:GetAttribute("Missiles") or 0, flares = model and model:GetAttribute("Flares") or 0,
		gear = f.gear, lock = lockInfo, warn = warn, info = info,
		aim = Vector2.new(math.clamp(aim.X, 0, vs.X), math.clamp(aim.Y, 0, vs.Y)),
	})
end)

Players.LocalPlayer.CharacterAdded:Connect(function()
	task.wait(0.5)
	setCharacterControls(false)
end)
