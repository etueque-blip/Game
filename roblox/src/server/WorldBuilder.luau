--!strict
-- Строит визуальный мир по данным World (сервер, один раз при старте).
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("SkyPilot")
local World = require(Shared:WaitForChild("World"))
local PlaneConfigs = require(Shared:WaitForChild("PlaneConfigs"))
local PlaneBuilder = require(Shared:WaitForChild("PlaneBuilder"))

local WorldBuilder = {}

local rng = Random.new(77)
local function R(a: number, b: number): number
	return a + (b - a) * rng:NextNumber()
end

local function part(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, collide: boolean?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = collide == true
	p.CanTouch = false
	p.CanQuery = collide == true
	p.Parent = parent
	return p
end

local function neon(parent: Instance, size: Vector3, cf: CFrame, color: Color3)
	local p = part(parent, size, cf, color, Enum.Material.Neon)
	p.CastShadow = false
	return p
end

local function setupLighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.5
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 150, 170)
	Lighting.GlobalShadows = true
	local atm = Instance.new("Atmosphere")
	atm.Density = 0.28
	atm.Offset = 0.15
	atm.Color = Color3.fromRGB(199, 215, 235)
	atm.Decay = Color3.fromRGB(106, 130, 160)
	atm.Glare = 0.3
	atm.Haze = 1.2
	atm.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.08
	cc.Contrast = 0.05
	cc.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.5
	bloom.Threshold = 1.6
	bloom.Size = 30
	bloom.Parent = Lighting
	local sun = Instance.new("SunRaysEffect")
	sun.Intensity = 0.05
	sun.Parent = Lighting
	local clouds = Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.6
	clouds.Parent = workspace.Terrain
end

local function buildGround(folder: Folder)
	local tile = 2048
	local n = math.ceil(World.SIZE * 2 / tile)
	local greens = { Color3.fromRGB(96, 140, 70), Color3.fromRGB(104, 146, 74), Color3.fromRGB(90, 132, 66) }
	for i = 0, n - 1 do
		for j = 0, n - 1 do
			local x = -World.SIZE + tile * (i + 0.5)
			local z = -World.SIZE + tile * (j + 0.5)
			part(folder, Vector3.new(tile, 4, tile), CFrame.new(x, -2, z), greens[(i + j) % 3 + 1], Enum.Material.Grass, true)
		end
	end
end

local function buildMountains(folder: Folder)
	for _, e in World.peaks do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		local sx, sy = math.min(e.a * 2, 2048), math.min(e.b * 2, 2048)
		p.Size = Vector3.new(sx, sy, sx)
		p.CFrame = CFrame.new(e.x, e.cy, e.z)
		p.Material = if e.snow then Enum.Material.Snow else Enum.Material.Rock
		p.Color = if e.snow then Color3.fromRGB(240, 244, 250) else Color3.fromRGB(112, 108, 100)
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Scale = Vector3.new(e.a * 2 / sx, e.b * 2 / sy, e.a * 2 / sx)
		m.Parent = p
		p.Parent = folder
	end
end

local function textDecal(p: BasePart, face: Enum.NormalId, text: string, color: Color3, bg: Color3?, font: Enum.Font?)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 4
	sg.LightInfluence = 0.3
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = if bg then 0 else 1
	t.BackgroundColor3 = bg or Color3.new()
	t.Text = text
	t.TextColor3 = color
	t.TextScaled = true
	t.Font = font or Enum.Font.GothamBlack
	t.Parent = sg
	sg.Parent = p
end

