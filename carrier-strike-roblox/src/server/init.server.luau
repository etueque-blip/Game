--!strict
-- Carrier Strike — сервер: команды, вылеты, бой (пушка и ракеты проверяются здесь),
-- захват островов, очки команд, боты.
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("CarrierStrike")
local World = require(Shared:WaitForChild("World"))
local Jets = require(Shared:WaitForChild("Jets"))
local FlightPhysics = require(Shared:WaitForChild("FlightPhysics"))
local PlaneBuilder = require(Shared:WaitForChild("PlaneBuilder"))
local WorldBuilder = require(script:WaitForChild("WorldBuilder"))
local Bots = require(script:WaitForChild("Bots"))

local rng = Random.new()

-- ===== группы столкновений: самолёты не цепляются за мир (столкновения считает физика игры)
local FLYING, DEBRIS = "CSFlying", "CSDebris"
for _, g in { FLYING, DEBRIS } do
	if not PhysicsService:IsCollisionGroupRegistered(g) then
		PhysicsService:RegisterCollisionGroup(g)
	end
end
PhysicsService:CollisionGroupSetCollidable(FLYING, "Default", false)
PhysicsService:CollisionGroupSetCollidable(FLYING, FLYING, false)
PhysicsService:CollisionGroupSetCollidable(FLYING, DEBRIS, false)
PhysicsService:CollisionGroupSetCollidable(DEBRIS, DEBRIS, false)
local function setGroup(inst: Instance, group: string)
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = group
		end
	end
end

