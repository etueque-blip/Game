--!strict
-- Carrier Strike — клиент: меню (3D-витрина самолёта на палубе), прогресс, быстрый старт, обучение,
-- локальная физика своего самолёта (как в Sky Pilot), катапульта и тросы, пушка/ракеты/ловушки,
-- метки, радар, звуки, награды, итоги раунда, кинокамера для обложек (только в Studio, клавиша K).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local SocialService = game:GetService("SocialService")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("CarrierStrike")
local World = require(Shared:WaitForChild("World"))
local Jets = require(Shared:WaitForChild("Jets"))
local Progress = require(Shared:WaitForChild("Progress"))
local Config = require(Shared:WaitForChild("Config"))
local Lang = require(Shared:WaitForChild("Lang"))
local FlightPhysics = require(Shared:WaitForChild("FlightPhysics"))
local PlaneBuilder = require(Shared:WaitForChild("PlaneBuilder"))
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
local ProfileR, RewardR, BuyR, DailyR, TutR, RoundR = ev("Profile"), ev("Reward"), ev("Buy"), ev("ClaimDaily"), ev("TutorialDone"), ev("RoundEnd")

-- ===== язык: русский для русскоязычных, иначе английский
local lang = Lang.pick(player.LocaleId)
local function L(key: string, ...: any): string
	return Lang.t(lang, key, ...)
end

local ui = Hud.new(L)
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

-- ===== звуки (id в Config.SOUNDS; пусто — без звука)
local sounds: { [string]: Sound } = {}
local function sound(name: string, looped: boolean?, vol: number?): Sound?
	local id = (Config.SOUNDS :: any)[name]
	if type(id) ~= "string" or id == "" then
		return nil
	end
	local s = sounds[name]
	if not s then
		s = Instance.new("Sound")
		s.SoundId = id
		s.Looped = looped == true
		s.Volume = vol or 0.6
		s.Parent = workspace.CurrentCamera
		sounds[name] = s
	end
	return s
end
local function play(name: string, vol: number?)
	local s = sound(name, false, vol)
	if s then
		s.TimePosition = 0
		s:Play()
	end
end

-- ===== состояние
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
local lock = { target = nil :: Model?, t = 0, beeped = false }
local incoming: { BasePart } = {}
local inMenu = true
local profile: any = nil
local dailyShown = false
local tut = { on = false, step = 0, t = 0, hit = false, msl = false }
local cine = { on = false, shot = 0, t = 0 }

-- ===== витрина в меню: выбранный самолёт стоит на палубе своего авианосца
local preview: Model? = nil
local previewKey = ""
local function paintCfg(c: any, side: string, paintId: string): any
	local out = table.clone(c)
	out.colors = table.clone(c.colors)
	local team = if side == "Blue" then Color3.fromRGB(46, 104, 170) else Color3.fromRGB(170, 52, 46)
	local pt = Progress.paint(paintId)
	if pt and pt.body then
		out.colors.body = pt.body
		out.colors.accent = pt.accent
	else
		out.colors.accent = team
	end
	out.colors.tail = team
	return out
end
local previewJet, previewPaint = "F16", "team"
local function buildPreview()
	local key = previewJet .. "|" .. previewPaint .. "|" .. mySide()
	if key == previewKey and preview and preview.Parent then
		return
	end
	previewKey = key
	if preview then
		preview:Destroy()
	end
	local c = Jets.JETS[previewJet]
	if not c then
		return
	end
	local m = PlaneBuilder.build(paintCfg(c, mySide(), previewPaint), { static = true })
	local carrier = World.carrierOf(mySide())
	m:PivotTo(carrier.cf * CFrame.new(-30, World.DECK_H + c.gearHeight, 40) * CFrame.Angles(0, math.rad(-25), 0))
	m.Name = "Preview"
	m.Parent = workspace
	preview = m