local function buildAirport(folder: Folder, ap: any)
	local f = Instance.new("Folder")
	f.Name = "Airport_" .. ap.id
	f.Parent = folder
	local L, W = ap.L, ap.W
	local function cf(lx: number, y: number, lz: number, ry: number?): CFrame
		return World.apCFrame(ap, lx, y, lz) * CFrame.Angles(0, ry or 0, 0)
	end
	local ASPHALT = Color3.fromRGB(48, 50, 54)
	local TAXI = Color3.fromRGB(70, 72, 76)
	local CONCRETE = Color3.fromRGB(165, 165, 160)
	local PAINT = Color3.fromRGB(242, 242, 242)
	local YELLOW = Color3.fromRGB(240, 192, 32)

	part(f, Vector3.new(W, 0.5, L), cf(0, 0.25, 0), ASPHALT, Enum.Material.Asphalt, true)
	-- следы шин в зонах касания
	for _, e in { -1, 1 } do
		local m = part(f, Vector3.new(40, 0.02, 700), cf(0, 0.51, e * (L / 2 - 650)), Color3.fromRGB(20, 20, 20))
		m.Transparency = 0.55
	end
	part(f, Vector3.new(60, 0.48, L), cf(W / 2 + 250, 0.24, 0), TAXI, Enum.Material.Asphalt, true)
	part(f, Vector3.new(1.2, 0.05, L), cf(W / 2 + 250, 0.5, 0), YELLOW)
	for _, s in { -1, 1 } do
		part(f, Vector3.new(3, 0.05, L), cf(s * (W / 2 - 5), 0.52, 0), PAINT)
	end
	for z = -L / 2 + 400, L / 2 - 400, 220 do
		part(f, Vector3.new(2.5, 0.05, 110), cf(0, 0.52, z), PAINT)
	end
	for _, e in { -1, 1 } do
		for i = 1, 6 do
			for _, s in { -1, 1 } do
				part(f, Vector3.new(7, 0.05, 90), cf(s * ((W / 2 - 18) - (i - 1) * 13), 0.52, e * (L / 2 - 60)), PAINT)
			end
		end
		for _, s in { -1, 1 } do
			part(f, Vector3.new(14, 0.05, 180), cf(s * 28, 0.52, e * (L / 2 - 500)), PAINT)
		end
		for k = 0, 2 do
			for _, s in { -1, 1 } do
				part(f, Vector3.new(4, 0.05, 70), cf(s * 22, 0.52, e * (L / 2 - 800 - k * 150)), PAINT)
			end
		end
		-- номер полосы (читается при заходе на посадку)
		local num = part(f, Vector3.new(60, 0.05, 80), cf(0, 0.52, e * (L / 2 - 210), if e > 0 then 0 else math.pi), PAINT)
		num.Transparency = 1
		textDecal(num, Enum.NormalId.Top, if e > 0 then ap.south else ap.north, PAINT)
		-- огни торца, ВПП и PAPI
		for x = -W / 2, W / 2, 20 do
			neon(f, Vector3.new(2, 1, 2), cf(x, 0.5, e * (L / 2 + 2)), Color3.fromRGB(64, 255, 112))
		end
		for k = 1, 10 do
			neon(f, Vector3.new(2, 1.5, 2), cf(0, 0.75, e * (L / 2 + 60 * k)), Color3.fromRGB(255, 243, 208))
		end
		neon(f, Vector3.new(80, 1.5, 2), cf(0, 0.75, e * (L / 2 + 300)), Color3.fromRGB(255, 243, 208))
		local px = -e * (W / 2 + 40)
		for i = 1, 4 do
			neon(f, Vector3.new(4, 3, 4), cf(px - e * (i - 1) * 12, 1.5, e * (L / 2 - 450)), if i <= 2 then Color3.fromRGB(255, 243, 208) else Color3.fromRGB(255, 48, 48))
		end
	end
	for z = -L / 2, L / 2, 125 do
		for _, s in { -1, 1 } do
			neon(f, Vector3.new(1.6, 1.2, 1.6), cf(s * (W / 2 + 3), 0.6, z), Color3.fromRGB(255, 243, 208))
		end
	end
	for _, z in { -L / 2 + 150, 0, L / 2 - 150 } do
		part(f, Vector3.new(220, 0.48, 60), cf(W / 2 + 110, 0.24, z), TAXI, Enum.Material.Asphalt, true)
		part(f, Vector3.new(220, 0.05, 1.2), cf(W / 2 + 110, 0.5, z), YELLOW)
	end
	part(f, Vector3.new(600, 0.49, 2000), cf(W / 2 + 580, 0.245, 0), CONCRETE, Enum.Material.Concrete, true)
	part(f, Vector3.new(600, 0.49, 500), cf(W / 2 + 580, 0.245, -1250), CONCRETE, Enum.Material.Concrete, true)
	for _, p in ap.parked do
		part(f, Vector3.new(160, 0.05, 1.2), cf(W / 2 + 720, 0.51, p[2]), YELLOW)
	end

	-- терминал
	local tx = W / 2 + 950
	local FRAME = Color3.fromRGB(233, 236, 240)
	local GLASS = Color3.fromRGB(34, 56, 79)
	part(f, Vector3.new(140, 8, 900), cf(tx, 4, 0), FRAME, Enum.Material.Concrete, true)
	local g = part(f, Vector3.new(136, 32, 890), cf(tx, 24, 0), GLASS, Enum.Material.Glass, true)
	g.Reflectance = 0.25
	for z = -440, 440, 40 do
		part(f, Vector3.new(141, 32, 1.4), cf(tx, 24, z), FRAME, Enum.Material.Metal)
	end
	part(f, Vector3.new(160, 3, 930), cf(tx + 5, 41.5, 0), Color3.fromRGB(61, 67, 76), Enum.Material.Metal, true)
	local sign = part(f, Vector3.new(2, 30, 500), cf(tx - 74.5, 58, 0), FRAME)
	textDecal(sign, Enum.NormalId.Left, ap.title, Color3.fromRGB(20, 60, 120), FRAME)
	-- телетрапы к лайнерам
	for _, p in ap.parked do
		local c = PlaneConfigs.PLANES[p[1]]
		if c.windows and c.length >= 100 then
			local doorX = W / 2 + 760 - c.length * 0.12
			local zb = p[2] - c.diameter * 0.5 - 4
			local len = (tx - 70) - doorX
			local y = 0.5 + c.gearHeight + c.diameter * 0.1
			part(f, Vector3.new(len, 8, 8), cf(doorX + len / 2, y, zb), Color3.fromRGB(184, 190, 198), Enum.Material.Metal)
			part(f, Vector3.new(2, y, 2), cf(doorX + len * 0.35, y / 2, zb), Color3.fromRGB(107, 112, 120), Enum.Material.Metal)
		end
	end
	-- вышка
	local tw = Instance.new("Part")
	tw.Shape = Enum.PartType.Cylinder
	tw.Anchored = true
	tw.Size = Vector3.new(130, 24, 24)
	tw.CFrame = cf(tx + 20, 65, 560) * CFrame.Angles(0, 0, math.pi / 2)
	tw.Color = Color3.fromRGB(223, 226, 230)
	tw.Material = Enum.Material.Concrete
	tw.Parent = f
	local cab = tw:Clone()
	cab.Size = Vector3.new(16, 44, 44)
	cab.CFrame = cf(tx + 20, 138, 560) * CFrame.Angles(0, 0, math.pi / 2)
	cab.Color = GLASS
	cab.Material = Enum.Material.Glass
	cab.Parent = f
	local roofT = tw:Clone()
	roofT.Size = Vector3.new(3, 48, 48)
	roofT.CFrame = cf(tx + 20, 147.5, 560) * CFrame.Angles(0, 0, math.pi / 2)
	roofT.Color = Color3.fromRGB(61, 67, 76)
	roofT.Material = Enum.Material.Metal
	roofT.Parent = f
	neon(f, Vector3.new(3, 3, 3), cf(tx + 20, 152, 560), Color3.fromRGB(255, 48, 48))
	-- ангары с арочной крышей
	for _, z in { -1130, -1370 } do
		local HW = Color3.fromRGB(183, 190, 200)
		part(f, Vector3.new(170, 30, 210), cf(W / 2 + 790, 15, z), HW, Enum.Material.Metal, true)
		local roof = Instance.new("Part")
		roof.Shape = Enum.PartType.Cylinder
		roof.Anchored = true
		roof.Size = Vector3.new(210, 170, 170)
		-- цилиндр вдоль длины ангара (локальная Z), половина торчит над стенами
		roof.CFrame = cf(W / 2 + 790, 30, z) * CFrame.Angles(0, math.pi / 2, 0)
		roof.Color = HW
		roof.Material = Enum.Material.Metal
		roof.Parent = f
		part(f, Vector3.new(1, 28, 180), cf(W / 2 + 704.5, 15, z), Color3.fromRGB(74, 82, 94), Enum.Material.Metal)
	end
	-- стоящие самолёты
	for _, p in ap.parked do
		local c = PlaneConfigs.PLANES[p[1]]
		local lx = W / 2 + 760 - c.length / 2
		local m = PlaneBuilder.build(c, { static = true })
		m:PivotTo(cf(lx, 0.5 + c.gearHeight, p[2], -math.pi / 2))
		m.Parent = f
	end
	-- точка появления персонажа у терминала
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn_" .. ap.id
	spawn.Anchored = true
	spawn.Size = Vector3.new(24, 1, 24)
	spawn.CFrame = cf(W / 2 + 840, 1, 0)
	spawn.Material = Enum.Material.Concrete
	spawn.Color = CONCRETE
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Enabled = ap.id == "A"
	spawn.Parent = f