-- ===== удалённые события
local remotes = Instance.new("Folder")
remotes.Name = "CSRemotes"
local function remote(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end
local SpawnR = remote("Spawn") -- клиент → сервер: (jetId, spawnId)
local StartedR = remote("Started") -- сервер → клиент: (model, jetId, spawnCF, air)
local ReadyR = remote("Ready")
local StateR = remote("State") -- (gear, throttle)
local GunR = remote("Gun") -- (target|nil): выстрел; target — модель, в которую клиент попал
local MissileR = remote("Missile") -- (target)
local FlareR = remote("Flare")
local CrashR = remote("Crash") -- (reason)
local RearmR = remote("Rearm")
local LeaveR = remote("Leave")
local KilledR = remote("Killed") -- сервер → клиент: (text)
local NotifyR = remote("Notify") -- (text, color)
local FeedR = remote("Feed") -- всем: строка ленты
local WarnR = remote("Warn") -- цели: ракета летит (missile part)
local HitR = remote("Hit") -- стрелку: попадание (для маркера)
remotes.Parent = ReplicatedStorage

-- ===== мир и команды
WorldBuilder.build()
local planes = Instance.new("Folder")
planes.Name = "Planes"
planes.Parent = workspace
local missilesFolder = Instance.new("Folder")
missilesFolder.Name = "Missiles"
missilesFolder.Parent = workspace

local TEAM: { [string]: Team } = {}
for _, t in { { "Blue", "Синие", BrickColor.new("Bright blue") }, { "Red", "Красные", BrickColor.new("Bright red") } } do
	local team = Instance.new("Team")
	team.Name = t[2]
	team.TeamColor = t[3]
	team.AutoAssignable = true
	team:SetAttribute("Side", t[1])
	team.Parent = Teams
	TEAM[t[1]] = team
	-- точка появления персонажа — на палубе своего авианосца (сам персонаж в бою не нужен)
	local c = World.carrierOf(t[1])
	local sp = Instance.new("SpawnLocation")
	sp.Name = "Deck_" .. t[1]
	sp.Size = Vector3.new(12, 1, 12)
	sp.CFrame = c.cf * CFrame.new(40, World.DECK_H + 0.5, 120)
	sp.Anchored = true
	sp.Neutral = false
	sp.TeamColor = t[3]
	sp.Transparency = 1
	sp.CanCollide = true
	sp.Duration = 0
	sp.Parent = workspace
	-- невидимый пол палубы для персонажа
	local floor = Instance.new("Part")
	floor.Name = "DeckFloor_" .. t[1]
	floor.Anchored = true
	floor.Transparency = 1
	floor.Size = Vector3.new(World.DECK_W, 1, World.DECK_L)
	floor.CFrame = c.cf * CFrame.new(0, World.DECK_H - 0.5, 0)
	floor.Parent = workspace
end
local function sideOf(p: Player): string
	return if p.Team == TEAM.Red then "Red" else "Blue"
end
local function other(side: string): string
	return if side == "Blue" then "Red" else "Blue"
end

-- состояние матча — атрибуты на ReplicatedStorage.CSMatch (клиент их читает)
local match = Instance.new("Configuration")
match.Name = "CSMatch"
match.Parent = ReplicatedStorage
local tickets = { Blue = Jets.TICKETS, Red = Jets.TICKETS }
local bases: { [string]: { owner: string, cap: number } } = {}
local function publish()
	match:SetAttribute("TicketsBlue", math.max(0, math.floor(tickets.Blue)))
	match:SetAttribute("TicketsRed", math.max(0, math.floor(tickets.Red)))
	for id, b in bases do
		match:SetAttribute("Owner_" .. id, b.owner)
		match:SetAttribute("Cap_" .. id, math.round(b.cap * 100) / 100)
	end
end
local function resetBases()
	for _, i in World.ISLANDS do
		bases[i.id] = { owner = i.owner, cap = if i.owner == "Blue" then 1 elseif i.owner == "Red" then -1 else 0 }
		WorldBuilder.setOwner(i.id, i.owner)
	end
end
resetBases()
publish()

-- ===== счёт игроков
local function stats(p: Player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	for _, n in { "Сбито", "Потери", "Базы" } do
		local v = Instance.new("IntValue")
		v.Name = n
		v.Parent = ls
	end
	ls.Parent = p
end
local function addStat(p: Player?, name: string, d: number)
	local ls = p and p:FindFirstChild("leaderstats")
	local v = ls and ls:FindFirstChild(name) :: IntValue?
	if v then
		v.Value += d
	end
end

-- ===== боевые единицы (игроки и боты)
type Unit = {
	model: Model, root: BasePart, side: string, cfg: any, name: string,
	player: Player?, bot: any?, flight: any?,
	hp: number, maxHp: number, missiles: number, flares: number,
	flareUntil: number, lastShot: number, lastMsl: number, lastRearm: number,
	alive: boolean, ready: boolean, born: number, conns: { RBXScriptConnection },
}
local units: { [Model]: Unit } = {}
local byPlayer: { [Player]: Unit } = {}

local function setAttrs(u: Unit)
	u.model:SetAttribute("HP", math.max(0, math.ceil(u.hp)))
	u.model:SetAttribute("MaxHP", u.maxHp)
	u.model:SetAttribute("Missiles", u.missiles)
	u.model:SetAttribute("Flares", u.flares)
end

local function vel(u: Unit): Vector3
	if u.flight then
		return u.flight.vel
	end
	return u.root.AssemblyLinearVelocity
end

local function explode(model: Model)
	local root = model.PrimaryPart
	if not root then
		model:Destroy()
		return
	end
	local pos = root.Position
	local v = root.AssemblyLinearVelocity * 0.25
	local ex = Instance.new("Explosion")
	ex.Position = pos
	ex.BlastRadius = 0
	ex.BlastPressure = 0
	ex.DestroyJointRadiusPercent = 0
	ex.Parent = workspace
	local fire = Instance.new("Part")
	fire.Anchored, fire.CanCollide, fire.CanQuery, fire.CanTouch = true, false, false, false
	fire.Transparency = 1
	fire.Size = Vector3.one
	fire.Position = Vector3.new(pos.X, math.max(pos.Y, World.SEA + 1), pos.Z)
	local sm = Instance.new("Smoke")
	sm.Size = 30
	sm.RiseVelocity = 14
	sm.Color = Color3.fromRGB(40, 40, 40)
	sm.Parent = fire
	local fl = Instance.new("Fire")
	fl.Size = 18
	fl.Parent = fire
	fire.Parent = workspace
	Debris:AddItem(fire, 8)
	model.Name = "Wreck"
	for _, d in model:GetDescendants() do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Seat") or d:IsA("BillboardGui") or d:IsA("Trail") then
			d:Destroy()
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = true
			d.CollisionGroup = DEBRIS
			d.AssemblyLinearVelocity = v + Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.2, 1.4), rng:NextNumber(-1, 1)) * rng:NextNumber(20, 90)
		end
	end
	Debris:AddItem(model, 7)
