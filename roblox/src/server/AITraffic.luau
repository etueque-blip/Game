--!strict
-- ИИ-пилоты (боты-«агенты»): летают по маршрутам между аэропортами и городом
-- на той же физике, что и игроки, управляются автопилотом.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("SkyPilot")
local World = require(Shared:WaitForChild("World"))
local PlaneConfigs = require(Shared:WaitForChild("PlaneConfigs"))
local PlaneBuilder = require(Shared:WaitForChild("PlaneBuilder"))
local FlightPhysics = require(Shared:WaitForChild("FlightPhysics"))
local Autopilot = require(Shared:WaitForChild("Autopilot"))

local AITraffic = {}

local COUNT = 5
local TYPES = { "B737", "A220", "A320", "B787", "A330", "A350", "B777", "B747", "A380", "G650", "GL7500", "LEAR75", "C172" }
local WAYPOINTS = {
	Vector3.new(0, 0, -9000), Vector3.new(9000, 0, -14000), Vector3.new(20000, 0, -18000),
	Vector3.new(16000, 0, -6000), Vector3.new(5500, 0, -7500), Vector3.new(-6000, 0, 2000),
	Vector3.new(-2000, 0, 14000), Vector3.new(8000, 0, 9000), Vector3.new(-18000, 0, -2000),
}

type Bot = { model: Model, root: BasePart, flight: FlightPhysics.Flight, wp: number, altFt: number, speed: number, retarget: number }
local bots: { Bot } = {}
local rng = Random.new()

local function spawnBot(): Bot
	local id = TYPES[rng:NextInteger(1, #TYPES)]
	local cfg = PlaneConfigs.PLANES[id]
	local callsign = string.format("SKY%03d", rng:NextInteger(100, 999))
	local model = PlaneBuilder.build(cfg, { label = callsign .. " · ИИ" })
	model.Name = "AI_" .. callsign
	model:SetAttribute("AI", true)
	model:SetAttribute("Gear", false)
	model:SetAttribute("Throttle", 0.7)
	local wp = rng:NextInteger(1, #WAYPOINTS)
	local start = WAYPOINTS[wp] + Vector3.new(rng:NextNumber(-3000, 3000), 0, rng:NextNumber(-3000, 3000))
	-- безопасная высота: выше гор с запасом и ниже потолка
	local altFt = math.min(cfg.ceilingFt * 0.7, rng:NextNumber(4500, 11000))
	local cf = CFrame.new(start.X, altFt / World.FT, start.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local f = FlightPhysics.new(cfg, cf, true)
	f.gear = cfg.fixedGear == true
	f.speed = math.min(cfg.maxKts * 0.72, cfg.stallKts * 2.2)
	model:PivotTo(cf)
	model.Parent = workspace:WaitForChild("Planes")
	local root = model.PrimaryPart :: BasePart
	root.Anchored = false
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	return { model = model, root = root, flight = f, wp = (wp % #WAYPOINTS) + 1, altFt = altFt, speed = f.speed, retarget = 0 }
end

local function stepBot(b: Bot, dt: number)
	local f = b.flight
	local target = WAYPOINTS[b.wp]
	local flat = Vector3.new(f.pos.X, 0, f.pos.Z)
	if (flat - target).Magnitude < 1500 then
		b.wp = (b.wp % #WAYPOINTS) + 1
		b.altFt = math.min(f.cfg.ceilingFt * 0.7, rng:NextNumber(4500, 11000))
	end
	local input = Autopilot.compute(f, { heading = Autopilot.bearingDeg(flat, target), altFt = b.altFt, speed = b.speed, maxBank = 22 })
	FlightPhysics.step(f, input, dt)
	table.clear(f.events)
	if f.crashed then
		return false
	end
	b.root.CFrame = FlightPhysics.pose(f)
	b.root.AssemblyLinearVelocity = f.vel
	b.root.AssemblyAngularVelocity = Vector3.zero
	return true
end

function AITraffic.start(count: number?)
	for _ = 1, count or COUNT do
		table.insert(bots, spawnBot())
	end
	RunService.PreSimulation:Connect(function(dt)
		for i, b in bots do
			local ok = stepBot(b, dt)
			if not ok or not b.model.Parent then
				b.model:Destroy()
				bots[i] = spawnBot()
			end
		end
	end)
end

return AITraffic
