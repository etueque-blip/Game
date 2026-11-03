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

local function startFlight(p: Player, planeId: any, mode: any, destination: any)
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
	local model = PlaneBuilder.build(cfg, { seat = true, label = p.DisplayName })
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

RequestFlight.OnServerEvent:Connect(function(p, planeId, mode, destination)
	startFlight(p, planeId, mode, destination)
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

Landing.OnServerEvent:Connect(function(p, fpm)
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
	a.fromAirport = apId
	Scores.add(p, pts, true, fpm)
	Notify:FireClient(p, msg, "green")
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

if AI_TRAFFIC_COUNT > 0 then
	AITraffic.start(AI_TRAFFIC_COUNT)
end
