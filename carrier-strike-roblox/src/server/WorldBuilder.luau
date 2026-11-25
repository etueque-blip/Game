--!strict
-- Строит мир по описанию World: океан, авианосцы, острова с полосами и флагами баз, свет и небо.
-- Всё из обычных деталей — никаких внешних моделей.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage:WaitForChild("CarrierStrike"):WaitForChild("World"))

local WorldBuilder = {}

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = size.Magnitude < 2000
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

local function ellipsoid(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?): Part
	local p = part(parent, name, size, cf, color, mat)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = p
	return p
end

-- плоский диск (цилиндр лёжа)
local function disc(parent: Instance, name: string, r: number, h: number, pos: Vector3, color: Color3, mat: Enum.Material?): Part
	r = math.min(r, 1024) -- предел размера детали в Roblox — 2048
	return part(parent, name, Vector3.new(h, r * 2, r * 2), CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2), color, mat, Enum.PartType.Cylinder)
end

local Terrain = workspace.Terrain

local function ocean(f: Folder)
	-- настоящая вода Roblox (волны, отражения) над всей зоной боя, слоем 4 studs (быстрее грузится на телефонах)
	Terrain.WaterColor = Color3.fromRGB(22, 84, 118)
	Terrain.WaterTransparency = 0.35
	Terrain.WaterReflectance = 0.9
	Terrain.WaterWaveSize = 0.35
	Terrain.WaterWaveSpeed = 10
	local half = World.SIZE + 800
	local chunk = 2048
	local n = 0
	local x = -half
	while x < half do
		local z = -half
		while z < half do
			local sx = math.min(chunk, half - x)
			local sz = math.min(chunk, half - z)
			Terrain:FillBlock(CFrame.new(x + sx / 2, World.SEA - 2, z + sz / 2), Vector3.new(sx, 4, sz), Enum.Material.Water)
			n += 1
			if n % 8 == 0 then
				task.wait()
			end
			z += chunk
		end
		x += chunk
	end
	-- дно под водой и море за краем зоны: одна тёмная деталь (видимый размер растягивает SpecialMesh)
	local span = (World.SIZE + 12000) * 2
	local sea = part(f, "SeaFloor", Vector3.new(2048, 2, 2048), CFrame.new(0, World.SEA - 5, 0), Color3.fromRGB(16, 52, 80), Enum.Material.SmoothPlastic)
	sea.CastShadow = false
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Brick
	mesh.Scale = Vector3.new(span / 2048, 1, span / 2048)
	mesh.Parent = sea
	-- море за краем зоны воды: 4 полосы вокруг (внутри зоны — настоящая вода)
	local function plane(cx: number, cz: number, sx: number, sz: number)
		local pl = part(f, "FarSea", Vector3.new(2048, 2, 2048), CFrame.new(cx, World.SEA - 1.2, cz), Color3.fromRGB(30, 86, 122), Enum.Material.SmoothPlastic)
		pl.CastShadow = false
		pl.Reflectance = 0.1
		local pm = Instance.new("SpecialMesh")
		pm.MeshType = Enum.MeshType.Brick
		pm.Scale = Vector3.new(sx / 2048, 1, sz / 2048)
		pm.Parent = pl
	end
	local outer = span / 2
	local band = outer - half
	plane(0, half + band / 2, outer * 2, band)
	plane(0, -half - band / 2, outer * 2, band)
	plane(half + band / 2, 0, band, half * 2)
	plane(-half - band / 2, 0, band, half * 2)
	-- граница зоны боя: светящиеся буи по периметру
	local s = World.SIZE
	for i = -4, 4 do
		for _, pos in { Vector3.new(i * s / 4, 6, -s), Vector3.new(i * s / 4, 6, s), Vector3.new(-s, 6, i * s / 4), Vector3.new(s, 6, i * s / 4) } do
			part(f, "Buoy", Vector3.new(10, 12, 10), CFrame.new(pos), Color3.fromRGB(255, 170, 40), Enum.Material.Neon, Enum.PartType.Cylinder)
		end
	end
end