end
-- карточки ангара: 3D-модели (без земли и меток — static)
ui.setJets(Jets.ORDER, Jets.JETS, Progress, function(id: string, paint: string): Model?
	local c = Jets.JETS[id]
	if not c then
		return nil
	end
	return PlaneBuilder.build(paintCfg(c, mySide(), paint), { static = true })
end)
ui.on("select", function(jet: string, paint: string)
	previewJet, previewPaint = jet, paint
	if inMenu then
		buildPreview()
	end
end)

-- ===== меню: точки вылета, счёт
local function refreshMenu()
	local side = mySide()
	ui.setTeam(side)
	local list = {
		{ id = "deck:" .. side, title = "⚓ " .. L("sp_deck"), sub = L("sp_deck_sub"), ok = true },
		{ id = "air:" .. side, title = "✈ " .. L("sp_air"), sub = L("sp_air_sub"), ok = true },
	}
	for _, i in World.ISLANDS do
		local owner = match:GetAttribute("Owner_" .. i.id) or i.owner
		local ok = owner == side
		table.insert(list, {
			id = "base:" .. i.id, title = "◆ " .. L("sp_base", L("base_" .. i.id)),
			sub = if ok then L("sp_base_ok") elseif owner == "" then L("sp_base_neutral") else L("sp_base_enemy"), ok = ok,
		})
	end
	ui.setSpawns(list)
	buildPreview()
end

local function refreshMatch()
	local b = match:GetAttribute("TicketsBlue") or 0
	local r = match:GetAttribute("TicketsRed") or 0
	ui.setTickets(b, r)
	local bases = {}
	for _, i in World.ISLANDS do
		local owner = match:GetAttribute("Owner_" .. i.id) or i.owner
		table.insert(bases, { id = i.id, owner = owner, cap = match:GetAttribute("Cap_" .. i.id) or 0 })
	end
	ui.setBases(bases)
end
local lastSpawnRefresh = 0
match.AttributeChanged:Connect(function(name: string)
	refreshMatch()
	if name == "Top" then
		local ok, list = pcall(function()
			return HttpService:JSONDecode(match:GetAttribute("Top") or "[]")
		end)
		ui.setTop(if ok and type(list) == "table" then list else {}, profile and profile.week or 0)
	elseif name:sub(1, 6) == "Owner_" and inMenu and os.clock() - lastSpawnRefresh > 0.5 then
		lastSpawnRefresh = os.clock()
		refreshMenu()
	end
end)
player:GetPropertyChangedSignal("Team"):Connect(refreshMenu)
refreshMatch()
refreshMenu()
ui.setTop({}, 0)

ui.on("launch", function(jetId: string, spawnId: string, paint: string)
	SpawnR:FireServer(jetId, spawnId, paint)
end)
ui.on("quick", function(jetId: string, paint: string)
	SpawnR:FireServer(jetId, "air:" .. mySide(), paint)
end)
ui.on("buy", function(kind: string, id: string)
	BuyR:FireServer(kind, id)
end)
ui.on("daily", function()
	DailyR:FireServer()
end)
ui.on("invite", function()
	local ok, can = pcall(function()
		return SocialService:CanSendGameInviteAsync(player)
	end)
	if ok and can then
		pcall(function()
			SocialService:PromptGameInvite(player)
		end)
	else
		ui.toast(L("invite_fail"), "amber")
	end
end)
ui.on("shop", function(kind: string, id: number)
	if kind == "vip" and id > 0 then
		MarketplaceService:PromptGamePassPurchase(player, id)
	elseif kind == "coins" and id > 0 then
		MarketplaceService:PromptProductPurchase(player, id)
	elseif kind == "vip" then
		ui.toast(L("soon"), "amber")
	end
end)

