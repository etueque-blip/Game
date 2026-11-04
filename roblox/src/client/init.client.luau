--!strict
-- Sky Pilot — клиент: локальная физика полёта (как FlightClient), ввод, камера, приборы.
-- Самолёт принадлежит игроку по сети (SetNetworkOwner), поэтому управление без задержки,
-- а другие игроки видят движение через обычную репликацию физики Roblox.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("SkyPilot")
local PlaneConfigs = require(Shared:WaitForChild("PlaneConfigs"))
local World = require(Shared:WaitForChild("World"))
local FlightPhysics = require(Shared:WaitForChild("FlightPhysics"))
local Autopilot = require(Shared:WaitForChild("Autopilot"))

local Ui = require(script:WaitForChild("Ui"))
local Controls = require(script:WaitForChild("Controls"))
local CameraRig = require(script:WaitForChild("CameraRig"))
local Animator = require(script:WaitForChild("Animator"))
local Race = require(script:WaitForChild("Race"))
local Radar = require(script:WaitForChild("Radar"))

local remotes = ReplicatedStorage:WaitForChild("SkyPilotRemotes")
local function R(name: string): RemoteEvent
	return remotes:WaitForChild(name) :: RemoteEvent
end
local RequestFlight, FlightStarted, ClientReady = R("RequestFlight"), R("FlightStarted"), R("ClientReady")
local PlaneState, Landing, CrashEvent, EndFlight, Notify = R("PlaneState"), R("Landing"), R("Crash"), R("EndFlight"), R("Notify")
local RaceFinished = R("RaceFinished")
local GateParked = R("GateParked")
local AchievementR = R("Achievement")
-- достижения, которые видит только клиент: отправляем один раз, сервер проверяет и награждает
local achSent: { [string]: boolean } = {}
local function claimAch(id: string)
	if achSent[id] then
		return
	end
	local have = tostring(Players.LocalPlayer:GetAttribute("Ach") or "")
	if string.find("," .. have .. ",", "," .. id .. ",", 1, true) then
		achSent[id] = true
		return
	end
	achSent[id] = true
	AchievementR:FireServer(id)
end

local FT = FlightPhysics.FT
local clamp = FlightPhysics.clamp

-- ===== состояние
local flight: FlightPhysics.Flight? = nil
local model: Model? = nil
local root: BasePart? = nil
local simulating = false
local crashPose: CFrame? = nil
local crashTimer = 0
local lastPlaneId: string? = nil
local lastMode = "runway:A"
local apTarget: Autopilot.Target? = nil
local navIdx = 0 -- 0 = навигация выключена
local parkBrake = false
local gateTarget: any = nil
local callsign = "SKY000"
local atcApproach = false -- разрешение на заход уже выдано
local flightSeq = 0 -- номер текущего полёта: отложенные сообщения старого полёта отбрасываются

local function runwayFor(ap: any, pos: Vector3): string
	-- с какого торца заходим: локальная Z > 0 — с юга (полоса ap.south)
	local dx, dz = pos.X - ap.cx, pos.Z - ap.cz
	local lz = if ap.rot == 1 then dx else dz
	return if lz > 0 then ap.south else ap.north
end -- стоянка, к которой надо зарулить после посадки
local lastDest: string? = nil
local apFollowNav = false
local vsSmooth = 0
local engineSound: Sound? = nil
local sent = { gear = true, flaps = 0, throttle = -1, reverse = false, t = 0 }
local logLines: { string } = {}
local fps = 60

local function addLog(t: string)
	table.insert(logLines, string.format("[%.1fs] %s", os.clock(), t))
	if #logLines > 12 then
		table.remove(logLines, 1)
	end
end

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
	local ch = player.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	if hum then
		hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, enabled)
	end
end

-- ===== UI + ввод + камера
local ui: any
local cameraRig: any
local controls: any