end

-- Города из CityData: каждая запись — деталь (коробка, цилиндр, шар, эллипсоид, клин)
local function buildCity(folder: Folder)
	local data = World.CityData
	local f = Instance.new("Folder")
	f.Name = "Cities"
	f.Parent = folder
	for i, d in data.props do
		local kind = d[1]
		local p: BasePart
		if kind == "wedge" then
			p = Instance.new("WedgePart")
		else
			local q = Instance.new("Part")
			if kind == "cyl" then
				q.Shape = Enum.PartType.Cylinder
			elseif kind == "ball" then
				q.Shape = Enum.PartType.Ball
			end
			p = q
		end
		local size = Vector3.new(d[5], d[6], d[7])
		if kind == "ell" then
			local cap = Vector3.new(math.min(size.X, 2048), math.min(size.Y, 2048), math.min(size.Z, 2048))
			p.Size = cap
			local m = Instance.new("SpecialMesh")
			m.MeshType = Enum.MeshType.Sphere
			m.Scale = size / cap
			m.Parent = p
		else
			p.Size = size
		end
		p.CFrame = CFrame.new(d[2], d[3], d[4]) * CFrame.Angles(d[8], d[9], d[10])
		p.Color = Color3.fromHex(string.format("%06x", d[11]))
		local ok, mat = pcall(function()
			return (Enum.Material :: any)[d[12]]
		end)
		p.Material = if ok and mat then mat else Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = d[13] == 1
		p.CanQuery = d[13] == 1
		p.CanTouch = false
		p.Reflectance = d[14] or 0
		p.Transparency = d[15] or 0
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if p.Material == Enum.Material.Neon or math.max(size.X, size.Z) < 2 then
			p.CastShadow = false
		end
		p.Parent = f
		if i % 400 == 0 then
			task.wait() -- не подвешиваем сервер на старте
		end
	end
	-- подписи городов: видно издалека, помогают ориентироваться
	for _, l in data.labels do
		local anchor = Instance.new("Part")
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.Transparency = 1
		anchor.Size = Vector3.one
		anchor.Position = Vector3.new(l.x, l.y, l.z)
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(320, 60)
		bb.MaxDistance = 30000
		bb.LightInfluence = 0
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		t.Text = l.name
		t.TextColor3 = Color3.fromRGB(255, 255, 255)
		t.TextStrokeTransparency = 0.3
		t.Parent = bb
		bb.Parent = anchor
		anchor.Parent = f
	end
