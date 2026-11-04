--!strict
-- Гонка через кольца: маршрут Skyport → Дубай → Ташкент → Лондон → Skyport.
-- Кольца строятся у каждого игрока локально, поэтому подсветка своя у каждого.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("SkyPilot")
local World = require(Shared:WaitForChild("World"))

local Race = {}

local SEGMENTS = 28
local COLOR_NEXT = Color3.fromRGB(59, 167, 255)
local COLOR_DONE = Color3.fromRGB(77, 255, 149)
local COLOR_IDLE = Color3.fromRGB(235, 240, 255)

type Ring = { cf: CFrame, r: number, name: string, parts: { BasePart } }

function Race.new(onPass: (string, number, number) -> (), onFinish: (number) -> ())
	local self: any = {}
	local rings: { Ring } = {}
	local folder = Instance.new("Folder")
	folder.Name = "SkyPilotRings"
	folder.Parent = workspace

	for _, d in World.CityData.rings do
		local cf = CFrame.new(d[1], d[2], d[3]) * CFrame.Angles(0, d[5], 0)
		local r = d[4]
		local ring: Ring = { cf = cf, r = r, name = d[6], parts = {} }
		local seg = 2 * math.pi * r / SEGMENTS * 1.08
		local thick = math.max(2, r * 0.07)
		for i = 0, SEGMENTS - 1 do
			local t = 2 * math.pi * i / SEGMENTS
			local p = Instance.new("Part")
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Material = Enum.Material.Neon
			p.Size = Vector3.new(seg, thick, thick)
			p.CFrame = cf * CFrame.new(r * math.cos(t), r * math.sin(t), 0) * CFrame.Angles(0, 0, t + math.pi / 2)
			p.Parent = folder
			table.insert(ring.parts, p)
		end
		table.insert(rings, ring)
	end

	local nextIdx = 1
	local startT: number? = nil

	local function paint()
		for i, ring in rings do
			local color = if i < nextIdx then COLOR_DONE elseif i == nextIdx then COLOR_NEXT else COLOR_IDLE
			local tr = if i < nextIdx then 0.7 elseif i == nextIdx then 0 else 0.45
			for _, p in ring.parts do
				p.Color = color
				p.Transparency = tr
			end
		end
	end
	paint()

	function self.reset()
		nextIdx = 1
		startT = nil
		paint()
	end

	-- prev/pos — позиция самолёта на прошлом и текущем шаге
	function self.step(prev: Vector3, pos: Vector3, now: number)
		local ring = rings[nextIdx]
		if not ring then
			return
		end
		local a = ring.cf:PointToObjectSpace(prev)
		local b = ring.cf:PointToObjectSpace(pos)
		if (a.Z > 0) == (b.Z > 0) or math.abs(a.Z - b.Z) < 1e-6 then
			return
		end
		local p = a:Lerp(b, a.Z / (a.Z - b.Z))
		if p.X * p.X + p.Y * p.Y > (ring.r * 1.1) ^ 2 then
			return
		end
		if nextIdx == 1 then
			startT = now
		end
		local elapsed = now - (startT or now)
		nextIdx += 1
		paint()
		if nextIdx > #rings then
			onFinish(elapsed)
			startT = nil
			nextIdx = 1
			task.delay(3, paint)
		else
			onPass(ring.name, nextIdx - 1, #rings)
		end
	end

	-- следующее кольцо для навигации (nil, если гонка не начата)
	function self.target(): (Vector3?, string?)
		if not startT then
			return nil, nil
		end
		local ring = rings[nextIdx]
		if not ring then
			return nil, nil
		end
		return ring.cf.Position, ring.name
	end

	function self.firstRing(): Vector3
		return rings[1].cf.Position
	end

	function self.status(now: number): string?
		if not startT then
			return nil
		end
		local t = now - startT
		return string.format("КОЛЬЦА %d/%d · %d:%04.1f", nextIdx - 1, #rings, math.floor(t / 60), t % 60)
	end

	return self
end

return Race