local function carrier(f: Folder, c: any)
	local m = Instance.new("Model")
	m.Name = c.id
	local cf: CFrame = c.cf
	local W, L, H = World.DECK_W, World.DECK_L, World.DECK_H
	local hull = Color3.fromRGB(96, 104, 114)
	local deckCol = Color3.fromRGB(58, 62, 68)
	local teamCol = World.TEAM_COLOR[c.team]
	-- корпус: прямоугольная часть + клиновидный нос
	part(m, "Hull", Vector3.new(W * 0.8, H + 10, L * 0.86), cf * CFrame.new(0, (H - 10) / 2, L * 0.07), hull, Enum.Material.Metal)
	local bow = Instance.new("WedgePart")
	bow.Name = "Bow"
	bow.Anchored, bow.CanCollide, bow.CanTouch, bow.CanQuery = true, false, false, false
	bow.Size = Vector3.new(W * 0.8, H + 10, L * 0.14)
	bow.CFrame = cf * CFrame.new(0, (H - 10) / 2, -L / 2 + L * 0.07) * CFrame.Angles(0, math.pi, 0)
	bow.Color = hull
	bow.Material = Enum.Material.Metal
	bow.Parent = m
	-- полётная палуба шире корпуса
	part(m, "Deck", Vector3.new(W, 3, L), cf * CFrame.new(0, H - 1.5, 0), deckCol, Enum.Material.Asphalt)
	-- разметка: осевая и угловая палуба
	for i = 0, 15 do
		part(m, "Mark", Vector3.new(2, 0.2, 18), cf * CFrame.new(-30, H + 0.1, L / 2 - 30 - i * 40), Color3.fromRGB(235, 235, 235), Enum.Material.SmoothPlastic)
	end
	part(m, "AngleLine", Vector3.new(2.5, 0.2, L * 0.55), cf * CFrame.new(-18, H + 0.1, L * 0.18) * CFrame.Angles(0, math.rad(-9), 0), Color3.fromRGB(240, 210, 60))
	part(m, "AngleLine", Vector3.new(2.5, 0.2, L * 0.55), cf * CFrame.new(-62, H + 0.1, L * 0.18) * CFrame.Angles(0, math.rad(-9), 0), Color3.fromRGB(240, 210, 60))
	-- катапульты
	for _, x in { -30, 0 } do
		part(m, "Catapult", Vector3.new(1.5, 0.25, 220), cf * CFrame.new(x, H + 0.12, -L / 2 + 140), Color3.fromRGB(150, 150, 150), Enum.Material.Metal)
	end
	-- аэрофинишёры (тросы) у кормы
	for i = 0, 3 do
		part(m, "Wire", Vector3.new(80, 0.3, 0.6), cf * CFrame.new(-35, H + 0.2, L / 2 - 120 - i * 22) * CFrame.Angles(0, math.rad(-9), 0), Color3.fromRGB(30, 30, 30), Enum.Material.Metal)
	end
	-- надстройка
	local t = World.TOWER
	local tc = cf * CFrame.new((t.x0 + t.x1) / 2, H + t.h * 0.3, (t.z0 + t.z1) / 2)
	part(m, "Tower", Vector3.new(t.x1 - t.x0, t.h * 0.6, t.z1 - t.z0), tc, hull, Enum.Material.Metal)
	part(m, "Bridge", Vector3.new(t.x1 - t.x0 + 4, t.h * 0.18, (t.z1 - t.z0) * 0.7), cf * CFrame.new((t.x0 + t.x1) / 2, H + t.h * 0.69, (t.z0 + t.z1) / 2 - 8), Color3.fromRGB(80, 86, 94), Enum.Material.Metal)
	part(m, "Windows", Vector3.new(t.x1 - t.x0 + 4.4, 4, (t.z1 - t.z0) * 0.7 - 2), cf * CFrame.new((t.x0 + t.x1) / 2, H + t.h * 0.7, (t.z0 + t.z1) / 2 - 8), Color3.fromRGB(30, 40, 52), Enum.Material.Glass)
	part(m, "Mast", Vector3.new(3, t.h * 0.25, 3), cf * CFrame.new((t.x0 + t.x1) / 2, H + t.h * 0.9, (t.z0 + t.z1) / 2), Color3.fromRGB(70, 74, 80), Enum.Material.Metal)
	part(m, "Radar", Vector3.new(18, 6, 1.5), cf * CFrame.new((t.x0 + t.x1) / 2, H + t.h * 0.85, (t.z0 + t.z1) / 2 + 14), Color3.fromRGB(120, 126, 134), Enum.Material.Metal)
	-- полоса цвета команды по борту и огонь на мачте
	part(m, "TeamStripe", Vector3.new(W * 0.8 + 0.6, 4, L * 0.7), cf * CFrame.new(0, H - 8, L * 0.05), teamCol, Enum.Material.SmoothPlastic)
	local beacon = part(m, "Beacon", Vector3.new(4, 4, 4), cf * CFrame.new((t.x0 + t.x1) / 2, H + t.h + 2, (t.z0 + t.z1) / 2), teamCol, Enum.Material.Neon, Enum.PartType.Ball)
	local pl = Instance.new("PointLight")
	pl.Range = 60
	pl.Color = teamCol
	pl.Brightness = 3
	pl.Parent = beacon
	-- кильватерный след
	local wake = part(m, "Wake", Vector3.new(W * 0.9, 0.4, 900), cf * CFrame.new(0, World.SEA + 0.6, L / 2 + 450), Color3.fromRGB(200, 225, 240), Enum.Material.SmoothPlastic)
	wake.Transparency = 0.55
	-- табличка над кораблём
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(260, 36)
	bb.StudsOffsetWorldSpace = Vector3.new(0, H + t.h + 30, 0)
	bb.MaxDistance = 30000
	bb.LightInfluence = 0
	bb.AlwaysOnTop = true
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.Text = "⚓ " .. c.name
	tl.TextColor3 = teamCol
	tl.TextStrokeTransparency = 0.3
	tl.Font = Enum.Font.GothamBold
	tl.TextScaled = true
	tl.Parent = bb
	bb.Parent = beacon
	m.Parent = f
