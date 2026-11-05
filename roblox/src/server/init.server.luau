--!strict
-- Sky Pilot — сервер: мир, выдача самолётов, посадка пилота, очки, крушения, ИИ-трафик.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("SkyPilot")
local World = require(Shared:WaitForChild("World"))
local PlaneConfigs = require(Shared:WaitForChild("PlaneConfigs"))
local PlaneBuilder = require(Shared:WaitForChild("PlaneBuilder"))

local WorldBuilder = require(script:WaitForChild("WorldBuilder"))
local Scores = require(script:WaitForChild("Scores"))
local AITraffic = require(script:WaitForChild("AITraffic"))

local AI_TRAFFIC_COUNT = 5 -- 0 = без ботов
local DAY_LENGTH_MIN = 40 -- полные сутки за 40 минут реального времени; 0 = всегда день

-- ===== группы столкновений: самолёт и пилот не цепляются за землю (столкновения считает физика игры)
local FLYING = "SkyPilotFlying"
local DEBRIS = "SkyPilotDebris"
for _, g in { FLYING, DEBRIS } do
	if not PhysicsService:IsCollisionGroupRegistered(g) then
		PhysicsService:RegisterCollisionGroup(g)
	end
end
PhysicsService:CollisionGroupSetCollidable(FLYING, "Default", false)
PhysicsService:CollisionGroupSetCollidable(FLYING, FLYING, false)
PhysicsService:CollisionGroupSetCollidable(FLYING, DEBRIS, false)
PhysicsService:CollisionGroupSetCollidable(DEBRIS, DEBRIS, false)