end

local function removeUnit(u: Unit, blowUp: boolean)
	if not u.alive then
		return
	end
	u.alive = false
	units[u.model] = nil
	if u.player and byPlayer[u.player] == u then
		byPlayer[u.player] = nil
	end
	for _, c in u.conns do
		c:Disconnect()
	end
	if blowUp then
		explode(u.model)
	else
		u.model:Destroy()
	end
	local p = u.player
	if p and p.Parent then
		task.delay(0.2, function()
			if p.Parent and not byPlayer[p] then
				p:LoadCharacter()
			end
		end)
	end
end

local function loseTickets(side: string, n: number)
	tickets[side] -= n
	publish()
end

-- урон; attacker = кто стрелял (для счёта)
local function damage(victim: Unit, dmg: number, attacker: Unit?, weapon: string)
	if not victim.alive or victim.born + 3 > os.clock() then
		return -- 3 с неуязвимости после появления
	end
	victim.hp -= dmg
	setAttrs(victim)
	if attacker and attacker.player then
		HitR:FireClient(attacker.player, victim.model, victim.hp <= 0)
	end
	if victim.hp > 0 then
		return
	end
	local by = if attacker then attacker.name else "ПВО"
	FeedR:FireAllClients(string.format("%s  [%s]  %s", by, weapon, victim.name), if attacker then attacker.side else "", victim.side)
	if attacker then
		addStat(attacker.player, "Сбито", 1)
	end
	addStat(victim.player, "Потери", 1)
	loseTickets(victim.side, 3)
	if victim.player then
		KilledR:FireClient(victim.player, "Сбит: " .. by .. " (" .. weapon .. ")")
	end
	removeUnit(victim, true)
end

-- ===== появление
local function spawnAllowed(side: string, spawnId: string): boolean
	local kind, arg = spawnId:match("^(%a+):(%w+)$")
	if kind == "deck" or kind == "air" then
		return arg == side
	elseif kind == "base" and arg then
		return bases[arg] ~= nil and bases[arg].owner == side
	end
	return false
end

local function slotFor(spawnId: string, cfg: any): (CFrame?, boolean)
	for s = 1, 8 do
		local cf, air = World.spawnCFrame(spawnId, cfg, s)
		if not cf then
			return nil, false
		end
		local free = true
		for _, u in units do
			if (u.root.Position - cf.Position).Magnitude < 45 then
				free = false
				break
			end
		end
		if free then
			return cf, air
		end
	end
	return World.spawnCFrame(spawnId, cfg, 1)
end

local function teamTint(cfg: any, side: string): any
	local c = table.clone(cfg)
	c.colors = table.clone(cfg.colors)
	c.colors.tail = if side == "Blue" then Color3.fromRGB(46, 104, 170) else Color3.fromRGB(170, 52, 46)
	c.colors.accent = c.colors.tail
	return c
end