end

local function island(f: Folder, i: any): BasePart
	local m = Instance.new("Model")
	m.Name = "Island_" .. i.id
	local sand = Color3.fromRGB(214, 196, 148)
	local grass = Color3.fromRGB(86, 128, 70)
	-- рельеф Roblox: отмель (бирюзовая вода), пляж, плато, холмы со скалами — та же форма, что в World.groundAt
	Terrain:FillCylinder(CFrame.new(i.x, World.SEA - 3.5, i.z), 3, i.r + World.BEACH + 260, Enum.Material.Sand)
	Terrain:FillCylinder(CFrame.new(i.x, World.SEA - 2.5, i.z), 11, i.r + World.BEACH, Enum.Material.Sand)
	Terrain:FillCylinder(CFrame.new(i.x, (i.h - 8) / 2, i.z), i.h + 8, i.r, Enum.Material.Grass)
	for _, hl in i.hills do
		local c = World.hillPos(i, hl)
		local R, Hh = hl[3], hl[4]
		local y = 0
		while y < Hh do
			local rr = R * math.sqrt(math.max(0, 1 - (y / Hh) ^ 2))
			if rr > 6 then
				local mat = if y > Hh * 0.62 then Enum.Material.Rock elseif y > Hh * 0.4 then Enum.Material.LeafyGrass else Enum.Material.Grass
				Terrain:FillCylinder(CFrame.new(c.X, i.h + y + 3, c.Z), 6, rr, mat)
			end
			y += 6
		end
	end
	task.wait()
	-- полоса
	local dir = World.runwayDir(i)
	local rcf = CFrame.lookAt(Vector3.new(i.x, i.h + 0.25, i.z), Vector3.new(i.x, i.h + 0.25, i.z) + dir)
	local rw = part(m, "RunwaySurface", Vector3.new(World.RUNWAY_W, 0.5, World.RUNWAY_LEN), rcf, Color3.fromRGB(48, 50, 54), Enum.Material.Asphalt)
	for k = -10, 10 do
		part(m, "Mark", Vector3.new(1.5, 0.2, 22), rcf * CFrame.new(0, 0.35, k * 50), Color3.fromRGB(235, 235, 235))
	end
	for _, s in { -1, 1 } do
		for k = -3, 3 do
			part(m, "Threshold", Vector3.new(4, 0.2, 40), rcf * CFrame.new(k * 8, 0.35, s * (World.RUNWAY_LEN / 2 - 30)), Color3.fromRGB(235, 235, 235))
		end
	end
	-- ангары и вышка в стороне от полосы
	local side = Vector3.new(-dir.Z, 0, dir.X)
	for k = -1, 1 do
		local hp = Vector3.new(i.x, i.h, i.z) + side * 110 + dir * (k * 120)
		part(m, "Hangar", Vector3.new(70, 26, 60), CFrame.lookAt(hp + Vector3.new(0, 13, 0), hp + Vector3.new(0, 13, 0) + dir), Color3.fromRGB(150, 156, 160), Enum.Material.CorrodedMetal)
	end
	-- флагшток базы: цвет флага = владелец (меняет сервер)
	local fp = Vector3.new(i.x, i.h, i.z) - side * 120
	part(m, "Pole", Vector3.new(2, 60, 2), CFrame.new(fp + Vector3.new(0, 30, 0)), Color3.fromRGB(210, 210, 210), Enum.Material.Metal)
	local flag = part(m, "Flag", Vector3.new(1, 18, 30), CFrame.new(fp + Vector3.new(0, 50, 15)), World.TEAM_COLOR[i.owner], Enum.Material.Neon)
	flag.Name = "Flag"
	-- граница зоны захвата: кольцо светящихся буёв (видно с воздуха)
	local ring = Instance.new("Model")
	ring.Name = "CaptureRing"
	for k = 0, 23 do
		local a = k / 24 * math.pi * 2
		local bp = Vector3.new(i.x + math.cos(a) * World.CAPTURE_R, World.SEA + 4, i.z + math.sin(a) * World.CAPTURE_R)
		part(ring, "RingBuoy", Vector3.new(8, 8, 8), CFrame.new(bp), World.TEAM_COLOR[i.owner], Enum.Material.Neon, Enum.PartType.Ball).CastShadow = false
	end
	ring.Parent = m
	local bb = Instance.new("BillboardGui")
	bb.Name = "Label"
	bb.Size = UDim2.fromOffset(200, 34)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 40, 0)
	bb.MaxDistance = 30000
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	local tl = Instance.new("TextLabel")
	tl.Name = "Text"
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.Text = "◆ База " .. i.name
	tl.TextColor3 = World.TEAM_COLOR[i.owner]
	tl.TextStrokeTransparency = 0.3
	tl.Font = Enum.Font.GothamBold
	tl.TextScaled = true
	tl.Parent = bb
	bb.Parent = flag
	m.Parent = f
	return flag