-- ===== удалённые события
local remotes = Instance.new("Folder")
remotes.Name = "SkyPilotRemotes"
local function remote(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end
local RequestFlight = remote("RequestFlight")
local FlightStarted = remote("FlightStarted")
local ClientReady = remote("ClientReady")
local PlaneState = remote("PlaneState")
local Landing = remote("Landing")
local CrashEvent = remote("Crash")
local EndFlight = remote("EndFlight")
local Notify = remote("Notify")
local RaceFinished = remote("RaceFinished")
local GateParked = remote("GateParked")
local AchievementRemote = remote("Achievement")
local DailyRemote = remote("DailyTask")
local TrickRemote = remote("Trick")
remotes.Parent = ReplicatedStorage

WorldBuilder.build()
local planesFolder = workspace:WaitForChild("Planes")

type Active = {
	model: Model, root: BasePart, cfgId: string, mode: string,
	started: number, lastLanding: number, fromAirport: string?, destination: string?, ready: boolean, crashed: boolean,
	conns: { RBXScriptConnection },
}
local active: { [Player]: Active } = {}
local lastRequest: { [Player]: number } = {}
local rng = Random.new()

local function setGroup(inst: Instance, group: string)
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = group
		end
	end
	if inst:IsA("BasePart") then
		inst.CollisionGroup = group
	end
end

local function cleanup(p: Player, destroyModel: boolean)
	local a = active[p]
	if not a then
		return
	end
	active[p] = nil
	for _, c in a.conns do
		c:Disconnect()
	end
	if destroyModel and a.model.Parent then
		a.model:Destroy()
	end
end

local function slotFree(cf: CFrame): boolean
	for _, a in active do
		if a.root.Parent and (a.root.Position - cf.Position).Magnitude < 450 then
			return false
		end
	end
	return true
end

-- режимы: "runway:<id аэропорта>", "air" (заход на полосу A), "race" (перед первым кольцом)
local function runwayId(mode: string): string?
	return mode:match("^runway:(%u)$")
end

local function pickSpawn(cfg: any, mode: string): (CFrame, boolean, string?)
	if mode == "race" then
		local r = World.CityData.rings[1]
		local look = Vector3.new(-math.sin(r[5]), 0, -math.cos(r[5]))
		local pos = Vector3.new(r[1], r[2], r[3]) - look * 1500 + Vector3.new(rng:NextNumber(-40, 40), 0, rng:NextNumber(-40, 40))
		return CFrame.lookAt(pos, pos + look), true, nil
	end
	local id = runwayId(mode)
	if id then
		local ap = World.airportById(id)
		if ap then
			for _, cf in World.runwaySpawns(ap, cfg) do
				if slotFree(cf) then
					return cf, false, ap.id
				end
			end
		end
	end
	-- в воздухе: заход на полосу 36 аэропорта A с небольшим разносом между игроками
	local cf = CFrame.new(rng:NextNumber(-600, 600), 3000 / World.FT + rng:NextNumber(-60, 60), 9000 + rng:NextNumber(0, 1500))
	return cf, true, nil
end

local function ensureCharacter(p: Player): Humanoid?
	local ch = p.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or not (ch :: Model).PrimaryPart then
		p:LoadCharacter()
		ch = p.Character or p.CharacterAdded:Wait()
		hum = (ch :: Model):WaitForChild("Humanoid", 5) :: Humanoid?
		;(ch :: Model):WaitForChild("HumanoidRootPart", 5)
	end
	return hum
end

local function explode(a: Active)
	local model = a.model
	if not model.Parent then
		return
	end
	local root = a.root
	local v = root.AssemblyLinearVelocity * 0.25
	local pos = root.Position
	local ex = Instance.new("Explosion")
	ex.Position = pos
	ex.BlastRadius = 0
	ex.BlastPressure = 0
	ex.DestroyJointRadiusPercent = 0
	ex.Parent = workspace
	local fire = Instance.new("Part")
	fire.Anchored = true
	fire.CanCollide = false
	fire.Transparency = 1
	fire.Size = Vector3.one
	fire.CFrame = CFrame.new(pos.X, math.max(pos.Y, World.groundAt(pos.X, pos.Z) + 1), pos.Z)
	local smoke = Instance.new("Smoke")
	smoke.Size = math.clamp(model:GetExtentsSize().Magnitude * 0.15, 8, 60)
	smoke.RiseVelocity = 12
	smoke.Color = Color3.fromRGB(40, 40, 40)
	smoke.Parent = fire
	local fl = Instance.new("Fire")
	fl.Size = math.clamp(model:GetExtentsSize().Magnitude * 0.08, 5, 30)
	fl.Parent = fire
	fire.Parent = workspace
	Debris:AddItem(fire, 12)
	-- разлёт обломков
	model.Name = "Wreck"
	for _, d in model:GetDescendants() do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") then
			d:Destroy()
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = true
			d.CollisionGroup = DEBRIS
			d.Massless = false
			d.AssemblyLinearVelocity = v + Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.3, 1.5), rng:NextNumber(-1, 1)) * rng:NextNumber(20, 80)
			d.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(-3, 3), rng:NextNumber(-3, 3))
		elseif d:IsA("BillboardGui") or d:IsA("Trail") or d:IsA("Seat") then
			d:Destroy()
		end
	end
	Debris:AddItem(model, 10)
end
PhysicsService:CollisionGroupSetCollidable(DEBRIS, "Default", true)

local function startFlight(p: Player, planeId: any, mode: any, destination: any, liveryId: any)
	if type(planeId) ~= "string" or type(mode) ~= "string" then
		return
	end
	local cfg = PlaneConfigs.PLANES[planeId]
	local rid = runwayId(mode)
	if not cfg or not (mode == "air" or mode == "race" or (rid and World.airportById(rid))) then
		return
	end
	if destination ~= nil and (type(destination) ~= "string" or not World.airportById(destination) or destination == rid) then
		destination = nil
	end
	local now = os.clock()
	if lastRequest[p] and now - lastRequest[p] < 1.5 then
		return
	end
	lastRequest[p] = now

	local old = active[p]
	if old then
		cleanup(p, true)
	end
	local hum = ensureCharacter(p)
	if not hum or not p.Parent then
		return
	end
	local character = p.Character :: Model

	local spawnCF, air, ap = pickSpawn(cfg, mode)
	if rid and air then
		Notify:FireClient(p, "Полоса занята — старт в воздухе", "amber")
	end
	local buildCfg = cfg
	if type(liveryId) == "string" then
		for _, lv in (PlaneConfigs :: any).LIVERIES do
			if lv.id == liveryId and lv.colors then
				buildCfg = table.clone(cfg)
				buildCfg.colors = lv.colors
			end
		end
	end
	local model = PlaneBuilder.build(buildCfg, { seat = true, label = p.DisplayName })
	model.Name = p.Name .. "_Plane"
	model:SetAttribute("Owner", p.UserId)
	model:SetAttribute("Gear", air == false or cfg.fixedGear == true)
	model:SetAttribute("Flaps", 0)
	model:SetAttribute("Throttle", if air then 0.7 else 0)
	model:PivotTo(spawnCF)
	local root = model.PrimaryPart :: BasePart
	root.Anchored = true
	setGroup(model, FLYING)
	model.Parent = planesFolder

	local seat = model:FindFirstChild("PilotSeat") :: Seat
	setGroup(character, FLYING)
	seat:Sit(hum)

	local a: Active = {
		model = model, root = root, cfgId = planeId, mode = if air then "air" else mode,
		started = now, lastLanding = 0, fromAirport = ap, destination = destination, ready = false, crashed = false, conns = {},
	}
	active[p] = a
	Scores.flight(p)

	table.insert(a.conns, hum.Died:Connect(function()
		if active[p] == a then
			cleanup(p, true)
		end
	end))
	task.delay(1, function()
		if active[p] ~= a then
			return
		end
		table.insert(a.conns, seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			if seat.Occupant == nil and active[p] == a and not a.crashed then
				cleanup(p, true)
				EndFlight:FireClient(p)
			end
		end))
	end)

	FlightStarted:FireClient(p, model, planeId, a.mode, spawnCF)
