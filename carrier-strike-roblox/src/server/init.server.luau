--!strict
-- Carrier Strike — сервер: команды, вылеты, бой (пушка и ракеты проверяются здесь),
-- захват островов, очки команд, боты, прогресс (монеты, опыт, самолёты, раскраски),
-- ежедневные награды и задания, серии сбитий, MVP раунда, недельный топ, VIP и покупки.
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")
local Debris = game:GetService("Debris")
local MarketplaceService = game:GetService("MarketplaceService")
local BadgeService = game:GetService("BadgeService")

local Shared = ReplicatedStorage:WaitForChild("CarrierStrike")
local World = require(Shared:WaitForChild("World"))
local Jets = require(Shared:WaitForChild("Jets"))
local Progress = require(Shared:WaitForChild("Progress"))
local Config = require(Shared:WaitForChild("Config"))
local FlightPhysics = require(Shared:WaitForChild("FlightPhysics"))
local PlaneBuilder = require(Shared:WaitForChild("PlaneBuilder"))
local WorldBuilder = require(script:WaitForChild("WorldBuilder"))
local Bots = require(script:WaitForChild("Bots"))
local Data = require(script:WaitForChild("Data"))

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
local SpawnR = remote("Spawn") -- клиент → сервер: (jetId, spawnId, paintId)
local StartedR = remote("Started") -- сервер → клиент: (model, jetId, spawnCF, air)
local ReadyR = remote("Ready")
local StateR = remote("State") -- (gear, throttle)
local GunR = remote("Gun") -- (target|nil)
local MissileR = remote("Missile") -- (target)
local FlareR = remote("Flare")
local CrashR = remote("Crash") -- (kind: "water" | "carrier" | "ground")
local RearmR = remote("Rearm")
local LeaveR = remote("Leave")
local KilledR = remote("Killed") -- сервер → клиент: (killerName | "", weapon)
local NotifyR = remote("Notify") -- (key, color, ...)
local FeedR = remote("Feed") -- всем: (kind, data)
local WarnR = remote("Warn") -- цели: ракета летит (missile part)
local HitR = remote("Hit") -- стрелку: попадание (model, kill)
local ProfileR = remote("Profile") -- сервер → клиент: снимок прогресса
local RewardR = remote("Reward") -- сервер → клиент: (coins, xp, key)
local BuyR = remote("Buy") -- клиент → сервер: (kind "jet"|"paint", id)
local DailyR = remote("ClaimDaily")
local TutR = remote("TutorialDone")
local RoundR = remote("RoundEnd") -- всем: (winner, mvp list)
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
for _, t in { { "Blue", "Blue", BrickColor.new("Bright blue") }, { "Red", "Red", BrickColor.new("Bright red") } } do
	local team = Instance.new("Team")
	team.Name = t[2]
	team.TeamColor = t[3]
	team.AutoAssignable = true
	team:SetAttribute("Side", t[1])
	team.Parent = Teams
	TEAM[t[1]] = team
	-- персонаж появляется на палубе своего авианосца (в бою он сидит в кабине)
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

-- =====================================================================
-- ПРОГРЕСС ИГРОКА
-- =====================================================================
local vip: { [Player]: boolean } = {}
local friendBonus: { [Player]: boolean } = {}
type RoundStat = { kills: number, caps: number, assists: number, score: number }
local roundStats: { [Player]: RoundStat } = {}

local function rs(p: Player): RoundStat
	local s = roundStats[p]
	if not s then
		s = { kills = 0, caps = 0, assists = 0, score = 0 }
		roundStats[p] = s
	end
	return s
end

local function badge(p: Player, name: string)
	local id = (Config.BADGES :: any)[name]
	if type(id) == "number" and id > 0 then
		task.spawn(function()
			pcall(function()
				if not BadgeService:UserHasBadgeAsync(p.UserId, id) then
					BadgeService:AwardBadge(p.UserId, id)
				end
			end)
		end)
	end
end

local function todayQuests(p: Player, d: any)
	local day = Progress.day()
	if d.quests.day ~= day then
		d.quests.day = day
		d.quests.list = {}
		for _, id in Progress.questsFor(day, p.UserId) do
			table.insert(d.quests.list, { id = id, p = 0, done = false })
		end
	end
end

