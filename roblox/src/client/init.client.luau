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
local DailyR = R("DailyTask")
local TrickR = R("Trick")
local FlightLogR = R("FlightLog")
local ChallengeR = R("Challenge")
local Challenge = require(Shared:WaitForChild("Challenge"))
local chalAp: string? = nil
local chalDone = false
local Aerobatics = require(Shared:WaitForChild("Aerobatics"))
local acro = Aerobatics.new()
-- цветной дым из хвоста (Y / кнопка ДЫМ): выкл → белый → красный → синий → зелёный → жёлтый
local SMOKE = {
	{ Color3.fromRGB(245, 245, 245), "белый" }, { Color3.fromRGB(235, 60, 60), "красный" }, { Color3.fromRGB(50, 110, 235), "синий" },
	{ Color3.fromRGB(60, 190, 90), "зелёный" }, { Color3.fromRGB(250, 200, 40), "жёлтый" },
}
local smokeIdx = 0
local function applySmoke(m: Model, cfg: any)
	local root = m.PrimaryPart
	if not root then
		return
	end
	local tr = root:FindFirstChild("SmokeTrail") :: Trail?
	if smokeIdx == 0 then
		if tr then
			tr.Enabled = false
		end
		return
	end
	if not tr then
		local L, D = cfg.length, cfg.diameter
		local a0 = Instance.new("Attachment")
		a0.Name = "SmokeA"
		a0.Position = Vector3.new(0, D * 0.3, L * 0.5 + 1)
		a0.Parent = root
		local a1 = Instance.new("Attachment")
		a1.Name = "SmokeB"
		a1.Position = Vector3.new(0, -D * 0.3, L * 0.5 + 1)
		a1.Parent = root
		local t = Instance.new("Trail")
		t.Name = "SmokeTrail"
		t.Attachment0, t.Attachment1 = a0, a1
		t.Lifetime = 7
		t.MinLength = 0.5
		t.FaceCamera = true
		t.LightInfluence = 1
		t.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.6, 0.55), NumberSequenceKeypoint.new(1, 1) })
		t.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 4) })
		t.Parent = root
		tr = t
	end
	local tt = tr :: Trail
	tt.Color = ColorSequence.new(SMOKE[smokeIdx][1])
	tt.Enabled = true
end
local Daily = require(Shared:WaitForChild("Daily"))
local dailySent: { [string]: boolean } = {}
local function dailyHave(id: string): boolean
	local a = tostring(Players.LocalPlayer:GetAttribute("Daily") or "")
	local key, list = string.match(a, "^(%d+):(.*)$")
	return tonumber(key) == Daily.dateKey() and string.find("," .. (list or "") .. ",", "," .. id .. ",", 1, true) ~= nil
end
local function claimDaily(id: string)
	if dailySent[id] or dailyHave(id) then
		return
	end
	dailySent[id] = true
	DailyR:FireServer(id)
end
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

-- аварийная тренировка (отказ двигателя): состояние текущего полёта, как в веб-версии (tools/web_fail.py)
local engRestart = 0
local ef = { t = 0, at = 0, side = 0, done = false }
local function engCount(c: any): number
	return if c.engines == "wing4" then 4 elseif c.engines == "wing2" or c.engines == "tail2" or c.engines == "turboprop2" then 2 else 1