local function makeUnit(cfg: any, side: string, name: string, cf: CFrame, seat: boolean): Unit
	local model = PlaneBuilder.build(teamTint(cfg, side), { seat = seat, label = name })
	model:SetAttribute("Side", side)
	model:SetAttribute("Pilot", name)
	model:SetAttribute("Gear", true)
	model:SetAttribute("Throttle", 0)
	model:PivotTo(cf)
	local tag = model.PrimaryPart and model.PrimaryPart:FindFirstChild("Tag")
	local lbl = tag and tag:FindFirstChildOfClass("TextLabel")
	if lbl then
		lbl.TextColor3 = World.TEAM_COLOR[side]
	end
	local root = model.PrimaryPart :: BasePart
	root.Anchored = true
	setGroup(model, FLYING)
	local u: Unit = {
		model = model, root = root, side = side, cfg = cfg, name = name,
		hp = cfg.hp, maxHp = cfg.hp, missiles = cfg.missiles, flares = Jets.FLARES,
		flareUntil = 0, lastShot = 0, lastMsl = 0, lastRearm = 0,
		alive = true, ready = false, born = os.clock(), conns = {},
	}
	setAttrs(u)
	model.Parent = planes
	units[model] = u
	return u
end

local lastSpawn: { [Player]: number } = {}
SpawnR.OnServerEvent:Connect(function(p, jetId, spawnId)
	if type(jetId) ~= "string" or type(spawnId) ~= "string" then
		return
	end
	local cfg = Jets.JETS[jetId]
	local side = sideOf(p)
	if not cfg or not spawnAllowed(side, spawnId) or byPlayer[p] then
		return
	end
	local now = os.clock()
	if lastSpawn[p] and now - lastSpawn[p] < 2 then
		return
	end
	lastSpawn[p] = now
	local cf, air = slotFor(spawnId, cfg)
	if not cf then
		return
	end
	local ch = p.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		p:LoadCharacter()
		ch = p.Character or p.CharacterAdded:Wait()
		hum = (ch :: Model):WaitForChild("Humanoid", 5) :: Humanoid?
	end
	if not hum or not p.Parent or byPlayer[p] then
		return
	end
	local u = makeUnit(cfg, side, p.DisplayName, cf, true)
	u.player = p
	u.model.Name = p.Name .. "_Jet"
	u.model:SetAttribute("Owner", p.UserId)
	u.model:SetAttribute("Gear", not air)
	byPlayer[p] = u
	for _, d in (ch :: Model):GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = FLYING
		end
	end
	local seat = u.model:FindFirstChild("PilotSeat") :: Seat
	seat:Sit(hum)
	table.insert(u.conns, hum.Died:Connect(function()
		removeUnit(u, true)
	end))
	StartedR:FireClient(p, u.model, jetId, cf, air)
end)

ReadyR.OnServerEvent:Connect(function(p, model)
	local u = byPlayer[p]
	if not u or u.ready or model ~= u.model then
		return
	end
	u.ready = true
	u.root.Anchored = false
	pcall(function()
		u.root:SetNetworkOwner(p)
	end)
end)

StateR.OnServerEvent:Connect(function(p, gear, throttle)
	local u = byPlayer[p]
	if u and type(gear) == "boolean" and type(throttle) == "number" then
		u.model:SetAttribute("Gear", gear)
		u.model:SetAttribute("Throttle", math.clamp(throttle, 0, 1))
	end
end)

-- ===== пушка: клиент сообщает о выстреле и (если попал) о цели; сервер проверяет дистанцию, угол и темп
local function inCone(from: Unit, to: Vector3, deg: number, range: number): boolean
	local d = to - from.root.Position
	local dist = d.Magnitude
	if dist > range or dist < 1 then
		return false
	end
	return from.root.CFrame.LookVector:Dot(d / dist) >= math.cos(math.rad(deg))
end

local function shoot(u: Unit, target: Unit?)
	local now = os.clock()
	if now - u.lastShot < Jets.GUN_RATE * 0.8 then
		return
	end
	u.lastShot = now
	u.model:SetAttribute("FiringUntil", workspace:GetServerTimeNow() + 0.2)
	-- запас по углу и дальности на сетевую задержку
	if target and target.alive and target.side ~= u.side and inCone(u, target.root.Position, Jets.GUN_CONE * 2.2, Jets.GUN_RANGE * 1.15) then
		damage(target, Jets.GUN_DMG, u, "пушка")
	end
end