local function onAction(a: string)
	if a == "hangar" then
		ui.showHangar()
		return
	elseif a == "cam" then
		ui.setCamLabel(cameraRig.cycle())
		return
	elseif a == "guide" then
		ui.showGuide(if flight then flight.cfg else PlaneConfigs.PLANES[lastPlaneId or "C172"])
		return
	elseif a == "mouse" then
		controls.mouseYoke = not controls.mouseYoke
		ui.setMouseLabel(controls.mouseYoke)
		ui.toast(if controls.mouseYoke then "Мышь-штурвал: курсор от центра = отклонение штурвала" else "Мышь-штурвал выключен")
		return
	end
	local f = flight
	if not f or f.crashed then
		return
	end
	if a == "park" then
		if f.onGround then
			parkBrake = not parkBrake
			ui.toast(if parkBrake then "Стояночный тормоз включён" else "Стояночный тормоз отключён", if parkBrake then "amber" else "green")
		else
			parkBrake = false
		end
		return
	end
	if a == "nav" then
		navIdx = (navIdx + 1) % (#World.NAV + 1)
		local n = World.NAV[navIdx]
		ui.toast(if n then "Навигация: " .. n.name .. " (P — автопилот поведёт к цели)" else "Навигация выключена")
		if not n then
			ui.setNav(nil)
			apFollowNav = false
		end
		return
	end
	if a == "autopilot" then
		if apTarget then
			apTarget = nil
			ui.toast("Автопилот выключен", "amber")
		elseif f.onGround then
			ui.toast("Автопилот включается только в воздухе", "amber")
		else
			-- безопасная высота: не ниже 3500 ft, чтобы пройти над горами и небоскрёбами
			local n = World.NAV[navIdx]
			apFollowNav = n ~= nil
			local alt = f.pos.Y * FT
			if n then
				alt = math.clamp(alt, 3500, f.cfg.ceilingFt * 0.8)
			end
			apTarget = { heading = World.headingDeg(f.att.LookVector), altFt = alt, speed = math.max(f.speed, f.cfg.stallKts * 1.4) }
			if n then
				ui.toast(string.format("Автопилот ведёт к цели: %s, %d ft", n.name, math.round(alt)), "green")
			else
				ui.toast(string.format("Автопилот: курс %03d°, %d ft, %d kt", math.round((apTarget :: any).heading) % 360, math.round((apTarget :: any).altFt), math.round((apTarget :: any).speed)), "green")
			end
		end
		ui.setAutopilot(apTarget ~= nil)
		return
	end
	local text, color = FlightPhysics.action(f, a)
	if text then
		ui.toast(text, color)
		addLog(text)
	end
end

local lastLivery: string? = nil
local function requestFlight(planeId: string, mode: string, destination: string?, livery: string?)
	lastPlaneId, lastMode, lastDest = planeId, mode, destination
	if livery then
		lastLivery = livery
	end
	ui.showHangar(false)
	ui.hideCrash()
	RequestFlight:FireServer(planeId, mode, destination, lastLivery)
end

ui = Ui.new({
	onPick = requestFlight,
	onAction = onAction,
	onAgain = function()
		if lastPlaneId then
			requestFlight(lastPlaneId, lastMode, lastDest)
		end
	end,
	onToHangar = function()
		ui.showHangar(true)
	end,
	onExit = function()
		if flight then
			EndFlight:FireServer()
			stopFlight()
		end
	end,
})
controls = Controls.new(ui, onAction)
local radar = Radar.new(ui.root, Ui.Colors)
local race = Race.new(function(name, i, n)
	ui.toast(string.format("Кольцо %d/%d · %s", i, n, name), "magenta")
end, function(t)
	ui.toast(string.format("ФИНИШ гонки: %d:%04.1f", math.floor(t / 60), t % 60), "green")
	addLog(string.format("Гонка: %.1f с", t))
	RaceFinished:FireServer(t)
end)
cameraRig = CameraRig.new(ui)

local function stopFlight()
	flight, model, root, simulating, apTarget, crashPose = nil, nil, nil, false, nil, nil
	if engineSound then
		engineSound:Destroy()
		engineSound = nil
	end
	Animator.setLocal(nil)
	race.reset()
	gateTarget = nil
	flightSeq += 1
	radar.setVisible(false)
	ui.setFlying(false)
	ui.setAutopilot(false)
	setCharacterControls(true)
end

FlightStarted.OnClientEvent:Connect(function(m: Model, planeId: string, mode: string, spawnCF: CFrame)
	local cfg = PlaneConfigs.PLANES[planeId]
	if not cfg or not m then
		return
	end
	stopFlight()
	model = m
	root = m:WaitForChild("Root", 5) :: BasePart?
	local f = FlightPhysics.new(cfg, spawnCF, mode == "air")
	flight = f
	simulating = false
	vsSmooth = 0
	sent = { gear = f.gear, flaps = 0, throttle = f.throttle, reverse = false, t = 0 }
	cameraRig.reset(spawnCF.Rotation, cfg)
	Animator.setLocal(m, f.gear, f.flaps, f.throttle)
	ui.setFlying(true, cfg.name)
	radar.setVisible(true)
	race.reset()
	ui.showHangar(false)
	ui.hideCrash()
	ui.setThrottleFill(f.throttle)
	setCharacterControls(false)
	if PlaneConfigs.ENGINE_SOUND_ID ~= "" and root then
		local s = Instance.new("Sound")
		s.SoundId = PlaneConfigs.ENGINE_SOUND_ID
		s.Looped = true
		s.Volume = 0.6
		s.RollOffMaxDistance = 2000
		s.Parent = root
		s:Play()
		engineSound = s
	end
	addLog(string.format("Старт: %s, %s", cfg.name, mode))
	callsign = string.format("SKY%03d", math.random(100, 999))
	atcApproach = false
	flightSeq += 1
	local seq = flightSeq
	do
		local apId = World.runwayAt(spawnCF.Position.X, spawnCF.Position.Z, 20)
		local ap = apId and World.airportById(apId)
		task.delay(4.5, function()
			if seq ~= flightSeq or not flight or flight.crashed then
				return
			end
			if ap then
				ui.atc(string.format("Вышка %s: %s, полоса %s, взлёт разрешён. Ветер штиль.", ap.code, callsign, runwayFor(ap, spawnCF.Position + spawnCF.LookVector * -100)))
			else
				ui.atc(string.format("Подход: %s, наблюдаю вас на радаре, %d ft. Курс по навигации.", callsign, math.round(spawnCF.Position.Y * FT)))
			end
		end)
	end
	parkBrake = mode ~= "air"
	-- рейс: навигация сразу на аэропорт назначения
	if lastDest then
		navIdx = World.navIndexForAirport(lastDest)
		local dst = World.airportById(lastDest)
		if dst then
			task.delay(3.2, function()
				if seq ~= flightSeq then
					return
				end
				ui.toast(string.format("Рейс в %s · %s — навигация включена (N)", dst.code, dst.title), "magenta")
			end)
		end
	end
	ui.toast(if lastMode == "race" then "Гонка: впереди голубое кольцо — пролети сквозь него" elseif mode == "air" then "Вы в воздухе на 3000 ft — аэропорт впереди" else string.format("На полосе: отпусти тормоз (пробел), тяга 100%% (Shift), на Vr %d kt тяни на себя (S)", cfg.vrKts), "magenta")
	ClientReady:FireServer(m)
end)

EndFlight.OnClientEvent:Connect(function()
	if flight and not flight.crashed then
		stopFlight()
	end
end)

Notify.OnClientEvent:Connect(function(text: string, color: string?)
	ui.toast(text, color)
	addLog(text)
end)

player.CharacterAdded:Connect(function()
	task.defer(function()
		if not flight then
			setCharacterControls(true)
		end
	end)
end)

-- дым шин при касании
local function tireSmoke(m: Model, cfg: any)
	local r = m.PrimaryPart
	if not r then
		return
	end
	for _, a in r:GetChildren() do
		if a:IsA("Attachment") and a.Name:sub(1, 8) == "MainGear" then
			local pe = a:FindFirstChild("Smoke") :: ParticleEmitter?
			if not pe then
				local e = Instance.new("ParticleEmitter")
				e.Name = "Smoke"
				e.Rate = 0
				e.Lifetime = NumberRange.new(1.2, 2)
				e.Speed = NumberRange.new(2, 6)
				e.SpreadAngle = Vector2.new(60, 60)
				e.Size = NumberSequence.new(cfg.diameter * 0.3, cfg.diameter * 1.4)
				e.Transparency = NumberSequence.new(0.3, 1)
				e.Color = ColorSequence.new(Color3.fromRGB(220, 220, 220))
				e.LockedToPart = false
				e.Parent = a
				pe = e
			end
			(pe :: ParticleEmitter):Emit(14)
		end
	end
end

local function handleEvents(f: FlightPhysics.Flight)
	for _, ev in f.events do
		if ev.type == "landing" then
			addLog(ev.text)
			-- карточка «отчёт о посадке» (очки за касание — как на сервере; бонусы за перелёт/рейс приходят уведомлением)
			do
				local ap = ev.airport and World.airportById(ev.airport)
				local offM: number? = nil
				if ap then
					local dx, dz = f.pos.X - ap.cx, f.pos.Z - ap.cz
					offM = math.abs(if ap.rot == 1 then -dz else dx) * World.METERS_PER_STUD
				end
				local fpmV = ev.fpm or 0
				if offM and offM < 2 then
					claimAch("center")
				end
				ui.landingReport({
					grade = ev.grade or "hard", fpm = fpmV, kts = f.speed, g = f.gload, offM = offM,
					pts = if ap then (if fpmV < 120 then 400 elseif fpmV < 250 then 300 elseif fpmV < 600 then 150 else 50) else 0,
					where = if ap then ap.code .. " · полоса" else "вне аэропорта", damaged = f.damage > 0.3,
				})
			end
			Landing:FireServer(ev.fpm)
			if ev.airport then
				local ap = World.airportById(ev.airport)
				if ap then
					ui.atc(string.format("Вышка %s: %s, посадка в %s. Освободите полосу.", ap.code, callsign, os.date("%H:%M")))
				end
			end
			-- после посадки в аэропорту назначения — рулим к свободной стоянке
			if lastDest and ev.airport == lastDest and not gateTarget then
				local list = World.STANDS[lastDest]
				if list and #list > 0 then
					gateTarget = list[math.random(1, #list)]
					task.delay(3, function()
						if gateTarget then
							ui.toast("Зарули на стоянку " .. gateTarget.id .. " и остановись", "magenta")
						end
					end)
				end
			end
			if model then
				tireSmoke(model, f.cfg)
			end
		elseif ev.type == "warn" then
			ui.toast(ev.text, "amber")
			addLog(ev.text)
		elseif ev.type == "takeoff" then
			claimAch("first_flight")
			ui.atc(string.format("%s, взлёт в %s. Набирайте 3000 ft, курс по навигации.", callsign, os.date("%H:%M")))
			addLog(ev.text)
		elseif ev.type == "crash" then
			ui.toast("💥 " .. ev.text, "red")
			addLog("КРУШЕНИЕ: " .. ev.text)
			crashPose = FlightPhysics.pose(f)
			crashTimer = 1.8
			apTarget = nil
			ui.setFlying(false)
			radar.setVisible(false)
			race.reset()
			CrashEvent:FireServer(ev.text)
			if engineSound then
				engineSound:Destroy()
				engineSound = nil
			end
		end
	end
	table.clear(f.events)
end

local function syncState(f: FlightPhysics.Flight)
	local now = os.clock()
	local changed = f.gear ~= sent.gear or f.flaps ~= sent.flaps or f.reverse ~= sent.reverse
	local thrChanged = math.abs(f.throttle - sent.throttle) > 0.04 and now - sent.t > 0.25
	if changed or thrChanged then
		sent.gear, sent.flaps, sent.reverse, sent.throttle, sent.t = f.gear, f.flaps, f.reverse, f.throttle, now
		PlaneState:FireServer(f.gear, f.flaps, f.throttle, f.reverse)
	end
	Animator.setLocal(model, f.gear, f.flaps, f.throttle)
end

-- ===== физика: каждый шаг перед симуляцией Roblox
RunService.PreSimulation:Connect(function(dt)
	local f = flight
	if not f or f.crashed or not model or not root then
		return
	end
	if not simulating then
		-- ждём, пока сервер отдаст нам самолёт (снимет Anchored и назначит владельца)
		if root.Anchored then
			return
		end
		simulating = true
	end
	local input, manual = controls.read()
	if parkBrake then
		if f.onGround then
			input.brakes = true
		else
			parkBrake = false
		end
	end
	if apTarget then
		if manual then
			apTarget = nil
			ui.setAutopilot(false)
			ui.toast("Автопилот отключён штурвалом", "amber")
		else
			local n = World.NAV[navIdx]
			if apFollowNav and n then
				local t = apTarget :: Autopilot.Target
				t.heading = Autopilot.bearingDeg(f.pos, Vector3.new(n.x, 0, n.z))
				-- над целью: переходим в удержание курса, чтобы не кружить
				if (Vector3.new(f.pos.X - n.x, 0, f.pos.Z - n.z)).Magnitude < 1200 then
					apFollowNav = false
					ui.toast("Цель достигнута: " .. n.name, "green")
				end
			end
			local ap = Autopilot.compute(f, apTarget)
			ap.brakes = input.brakes
			input = ap
		end
	end
	local prevPos = f.pos
	FlightPhysics.step(f, input, dt)
	if not f.crashed then
		race.step(prevPos, f.pos, os.clock())
	end
	handleEvents(f)
	if f.crashed then
		return
	end
	root.CFrame = FlightPhysics.pose(f)
	root.AssemblyLinearVelocity = f.vel
	root.AssemblyAngularVelocity = Vector3.zero
	syncState(f)
end)

-- ===== приборы
local function fmt(n: number): string
	local s = tostring(math.round(math.abs(n)))
	local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "")
	return (if n < 0 then "−" else "") .. out
end

local function updateHud(f: FlightPhysics.Flight, dt: number, now: number)
	local c = f.cfg
	if f.pos.Y * FT > 35000 then
		claimAch("high")
	end
	if c.id == "F16" and f.gload >= 8 and f.damage < 0.05 then
		claimAch("ace")
	end
	local att = f.att
	local look, right, up = att.LookVector, att.RightVector, att.UpVector
	local agl = (f.dbg.agl or 0) * FT
	vsSmooth += (f.vel.Y * 60 * FT - vsSmooth) * math.min(1, dt * 6)
	local vs = math.round(vsSmooth / 10) * 10
	local hdg = World.headingDeg(look)
	ui.setCells({
		spd = { tostring(math.round(f.speed)) },
		alt = { fmt(f.pos.Y * FT), if agl < 2500 then "над землёй " .. fmt(math.max(0, agl)) else "ft" },
		vs = { (if vs > 0 then "+" else "") .. fmt(vs) },
		hdg = { string.format("%03d", math.round(hdg) % 360) },
		thr = { if f.reverse then "REV" else tostring(math.round(f.throttle * 100)), nil :: any, if f.reverse then "amber" else "green" },
		flaps = { if c.noFlaps then "—" else tostring(f.flaps), if f.gear then "шасси ▼" else "шасси ▲", "green", if f.gear then "green" else "dim" },
	})
	ui.setThrottleFill(f.throttle)
	local pitchDeg = math.deg(math.asin(clamp(look.Y, -1, 1)))
	local bankDeg = math.deg(math.atan2(-right.Y, up.Y))
	ui.setAdi(pitchDeg, bankDeg)
	ui.setHeading(hdg)
	ui.setWeather(f.pos.Y * FT)

	-- навигация (во время гонки — на следующее кольцо), радар, таймер гонки
	-- разрешение на заход: рейс, до аэропорта назначения меньше 6 км
	if lastDest and not atcApproach and not f.onGround then
		local dst = World.airportById(lastDest)
		if dst and Vector3.new(f.pos.X - dst.cx, 0, f.pos.Z - dst.cz).Magnitude * World.METERS_PER_STUD < 6000 then
			atcApproach = true
			ui.atc(string.format("Вышка %s: %s, заход на полосу %s разрешён. Шасси, закрылки.", dst.code, callsign, runwayFor(dst, f.pos)))
		end
	end
	local ringPos, ringName = race.target()
	if gateTarget then
		local gp = Vector3.new(gateTarget.x, 0, gateTarget.z)
		local d = Vector3.new(f.pos.X, 0, f.pos.Z) - gp
		if f.onGround and f.speed < 3 and d.Magnitude < 45 then
			GateParked:FireServer(gateTarget.id)
			ui.atc(string.format("Земля: %s, стоянка %s, двигатели выключить. До связи!", callsign, gateTarget.id))
			gateTarget = nil
		else
			ringPos, ringName = Vector3.new(gp.X, 0, gp.Z), "стоянка " .. gateTarget.id
		end
	end
	if not ringPos and lastMode == "race" then
		ringPos, ringName = race.firstRing(), "Старт гонки"
	end
	ui.setBanner(if parkBrake then (if UserInputService.GamepadEnabled then "Ⓟ  Стояночный тормоз · L3 (нажми левый стик) или пробел" else "Ⓟ  Стояночный тормоз · пробел или нажми, чтобы отключить") else nil)
	radar.update(f.pos, hdg, model, ringPos or race.firstRing())
	ui.setRace(race.status(now))
	-- глиссада к аэропорту назначения
	do
		-- в рейсе — аэропорт назначения, в свободном полёте — первый аэропорт, на чью глиссаду мы попали
		local dst = lastDest and World.airportById(lastDest)
		local dev, lat, rwy
		if not f.onGround then
			if dst then
				dev, lat, rwy = World.glideslope(dst, f.pos)
			elseif lastMode ~= "race" then
				-- выровнены на ось (< 12°) и ближе всех
				local bestD = math.huge
				for _, ap in World.AIRPORTS do
					local d1, l1, r1 = World.glideslope(ap, f.pos)
					local dist = Vector3.new(f.pos.X - ap.cx, 0, f.pos.Z - ap.cz).Magnitude
					if d1 and l1 and math.abs(l1) < 12 and math.abs(d1) < 2500 and dist < bestD then
						bestD, dst, dev, lat, rwy = dist, ap, d1, l1, r1
					end
				end
			end
		end
		if dev and lat then
			local good = math.abs(dev) < 80 and math.abs(lat) < 1.5
			local v = if math.abs(dev) < 80 then "на глиссаде" elseif dev > 0 then string.format("выше %d ft", math.round(dev)) else string.format("ниже %d ft", math.round(-dev))
			local h = if math.abs(lat) < 1.5 then "по оси" elseif lat > 0 then string.format("правее %.0f°", lat) else string.format("левее %.0f°", -lat)
			ui.setIls(string.format("ILS %s %s · %s · %s%s", dst.code, rwy, v, h, if good then " ✓" else ""), good)
		else
			ui.setIls(nil)
		end
	end
	local n = World.NAV[navIdx]
	if ringPos then
		local brg = Autopilot.bearingDeg(f.pos, ringPos)
		local dist = Vector3.new(f.pos.X - ringPos.X, 0, f.pos.Z - ringPos.Z).Magnitude * World.METERS_PER_STUD / 1000
		if gateTarget then
			ui.setNav(string.format("%s · %.2f км · курс %03d°", string.upper(ringName or ""), dist, math.round(brg) % 360), Autopilot.wrap180(brg - hdg))
		else
			ui.setNav(string.format("КОЛЬЦО · %s · %.1f км · высота %d ft", ringName or "", dist, math.round(ringPos.Y * FT)), Autopilot.wrap180(brg - hdg))
		end
	elseif n then
		local brg = Autopilot.bearingDeg(f.pos, Vector3.new(n.x, 0, n.z))
		local dist = Vector3.new(f.pos.X - n.x, 0, f.pos.Z - n.z).Magnitude * World.METERS_PER_STUD / 1000
		ui.setNav(string.format("%s · %.1f км · курс %03d°", n.name, dist, math.round(brg) % 360), Autopilot.wrap180(brg - hdg))
	else
		ui.setNav(nil)
	end

	-- предупреждения
	local w, col = "", Ui.Colors.red
	local stall = f.dbg.stall or c.stallKts
	local dAgl = f.dbg.agl or 0
	local ahead = f.pos + f.vel * 6
	local terrainAhead = not f.onGround and f.vel.Y < -5 and ahead.Y < World.groundAt(ahead.X, ahead.Z) + 60
	local gMax, gMin = FlightPhysics.limits(c)
	ui.setG(f.gload, gMax, gMin, f.damage)
	if not f.onGround and (f.gload > gMax * 0.9 or f.gload < gMin * 0.9) then
		w = string.format("ПЕРЕГРУЗКА %.1f G · ПРЕДЕЛ %.1f", f.gload, if f.gload > 0 then gMax else gMin)
	elseif not f.onGround and f.speed < stall * 1.05 then
		w = "STALL · СВАЛИВАНИЕ"
	elseif not f.onGround and ((dAgl < 400 and f.vel.Y < -25) or terrainAhead) then
		w = "PULL UP · ТЯНИ ВВЕРХ"
	elseif not f.onGround and not f.gear and dAgl < 250 and f.vel.Y < 0 then
		w, col = "ВЫПУСТИ ШАССИ", Ui.Colors.amber
	elseif f.flaps > 0 and f.speed > c.flapMaxKts then
		w, col = "ЗАКРЫЛКИ: ПРЕВЫШЕНИЕ", Ui.Colors.amber
	elseif f.speed > c.maxKts * 1.02 then
		w, col = "ПРЕВЫШЕНИЕ СКОРОСТИ", Ui.Colors.amber
	end
	ui.setWarn(if w ~= "" and (now % 0.6) < 0.42 then w else "", col)

	if engineSound then
		engineSound.PlaybackSpeed = 0.6 + f.throttle * 0.8
	end

	if ui.debugVisible() then
		local d = f.dbg
		ui.setDebug(string.format(
			"<b>ОТЛАДКА · %s</b>\nпоз   x %d  y %.1f  z %d\nAGL   %s stud  земля: %s\nскор  %.1f kt   ускор %.2f kt/с\nтяга  %.2f  сопр %.2f  ×выс %.2f\nподъём %.2f  эфф %.2f  свал %d kt\nтангаж %.1f°  крен %.1f°\nвход  P %.2f  R %.2f  Y %.2f\nvy    %.2f  vyExtra %.2f\nFPS   %d\n<b>ЖУРНАЛ</b>\n%s",
			c.name, math.round(f.pos.X), f.pos.Y, math.round(f.pos.Z),
			if d.agl == math.huge then "∞" else string.format("%.2f", d.agl), tostring(f.onGround),
			f.speed, d.accel or 0, d.thrust or 0, d.drag or 0, d.thrustMul or 1,
			d.lift or 0, d.eff or 0, math.round(d.stall or 0), pitchDeg, bankDeg,
			f.inP, f.inR, f.inY, f.vel.Y, f.vyExtra, math.round(fps),
			table.concat(logLines, "\n", math.max(1, #logLines - 7))
		))
	end
end

-- ===== кадр: камера, приборы, анимация
RunService:BindToRenderStep("SkyPilot", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local now = os.clock()
	fps += ((1 / math.max(dt, 1e-3)) - fps) * 0.05
	ui.tick(dt)
	ui.atcTick(dt)
	Animator.step(dt, now)
	local f = flight
	if f then
		if f.crashed then
			if crashTimer > 0 then
				crashTimer -= dt
				if crashTimer <= 0 then
					ui.showCrash(f.crashReason or "Крушение")
				end
			end
			cameraRig.update(dt, crashPose or FlightPhysics.pose(f), f.cfg, 0, false, true)
		else
			local pose = if root and simulating then root.CFrame else FlightPhysics.pose(f)
			cameraRig.update(dt, pose, f.cfg, f.speed, f.onGround, false, f.buffet)
			updateHud(f, dt, now)
		end
	elseif ui.hangarVisible() then
		cameraRig.idle(now)
	else
		cameraRig.release()
	end
end)

-- ночной город: в сумерках стеклянные башни, терминалы и вышки светятся тёплым светом окон
task.spawn(function()
	local Lighting = game:GetService("Lighting")
	local worldFolder = workspace:WaitForChild("SkyPilotWorld", 60)
	if not worldFolder then
		return
	end
	task.wait(5) -- даём серверу достроить город
	local glass: { { p: BasePart, color: Color3, mat: Enum.Material } } = {}
	for _, d in worldFolder:GetDescendants() do
		if d:IsA("BasePart") and d.Material == Enum.Material.Glass and d.Size.Y > 20 and d.Transparency < 0.5 then
			table.insert(glass, { p = d, color = d.Color, mat = d.Material })
		end
	end
	local WARM = Color3.fromRGB(255, 205, 130)
	local night: boolean? = nil
	while true do
		local t = Lighting.ClockTime
		local isNight = t < 6.3 or t > 18.7
		if isNight ~= night then
			night = isNight
			for i, g in glass do
				if g.p.Parent then
					if isNight then
						local c = g.color:Lerp(WARM, 0.45)
						g.p.Material = Enum.Material.Neon
						g.p.Color = Color3.new(c.R * 0.42, c.G * 0.4, c.B * 0.34)
					else
						g.p.Material = g.mat
						g.p.Color = g.color
					end
				end
				if i % 300 == 0 then
					task.wait()
				end
			end
		end
		task.wait(5)
	end
end)

-- после крушения: «В ангар» сбрасывает полёт, «Снова» — новый запрос
local baseToHangar = ui.showHangar
ui.showHangar = function(on: boolean?)
	if on == true and flight and flight.crashed then
		stopFlight()
	end
	baseToHangar(on)
end

ui.showHangar(true)