end
-- состояние фото-режима и паузы (объявлено до onAction: раньше стояло ниже, и фото-режим писал в глобальную переменную — самолёт не замирал)
local photoMode, photoPrevCam = false, 1
local paused = false
local pauseSummary: () -> string
local againFlight: () -> ()
local function onAction(a: string)
	if a == "hangar" then
		ui.showHangar()
		return
	elseif a == "cam" then
		ui.setCamLabel(cameraRig.cycle())
		return
	elseif a == "photo" then
		if flight and not flight.crashed then
			photoMode = not photoMode
			if photoMode then
				photoPrevCam = cameraRig.mode
				cameraRig.mode = 3
			else
				cameraRig.mode = photoPrevCam
			end
			ui.setPhoto(photoMode)
		end
		return
	elseif a == "pause" then
		if flight and not flight.crashed then
			paused = not paused
			ui.setPause(paused, pauseSummary())
		else
			paused = false
			ui.setPause(false)
		end
		return
	elseif a == "again" then
		againFlight()
		return
	elseif a == "settings" then
		ui.openSettings()
		return
	elseif a == "restart" then
		if flight and ((flight :: any).engOut or 0) > 0 and engRestart <= 0 then
			engRestart = 4
			ui.toast("Перезапуск двигателя…", "amber")
		end
		return
	elseif a == "smoke" then
		smokeIdx = (smokeIdx + 1) % (#SMOKE + 1)
		ui.toast(if smokeIdx > 0 then "Дым: " .. SMOKE[smokeIdx][2] .. " · Y — сменить цвет" else "Дым выключен", if smokeIdx > 0 then "green" else nil)
		return
	elseif a == "map" then
		ui.toggleMap()
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

-- объявлена заранее: кнопка «Выйти из самолёта» (onExit) вызывает её раньше определения ниже
local stopFlight: () -> ()
local logFlight: (result: string) -> ()
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

function stopFlight()
	logFlight("ok")
	if paused then
		paused = false
		ui.setPause(false)
	end
	if photoMode then
		photoMode = false
		cameraRig.mode = photoPrevCam
		ui.setPhoto(false)
	end
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

-- статистика полёта для экрана крушения
local Comfort = require(Shared:WaitForChild("Comfort"))
local comfort = 100
local fstats: any = { time = 0, dist = 0, maxAlt = 0, maxKts = 0, maxG = 1, landings = 0, points = 0, plane = "", startPts = 0, lastPos = nil :: Vector3?, bestG = "", bestF = 0, where = "", perfect = 0, logged = false }
local function playerPoints(): number
	local ls = Players.LocalPlayer:FindFirstChild("leaderstats")
	local v = ls and ls:FindFirstChild("Очки")
	return if v and v:IsA("IntValue") then v.Value else 0
end
function pauseSummary(): string
	local name = if flight then flight.cfg.name else ""
	return string.format("%s\nВ воздухе %d:%02d · посадок %d · очки за полёт +%d", name, math.floor(fstats.time / 60), math.floor(fstats.time % 60), fstats.landings, math.max(0, playerPoints() - fstats.startPts))
end
function againFlight()
	if lastPlaneId then
		requestFlight(lastPlaneId, lastMode, lastDest)
	end
end

-- бортовой журнал: итог полёта уходит на сервер один раз (при крушении, выходе или новом полёте)
local GRADE_RANK = { perfect = 3, good = 2, hard = 1 }
function logFlight(result: string)
	if fstats.logged or fstats.plane == "" or (fstats.time < 5 and fstats.landings == 0) then
		return
	end
	fstats.logged = true
	FlightLogR:FireServer({
		p = fstats.plane, r = result, t = math.round(fstats.time), d = math.round(fstats.dist * World.METERS_PER_STUD / 100) / 10,
		a = math.round(fstats.maxAlt), l = fstats.landings, g = fstats.bestG, f = fstats.bestF, pts = math.max(0, playerPoints() - fstats.startPts),
		w = fstats.where, perfect = fstats.perfect,
	})
end

FlightStarted.OnClientEvent:Connect(function(m: Model, planeId: string, mode: string, spawnCF: CFrame)
	logFlight("ok")
	fstats = { time = 0, dist = 0, maxAlt = 0, maxKts = 0, maxG = 1, landings = 0, points = 0, plane = "", startPts = playerPoints(), lastPos = nil, bestG = "", bestF = 0, where = "", perfect = 0, logged = false }
	comfort = 100
	local cfg = PlaneConfigs.PLANES[planeId]
	if not cfg or not m then
		return
	end
	stopFlight()
	model = m
	root = m:WaitForChild("Root", 5) :: BasePart?
	chalAp = Challenge.airportOf(mode)
	chalDone = false
	ef = { t = 0, at = 60 + math.random() * 120, side = 0, done = false }
	engRestart = 0
	local f = FlightPhysics.new(cfg, spawnCF, mode == "air" or chalAp ~= nil)
	if chalAp then
		Challenge.setup(f)
	end
	f.hard = ui.isHard()
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
				local rw = runwayFor(ap, spawnCF.Position + spawnCF.LookVector * -100)
				local wd = tonumber(workspace:GetAttribute("WindDir")) or 0
				local wk = tonumber(workspace:GetAttribute("WindKts")) or 0
				local windTxt = if wk < 2 then "Ветер штиль." else string.format("Ветер %03d°, %d kt, боковой %d kt.", wd, math.round(wk), math.round(FlightPhysics.crosswind(wd, wk, (tonumber(rw) or 36) * 10)))
				ui.atc(string.format("Вышка %s: %s, полоса %s, взлёт разрешён. %s", ap.code, callsign, rw, windTxt))
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
	ui.toast(if lastMode == "race" then "Гонка: впереди голубое кольцо — пролети сквозь него" elseif chalAp then "🎯 Посадочный вызов: садись на полосу впереди — мягко, по оси и у посадочных знаков" elseif mode == "air" then "Вы в воздухе на 3000 ft — аэропорт впереди" else string.format("На полосе: отпусти тормоз (пробел), тяга 100%% (Shift), на Vr %d kt тяни на себя (S)", cfg.vrKts), "magenta")
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
-- брызги из-под колёс на мокрой полосе (дождь): эмиттеры на стойках, сила — от скорости
local function sprayEmitters(m: Model): { ParticleEmitter }
	local out = {}
	local r = m.PrimaryPart
	if not r then
		return out
	end
	for _, a in r:GetChildren() do
		if a:IsA("Attachment") and a.Name:sub(1, 8) == "MainGear" then
			local e = a:FindFirstChild("Spray") :: ParticleEmitter?
			if not e then
				local pe = Instance.new("ParticleEmitter")
				pe.Name = "Spray"
				pe.Rate = 0
				pe.Lifetime = NumberRange.new(0.6, 1.1)
				pe.Speed = NumberRange.new(8, 16)
				pe.SpreadAngle = Vector2.new(25, 25)
				pe.EmissionDirection = Enum.NormalId.Back
				pe.Acceleration = Vector3.new(0, -30, 0)
				pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 4.5) })
				pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
				pe.Color = ColorSequence.new(Color3.fromRGB(220, 228, 236))
				pe.LightEmission = 0.1
				pe.Parent = a
				e = pe
			end
			table.insert(out, e :: ParticleEmitter)
		end
	end
	return out