end

-- достижения: открыть один раз, начислить награду, сообщить игроку
local Achievements = require(Shared:WaitForChild("Achievements"))
local function award(p: Player, id: string)
	local ach = Achievements.BY_ID[id]
	if ach and Scores.unlock(p, id) then
		Scores.add(p, ach.reward, false)
		Notify:FireClient(p, string.format("🏆 Достижение «%s» · +%d", ach.title, ach.reward), "green")
	end
end
-- то, что видит только клиент (высота, перегрузка, ось полосы, отрыв): принимаем только из белого списка во время полёта
AchievementRemote.OnServerEvent:Connect(function(p, id)
	local a = active[p]
	if type(id) ~= "string" or not a or a.crashed then
		return
	end
	local ach = Achievements.BY_ID[id]
	if not ach or not ach.client then
		return
	end
	if id == "ace" and a.cfgId ~= "F16" then
		return
	end
	award(p, id)
end)

-- авиашоу: фигуры пилотажа видит только клиент; сервер ограничивает частоту и сумму за полёт
local Aerobatics = require(Shared:WaitForChild("Aerobatics"))
TrickRemote.OnServerEvent:Connect(function(p, id)
	local a = active[p]
	if type(id) ~= "string" or not a or a.crashed then
		return
	end
	local t = Aerobatics.TRICKS[id]
	if not t then
		return
	end
	local now = os.clock()
	a.trickAt = a.trickAt or {}
	a.trickPts = a.trickPts or 0
	if now - (a.trickAt[id] or -1e9) < t.gap or a.trickPts + t.pts > Aerobatics.FLIGHT_CAP then
		return
	end
	if a.root and a.root.Position.Y * World.FT < 250 then
		return
	end
	a.trickAt[id] = now
	a.trickPts += t.pts
	Scores.add(p, t.pts, false)
	Notify:FireClient(p, string.format("✈ %s · +%d", t.title, t.pts), "green")
end)

-- задания дня: принимаем только сегодняшние и только во время полёта
local Daily = require(Shared:WaitForChild("Daily"))
DailyRemote.OnServerEvent:Connect(function(p, id)
	local a = active[p]
	if type(id) ~= "string" or not a or a.crashed then
		return
	end
	local key = Daily.dateKey()
	for _, t in Daily.tasks(key) do
		if t.id == id then
			if t.kind == "soft" and a.cfgId ~= t.target then
				return
			end
			if Scores.dailyDone(p, key, id) then
				Scores.add(p, t.reward, false)
				Notify:FireClient(p, string.format("📋 Задание дня выполнено: %s · +%d", t.text, t.reward), "green")
			end
			return
		end
	end
end)

RequestFlight.OnServerEvent:Connect(function(p, planeId, mode, destination, liveryId)
	startFlight(p, planeId, mode, destination, liveryId)
end)

