--!strict
-- Сохранения игроков (DataStore). Если хранилище недоступно (в Studio не включён доступ к API),
-- игра работает с временным профилем и НЕ перезаписывает настоящие сохранения.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("CarrierStrike")
local Config = require(Shared:WaitForChild("Config"))
local Progress = require(Shared:WaitForChild("Progress"))

local Data = {}

local store: DataStore? = nil
local top: OrderedDataStore? = nil
local topWeek = -1
pcall(function()
	store = DataStoreService:GetDataStore(Config.DATASTORE)
end)

local function default(): any
	return {
		v = 1,
		coins = 300,
		xp = 0,
		owned = { F16 = true, MIG29 = true },
		paints = { team = true },
		paint = "team",
		jet = "F16",
		daily = { last = 0, streak = 0 },
		quests = { day = 0, list = {} },
		week = { id = 0, kills = 0 },
		stats = { kills = 0, deaths = 0, wins = 0, caps = 0, sorties = 0, assists = 0 },
		purchases = {},
		tut = false,
		lang = "",
	}
end

-- дописать новые поля в старое сохранение
local function reconcile(d: any): any
	local def = default()
	for k, v in def do
		if d[k] == nil then
			d[k] = v
		elseif type(v) == "table" and type(d[k]) == "table" and k ~= "purchases" and k ~= "owned" and k ~= "paints" then
			for k2, v2 in v do
				if d[k][k2] == nil then
					d[k][k2] = v2
				end
			end
		end
	end
	d.owned.F16 = true
	d.owned.MIG29 = true
	d.paints.team = true
	return d
end

type Slot = { data: any, noSave: boolean, dirty: boolean, savedKills: number }
local slots: { [Player]: Slot } = {}
local warned = false

function Data.load(p: Player): any
	local key = "u_" .. p.UserId
	local data: any = nil
	local ok = false
	if store then
		for attempt = 1, 3 do
			local s, res = pcall(function()
				return (store :: DataStore):GetAsync(key)
			end)
			if s then
				ok = true
				data = res
				break
			end
			if not warned then
				warn("[CarrierStrike] DataStore недоступен:", res, "— в Studio включи Game Settings → Security → Enable Studio Access to API Services")
				warned = true
			end
			task.wait(attempt)
		end
	end
	local slot: Slot = {
		data = reconcile(if type(data) == "table" then data else default()),
		noSave = not ok, -- загрузка не удалась: не затираем настоящий профиль пустым
		dirty = false,
		savedKills = -1,
	}
	slots[p] = slot
	return slot.data
end

function Data.get(p: Player): any?
	local s = slots[p]
	return s and s.data
end

function Data.mark(p: Player)
	local s = slots[p]
	if s then
		s.dirty = true
	end
end

function Data.save(p: Player): boolean
	local s = slots[p]
	if not s or s.noSave or not store then
		return false
	end
	local key = "u_" .. p.UserId
	local d = s.data
	local ok = pcall(function()
		(store :: DataStore):UpdateAsync(key, function()
			return d
		end)
	end)
	if ok then
		s.dirty = false
	end
	-- недельный топ сбитий
	local wk = Progress.week()
	if wk ~= topWeek then
		topWeek = wk
		pcall(function()
			top = DataStoreService:GetOrderedDataStore("CS_WeekKills_" .. wk)
		end)
	end
	if ok and top and d.week.id == wk and d.week.kills ~= s.savedKills and d.week.kills > 0 then
		local kills = d.week.kills
		if pcall(function()
			(top :: OrderedDataStore):SetAsync(key, kills)
		end) then
			s.savedKills = kills
		end
	end
	return ok
end

function Data.release(p: Player)
	if slots[p] then
		Data.save(p)
		slots[p] = nil
	end
end

-- топ-10 недели: { {name, kills} }
local nameCache: { [number]: string } = {}
function Data.fetchTop(): { any }
	local out = {}
	local wk = Progress.week()
	local ok, pages = pcall(function()
		return DataStoreService:GetOrderedDataStore("CS_WeekKills_" .. wk):GetSortedAsync(false, 10)
	end)
	if not ok or not pages then
		return out
	end
	for _, e in (pages :: any):GetCurrentPage() do
		local uid = tonumber(string.match(e.key, "%d+")) or 0
		local name = nameCache[uid]
		if not name then
			local s, n = pcall(function()
				return Players:GetNameFromUserIdAsync(uid)
			end)
			name = if s and n then n else "?"
			nameCache[uid] = name
		end
		table.insert(out, { name, e.value })
	end
	return out
end

function Data.encode(t: any): string
	return HttpService:JSONEncode(t)
end

-- автосохранение раз в 90 с и при выключении сервера
task.spawn(function()
	while true do
		task.wait(90)
		for p, s in slots do
			if s.dirty then
				task.spawn(Data.save, p)
			end
		end
	end
end)
game:BindToClose(function()
	local left = 0
	for p in slots do
		left += 1
		task.spawn(function()
			Data.save(p)
			left -= 1
		end)
	end
	local t = os.clock()
	while left > 0 and os.clock() - t < 25 do
		task.wait(0.2)
	end
end)

return Data