end

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
			fstats.landings += 1
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
				do
					local g = ev.grade or "hard"
					if (GRADE_RANK[g] or 0) > (GRADE_RANK[fstats.bestG] or 0) then
						fstats.bestG = g
					end
					if fstats.bestF == 0 or fpmV < fstats.bestF then
						fstats.bestF = fpmV
					end
					if ap then
						fstats.where = ap.code
					end
					if g == "perfect" then
						fstats.perfect += 1
					end
				end
				if ap and ((f :: any).engOut or 0) > 0 then
					claimAch("one_engine")
				end
				if chalAp and not chalDone then
					chalDone = true
					if ap and ap.id == chalAp then
						local zone = Challenge.zoneM(ap, f.pos)
						local sc = Challenge.score(fpmV, offM, zone)
						local bestS = tostring(player:GetAttribute("Chal") or ""):match(ap.id .. ":(%d+)")
						local best = tonumber(bestS) or 0
						task.delay(0.9, function()
							ui.toast(string.format("🎯 Посадочный вызов %s: %d/100 · касание %d м от знаков", ap.code, sc, math.round(zone)) .. (if sc > best then " · новый рекорд!" else string.format(" · рекорд %d", best)), if sc > best then "green" else nil)
						end)
						ChallengeR:FireServer(ap.id, sc)
					else
						task.delay(0.9, function()
							ui.toast("🎯 Вызов не засчитан: посадка не на ту полосу", "amber")
						end)
					end
				end
				ui.landingReport({
					grade = ev.grade or "hard", fpm = fpmV, kts = f.speed, g = f.gload, offM = offM,
					pts = if ap then (if fpmV < 120 then 400 elseif fpmV < 250 then 300 elseif fpmV < 600 then 150 else 50) else 0,
					where = if ap then ap.code .. " · полоса" else "вне аэропорта", damaged = f.damage > 0.3,
					pax = if Comfort.passengers(f.cfg) > 0 then Comfort.starsText(comfort) else nil,
					paxBonus = if lastDest and ev.airport == lastDest and Comfort.passengers(f.cfg) > 0 then math.floor(comfort * 5) else 0,
				})
			end
			comfort = Comfort.touchdown(comfort, ev.fpm or 0)
			if ev.airport then
				for _, t in Daily.tasks(Daily.dateKey()) do
					if (t.kind == "land" and t.target == ev.airport) or (t.kind == "soft" and t.target == f.cfg.id and (ev.fpm or 999) < 200) then
						claimDaily(t.id)
					end
				end
			end
			Landing:FireServer(ev.fpm, comfort)
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
			logFlight("crash")
			if paused then
				paused = false
				ui.setPause(false)
			end
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
	Animator.setInputs(f.inP, f.inR, f.inY)
	if model then
		local rainNow = tonumber(workspace:GetAttribute("Rain")) or 0
		local rate = if f.onGround and rainNow > 0.2 and f.speed > 35 then math.min(70, f.speed * 0.4) * rainNow else 0
		for _, e in sprayEmitters(model) do
			e.Rate = rate
		end
	end
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
	-- фото-режим: самолёт замер в воздухе (держим позу, скорость обнулена)
	if photoMode or paused then
		root.CFrame = FlightPhysics.pose(f)
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		return
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
	-- ветер с сервера + порывы (каждый клиент считает порывы сам)
	do
		local wd = tonumber(workspace:GetAttribute("WindDir")) or 0
		local wk = tonumber(workspace:GetAttribute("WindKts")) or 0
		local t = os.clock()
		local gust = 1 + 0.25 * math.sin(t * 0.9) * math.sin(t * 0.37 + 1)
		f.wind = FlightPhysics.windVector(wd, wk * gust)
	end
	-- чувствительность из настроек
	local sens = ui.sens()
	if sens ~= 1 then
		input.p = math.clamp(input.p * sens, -1, 1)
		input.r = math.clamp(input.r * sens, -1, 1)
		input.y = math.clamp(input.y * sens, -1, 1)
	end
	do -- отказ двигателя: тяга падает, самолёт уводит в сторону отказавшего, дым, перезапуск (J)
		local fa = f :: any
		local n = engCount(f.cfg)
		if ui.failTraining() and n >= 2 and not f.crashed then
			if (fa.engOut or 0) == 0 and not ef.done then
				if not f.onGround and (f.dbg.agl or 0) * FT > 1500 then
					ef.t += dt
				end
				if ef.t >= ef.at then
					fa.engOut = 1 / n
					ef.side = if math.random() < 0.5 then -1 else 1
					ui.toast(string.format("🔥 ОТКАЗ ДВИГАТЕЛЯ %d · J — перезапуск", if ef.side < 0 then 1 else n), "red")
					local best, bd = nil, math.huge
					for _, ap in World.AIRPORTS do
						local d = (Vector2.new(ap.cx, ap.cz) - Vector2.new(f.pos.X, f.pos.Z)).Magnitude
						if d < bd then
							best, bd = ap, d
						end
					end
					if best then
						ui.atc(string.format("Mayday принят. Ближайший аэропорт %s, полоса свободна, заход по готовности.", best.code))
					end
					-- дым из отказавшего двигателя
					local eng = model and model:FindFirstChild("Engines")
					local pick: BasePart? = nil
					if eng and model and model.PrimaryPart then
						for _, p in eng:GetChildren() do
							if p:IsA("BasePart") and p.Name == "Nacelle" then
								local lx = model.PrimaryPart.CFrame:PointToObjectSpace(p.Position).X
								if math.sign(lx) == ef.side and (not pick or math.abs(lx) < math.abs(model.PrimaryPart.CFrame:PointToObjectSpace((pick :: BasePart).Position).X)) then
									pick = p
								end
							end
						end
					end
					if pick then
						local pe = Instance.new("ParticleEmitter")
						pe.Name = "FailSmoke"
						pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
						pe.Color = ColorSequence.new(Color3.fromRGB(70, 72, 78))
						pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
						pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, f.cfg.diameter * 0.25), NumberSequenceKeypoint.new(1, f.cfg.diameter * 1.4) })
						pe.Lifetime = NumberRange.new(2.5, 3.5)
						pe.Rate = 18
						pe.Speed = NumberRange.new(1, 3)
						pe.EmissionDirection = Enum.NormalId.Back
						pe.Parent = pick
					end
				end
			end
			if (fa.engOut or 0) > 0 then
				input.y = math.clamp(input.y + ef.side * 0.22 * f.throttle, -1, 1)
				if engRestart > 0 then
					engRestart -= dt
					if engRestart <= 0 then
						if math.random() < 0.7 then
							fa.engOut = 0
							ef.done = true
							ui.toast("✅ Двигатель перезапущен", "green")
							if model then
								for _, d in model:GetDescendants() do
									if d.Name == "FailSmoke" then
										d:Destroy()
									end
								end
							end
						else
							ui.toast("Перезапуск не удался — попробуй ещё (J)", "amber")
						end
					end
				end
			end
		end
	end
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
	fstats.plane = c.name
	if not f.onGround then
		fstats.time += dt
	end
	if fstats.lastPos then
		local d = f.pos - (fstats.lastPos :: Vector3)
		fstats.dist += Vector3.new(d.X, 0, d.Z).Magnitude
	end
	fstats.lastPos = f.pos
	fstats.maxAlt = math.max(fstats.maxAlt, f.pos.Y * FT)
	fstats.maxKts = math.max(fstats.maxKts, f.speed)
	fstats.maxG = math.max(fstats.maxG, f.gload)
	if f.pos.Y * FT > 35000 then
		claimAch("high")
	end
	if c.id == "F16" and f.gload >= 8 and f.damage < 0.05 then
		claimAch("ace")
	end
	if model then
		local rainNow = tonumber(workspace:GetAttribute("Rain")) or 0
		local vapor = not f.onGround and f.speed > 120 and (f.gload > 1.7 or (rainNow > 0.25 and f.flaps >= 2))
		if model:GetAttribute("Vapor") ~= vapor then
			model:SetAttribute("Vapor", vapor)
		end
	end
	-- авиашоу: дым и фигуры пилотажа (очки начисляет сервер)
	if model then
		if model:GetAttribute("SmokeIdx") ~= smokeIdx then
			model:SetAttribute("SmokeIdx", smokeIdx)
			applySmoke(model, c)
		end
	end
	if not f.crashed then
		local trick = Aerobatics.step(acro, f.att, dt, not f.onGround and (f.dbg.agl or 0) * FT > 300)
		if trick then
			TrickR:FireServer(trick)
		end
	end
	if not f.onGround and f.pos.Y * FT < 3000 then
		for _, t in Daily.tasks(Daily.dateKey()) do
			if t.kind == "over" and t.x and t.z and t.r and (Vector2.new(f.pos.X, f.pos.Z) - Vector2.new(t.x, t.z)).Magnitude < t.r then
				claimDaily(t.id)
			end
		end
	end
	local att = f.att
	local look, right, up = att.LookVector, att.RightVector, att.UpVector
	local agl = (f.dbg.agl or 0) * FT
	vsSmooth += (f.vel.Y * 60 * FT - vsSmooth) * math.min(1, dt * 6)
	local vs = math.round(vsSmooth / 10) * 10
	-- комфорт пассажиров
	local pax = Comfort.passengers(c)
	if not f.onGround then
		comfort = Comfort.step(comfort, dt, math.deg(math.asin(math.clamp(-right.Y, -1, 1))), f.gload, vsSmooth, f.buffet or 0)
	end
	ui.setPax(pax, comfort)
	local hdg = World.headingDeg(look)
	local metric = ui.metric()
	local altU = if metric then 0.3048 else 1
	local vsShow = if metric then math.round(vsSmooth * 0.00508 * 10) / 10 else vs
	ui.setCells({
		spd = { tostring(math.round(f.speed * (if metric then 1.852 else 1))), if metric then "км/ч" else "kt" },
		alt = { fmt(f.pos.Y * FT * altU), if agl < 2500 then "над землёй " .. fmt(math.max(0, agl) * altU) else (if metric then "м" else "ft") },
		vs = { (if vsShow > 0 then "+" else "") .. (if metric then string.format("%.1f", vsShow) else fmt(vsShow)), if metric then "м/с" else "ft/min" },
		hdg = { string.format("%03d", math.round(hdg) % 360) },
		thr = { if f.reverse then "REV" else tostring(math.round(f.throttle * 100)), nil :: any, if f.reverse then "amber" else "green" },
		flaps = { if c.noFlaps then "—" else tostring(f.flaps), if f.gear then "шасси ▼" else "шасси ▲", "green", if f.gear then "green" else "dim" },
	})
	ui.setThrottleFill(f.throttle)
	local pitchDeg = math.deg(math.asin(clamp(look.Y, -1, 1)))
	local bankDeg = math.deg(math.atan2(-right.Y, up.Y))
	ui.setAdi(pitchDeg, bankDeg)
	ui.setTapes({
		kt = f.speed, accel = f.dbg.accel or 0, stall = f.dbg.stall or c.stallKts, maxKts = c.maxKts,
		flapLim = if f.flaps > 0 and not c.noFlaps then c.flapMaxKts else nil, vr = if f.onGround then c.vrKts else nil,
		onGround = f.onGround, altFt = f.pos.Y * FT, groundFt = if (f.dbg.agl or math.huge) < 1e6 then (f.pos.Y - f.dbg.agl) * FT else nil,
		vs = vsSmooth, aglFt = agl, metric = metric,
	})
	ui.setHeading(hdg)
	do -- полоса маршрута (только рейс: аэропорт вылета → назначения)
		local fromId = lastMode and lastMode:match("^runway:(%u)$")
		local from, to = fromId and World.airportById(fromId), lastDest and World.airportById(lastDest)
		if from and to and not f.crashed then
			local total = (Vector2.new(to.cx, to.cz) - Vector2.new(from.cx, from.cz)).Magnitude
			local rem = (Vector2.new(to.cx, to.cz) - Vector2.new(f.pos.X, f.pos.Z)).Magnitude
			ui.setRoute({
				from = from.code, to = to.code, frac = math.clamp(1 - rem / math.max(1, total), 0, 1), km = rem * World.METERS_PER_STUD / 1000,
				eta = if f.speed > 20 then rem / f.speed else nil,
				tod = if not f.onGround and f.pos.Y * FT > 2000 and rem < 4500 and rem > 1500 then "↘ пора снижаться" elseif rem < 1500 then "заход на посадку" else nil,
			})
		else
			ui.setRoute(nil)
		end
	end
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
	if f.hard then
		ui.setG(f.gload, gMax, gMin, f.damage)
	else
		ui.hideG()
	end
	if f.hard and not f.onGround and (f.gload > gMax * 0.9 or f.gload < gMin * 0.9) then
		w = string.format("ПЕРЕГРУЗКА %.1f G · ПРЕДЕЛ %.1f", f.gload, if f.gload > 0 then gMax else gMin)
	elseif not f.onGround and f.speed < stall * 1.05 then
		w = "STALL · СВАЛИВАНИЕ"
	elseif not f.onGround and ((dAgl < 400 and f.vel.Y < -25) or terrainAhead) then
		w = "PULL UP · ТЯНИ ВВЕРХ"
	elseif not f.onGround and not f.gear and dAgl < 250 and f.vel.Y < 0 then
		w, col = "ВЫПУСТИ ШАССИ", Ui.Colors.amber
	elseif ((f :: any).engOut or 0) > 0 then
		w, col = "ОТКАЗ ДВИГАТЕЛЯ · J — ПЕРЕЗАПУСК", Ui.Colors.amber
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

