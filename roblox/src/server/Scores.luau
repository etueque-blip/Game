--!strict
-- Очки и статистика игрока (leaderstats + DataStore, если включён доступ к API).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Scores = {}

local store: DataStore? = nil
pcall(function()
	store = DataStoreService:GetDataStore("SkyPilot_v1")
end)

type Data = { score: number, landings: number, best: number, flights: number }
local cache: { [Player]: Data } = {}

local function key(p: Player): string
	return "u_" .. p.UserId
end

local function stat(p: Player, name: string, value: number)
	local ls = p:FindFirstChild("leaderstats")
	local v = ls and ls:FindFirstChild(name) :: IntValue?
	if v then
		v.Value = value
	end
end

function Scores.get(p: Player): Data
	return cache[p] or { score = 0, landings = 0, best = 0, flights = 0 }
end

local function refresh(p: Player)
	local d = Scores.get(p)
	stat(p, "Очки", d.score)
	stat(p, "Посадки", d.landings)
	p:SetAttribute("BestFpm", d.best)
end

function Scores.load(p: Player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	for _, n in { "Очки", "Посадки" } do
		local v = Instance.new("IntValue")
		v.Name = n
		v.Parent = ls
	end
	ls.Parent = p
	local data: Data = { score = 0, landings = 0, best = 0, flights = 0 }
	if store then
		local ok, res = pcall(function()
			return (store :: DataStore):GetAsync(key(p))
		end)
		if ok and type(res) == "table" then
			data.score = tonumber(res.score) or 0
			data.landings = tonumber(res.landings) or 0
			data.best = tonumber(res.best) or 0
			data.flights = tonumber(res.flights) or 0
		end
	end
	cache[p] = data
	refresh(p)
end

function Scores.save(p: Player)
	local d = cache[p]
	if not d or not store then
		return
	end
	pcall(function()
		(store :: DataStore):SetAsync(key(p), d)
	end)
end

function Scores.add(p: Player, points: number, landing: boolean, fpm: number?)
	local d = cache[p]
	if not d then
		return
	end
	d.score += points
	if landing then
		d.landings += 1
		if fpm and (d.best == 0 or fpm < d.best) then
			d.best = math.max(1, fpm)
		end
	end
	refresh(p)
end

function Scores.flight(p: Player)
	local d = cache[p]
	if d then
		d.flights += 1
	end
end

function Scores.unload(p: Player)
	Scores.save(p)
	cache[p] = nil
end

task.spawn(function()
	while true do
		task.wait(120)
		for _, p in Players:GetPlayers() do
			Scores.save(p)
		end
	end
end)

game:BindToClose(function()
	for _, p in Players:GetPlayers() do
		Scores.save(p)
	end
end)

return Scores