GunR.OnServerEvent:Connect(function(p, target)
	local u = byPlayer[p]
	if not u or not u.ready then
		return
	end
	local t = if typeof(target) == "Instance" then units[target :: any] else nil
	shoot(u, t)
end)

-- ===== ракеты (летят на сервере)
type Missile = { part: BasePart, owner: Unit, target: Unit, dir: Vector3, t: number, decoy: Vector3?, flareChecked: number }
local missiles: { Missile } = {}

local function launch(u: Unit, target: Unit): boolean
	local now = os.clock()
	if u.missiles <= 0 or now - u.lastMsl < 1 or not target.alive or target.side == u.side then
		return false
	end
	if not inCone(u, target.root.Position, Jets.MSL_CONE * 1.6, Jets.MSL_RANGE * 1.15) then
		return false
	end
	u.lastMsl = now
	u.missiles -= 1
	setAttrs(u)
	local part = Instance.new("Part")
	part.Name = "Missile"
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	part.Size = Vector3.new(0.9, 0.9, 9)
	part.Color = Color3.fromRGB(230, 230, 230)
	part.Material = Enum.Material.Metal
	local start = u.root.CFrame * CFrame.new(0, -3, -u.cfg.length * 0.3)
	part.CFrame = start
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.3, 4.5)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.3, 4.5)
	a1.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime = 1.6
	trail.WidthScale = NumberSequence.new(3, 9)
	trail.Color = ColorSequence.new(Color3.fromRGB(240, 240, 240))
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.FaceCamera = true
	trail.Parent = part
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 170, 80)
	glow.Range = 20
	glow.Parent = part
	part:SetAttribute("Side", u.side)
	part.Parent = missilesFolder
	table.insert(missiles, { part = part, owner = u, target = target, dir = start.LookVector, t = 0, decoy = nil, flareChecked = 0 })
	if target.player then
		WarnR:FireClient(target.player, part)
	end
	return true
end

MissileR.OnServerEvent:Connect(function(p, target)
	local u = byPlayer[p]
	local t = if typeof(target) == "Instance" then units[target :: any] else nil
	if u and u.ready and t then
		launch(u, t)
	end
end)

local function flare(u: Unit)
	if u.flares <= 0 or os.clock() < u.flareUntil - Jets.FLARE_TIME + 0.6 then
		return
	end
	u.flares -= 1
	u.flareUntil = os.clock() + Jets.FLARE_TIME
	setAttrs(u)
	u.model:SetAttribute("FlareAt", workspace:GetServerTimeNow())
end
FlareR.OnServerEvent:Connect(function(p)
	local u = byPlayer[p]
	if u then
		flare(u)
	end
end)

local function stepMissiles(dt: number)
	for i = #missiles, 1, -1 do
		local m = missiles[i]
		m.t += dt
		local tg = m.target
		local pos = m.part.Position
		local done = m.t > Jets.MSL_LIFE or not tg.alive
		if not done then
			-- ловушки: ракета проверяет каждую новую порцию ловушек один раз
			if tg.flareUntil > os.clock() and m.flareChecked ~= tg.flareUntil and not m.decoy then
				m.flareChecked = tg.flareUntil
				if rng:NextNumber() < Jets.FLARE_CHANCE then
					m.decoy = tg.root.Position - tg.root.CFrame.LookVector * 60 + Vector3.new(0, -30, 0)
				end
			end
			local aim = if m.decoy then m.decoy else Bots.lead(pos, tg.root.Position, vel(tg), Jets.MSL_SPEED)
			local want = (aim - pos)
			if want.Magnitude > 1 then
				want = want.Unit
				local ang = math.acos(math.clamp(m.dir:Dot(want), -1, 1))
				local maxA = Jets.MSL_TURN * dt
				if ang > 1e-4 then
					local k = math.min(1, maxA / ang)
					m.dir = m.dir:Lerp(want, k).Unit
				end
			end
			local np = pos + m.dir * Jets.MSL_SPEED * dt
			m.part.CFrame = CFrame.lookAt(np, np + m.dir)
			if not m.decoy and (tg.root.Position - np).Magnitude < 55 then
				damage(tg, Jets.MSL_DMG, m.owner, "ракета")
				done = true
			elseif m.decoy and (m.decoy - np).Magnitude < 40 then
				done = true
			elseif np.Y < math.max(World.groundAt(np.X, np.Z), World.SEA) then
				done = true
			end
		end
		if done then
			local ex = Instance.new("Explosion")
			ex.Position = m.part.Position
			ex.BlastRadius = 0
			ex.BlastPressure = 0
			ex.Parent = workspace
			m.part.Anchored = true
			m.part.Transparency = 1
			Debris:AddItem(m.part, 1.7)
			table.remove(missiles, i)
		end
	end