-- ===== дождь: струи вокруг камеры (сила — атрибут сервера Rain)
local rainEmitter: ParticleEmitter? = nil
do
	local box = Instance.new("Part")
	box.Name = "SkyPilotRain"
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
	box.Transparency = 1
	box.Size = Vector3.new(160, 1, 160)
	box.Parent = workspace.CurrentCamera
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(Color3.fromRGB(200, 214, 230))
	pe.LightEmission = 0.2
	pe.Transparency = NumberSequence.new(0.35)
	pe.Size = NumberSequence.new(0.18)
	pe.Squash = NumberSequence.new(-2.5)
	pe.Orientation = Enum.ParticleOrientation.VelocityParallel
	pe.EmissionDirection = Enum.NormalId.Bottom
	pe.Speed = NumberRange.new(140, 170)
	pe.Lifetime = NumberRange.new(0.7, 0.9)
	pe.Rate = 0
	pe.Parent = box
	rainEmitter = pe
	RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		box.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, 60, 0))
		local r = tonumber(workspace:GetAttribute("Rain")) or 0
		pe.Rate = if r > 0.05 then r * 900 else 0
	end)
end

-- ===== обзорные радары аэропортов: антенна вращается (~10 об/мин)
do
	local dishes: { { p: BasePart, pivot: CFrame, off: CFrame } } = {}
	task.spawn(function()
		task.wait(5)
		for _, d in workspace:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "RadarDish" then
				local pv, off = d:GetAttribute("RadarPivot"), d:GetAttribute("RadarOff")
				if typeof(pv) == "CFrame" and typeof(off) == "CFrame" then
					table.insert(dishes, { p = d, pivot = pv, off = off })
				end
			end
		end
	end)
	local ang = 0
	RunService.RenderStepped:Connect(function(dt)
		ang = (ang + dt * 1.05) % (math.pi * 2)
		local rot = CFrame.Angles(0, ang, 0)
		for _, e in dishes do
			e.p.CFrame = e.pivot * rot * e.off
		end
	end)