-- ===== прогресс с сервера
ProfileR.OnClientEvent:Connect(function(p: any)
	profile = p
	ui.setProfile(p)
	ui.setQuickSub(if p.tut then L("play_sub") else L("play_sub_new"))
	if p.daily.can and not dailyShown and inMenu then
		dailyShown = true
		task.delay(1.2, function()
			if inMenu and profile and profile.daily.can then
				ui.showDaily()
			end
		end)
	end
end)
RewardR.OnClientEvent:Connect(function(coins: number, xp: number, key: string)
	local k = if key:sub(1, 6) == "quest_" then "r_quest" else "r_" .. key
	ui.reward(coins, xp, L(k))
	play("reward", 0.5)
end)
NotifyR.OnClientEvent:Connect(function(key: string, colr: string?, ...: any)
	local args = { ... }
	if key == "bought" then
		args = { Jets.JETS[args[1]] and Jets.JETS[args[1]].name or tostring(args[1]) }
	end
	local text = L("n_" .. key, table.unpack(args))
	if key == "levelup" or key == "quest_done" then
		ui.banner(text, Hud.C.gold)
	else
		ui.toast(text, colr)
	end
end)
RoundR.OnClientEvent:Connect(function(winner: string, mvp: { any })
	ui.showRound(winner, mvp, mySide(), 15)
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
	ui.tutorial(nil)
	inMenu = true
	local eng = sounds.engine
	if eng then
		eng:Stop()
	end
	local mus = sound("music", true, 0.35)
	if mus and not mus.IsPlaying then
		mus:Play()
	end
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
	ui.tutorial(nil)
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
	if preview then
		preview:Destroy()
		preview = nil
		previewKey = ""
	end
	ui.closeModal()
	ui.showMenu(false)
	ui.showDead(nil)
	ui.setFlying(true)
	ui.setThrottleKnob(f.throttle)
	cameraRig.reset(spawnCF.Rotation, c)
	Animator.setLocal(m, f.gear, 0, f.throttle)
	setCharacterControls(false)
	local mus = sounds.music
	if mus then
		mus:Stop()
	end
	local eng = sound("engine", true, 0.45)
	if eng then
		eng:Play()
	end
	if air then
		ui.toast(L("t_air"), "accent")
	elseif World.runwayAt(spawnCF.Position.X, spawnCF.Position.Z, 5) == World.carrierOf(mySide()).id then
		ui.toast(L("t_catapult"), "accent")
	else
		ui.toast(L("t_runway"), "accent")
	end
	-- обучение новичка
	if profile and not profile.tut then
		tut.on, tut.step, tut.t, tut.hit, tut.msl = true, 1, 0, false, false
	end
	ReadyR:FireServer(m)
end)