end

-- ===== крушение, перевооружение, выход
CrashR.OnServerEvent:Connect(function(p, reason)
	local u = byPlayer[p]
	if not u then
		return
	end
	local r = if type(reason) == "string" then reason:sub(1, 80) else "Крушение"
	FeedR:FireAllClients(string.format("%s  [%s]", u.name, r), "", u.side)
	addStat(p, "Потери", 1)
	loseTickets(u.side, 2)
	removeUnit(u, true)
end)

RearmR.OnServerEvent:Connect(function(p)
	local u = byPlayer[p]
	if not u or not u.ready or os.clock() - u.lastRearm < 2 then
		return
	end
	-- только на своей палубе / своей полосе и почти без скорости
	local pos = u.root.Position
	local where = World.runwayAt(pos.X, pos.Z, 10)
	local mine = where == World.carrierOf(u.side).id or (where ~= nil and bases[where] ~= nil and bases[where].owner == u.side)
	if not mine or u.root.AssemblyLinearVelocity.Magnitude > 25 then
		return
	end
	u.lastRearm = os.clock()
	local before = u.hp + u.missiles + u.flares
	u.hp = math.min(u.maxHp, u.hp + 30)
	u.missiles = u.cfg.missiles
	u.flares = Jets.FLARES
	setAttrs(u)
	if u.hp + u.missiles + u.flares > before then
		NotifyR:FireClient(p, "Ремонт и перезарядка…", "cyan")
	end
end)

LeaveR.OnServerEvent:Connect(function(p)
	local u = byPlayer[p]
	if u then
		removeUnit(u, false)
	end
end)

Players.PlayerAdded:Connect(function(p)
	stats(p)
end)
for _, p in Players:GetPlayers() do
	stats(p)
end
Players.PlayerRemoving:Connect(function(p)
	local u = byPlayer[p]
	if u then
		removeUnit(u, false)
	end
	lastSpawn[p] = nil
end)