local function snapshot(p: Player): any
	local d = Data.get(p)
	if not d then
		return nil
	end
	todayQuests(p, d)
	local day = Progress.day()
	local can = d.daily.last ~= day
	local streak = if d.daily.last == day - 1 or d.daily.last == day then d.daily.streak else 0
	local nextIdx = if can then (streak % #Progress.DAILY) + 1 else ((streak - 1) % #Progress.DAILY) + 1
	local qs = {}
	for _, q in d.quests.list do
		local def = Progress.quest(q.id)
		if def then
			table.insert(qs, { id = q.id, n = def.n, p = math.min(q.p, def.n), done = q.done, reward = def.reward })
		end
	end
	return {
		coins = d.coins, xp = d.xp, owned = d.owned, paints = d.paints, jet = d.jet, paint = d.paint,
		vip = vip[p] == true, tut = d.tut, stats = d.stats,
		daily = { can = can, streak = streak, idx = nextIdx },
		quests = qs, week = if d.week.id == Progress.week() then d.week.kills else 0,
		shop = { vip = Config.VIP_PASS_ID, coins = Config.COIN_PRODUCTS },
	}
end
local function sendProfile(p: Player)
	local s = snapshot(p)
	if s then
		ProfileR:FireClient(p, s)
	end
end

-- начислить монеты и опыт; key — за что (для всплывающей подписи)
local function give(p: Player?, coins: number, xp: number, key: string)
	if not p then
		return
	end
	local d = Data.get(p)
	if not d then
		return
	end
	local mul = (if vip[p] then 2 else 1) * (if friendBonus[p] then 1.2 else 1)
	local c = math.floor(coins * mul + 0.5)
	local before = Progress.levelOf(d.xp)
	d.coins += c
	d.xp += xp
	Data.mark(p)
	RewardR:FireClient(p, c, xp, key)
	local after = Progress.levelOf(d.xp)
	if after > before then
		NotifyR:FireClient(p, "levelup", "amber", after)
		if after >= 10 then
			badge(p, "level10")
		end
	end
	sendProfile(p)
end
local function reward(p: Player?, kind: string)
	local r = Progress.REWARD[kind]
	if r then
		give(p, r[1], r[2], kind)
	end
end

-- продвинуть ежедневное задание
local function quest(p: Player?, id: string, n: number)
	if not p then
		return
	end
	local d = Data.get(p)
	if not d then
		return
	end
	todayQuests(p, d)
	for _, q in d.quests.list do
		if q.id == id and not q.done then
			local def = Progress.quest(id)
			q.p += n
			if def and q.p >= def.n then
				q.done = true
				give(p, def.reward, 100, "quest_" .. id)
				NotifyR:FireClient(p, "quest_done", "green")
			end
			Data.mark(p)
		end
	end
end

local function stat(p: Player?, name: string, n: number)
	local d = p and Data.get(p)
	if d then
		d.stats[name] = (d.stats[name] or 0) + n
		if name == "kills" then
			local wk = Progress.week()
			if d.week.id ~= wk then
				d.week.id = wk
				d.week.kills = 0
			end
			d.week.kills += n
		end
		Data.mark(p :: Player)
	end
end

-- ===== счёт в списке игроков (Tab)
local function leaderstats(p: Player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	for _, n in { "Kills", "Level" } do
		local v = Instance.new("IntValue")
		v.Name = n
		v.Parent = ls
	end
	ls.Parent = p
end
local function setLS(p: Player)
	local d = Data.get(p)
	local ls = p:FindFirstChild("leaderstats")
	if d and ls then
		(ls:FindFirstChild("Kills") :: IntValue).Value = (roundStats[p] and roundStats[p].kills) or 0;
		(ls:FindFirstChild("Level") :: IntValue).Value = (Progress.levelOf(d.xp))
	end
end

-- =====================================================================
-- БОЕВЫЕ ЕДИНИЦЫ (игроки и боты)
-- =====================================================================
type Unit = {
	model: Model, root: BasePart, side: string, cfg: any, name: string,
	player: Player?, bot: any?, flight: any?,
	hp: number, maxHp: number, missiles: number, flares: number,
	flareUntil: number, lastShot: number, lastMsl: number, lastRearm: number,
	alive: boolean, ready: boolean, born: number, conns: { RBXScriptConnection },
	dmgBy: { [any]: number }, streak: number, kills: number, airborne: boolean,
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

-- урон; attacker = кто стрелял
local function damage(victim: Unit, dmg: number, attacker: Unit?, weapon: string)
	if not victim.alive or victim.born + 3 > os.clock() then
		return -- 3 с неуязвимости после появления
	end
	victim.hp -= dmg
	if attacker then
		victim.dmgBy[attacker] = (victim.dmgBy[attacker] or 0) + dmg
	end
	setAttrs(victim)
	if attacker and attacker.player then
		HitR:FireClient(attacker.player, victim.model, victim.hp <= 0)
	end
	if victim.hp > 0 then
		return
	end
	FeedR:FireAllClients("kill", { k = if attacker then attacker.name else "", ks = if attacker then attacker.side else "", w = weapon, v = victim.name, vs = victim.side })
	if attacker then
		attacker.kills += 1
		attacker.streak += 1
		local ap = attacker.player
		if ap then
			reward(ap, "kill")
			stat(ap, "kills", 1)
			quest(ap, "kills", 1)
			quest(ap, if weapon == "msl" then "msl" else "gun", 1)
			local r = rs(ap)
			r.kills += 1
			r.score += 100
			setLS(ap)
			badge(ap, "first_kill")
			if attacker.kills == 5 then
				badge(ap, "ace")
			end
			local bonus = Progress.STREAK[attacker.streak]
			if bonus then
				give(ap, bonus, bonus, "streak")
				FeedR:FireAllClients("streak", { n = attacker.streak, k = attacker.name, ks = attacker.side })
			end
		end
	end
	-- помощь: игроки, нанёсшие ≥25 урона, но не добившие
	for who, d in victim.dmgBy do
		local wu = who :: Unit
		if wu ~= attacker and d >= 25 and wu.player then
			reward(wu.player, "assist")
			stat(wu.player, "assists", 1)
			quest(wu.player, "assists", 1)
			local r = rs(wu.player)
			r.assists += 1
			r.score += 40
		end
	end
	stat(victim.player, "deaths", 1)
	loseTickets(victim.side, 3)
	if victim.player then
		KilledR:FireClient(victim.player, if attacker then attacker.name else "", weapon)
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

local function paintCfg(cfg: any, side: string, paintId: string?): any
	local c = table.clone(cfg)
	c.colors = table.clone(cfg.colors)
	local team = if side == "Blue" then Color3.fromRGB(46, 104, 170) else Color3.fromRGB(170, 52, 46)
	local pt = paintId and Progress.paint(paintId)
	if pt and pt.body then
		c.colors.body = pt.body
		c.colors.accent = pt.accent
	else
		c.colors.accent = team
	end
	c.colors.tail = team -- киль всегда цвета команды
	return c
end

local function makeUnit(cfg: any, side: string, name: string, cf: CFrame, seat: boolean, paintId: string?): Unit
	local model = PlaneBuilder.build(paintCfg(cfg, side, paintId), { seat = seat, label = name })
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
		dmgBy = {}, streak = 0, kills = 0, airborne = false,
	}
	setAttrs(u)
	model.Parent = planes
	units[model] = u
	return u
end

local function ownsJet(p: Player, jetId: string): boolean
	local d = Data.get(p)
	return d ~= nil and d.owned[jetId] == true
end
local function ownsPaint(p: Player, paintId: string): boolean
	local d = Data.get(p)
	local pt = Progress.paint(paintId)
	if not d or not pt then
		return false
	end
	if pt.vip then
		return vip[p] == true
	end
	return d.paints[paintId] == true
end

local lastSpawn: { [Player]: number } = {}
SpawnR.OnServerEvent:Connect(function(p, jetId, spawnId, paintId)
	if type(jetId) ~= "string" or type(spawnId) ~= "string" then
		return
	end
	local cfg = Jets.JETS[jetId]
	local side = sideOf(p)
	if not cfg or not spawnAllowed(side, spawnId) or byPlayer[p] or not ownsJet(p, jetId) then
		return
	end
	local paint = if type(paintId) == "string" and ownsPaint(p, paintId) then paintId else "team"
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
	local label = if vip[p] then "★ " .. p.DisplayName else p.DisplayName
	local u = makeUnit(cfg, side, label, cf, true, paint)
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
	local d = Data.get(p)
	if d then
		d.jet = jetId
		d.paint = paint
	end
	stat(p, "sorties", 1)
	quest(p, "sorties", 1)
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
	-- запас по углу (помощь прицеливания на телефоне) и по дальности (сетевая задержка)
	if target and target.alive and target.side ~= u.side and inCone(u, target.root.Position, math.max(Jets.GUN_CONE, Jets.GUN_CONE_TOUCH) * 2, Jets.GUN_RANGE * 1.15) then
		damage(target, Jets.GUN_DMG, u, "gun")
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
					m.dir = m.dir:Lerp(want, math.min(1, maxA / ang)).Unit
				end
			end
			local np = pos + m.dir * Jets.MSL_SPEED * dt
			m.part.CFrame = CFrame.lookAt(np, np + m.dir)
			if not m.decoy and (tg.root.Position - np).Magnitude < 55 then
				damage(tg, Jets.MSL_DMG, m.owner, "msl")
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
			m.part.Transparency = 1
			Debris:AddItem(m.part, 1.7)
			table.remove(missiles, i)
		end
	end
end

-- ===== крушение, перевооружение, выход
CrashR.OnServerEvent:Connect(function(p, kind)
	local u = byPlayer[p]
	if not u then
		return
	end
	local why = if kind == "water" or kind == "carrier" or kind == "ground" then kind else "ground"
	FeedR:FireAllClients("crash", { v = u.name, vs = u.side, why = why })
	stat(p, "deaths", 1)
	loseTickets(u.side, 2)
	removeUnit(u, true)
end)

RearmR.OnServerEvent:Connect(function(p)
	local u = byPlayer[p]
	if not u or not u.ready or os.clock() - u.lastRearm < 2 then
		return
	end
	local pos = u.root.Position
	local where = World.runwayAt(pos.X, pos.Z, 10)
	local onCarrier = where == World.carrierOf(u.side).id
	local mine = onCarrier or (where ~= nil and bases[where] ~= nil and bases[where].owner == u.side)
	if not mine or u.root.AssemblyLinearVelocity.Magnitude > 25 then
		return
	end
	u.lastRearm = os.clock()
	-- посадка на палубу после вылета: награда и задание
	if onCarrier and u.airborne then
		u.airborne = false
		reward(p, "landing")
		quest(p, "deck", 1)
	end
	local before = u.hp + u.missiles + u.flares
	u.hp = math.min(u.maxHp, u.hp + 30)
	u.missiles = u.cfg.missiles
	u.flares = Jets.FLARES
	setAttrs(u)
	if u.hp + u.missiles + u.flares > before then
		NotifyR:FireClient(p, "rearm", "cyan")
	end
end)

LeaveR.OnServerEvent:Connect(function(p)
	local u = byPlayer[p]
	if u then
		removeUnit(u, false)
	end
end)

-- ===== магазин: самолёты и раскраски за монеты
BuyR.OnServerEvent:Connect(function(p, kind, id)
	local d = Data.get(p)
	if not d or type(id) ~= "string" then
		return
	end
	local level = Progress.levelOf(d.xp)
	if kind == "jet" then
		local j = Progress.JETS[id]
		if not j or d.owned[id] then
			return
		end
		if level < j.level then
			NotifyR:FireClient(p, "need_level", "amber", j.level)
		elseif d.coins < j.cost then
			NotifyR:FireClient(p, "need_coins", "amber", j.cost - d.coins)
		else
			d.coins -= j.cost
			d.owned[id] = true
			d.jet = id
			Data.mark(p)
			task.spawn(Data.save, p)
			NotifyR:FireClient(p, "bought", "green", id)
		end
	elseif kind == "paint" then
		local pt = Progress.paint(id)
		if not pt or pt.vip or d.paints[id] then
			return
		end
		if level < pt.level then
			NotifyR:FireClient(p, "need_level", "amber", pt.level)
		elseif d.coins < pt.cost then
			NotifyR:FireClient(p, "need_coins", "amber", pt.cost - d.coins)
		else
			d.coins -= pt.cost
			d.paints[id] = true
			d.paint = id
			Data.mark(p)
			task.spawn(Data.save, p)
			NotifyR:FireClient(p, "bought_paint", "green")
		end
	end
	sendProfile(p)
end)

-- ===== ежедневная награда
DailyR.OnServerEvent:Connect(function(p)
	local d = Data.get(p)
	if not d then
		return
	end
	local day = Progress.day()
	if d.daily.last == day then
		return
	end
	d.daily.streak = if d.daily.last == day - 1 then d.daily.streak + 1 else 1
	d.daily.last = day
	local idx = ((d.daily.streak - 1) % #Progress.DAILY) + 1
	give(p, Progress.DAILY[idx], 50, "daily")
	Data.mark(p)
	task.spawn(Data.save, p)
end)

TutR.OnServerEvent:Connect(function(p)
	local d = Data.get(p)
	if d and not d.tut then
		d.tut = true
		Data.mark(p)
		sendProfile(p)
	end
end)

-- ===== VIP и покупки за Robux
local function checkVip(p: Player)
	if Config.VIP_PASS_ID and Config.VIP_PASS_ID > 0 then
		local ok, has = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(p.UserId, Config.VIP_PASS_ID)
		end)
		vip[p] = ok and has == true
	end
end
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(p, passId, bought)
	if bought and passId == Config.VIP_PASS_ID then
		vip[p] = true
		NotifyR:FireClient(p, "vip_thanks", "amber")
		sendProfile(p)
	end
end)
MarketplaceService.ProcessReceipt = function(info: any)
	local p = Players:GetPlayerByUserId(info.PlayerId)
	local d = p and Data.get(p)
	if not p or not d then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	for _, id in d.purchases do
		if id == info.PurchaseId then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end
	local coins = 0
	for _, pr in Config.COIN_PRODUCTS do
		if pr.id == info.ProductId then
			coins = pr.coins
		end
	end
	if coins == 0 then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	d.coins += coins
	table.insert(d.purchases, info.PurchaseId)
	while #d.purchases > 50 do
		table.remove(d.purchases, 1)
	end
	if not Data.save(p) then
		-- не сохранилось — откатываем и попросим Roblox повторить позже
		d.coins -= coins
		table.remove(d.purchases)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	RewardR:FireClient(p, coins, 0, "purchase")
	sendProfile(p)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- ===== вход и выход игроков
local function updateFriends()
	local list = Players:GetPlayers()
	for _, p in list do
		task.spawn(function()
			local has = false
			for _, q in list do
				if q ~= p then
					local ok, f = pcall(function()
						return p:IsFriendsWith(q.UserId)
					end)
					if ok and f then
						has = true
						break
					end
				end
			end
			friendBonus[p] = has
		end)
	end
end

local function onJoin(p: Player)
	leaderstats(p)
	Data.load(p)
	checkVip(p)
	if not p.Parent then
		Data.release(p)
		return
	end
	setLS(p)
	sendProfile(p)
	badge(p, "welcome")
	updateFriends()
end
Players.PlayerAdded:Connect(onJoin)
for _, p in Players:GetPlayers() do
	task.spawn(onJoin, p)
end
Players.PlayerRemoving:Connect(function(p)
	local u = byPlayer[p]
	if u then
		removeUnit(u, false)
	end
	lastSpawn[p] = nil
	roundStats[p] = nil
	vip[p] = nil
	friendBonus[p] = nil
	Data.release(p)
	updateFriends()
end)

-- недельный топ: раз в 2 минуты в атрибут Top (JSON)
task.spawn(function()
	while true do
		local ok, list = pcall(Data.fetchTop)
		if ok then
			match:SetAttribute("Top", Data.encode(list))
		end
		task.wait(120)
	end
end)

-- =====================================================================
-- БОТЫ
-- =====================================================================
local BOT_NAMES = { "Falcon", "Viper", "Ghost", "Maverick", "Cobra", "Typhoon", "Hawk", "Storm", "Blaze", "Raven", "Phantom", "Sabre" }
local botSeq = 0
local function spawnBot(side: string)
	botSeq += 1
	local id = Jets.ORDER[rng:NextInteger(1, #Jets.ORDER)]
	local cfg = Jets.JETS[id]
	local cf = World.spawnCFrame("air:" .. side, cfg, rng:NextInteger(1, 4)) :: CFrame
	cf = cf + Vector3.new(rng:NextNumber(-300, 300), rng:NextNumber(0, 400), rng:NextNumber(-300, 300))
	local paints = { "team", "camo", "desert", "arctic", "night" }
	local u = makeUnit(cfg, side, "[BOT] " .. BOT_NAMES[(botSeq - 1) % #BOT_NAMES + 1], cf, false, paints[rng:NextInteger(1, #paints)])
	u.flight = FlightPhysics.new(cfg, cf, true)
	u.bot = { skill = rng:NextNumber(0.3, 0.9), target = nil :: Unit?, retarget = 0, lastMsl = os.clock() + 6, aimErr = rng:NextNumber(0.5, 1.5) }
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
		FeedR:FireAllClients("crash", { v = u.name, vs = u.side, why = if f.pos.Y < 5 then "water" else "ground" })
		loseTickets(u.side, 2)
		removeUnit(u, true)
		return
	end
	u.root.CFrame = FlightPhysics.pose(f)
end

-- =====================================================================
-- РАУНД
-- =====================================================================
local capAcc, bleedAcc, botAcc = 0, 0, 0
local roundOver = false

local function endRound(winner: string)
	roundOver = true
	-- MVP: трое лучших игроков раунда
	local list = {}
	for p, s in roundStats do
		if p.Parent then
			table.insert(list, { p = p, s = s })
		end
	end
	table.sort(list, function(a, b)
		return a.s.score > b.s.score
	end)
	local mvp = {}
	for i = 1, math.min(3, #list) do
		local e = list[i]
		table.insert(mvp, { name = e.p.DisplayName, side = sideOf(e.p), kills = e.s.kills, caps = e.s.caps, score = e.s.score, userId = e.p.UserId })
	end
	RoundR:FireAllClients(winner, mvp)
	for _, p in Players:GetPlayers() do
		if sideOf(p) == winner then
			reward(p, "win")
			stat(p, "wins", 1)
			quest(p, "wins", 1)
			badge(p, "first_win")
		else
			reward(p, "loss")
		end
	end
	if list[1] and list[1].s.score > 0 then
		reward(list[1].p, "mvp")
	end
	for _, p in Players:GetPlayers() do
		task.spawn(Data.save, p)
	end
	task.delay(15, function()
		for _, u in units do
			if u.player then
				KilledR:FireClient(u.player, "", "round")
			end
			removeUnit(u, false)
		end
		for _, m in missiles do
			m.part:Destroy()
		end
		table.clear(missiles)
		table.clear(roundStats)
		tickets.Blue, tickets.Red = Jets.TICKETS, Jets.TICKETS
		resetBases()
		publish()
		for _, p in Players:GetPlayers() do
			setLS(p)
		end
		roundOver = false
	end)
end

RunService.Heartbeat:Connect(function(dt)
	dt = math.min(dt, 0.1)
	for _, u in units do
		if u.bot and u.alive then
			local ok, err = pcall(stepBot, u, dt)
			if not ok then
				warn("[CarrierStrike] бот убран из-за ошибки:", err)
				removeUnit(u, false)
			end
		end
	end
	stepMissiles(dt)

	capAcc += dt
	if capAcc >= 0.5 then
		local step = capAcc
		capAcc = 0
		for _, u in units do
			local p = u.root.Position
			if u.alive and p.Y > World.DECK_H + 80 then
				u.airborne = true
			end
			if u.alive and (math.abs(p.X) > World.SIZE or math.abs(p.Z) > World.SIZE) then
				u.born = 0
				damage(u, 6 * step, nil, "zone")
			end
		end
		-- захват баз: самолёты низко над островом
		for _, i in World.ISLANDS do
			local nb, nr = 0, 0
			local inZone: { Unit } = {}
			for _, u in units do
				if u.alive and u.ready then
					local p = u.root.Position
					local dx, dz = p.X - i.x, p.Z - i.z
					if dx * dx + dz * dz < World.CAPTURE_R * World.CAPTURE_R and p.Y < i.h + World.CAPTURE_ALT then
						table.insert(inZone, u)
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
						FeedR:FireAllClients("cap", { side = b.owner, base = i.id })
						for _, u in inZone do
							if u.player and u.side == b.owner then
								reward(u.player, "capture")
								stat(u.player, "caps", 1)
								quest(u.player, "caps", 1)
								badge(u.player, "first_capture")
								local r = rs(u.player)
								r.caps += 1
								r.score += 75
							end
						end
					else
						FeedR:FireAllClients("neutral", { base = i.id })
					end
				end
			end
		end
		publish()
	end

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