KilledR.OnClientEvent:Connect(function(killer: string, weapon: string)
	if flight then
		if weapon == "round" then
			die(L("round_new"))
		elseif killer ~= "" then
			die(L("killed_by", killer, L("w_" .. weapon)))
		else
			die(L("killed_" .. weapon))
		end
	end
end)
FeedR.OnClientEvent:Connect(function(kind: string, d: any)
	local C = World.TEAM_COLOR
	if kind == "kill" then
		if d.k ~= "" then
			ui.feed(string.format("%s  [%s]  %s", d.k, L("w_" .. d.w), d.v), C[d.ks] or Hud.C.text)
		else
			ui.feed(string.format("%s  [%s]", d.v, L("w_" .. d.w)), C[d.vs] or Hud.C.text)
		end
	elseif kind == "crash" then
		ui.feed(string.format("%s  [%s]", d.v, L("crash_" .. d.why)), C[d.vs] or Hud.C.text)
	elseif kind == "cap" then
		ui.feed(L("f_cap", L("team_" .. d.side), L("base_" .. d.base)), C[d.side] or Hud.C.text)
		if d.side == mySide() and flight then
			ui.banner(L("f_cap", L("team_" .. d.side), L("base_" .. d.base)), C[d.side])
		end
	elseif kind == "neutral" then
		ui.feed(L("f_neutral", L("base_" .. d.base)), Hud.C.text)
	elseif kind == "streak" then
		ui.feed(L("f_streak", d.k, d.n), Hud.C.gold)
		if model and d.k == model:GetAttribute("Pilot") then
			ui.banner(L("streak_n", d.n), Hud.C.gold)
		end
	end
end)
HitR.OnClientEvent:Connect(function(_m: Model, kill: boolean)
	ui.hit(kill)
	play("hit", 0.5)
	tut.hit = true
end)
WarnR.OnClientEvent:Connect(function(part: BasePart)
	table.insert(incoming, part)
	play("warn", 0.6)
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
	addFx(Vector3.new(0.35, 0.35, 26), from * CFrame.new(0, 0, -20), Color3.fromRGB(255, 214, 120), from.LookVector * (2600 + speed), 0.7, 0)
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

local function lockNeed(m: Model): number
	local j = Jets.JETS[m:GetAttribute("PlaneId") :: any]
	return Jets.MSL_LOCK * (if j then j.lockMul else 1)
end

-- ===== действия (клавиши, геймпад и сенсорные кнопки — один обработчик)
local controls: any = nil
local function act(a: string)
	local f = flight
	if a == "cam" then
		cameraRig.cycle()
		ui.toast(L("cam_" .. tostring(cameraRig.mode)))
		return
	end
	if a == "cine" then
		if RunService:IsStudio() then
			cine.on = not cine.on
			cine.shot = (cine.shot % 4) + 1
			cine.t = 0
			ui.hideAll(cine.on)
		end
		return
	end
	if not f or f.crashed then
		return
	end
	if a == "missile" then
		if lock.target and lock.t >= lockNeed(lock.target) then
			if ((model and model:GetAttribute("Missiles")) or 0) > 0 then
				MissileR:FireServer(lock.target)
				lock.t = 0
				lock.beeped = false
				tut.msl = true
				play("missile", 0.7)
				ui.toast(L("t_fired"), "amber")
			else
				ui.toast(L("t_no_msl"), "amber")
			end
			return
		end
		ui.toast(L("t_no_lock"), "amber")
	elseif a == "flare" then
		FlareR:FireServer()
	elseif a == "gear" then
		if f.onGround and f.gear then
			ui.toast(L("gear_ground"), "amber")
		else
			FlightPhysics.action(f, "gear")
			ui.toast(if f.gear then L("gear_down") else L("gear_up"))
		end
	elseif a == "mouse" then
		controls.mouseYoke = not controls.mouseYoke
		ui.toast(if controls.mouseYoke then L("mouse_on") else L("mouse_off"))
	elseif a == "brake" then
		ui.touch.brake = not ui.touch.brake
		ui.toast(if ui.touch.brake then L("brake_on") else L("brake_off"))
	elseif a == "idle" then
		FlightPhysics.action(f, "idle")
		ui.setThrottleKnob(0)
	elseif a == "menu" then
		if f.onGround and f.speed < 25 then
			LeaveR:FireServer()
			stopFlight()
		else
			ui.toast(L("menu_ground"), "amber")
		end
	end
end
controls = Controls.new(ui, act)
ui.onAction(function(a: string)
	if a ~= "gun" then
		act(a)
	end
end)

local function crashKind(reason: string?): string
	local r = reason or ""
	if r:find("океан") then
		return "water"
	elseif r:find("авианос") then
		return "carrier"
	end
	return "ground"
end

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
		die(L("destroyed"))
		return
	end
	local input = controls.read()
	if input.throttle then
		ui.setThrottleKnob(input.throttle)
	end
	-- на телефоне самолёт сам выравнивает крен, когда стик отпущен (проще для новичков)
	if ui.isTouch and not ui.touch.active and not f.onGround then
		local bank = math.asin(math.clamp(-f.att.RightVector.Y, -1, 1))
		input.r += math.clamp(-bank * 1.2, -0.6, 0.6)
	end
	if parkBrake then
		input.brakes = true
		if f.throttle >= 0.9 or (input.throttle and input.throttle >= 0.9) then
			parkBrake = false
			assist = true
			ui.toast(L("t_go"), "accent")
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
		local kind = crashKind(f.crashReason)
		CrashR:FireServer(kind)
		die(L("crash_" .. kind))
		return
	end
	r.CFrame = FlightPhysics.pose(f)
	r.AssemblyLinearVelocity = f.vel
	r.AssemblyAngularVelocity = Vector3.zero
	Animator.setLocal(model, f.gear, f.flaps, f.throttle)
	Animator.setInputs(f.inP, f.inR, f.inY)
	local eng = sounds.engine
	if eng then
		eng.PlaybackSpeed = 0.7 + f.throttle * 0.6
	end
	local now = os.clock()
	if now - lastSync > 0.25 then
		lastSync = now
		StateR:FireServer(f.gear, f.throttle)
	end
end)