-- ===== боты
local BOT_NAMES = { "Сокол", "Гроза", "Вихрь", "Беркут", "Кобра", "Тайфун", "Ястреб", "Шторм", "Молния", "Стриж" }
local botSeq = 0
local function spawnBot(side: string)
	botSeq += 1
	local id = Jets.ORDER[rng:NextInteger(1, #Jets.ORDER)]
	local cfg = Jets.JETS[id]
	local cf = World.spawnCFrame("air:" .. side, cfg, rng:NextInteger(1, 4)) :: CFrame
	cf = cf + Vector3.new(rng:NextNumber(-300, 300), rng:NextNumber(0, 400), rng:NextNumber(-300, 300))
	local u = makeUnit(cfg, side, "[ИИ] " .. BOT_NAMES[(botSeq - 1) % #BOT_NAMES + 1], cf, false)
	u.flight = FlightPhysics.new(cfg, cf, true)
	u.bot = { skill = rng:NextNumber(0.3, 0.9), target = nil :: Unit?, goal = nil :: string?, retarget = 0, lastMsl = os.clock() + 6, aimErr = rng:NextNumber(0.5, 1.5), stuck = 0 }
	u.ready = true
	u.model:SetAttribute("Gear", false)
	u.model:SetAttribute("Throttle", 0.85)
end

local function playersOn(side: string): number
	local n = 0
	for _, p in Players:GetPlayers() do
		if sideOf(p) == side then
			n += 1
		end
	end
	return n
end

local function botCount(side: string): number
	local n = 0
	for _, u in units do
		if u.bot and u.side == side then
			n += 1
		end
	end
	return n
end

local function nearestEnemy(u: Unit, maxDist: number): Unit?
	local best, bd = nil, maxDist
	for _, o in units do
		if o.alive and o.side ~= u.side and o.ready then
			local d = (o.root.Position - u.root.Position).Magnitude
			if d < bd then
				best, bd = o, d
			end
		end
	end
	return best
end

local function botGoal(u: Unit): Vector3
	-- ближайшая чужая или нейтральная база; если все наши — к авианосцу врага
	local best, bd = nil, math.huge
	for _, i in World.ISLANDS do
		if bases[i.id].owner ~= u.side then
			local d = (Vector3.new(i.x, 0, i.z) - u.root.Position).Magnitude
			if d < bd then
				best, bd = i, d
			end
		end
	end
	if best then
		return Vector3.new(best.x, best.h + 420, best.z)
	end
	local c = World.carrierOf(other(u.side))
	return c.cf.Position + Vector3.new(0, 1500, 0)
end

local function stepBot(u: Unit, dt: number)
	local f = u.flight
	local b = u.bot
	b.retarget -= dt
	if b.retarget <= 0 then
		b.retarget = 1.5
		b.target = nearestEnemy(u, 6500)
	end
	local tg: Unit? = b.target
	if tg and not tg.alive then
		tg = nil
		b.target = nil
	end
	local dir: Vector3
	if tg then
		local aim = Bots.lead(f.pos, tg.root.Position, vel(tg), math.max(f.speed, 300) + 900)
		dir = (aim - f.pos).Unit
		-- огонь
		local d = (tg.root.Position - f.pos).Magnitude
		local cosA = f.att.LookVector:Dot(dir)
		if d < Jets.GUN_RANGE * 0.85 and cosA > math.cos(math.rad(Jets.GUN_CONE * b.aimErr)) then
			if rng:NextNumber() < 0.45 * (0.6 + b.skill * 0.6) then
				shoot(u, tg)
			else
				shoot(u, nil)
			end
		end
		if u.missiles > 0 and d < Jets.MSL_RANGE * 0.8 and d > 900 and cosA > math.cos(math.rad(Jets.MSL_CONE * 0.6)) and os.clock() > b.lastMsl then
			if launch(u, tg) then
				b.lastMsl = os.clock() + rng:NextNumber(8, 16)
			end
		end
	else
		dir = (botGoal(u) - f.pos)
		dir = if dir.Magnitude > 1 then dir.Unit else f.att.LookVector
	end
	-- уклонение: ракета летит в бота — ловушки и резкий вираж
	for _, m in missiles do
		if m.target == u and not m.decoy and (m.part.Position - f.pos).Magnitude < 2500 then
			if rng:NextNumber() < 0.04 + b.skill * 0.04 then
				flare(u)
			end
			dir = (dir + f.att.RightVector * 1.5).Unit
			break
		end
	end
	local input = Bots.steer(f, dir, b.skill)
	FlightPhysics.step(f, input, dt)
	if f.crashed then
		FeedR:FireAllClients(string.format("%s  [%s]", u.name, f.crashReason or "крушение"), "", u.side)
		loseTickets(u.side, 2)
		removeUnit(u, true)
		return
	end
	u.root.CFrame = FlightPhysics.pose(f)
end

-- ===== главный цикл
local capAcc, bleedAcc, botAcc = 0, 0, 0
local roundOver = false

local function endRound(winner: string)
	roundOver = true
	FeedR:FireAllClients("ПОБЕДА: " .. World.TEAM_NAME[winner] .. "! Новый раунд через 15 с", winner, "")
	NotifyR:FireAllClients("Раунд окончен — победили " .. World.TEAM_NAME[winner], if winner == "Blue" then "cyan" else "red")
	task.delay(15, function()
		for _, u in units do
			if u.player then
				KilledR:FireClient(u.player, "Новый раунд")
			end
			removeUnit(u, false)
		end
		for _, m in missiles do
			m.part:Destroy()
		end
		table.clear(missiles)
		tickets.Blue, tickets.Red = Jets.TICKETS, Jets.TICKETS
		resetBases()
		publish()
		roundOver = false
	end)
end

RunService.Heartbeat:Connect(function(dt)
	dt = math.min(dt, 0.1)
	for _, u in units do
		if u.bot and u.alive then
			stepBot(u, dt)
		end
	end
	stepMissiles(dt)

	-- вне зоны боя — урон; ниже палубы игрок проверяется на клиенте
	capAcc += dt
	if capAcc >= 0.5 then
		local step = capAcc
		capAcc = 0
		for _, u in units do
			local p = u.root.Position
			if u.alive and (math.abs(p.X) > World.SIZE or math.abs(p.Z) > World.SIZE) then
				u.born = 0
				damage(u, 6 * step, nil, "вне зоны")
			end
		end
		-- захват баз: кто держит самолёты низко над островом
		for _, i in World.ISLANDS do
			local nb, nr = 0, 0
			for _, u in units do
				if u.alive and u.ready then
					local p = u.root.Position
					local dx, dz = p.X - i.x, p.Z - i.z
					if dx * dx + dz * dz < World.CAPTURE_R * World.CAPTURE_R and p.Y < i.h + World.CAPTURE_ALT then
						if u.side == "Blue" then
							nb += 1
						else
							nr += 1
						end
					end
				end
			end
			local b = bases[i.id]
			if nb ~= nr then
				local was = b.owner
				b.cap = math.clamp(b.cap + (nb - nr) * 0.045 * step / 0.5, -1, 1)
				if b.cap >= 1 then
					b.owner = "Blue"
				elseif b.cap <= -1 then
					b.owner = "Red"
				elseif (b.owner == "Blue" and b.cap <= 0) or (b.owner == "Red" and b.cap >= 0) then
					b.owner = ""
				end
				if b.owner ~= was then
					WorldBuilder.setOwner(i.id, b.owner)
					if b.owner ~= "" then
						FeedR:FireAllClients(string.format("%s захватили базу «%s»", World.TEAM_NAME[b.owner], i.name), b.owner, "")
						for _, u in units do
							if u.player and u.side == b.owner then
								local p = u.root.Position
								if (Vector3.new(p.X - i.x, 0, p.Z - i.z)).Magnitude < World.CAPTURE_R then
									addStat(u.player, "Базы", 1)
								end
							end
						end
					else
						FeedR:FireAllClients(string.format("База «%s» стала нейтральной", i.name), "", "")
					end
				end
			end
		end
		publish()
	end

	-- у кого меньше баз — теряет очки
	bleedAcc += dt
	if bleedAcc >= Jets.BLEED_EVERY and not roundOver then
		bleedAcc = 0
		local nb, nr = 0, 0
		for _, b in bases do
			if b.owner == "Blue" then
				nb += 1
			elseif b.owner == "Red" then
				nr += 1
			end
		end
		if nb > nr then
			loseTickets("Red", nb - nr)
		elseif nr > nb then
			loseTickets("Blue", nr - nb)
		end
	end
	if not roundOver then
		if tickets.Blue <= 0 then
			endRound("Red")
		elseif tickets.Red <= 0 then
			endRound("Blue")
		end
	end

	-- держим нужное число ботов
	botAcc += dt
	if botAcc >= 3 and not roundOver then
		botAcc = 0
		for _, side in { "Blue", "Red" } do
			local want = math.max(0, Jets.BOTS_PER_TEAM - playersOn(side))
			local have = botCount(side)
			if have < want then
				spawnBot(side)
			elseif have > want then
				for _, u in units do
					if u.bot and u.side == side then
						removeUnit(u, false)
						break
					end
				end
			end
		end
	end
end)