end

local function buildNature(folder: Folder)
	local f = Instance.new("Folder")
	f.Name = "Nature"
	f.Parent = folder
	local avoid = { { 400, 0, 3800 }, { 14000, -16000, 3600 } }
	for _, c in World.CITIES do
		table.insert(avoid, { c.x, c.z, c.r })
	end
	table.insert(avoid, { 5500, -9800, 3300 }) -- море у Дубая
	for _, lk in World.LAKES do
		if World.terrainH(lk[1], lk[2]) <= 5 then
			local water = Instance.new("Part")
			water.Shape = Enum.PartType.Cylinder
			water.Anchored = true
			water.CanCollide = false
			water.Size = Vector3.new(0.2, lk[3], lk[3])
			water.CFrame = CFrame.new(lk[1], 0.6, lk[2]) * CFrame.Angles(0, 0, math.pi / 2)
			water.Color = Color3.fromRGB(31, 90, 134)
			water.Material = Enum.Material.Glass
			water.Reflectance = 0.35
			water.Parent = f
			local shore = water:Clone()
			shore.Size = Vector3.new(0.1, lk[3] + 80, lk[3] + 80)
			shore.CFrame = CFrame.new(lk[1], 0.52, lk[2]) * CFrame.Angles(0, 0, math.pi / 2)
			shore.Color = Color3.fromRGB(201, 185, 143)
			shore.Material = Enum.Material.Sand
			shore.Reflectance = 0
			shore.Parent = f
			table.insert(avoid, { lk[1], lk[2], lk[3] / 2 + 50 })
		end
	end
	local function free(x: number, z: number, pad: number): boolean
		for _, a in avoid do
			local dx, dz = x - a[1], z - a[2]
			if math.sqrt(dx * dx + dz * dz) <= a[3] + pad then
				return false
			end
		end
		return World.terrainH(x, z) < 1
	end
	-- поля
	local fc = {
		Color3.fromRGB(122, 166, 74), Color3.fromRGB(201, 182, 94), Color3.fromRGB(139, 107, 75),
		Color3.fromRGB(90, 138, 60), Color3.fromRGB(168, 189, 98), Color3.fromRGB(181, 154, 82),
	}
	local placed = 0
	for _ = 1, 900 do
		if placed >= 220 then
			break
		end
		local x, z = R(-22000, 22000), R(-22000, 22000)
		if free(x, z, 700) then
			placed += 1
			local p = part(f, Vector3.new(R(300, 1100), 0.1, R(300, 1100)), CFrame.new(x, 0.05 + (placed % 20) * 0.012, z) * CFrame.Angles(0, R(0, math.pi), 0), fc[rng:NextInteger(1, #fc)], Enum.Material.Grass)
			p.CastShadow = false
		end
	end
	-- лес: ствол + крона
	local leafs = { Color3.fromRGB(47, 90, 42), Color3.fromRGB(59, 107, 48), Color3.fromRGB(39, 77, 38), Color3.fromRGB(70, 115, 58) }
	for _ = 1, 45 do
		local cx, cz = R(-21000, 21000), R(-21000, 21000)
		if free(cx, cz, 900) then
			local n = rng:NextInteger(30, 55)
			local spread = R(250, 600)
			for _ = 1, n do
				local a, d = rng:NextNumber() * math.pi * 2, math.sqrt(rng:NextNumber()) * spread
				local x, z = cx + math.cos(a) * d, cz + math.sin(a) * d
				local h = World.terrainH(x, z)
				if h <= 380 then
					local s = R(0.8, 1.5)
					local trunk = part(f, Vector3.new(1.6 * s, 10 * s, 1.6 * s), CFrame.new(x, h + 5 * s, z), Color3.fromRGB(74, 53, 36), Enum.Material.Wood)
					trunk.CastShadow = false
					local crown = Instance.new("Part")
					crown.Shape = Enum.PartType.Ball
					crown.Anchored = true
					crown.CanCollide = false
					crown.CanQuery = false
					crown.Size = Vector3.one * (14 * s)
					crown.CFrame = CFrame.new(x, h + 15 * s, z)
					crown.Color = leafs[rng:NextInteger(1, #leafs)]
					crown.Material = Enum.Material.LeafyGrass
					crown.Parent = f
				end
			end
		end
	end
end

function WorldBuilder.build()
	setupLighting()
	local folder = Instance.new("Folder")
	folder.Name = "SkyPilotWorld"
	folder.Parent = workspace
	buildGround(folder)
	buildMountains(folder)
	for _, ap in World.AIRPORTS do
		buildAirport(folder, ap)
	end
	buildCity(folder)
	buildNature(folder)
	local planes = Instance.new("Folder")
	planes.Name = "Planes"
	planes.Parent = workspace
	return folder
end

return WorldBuilder