end

-- ===== радуга после дождя (как в веб-версии, tools/web_rainbow.py): если днём шёл дождь (> 0.4) и стих (< 0.15),
-- на ~2 минуты напротив солнца — дуга радиусом 42° из семи цветных полос (только у себя на экране)
do
	local Lighting = game:GetService("Lighting")
	local COLORS = { Color3.fromRGB(255, 60, 60), Color3.fromRGB(255, 150, 40), Color3.fromRGB(255, 230, 60), Color3.fromRGB(80, 220, 90), Color3.fromRGB(60, 150, 255), Color3.fromRGB(70, 80, 220), Color3.fromRGB(150, 70, 210) }
	local D = 1500
	local R = D * math.tan(math.rad(42))
	local band = D * math.tan(math.rad(2.4)) / #COLORS
	local SEG = 26
	local model = Instance.new("Model")
	model.Name = "SkyPilotRainbow"
	local segs: { { p: BasePart, off: CFrame } } = {}
	for ci, col in COLORS do
		local r = R - (ci - 1) * band
		for i = 0, SEG - 1 do
			local a0 = math.rad(-12) + (i + 0.5) * math.rad(204) / SEG
			local len = 2 * r * math.sin(math.rad(204) / SEG / 2) + 2
			local p = Instance.new("Part")
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
			p.Material = Enum.Material.Neon
			p.Color = col
			p.Size = Vector3.new(band, len, 1)
			p.Transparency = 1
			p.Parent = model
			table.insert(segs, { p = p, off = CFrame.new(math.cos(a0) * r, math.sin(a0) * r, 0) * CFrame.Angles(0, 0, a0) })
		end
	end
	local armed, t, acc, alpha = false, 0, 0, -1
	RunService.RenderStepped:Connect(function(dt)
		local rain = tonumber(workspace:GetAttribute("Rain")) or 0
		local sun = Lighting:GetSunDirection()
		if rain > 0.4 then
			armed = true
		end
		if armed and rain < 0.15 and sun.Y > 0.05 then
			armed = false
			t = 120
		end
		if t > 0 then
			t -= dt
		end
		local a = math.clamp(math.min(t / 15, (120 - t) / 10), 0, 1) * math.clamp(sun.Y * 4, 0, 1) * (1 - (tonumber(workspace:GetAttribute("Mist")) or 0))
		if a <= 0.01 then
			if model.Parent then
				model.Parent = nil
				alpha = -1
			end
			return
		end
		if not model.Parent then
			model.Parent = workspace.CurrentCamera
		end
		acc += dt
		if acc < 0.2 and math.abs(a - alpha) < 0.03 then
			return
		end
		acc = 0
		local cam = workspace.CurrentCamera.CFrame.Position
		local frame = CFrame.lookAt(cam - sun * D, cam)
		local tr = 1 - 0.32 * a
		for _, e in segs do
			e.p.CFrame = frame * e.off
			if math.abs(a - alpha) >= 0.03 then
				e.p.Transparency = tr
			end
		end
		if math.abs(a - alpha) >= 0.03 then
			alpha = a
		end
	end)
end