ClientReady.OnServerEvent:Connect(function(p, model)
	local a = active[p]
	if not a or a.ready or model ~= a.model then
		return
	end
	a.ready = true
	a.root.Anchored = false
	pcall(function()
		a.root:SetNetworkOwner(p)
	end)
end)

PlaneState.OnServerEvent:Connect(function(p, gear, flaps, throttle, reverse)
	local a = active[p]
	if not a then
		return
	end
	if type(gear) == "boolean" then
		a.model:SetAttribute("Gear", gear)
	end
	if type(flaps) == "number" then
		a.model:SetAttribute("Flaps", math.clamp(math.floor(flaps), 0, 3))
	end
	if type(throttle) == "number" then
		a.model:SetAttribute("Throttle", math.clamp(throttle, 0, 1))
	end
	if type(reverse) == "boolean" then
		a.model:SetAttribute("Reverse", reverse)
	end
end)

Landing.OnServerEvent:Connect(function(p, fpm, comfort)
	local a = active[p]
	if not a or a.crashed or type(fpm) ~= "number" then
		return
	end
	local now = os.clock()
	if now - a.lastLanding < 8 or now - a.started < 5 then
		return
	end
	local pos = a.root.Position
	local apId = World.runwayAt(pos.X, pos.Z, 40)
	if not apId or pos.Y - World.groundAt(pos.X, pos.Z) > 80 then
		Notify:FireClient(p, "Посадка вне полосы — очки не начислены", "amber")
		return
	end
	a.lastLanding = now
	fpm = math.max(0, math.floor(fpm))
	local pts = if fpm < 120 then 400 elseif fpm < 250 then 300 elseif fpm < 600 then 150 else 50
	local msg = string.format("+%d очков за посадку", pts)
	if a.fromAirport and a.fromAirport ~= apId then
		pts += 500
		msg ..= string.format("  ·  +500 за перелёт %s → %s", a.fromAirport, apId)
	end
	-- рейс (карьера): посадка в аэропорту назначения
	if a.destination and a.destination == apId then
		pts += 1000
		local dst = World.airportById(apId)
		msg ..= string.format("  ·  РЕЙС ВЫПОЛНЕН +1000 (%s)", if dst then dst.code else apId)
		a.destination = nil
	end
	local routeDone = a.destination == nil and msg:find("РЕЙС ВЫПОЛНЕН", 1, true) ~= nil
	a.fromAirport = apId
	Scores.add(p, pts, true, fpm)
	Notify:FireClient(p, msg, "green")
	-- достижения за посадку
	if fpm < 250 then
		award(p, "soft")
	end
	if fpm < 80 then
		award(p, "butter")
	end
	if routeDone then
		award(p, "route")
		-- бонус за комфорт пассажиров (до +500) — только за выполненный рейс
		if type(comfort) == "number" and comfort == comfort then
			local bonus = math.floor(math.clamp(comfort, 0, 100) * 5)
			if bonus > 0 then
				Scores.add(p, bonus, false)
				Notify:FireClient(p, string.format("🧳 Пассажиры довольны: +%d за комфорт", bonus), "green")
			end
		end
	end
	if Scores.visit(p, apId) >= #World.AIRPORTS then
		award(p, "airports")
	end
	if Scores.get(p).landings >= 10 then
		award(p, "ten")
	end
	local clock = game:GetService("Lighting").ClockTime
	if clock < 5.5 or clock > 19.5 then
		award(p, "night")
	end
	if a.cfgId == "A380" or a.cfgId == "B747" then
		award(p, "heavy")
	end
end)

CrashEvent.OnServerEvent:Connect(function(p, reason)
	local a = active[p]
	if not a or a.crashed then
		return
	end
	a.crashed = true
	local name = p.DisplayName
	if type(reason) == "string" then
		print(string.format("[SkyPilot] %s: крушение — %s", name, reason:sub(1, 120)))
	end
	cleanup(p, false)
	explode(a)
	-- пилот «катапультировался» в терминал
	task.delay(0.3, function()
		if p.Parent and not active[p] then
			p:LoadCharacter()
		end
	end)
end)