-- ===== обучение: короткие шаги в первом вылете
local TUT_STEPS = { "tut1", "tut2", "tut3", "tut4" }
local function tutorialTick(dt: number, f: any)
	if not tut.on then
		return
	end
	tut.t += dt
	local s = tut.step
	local nextStep = (s == 1 and (tut.t > 7 or (tut.t > 3 and (math.abs(f.inR) > 0.3 or math.abs(f.inP) > 0.3))))
		or (s == 2 and (tut.hit or tut.t > 22))
		or (s == 3 and (tut.msl or tut.t > 18))
		or (s == 4 and tut.t > 10)
	if nextStep then
		tut.step += 1
		tut.t = 0
		if tut.step > #TUT_STEPS then
			tut.on = false
			ui.tutorial(nil)
			ui.banner(L("tut_done"), Hud.C.green)
			TutR:FireServer()
			return
		end
	end
	local key = TUT_STEPS[tut.step]
	ui.tutorial(L(key .. (if ui.isTouch then "_t" else "")))
end

-- ===== кадр: камера, оружие, приборы
local function fmtDist(d: number): string
	local m = d * 0.515
	return if m >= 1000 then string.format("%.1f km", m / 1000) else string.format("%d m", math.round(m / 10) * 10)
end

local function cinematic(dt: number, cam: Camera)
	cine.t += dt
	local c = World.carrierOf(mySide())
	local folder = workspace:FindFirstChild("Planes")
	local subject: BasePart? = nil
	if model and model.PrimaryPart then
		subject = model.PrimaryPart
	elseif folder then
		for _, m in folder:GetChildren() do
			if m:IsA("Model") and m.PrimaryPart and m.Name ~= "Wreck" then
				subject = m.PrimaryPart
				break
			end
		end
	end
	cam.CameraType = Enum.CameraType.Scriptable
	if cine.shot == 1 and subject then
		-- низко сбоку от самолёта, длинный фокус
		local p = subject.Position
		local cf = subject.CFrame
		cam.FieldOfView = 30
		cam.CFrame = CFrame.lookAt(p + cf.RightVector * 90 + cf.UpVector * 12 - cf.LookVector * 30, p)
	elseif cine.shot == 2 and subject then
		-- сзади-сверху, видно море и остров
		local cf = subject.CFrame
		cam.FieldOfView = 55
		cam.CFrame = CFrame.lookAt(cf.Position - cf.LookVector * 70 + Vector3.new(0, 25, 0), cf.Position + cf.LookVector * 400)
	elseif cine.shot == 3 then
		-- авианосец с воздуха, медленный облёт
		local a = cine.t / 20
		local center = c.cf.Position + Vector3.new(0, World.DECK_H, 0)
		cam.FieldOfView = 40
		cam.CFrame = CFrame.lookAt(center + Vector3.new(math.sin(a) * 900, 320, math.cos(a) * 900), center)
	else
		-- остров «Центр» на закате
		local a = cine.t / 25
		cam.FieldOfView = 45
		cam.CFrame = CFrame.lookAt(Vector3.new(math.sin(a) * 2600, 500, math.cos(a) * 2600), Vector3.new(0, 80, 0))
	end
end