-- ===== гроза: в ливень (Rain > 0.6) раз в 6–20 с молния в 1–5 км от камеры — ломаный разряд с ветками,
-- вспышка неба (ColorCorrection) и гром с задержкой по расстоянию; как в веб-версии (tools/web_storm.py). Только у себя на экране.
do
	local Lighting = game:GetService("Lighting")
	local flashCC = Instance.new("ColorCorrectionEffect")
	flashCC.Name = "SkyPilotStormFlash"
	flashCC.Parent = Lighting
	local rng = Random.new()
	local nextAt, flash, boltT = 5, 0, 0
	local bolt: Folder? = nil
	local boltParts: { BasePart } = {}
	local function path(a: Vector3, b: Vector3, n: number, jag: number): { Vector3 }
		local pts = { a }
		for i = 1, n - 1 do
			local p = a:Lerp(b, i / n)
			table.insert(pts, p + Vector3.new(rng:NextNumber(-jag, jag), rng:NextNumber(-jag, jag) * 0.3, rng:NextNumber(-jag, jag)))
		end
		table.insert(pts, b)
		return pts
	end
	local function strike()
		local cam = workspace.CurrentCamera
		local base = cam.CFrame.Position
		local ang, dist = rng:NextNumber(0, math.pi * 2), rng:NextNumber(900, 5000)
		local gx, gz = base.X + math.cos(ang) * dist, base.Z + math.sin(ang) * dist
		local hit = workspace:Raycast(Vector3.new(gx, 6000, gz), Vector3.new(0, -7000, 0))
		local gy = if hit then hit.Position.Y else 0
		local top = Vector3.new(gx + rng:NextNumber(-300, 300), math.max(2400, gy + 2000), gz + rng:NextNumber(-300, 300))
		if bolt then
			bolt:Destroy()
		end
		local folder = Instance.new("Folder")
		folder.Name = "SkyPilotBolt"
		boltParts = {}
		local w = dist / 900 * 1.6
		local function seg(pts: { Vector3 }, r: number)
			for i = 1, #pts - 1 do
				local a, b = pts[i], pts[i + 1]
				local p = Instance.new("Part")
				p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
				p.Material = Enum.Material.Neon
				p.Color = Color3.fromRGB(235, 242, 255)
				p.Size = Vector3.new(r * 2, r * 2, (b - a).Magnitude)
				p.CFrame = CFrame.lookAt((a + b) / 2, b)
				p.Parent = folder
				table.insert(boltParts, p)
			end
		end
		local main = path(top, Vector3.new(gx, gy, gz), 16, 160)
		seg(main, w)
		for _ = 1, 3 do
			local s = main[rng:NextInteger(3, 10)]
			seg(path(s, s + Vector3.new(rng:NextNumber(-500, 500), -rng:NextNumber(300, 700), rng:NextNumber(-500, 500)), 6, 90), w * 0.55)
		end
		folder.Parent = workspace
		bolt, boltT, flash = folder, 0.4, 1
		local id = (PlaneConfigs :: any).THUNDER_SOUND_ID
		if type(id) == "string" and id ~= "" then
			task.delay(math.min(8, dist * 0.515 / 343), function()
				local snd = Instance.new("Sound")
				snd.SoundId = id
				snd.Volume = math.clamp(1.6 - dist / 4000, 0.25, 1.2)
				snd.Parent = workspace.CurrentCamera
				snd:Play()
				snd.Ended:Connect(function()
					snd:Destroy()
				end)
			end)
		end
	end
	RunService.RenderStepped:Connect(function(dt)
		local r = tonumber(workspace:GetAttribute("Rain")) or 0
		if r > 0.6 then
			nextAt -= dt
			if nextAt <= 0 then
				nextAt = rng:NextNumber(6, 20)
				strike()
			end
		else
			nextAt = math.max(nextAt, 3)
		end
		if flash > 0 then
			flash = math.max(0, flash - dt * 2.6)
			local k = flash * (if flash > 0.55 and rng:NextNumber() < 0.35 then 0.3 else 1)
			flashCC.Brightness = 0.35 * k
			flashCC.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(215, 228, 255), k)
		elseif flashCC.Brightness ~= 0 then
			flashCC.Brightness = 0
			flashCC.TintColor = Color3.new(1, 1, 1)
		end
		if bolt then
			boltT -= dt
			if boltT <= 0 then
				bolt:Destroy()
				bolt = nil
			else
				local tr = 1 - math.clamp(boltT / 0.25, 0, 1) * (if rng:NextNumber() < 0.2 then 0.4 else 1)
				for _, p in boltParts do
					p.Transparency = tr
				end
			end
		end
	end)
end