-- рейс завершён у гейта: самолёт стоит на стоянке вскоре после посадки
local gateDone: { [Player]: number } = {}
GateParked.OnServerEvent:Connect(function(p, standId)
	local a = active[p]
	if not a or a.crashed or type(standId) ~= "string" then
		return
	end
	local now = os.clock()
	if a.lastLanding == 0 or now - a.lastLanding > 600 or (gateDone[p] and gateDone[p] >= a.lastLanding) then
		return
	end
	local pos = a.root.Position
	for _, list in World.STANDS do
		for _, st in list do
			if st.id == standId and (Vector3.new(pos.X - st.x, 0, pos.Z - st.z)).Magnitude < 70 and a.root.AssemblyLinearVelocity.Magnitude < 8 then
				gateDone[p] = a.lastLanding
				Scores.add(p, 500, false)
				Notify:FireClient(p, string.format("Рейс завершён у гейта %s · +500", standId), "green")
				return
			end
		end
	end
end)

-- гонка через кольца: минимальное правдоподобное время ~60 с даже для истребителя
local lastRace: { [Player]: number } = {}
RaceFinished.OnServerEvent:Connect(function(p, t)
	local a = active[p]
	if not a or type(t) ~= "number" or t < 60 or t > 3600 then
		return
	end
	local now = os.clock()
	if lastRace[p] and now - lastRace[p] < 60 then
		return
	end
	lastRace[p] = now
	Scores.add(p, 1500, false)
	local best = p:GetAttribute("BestRace")
	local msg = string.format("+1500 очков за гонку · %d:%04.1f", math.floor(t / 60), t % 60)
	if type(best) ~= "number" or t < best then
		p:SetAttribute("BestRace", t)
		msg ..= " · новый рекорд!"
	end
	Notify:FireClient(p, msg, "green")
	award(p, "race")
end)

EndFlight.OnServerEvent:Connect(function(p)
	if active[p] then
		cleanup(p, true)
		p:LoadCharacter()
	end
end)

Players.PlayerAdded:Connect(function(p)
	Scores.load(p)
end)
for _, p in Players:GetPlayers() do
	task.spawn(Scores.load, p)
end
Players.PlayerRemoving:Connect(function(p)
	cleanup(p, true)
	lastRequest[p] = nil
	lastRace[p] = nil
	Scores.unload(p)
end)

-- смена дня и ночи (видна всем игрокам, огни полос и самолётов ночью светятся)
if DAY_LENGTH_MIN > 0 then
	local Lighting = game:GetService("Lighting")
	Lighting.ClockTime = 10
	-- ветер: общий для всех игроков, плавно меняется (атрибуты workspace WindDir / WindKts)
	local wind = { dir = math.random(0, 359), kts = math.random(3, 12), tDir = 0, tKts = 0, nextAt = 0, rain = 0, rainT = 0, rainAt = os.clock() + 120 }
	wind.tDir, wind.tKts = wind.dir, wind.kts
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(1)
			local now = os.clock()
			if now > wind.nextAt then
				wind.tDir = (wind.dir + math.random(-70, 70)) % 360
				wind.tKts = math.floor(math.random() ^ 1.6 * 25)
				wind.nextAt = now + math.random(300, 600)
			end
			local dd = ((wind.tDir - wind.dir + 540) % 360) - 180
			wind.dir = (wind.dir + math.clamp(dd, -0.4, 0.4)) % 360
			wind.kts += math.clamp(wind.tKts - wind.kts, -0.04, 0.04)
			workspace:SetAttribute("WindDir", math.round(wind.dir))
			workspace:SetAttribute("WindKts", math.round(wind.kts * 10) / 10)
			-- дождь: раз в 5–12 минут новая цель (примерно половина времени — дождь разной силы), плавно
			if now > wind.rainAt then
				wind.rainT = if math.random() < 0.45 then 0.3 + math.random() * 0.7 else 0
				wind.rainAt = now + math.random(300, 720)
			end
			wind.rain += math.clamp(wind.rainT - wind.rain, -0.004, 0.004)
			workspace:SetAttribute("Rain", math.round(wind.rain * 100) / 100)
			Lighting.ClockTime = (Lighting.ClockTime + (now - last) * 24 / (DAY_LENGTH_MIN * 60)) % 24
			last = now
			WorldBuilder.updateSky(Lighting.ClockTime, wind.rain)
		end
	end)
end

if AI_TRAFFIC_COUNT > 0 then
	AITraffic.start(AI_TRAFFIC_COUNT)
end