RunService:BindToRenderStep("CarrierStrike", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local now = os.clock()
	Animator.step(dt, now)
	local cam = workspace.CurrentCamera
	local serverNow = workspace:GetServerTimeNow()

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

	if cine.on then
		cinematic(dt, cam)
		return
	end

	local f = flight
	if not f then
		-- меню: медленный облёт самолёта на палубе (самолёт смещён вправо от меню)
		local c = World.carrierOf(mySide())
		local target = if preview and preview.PrimaryPart then preview.PrimaryPart.Position else c.cf.Position + Vector3.new(0, World.DECK_H + 10, 0)
		local L0 = (Jets.JETS[previewJet] or Jets.JETS.F16).length
		local a = now / 18
		local r = L0 * 1.5 + 34
		local eye = target + Vector3.new(math.sin(a) * r, 10 + L0 * 0.18 + math.sin(a * 0.7) * 4, math.cos(a) * r)
		local look = CFrame.lookAt(eye, target)
		cam.CameraType = Enum.CameraType.Scriptable
		cam.FieldOfView = 50
		cam.CFrame = CFrame.lookAt(eye, target - look.RightVector * L0 * 0.45)
		return
	end
	if f.crashed then
		cameraRig.update(dt, crashPose or FlightPhysics.pose(f), f.cfg, 0, false, true)
		return
	end
	local pose = if root and simulating then (root :: BasePart).CFrame else FlightPhysics.pose(f)
	cameraRig.update(dt, pose, f.cfg, f.speed, f.onGround, false, f.buffet)
	tutorialTick(dt, f)

	-- пушка (на телефоне конус шире — помощь прицеливания)
	local cone = if ui.isTouch then Jets.GUN_CONE_TOUCH else Jets.GUN_CONE
	if simulating and controls.firing() and now - lastShot >= Jets.GUN_RATE then
		lastShot = now
		local t = bestInCone(f.att.LookVector, f.pos, cone, Jets.GUN_RANGE)
		GunR:FireServer(t)
		tracer(FlightPhysics.pose(f) * CFrame.new(if math.random() < 0.5 then 1.5 else -1.5, 0, -f.cfg.length * 0.5), f.speed)
		play("gun", 0.35)
	end

	-- захват ракетой
	local cand = bestInCone(f.att.LookVector, f.pos, Jets.MSL_CONE, Jets.MSL_RANGE)
	if cand ~= lock.target then
		lock.target = cand
		lock.t = 0
		lock.beeped = false
	elseif cand then
		lock.t += dt
	end
	local lockInfo = nil
	if lock.target and lock.target.PrimaryPart then
		local sp, on = cam:WorldToViewportPoint(lock.target.PrimaryPart.Position)
		if on then
			local need = lockNeed(lock.target)
			local locked = lock.t >= need
			if locked and not lock.beeped then
				lock.beeped = true
				play("lock", 0.5)
			end
			lockInfo = { x = sp.X, y = sp.Y, k = math.clamp(lock.t / need, 0, 1), locked = locked }
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
		warn = L("w_missile", fmtDist(nearest))
	end
	if math.abs(myPos.X) > World.SIZE or math.abs(myPos.Z) > World.SIZE then
		warn = L("w_zone")
	end
	local hp = (model and model:GetAttribute("HP") or 0) :: number
	local maxHp = (model and model:GetAttribute("MaxHP") or 100) :: number
	if not warn and hp < maxHp * 0.3 then
		warn = L("w_hp")
	end
	local info: string? = nil
	if parkBrake then
		info = L("i_throttle")
	elseif f.onGround and f.speed < 15 then
		local where = World.runwayAt(myPos.X, myPos.Z, 10)
		local mine = where == World.carrierOf(side).id or (where ~= nil and match:GetAttribute("Owner_" .. where) == side)
		if mine then
			info = L("i_rearm")
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
				local whose = L("team_" .. (if cap >= 0 then "Blue" else "Red"))
				if myPos.Y < i.h + World.CAPTURE_ALT then
					info = L("i_capture", L("base_" .. i.id), whose, pct)
				else
					info = L("i_capture_low", L("base_" .. i.id), math.floor((i.h + World.CAPTURE_ALT) * World.FT))
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

player.CharacterAdded:Connect(function()
	task.wait(0.5)
	setCharacterControls(false)
end)

-- музыка меню (если задана)
task.defer(function()
	local mus = sound("music", true, 0.35)
	if mus and inMenu then
		mus:Play()
	end
end)