-- ===== кадр: камера, приборы, анимация
RunService:BindToRenderStep("SkyPilot", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local now = os.clock()
	fps += ((1 / math.max(dt, 1e-3)) - fps) * 0.05
	ui.tick(dt)
	ui.updateMap(if flight then flight.pos else nil, if flight then World.headingDeg(flight.att.LookVector) else nil)
	ui.atcTick(dt)
	Animator.step(dt, now)
	local f = flight
	if f then
		if f.crashed then
			if crashTimer > 0 then
				crashTimer -= dt
				if crashTimer <= 0 then
					fstats.points = math.max(0, playerPoints() - fstats.startPts)
					ui.showCrash(f.crashReason or "Крушение", fstats)
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
	local lamps: { BasePart } = {}
	local rabbits: { BasePart } = {}
	local runways: { { p: BasePart, color: Color3, mat: Enum.Material } } = {}
	for _, d in worldFolder:GetDescendants() do
		if d:IsA("BasePart") and d.Material == Enum.Material.Glass and d.Size.Y > 20 and d.Transparency < 0.5 then
			table.insert(glass, { p = d, color = d.Color, mat = d.Material })
		elseif d:IsA("BasePart") and d.Name == "ApronLamp" then
			table.insert(lamps, d)
		elseif d:IsA("BasePart") and d.Name == "Rabbit" then
			table.insert(rabbits, d)
		elseif d:IsA("BasePart") and d.Name == "RunwaySurface" then
			table.insert(runways, { p = d, color = d.Color, mat = d.Material })
		end
	end
	-- ветроуказатели аэропортов: конус по ветру, при слабом ветре повисает
	local socks: { BasePart } = {}
	for _, d in worldFolder:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "WindsockCone" then
			table.insert(socks, d)
		end
	end
	if #socks > 0 then
		task.spawn(function()
			while true do
				local wd = math.rad(tonumber(workspace:GetAttribute("WindDir")) or 0)
				local wk = tonumber(workspace:GetAttribute("WindKts")) or 0
				local droop = math.clamp(1 - wk / 15, 0, 0.85)
				local v = Vector3.new(-math.sin(wd), 0, math.cos(wd)) * (1 - droop) + Vector3.new(0, -droop, 0)
				v = if v.Magnitude > 0.01 then v.Unit else Vector3.new(0, -1, 0)
				for _, c in socks do
					local pole = c:GetAttribute("PoleCF")
					if typeof(pole) == "CFrame" then
						local p0 = pole.Position
						c.CFrame = CFrame.lookAt(p0 + v * 7, p0 + v * 14)
						for _, b in c:GetChildren() do
							if b:IsA("BasePart") then
								b.CFrame = c.CFrame * CFrame.new(0, 0, b:GetAttribute("Offset") :: number)
							end
						end
					end
				end
				task.wait(1)
			end
		end)
	end
	-- мокрые полосы в дождь: тёмный глянцевый асфальт с отражением
	task.spawn(function()
		local wet: boolean? = nil
		while true do
			local isWet = (tonumber(workspace:GetAttribute("Rain")) or 0) > 0.25
			if isWet ~= wet then
				wet = isWet
				for _, r in runways do
					r.p.Material = if isWet then Enum.Material.SmoothPlastic else r.mat
					r.p.Reflectance = if isWet then 0.22 else 0
					r.p.Color = if isWet then r.color:Lerp(Color3.new(0, 0, 0), 0.35) else r.color
				end
			end
			task.wait(3)
		end
	end)
	-- бегущие вспышки огней подхода: дважды в секунду от дальнего огня к полосе
	if #rabbits > 0 then
		task.spawn(function()
			local last = -1
			while true do
				local active = math.floor((os.clock() * 2 % 1) * 10)
				if active ~= last then
					last = active
					for _, r in rabbits do
						r.Transparency = if r:GetAttribute("Seq") == active then 0 else 1
					end
				end
				task.wait(0.03)
			end
		end)
	end
	local WARM = Color3.fromRGB(255, 205, 130)
	local night: boolean? = nil
	while true do
		local t = Lighting.ClockTime
		local isNight = t < 6.3 or t > 18.7
		if isNight ~= night then
			night = isNight
			-- мачты освещения перрона
			for _, l in lamps do
				l.Material = if isNight then Enum.Material.Neon else Enum.Material.SmoothPlastic
				local sl = l:FindFirstChildOfClass("SpotLight")
				if sl then
					sl.Enabled = isNight
				end
			end
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

-- ===== 3D-кабина для вида «кабина» (как в веб-версии, tools/web_cockpit.py): козырёк, приборная панель
-- с четырьмя экранами (авиагоризонт, навигация, двигатели, сводка), рама окон, пульт с рычагами тяги
do
	local cam = workspace.CurrentCamera
	local folder = Instance.new("Model")
	folder.Name = "SkyPilotCockpit"
	local parts: { { p: BasePart, off: CFrame } } = {}
	local function cpart(size: Vector3, off: CFrame, color: Color3, mat: Enum.Material?): BasePart
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Size = size
		p.Color = color
		p.Material = mat or Enum.Material.SmoothPlastic
		p.Parent = folder
		table.insert(parts, { p = p, off = off })
		return p
	end
	local PANEL, FRAME, TRIM = Color3.fromRGB(38, 43, 51), Color3.fromRGB(52, 58, 68), Color3.fromRGB(74, 81, 92)
	local tilt = CFrame.Angles(-0.28, 0, 0)
	local panelCF = CFrame.new(0, -0.655, -1.25) * tilt
	cpart(Vector3.new(3.2, 0.5, 0.06), panelCF, PANEL)
	cpart(Vector3.new(3.2, 0.05, 0.22), CFrame.new(0, -0.37, -1.1) * CFrame.Angles(0.08, 0, 0), FRAME)
	cpart(Vector3.new(0.1, 1.8, 0.1), CFrame.new(-1.38, 0.2, -1.15) * CFrame.Angles(0, 0, 0.22), FRAME)
	cpart(Vector3.new(0.1, 1.8, 0.1), CFrame.new(1.38, 0.2, -1.15) * CFrame.Angles(0, 0, -0.22), FRAME)
	cpart(Vector3.new(3.4, 0.14, 0.1), CFrame.new(0, 0.74, -1.12), FRAME)
	cpart(Vector3.new(0.5, 0.22, 0.5), CFrame.new(0, -0.86, -0.95), PANEL)
	local levers: { { p: BasePart, x: number } } = {}
	for _, x in { -0.08, 0.08 } do
		local l = cpart(Vector3.new(0.05, 0.2, 0.05), CFrame.new(x, -0.66, -0.95), TRIM)
		table.insert(levers, { p = l, x = x })
	end
	-- экраны: часть с SurfaceGui на передней грани
	local function screen(x: number): Frame
		cpart(Vector3.new(0.38, 0.38, 0.02), panelCF * CFrame.new(x, -0.02, 0.04), TRIM)
		local s = cpart(Vector3.new(0.33, 0.33, 0.01), panelCF * CFrame.new(x, -0.02, 0.05), Color3.new(0, 0, 0))
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Back -- задняя грань детали смотрит на пилота (+Z камеры)
		sg.CanvasSize = Vector2.new(256, 256)
		sg.LightInfluence = 0
		sg.Parent = s
		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = Color3.fromRGB(5, 8, 15)
		bg.BorderSizePixel = 0
		bg.Parent = sg
		return bg
	end
	local function label(parent: Instance, pos: UDim2, size: UDim2, text: string, color: Color3, ts: number, font: Enum.Font?): TextLabel
		local t = Instance.new("TextLabel")
		t.Position, t.Size = pos, size
		t.BackgroundTransparency = 1
		t.Font = font or Enum.Font.RobotoMono
		t.TextSize = ts
		t.TextColor3 = color
		t.Text = text
		t.Parent = parent
		return t
	end
	-- 1) авиагоризонт
	local pfd = screen(-0.92)
	local cg = Instance.new("CanvasGroup")
	cg.Size = UDim2.fromScale(1, 1)
	cg.BackgroundTransparency = 1
	cg.Parent = pfd
	local hz = Instance.new("Frame")
	hz.Size = UDim2.fromOffset(700, 700)
	hz.AnchorPoint = Vector2.new(0.5, 0.5)
	hz.Position = UDim2.fromScale(0.5, 0.5)
	hz.BackgroundTransparency = 1
	hz.Parent = cg
	for i, col in { Color3.fromRGB(47, 111, 191), Color3.fromRGB(122, 82, 50) } do
		local h = Instance.new("Frame")
		h.Size = UDim2.new(1, 0, 0.5, 0)
		h.Position = UDim2.fromScale(0, (i - 1) * 0.5)
		h.BackgroundColor3 = col
		h.BorderSizePixel = 0
		h.Parent = hz
	end
	local line = Instance.new("Frame")
	line.Size = UDim2.new(1, 0, 0, 3)
	line.Position = UDim2.new(0, 0, 0.5, -1)
	line.BackgroundColor3 = Color3.new(1, 1, 1)
	line.BorderSizePixel = 0
	line.Parent = hz
	for _, x in { -46, 46 } do
		local w = Instance.new("Frame")
		w.Size = UDim2.fromOffset(56, 6)
		w.AnchorPoint = Vector2.new(0.5, 0.5)
		w.Position = UDim2.new(0.5, x, 0.5, 0)
		w.BackgroundColor3 = Color3.fromRGB(255, 191, 60)
		w.BorderSizePixel = 0
		w.ZIndex = 3
		w.Parent = pfd
	end
	-- 2) навигация: курс и ветер
	local nd = screen(-0.5)
	local ndHdg = label(nd, UDim2.fromOffset(0, 40), UDim2.new(1, 0, 0, 70), "000°", Color3.fromRGB(224, 91, 216), 60)
	label(nd, UDim2.fromOffset(0, 112), UDim2.new(1, 0, 0, 20), "КУРС", Color3.fromRGB(143, 160, 184), 16, Enum.Font.GothamBold)
	local ndWind = label(nd, UDim2.fromOffset(0, 170), UDim2.new(1, 0, 0, 30), "", Color3.fromRGB(61, 214, 245), 22)
	-- 3) двигатели
	local eng = screen(0.5)
	local n1 = label(eng, UDim2.fromOffset(0, 30), UDim2.new(1, 0, 0, 60), "", Color3.fromRGB(61, 220, 132), 44)
	label(eng, UDim2.fromOffset(0, 92), UDim2.new(1, 0, 0, 20), "N1 %", Color3.fromRGB(143, 160, 184), 16, Enum.Font.GothamBold)
	local engGear = label(eng, UDim2.fromOffset(0, 150), UDim2.new(1, 0, 0, 30), "", Color3.fromRGB(61, 220, 132), 22)
	local engFlaps = label(eng, UDim2.fromOffset(0, 190), UDim2.new(1, 0, 0, 30), "", Color3.fromRGB(61, 214, 245), 22)
	-- 4) сводка
	local info = screen(0.92)
	local infoRows: { TextLabel } = {}
	for i, k in { "СКОР", "ВЫС", "ВЕРТ" } do
		label(info, UDim2.fromOffset(10, 20 + (i - 1) * 75), UDim2.fromOffset(70, 40), k, Color3.fromRGB(143, 160, 184), 16, Enum.Font.GothamBold)
		infoRows[i] = label(info, UDim2.fromOffset(80, 20 + (i - 1) * 75), UDim2.fromOffset(170, 40), "", Color3.new(1, 1, 1), 34)
	end
	folder.Parent = cam
	local shown = true
	local function setShown(on: boolean)
		if shown ~= on then
			shown = on
			folder.Parent = if on then workspace.CurrentCamera else nil
		end
	end
	setShown(false)
	RunService:BindToRenderStep("SkyPilotCockpit", Enum.RenderPriority.Camera.Value + 3, function()
		local f = flight
		local on = f ~= nil and not f.crashed and not photoMode and cameraRig ~= nil and cameraRig.mode == 2
		setShown(on)
		if not on or not f then
			return
		end
		local ccf = workspace.CurrentCamera.CFrame
		for _, e in parts do
			e.p.CFrame = ccf * e.off
		end
		for _, l in levers do
			l.p.CFrame = ccf * CFrame.new(l.x, -0.75, -0.95) * CFrame.Angles(-0.6 + f.throttle * 1.1, 0, 0) * CFrame.new(0, 0.1, 0)
		end
		local look, right, up = f.att.LookVector, f.att.RightVector, f.att.UpVector
		local pitch = math.deg(math.asin(math.clamp(look.Y, -1, 1)))
		local bank = math.deg(math.atan2(-right.Y, up.Y))
		local th = math.rad(-bank)
		local t = math.clamp(pitch, -40, 40) * 3.2
		hz.Rotation = -bank
		hz.Position = UDim2.new(0.5, -math.sin(th) * t, 0.5, math.cos(th) * t)
		ndHdg.Text = string.format("%03d°", math.round(World.headingDeg(look)) % 360)
		ndWind.Text = string.format("ВЕТЕР %03d° / %d kt", math.round(tonumber(workspace:GetAttribute("WindDir")) or 0), math.round(tonumber(workspace:GetAttribute("WindKts")) or 0))
		local n1v = math.round(22 + f.throttle * 76)
		local dead = ((f :: any).engOut or 0) > 0
		n1.Text = if f.reverse then "REV" elseif dead then (if ef.side < 0 then string.format("0  %d", n1v) else string.format("%d  0", n1v)) else string.format("%d  %d", n1v, n1v)
		n1.TextColor3 = if dead then Color3.fromRGB(229, 72, 77) else Color3.fromRGB(61, 220, 132)
		engGear.Text = if f.gear then "ШАССИ ▼ ▼ ▼" else "ШАССИ УБРАНО"
		engFlaps.Text = "ЗАКРЫЛКИ " .. (if f.cfg.noFlaps then "—" else tostring(f.flaps))
		local metric = ui.metric()
		infoRows[1].Text = tostring(math.round(f.speed * (if metric then 1.852 else 1))) .. (if metric then " км/ч" else " kt")
		infoRows[2].Text = fmt(f.pos.Y * FT * (if metric then 0.3048 else 1)) .. (if metric then " м" else " ft")
		infoRows[3].Text = tostring(math.round(vsSmooth / 10) * 10)
	end)
end