end

-- перекрасить базу под владельца
function WorldBuilder.setOwner(id: string, owner: string)
	local f = workspace:FindFirstChild("CarrierStrikeWorld")
	local m = f and f:FindFirstChild("Island_" .. id)
	if not m then
		return
	end
	local col = World.TEAM_COLOR[owner] or World.TEAM_COLOR[""]
	local flag = m:FindFirstChild("Flag") :: BasePart?
	local ring = m:FindFirstChild("CaptureRing")
	if flag then
		flag.Color = col
		local lbl = flag:FindFirstChild("Label")
		local t = lbl and lbl:FindFirstChild("Text") :: TextLabel?
		if t then
			t.TextColor3 = col
		end
	end
	if ring then
		for _, b in ring:GetChildren() do
			(b :: BasePart).Color = col
		end
	end
end

function WorldBuilder.build()
	local f = Instance.new("Folder")
	f.Name = "CarrierStrikeWorld"
	ocean(f)
	for _, c in World.CARRIERS do
		carrier(f, c)
	end
	for _, i in World.ISLANDS do
		island(f, i)
	end
	f.Parent = workspace

	-- свет: золотой час над морем (как на обложках), лёгкая дымка — острова видно издалека
	Lighting.ClockTime = 17.3
	Lighting.GeographicLatitude = 25
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(80, 74, 90)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 120, 130)
	Lighting.EnvironmentDiffuseScale = 0.7
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true
	local sky = Instance.new("Sky")
	sky.SunAngularSize = 18
	sky.Parent = Lighting
	local atm = Instance.new("Atmosphere")
	atm.Density = 0.1
	atm.Offset = 0.05
	atm.Color = Color3.fromRGB(255, 206, 170)
	atm.Decay = Color3.fromRGB(140, 100, 120)
	atm.Glare = 0.6
	atm.Haze = 0.8
	atm.Parent = Lighting
	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.06
	rays.Spread = 0.6
	rays.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.4
	bloom.Size = 30
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Contrast = 0.06
	cc.Saturation = 0.08
	cc.Parent = Lighting
	local clouds = Instance.new("Clouds")
	clouds.Cover = 0.5
	clouds.Density = 0.6
	clouds.Parent = workspace.Terrain
end

return WorldBuilder
