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

-- ссылки для смены цвета неба по времени суток (updateSky)
local skyFx: { atm: Atmosphere?, cc: ColorCorrectionEffect?, clouds: Clouds?, cabs: { PointLight } } = { cabs = {} }

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
	skyFx.atm = atm
	-- звёздное небо, солнце и луна
	local sky = Instance.new("Sky")
	sky.StarCount = 3000
	sky.CelestialBodiesShown = true
	sky.SunAngularSize = 16
	sky.MoonAngularSize = 10
	sky.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.08
	cc.Contrast = 0.05
	cc.Parent = Lighting
	skyFx.cc = cc
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
	skyFx.clouds = clouds
	-- вода движка: цвет, волны, отражения
	local T = workspace.Terrain
	T.WaterColor = Color3.fromRGB(24, 86, 122)
	T.WaterReflectance = 0.8
	T.WaterTransparency = 0.35
	T.WaterWaveSize = 0.12
	T.WaterWaveSpeed = 9
end

local function mix(a: Color3, b: Color3, t: number): Color3
	return a:Lerp(b, math.clamp(t, 0, 1))
end

-- цвет атмосферы, облаков и общий оттенок по времени суток: голубой день, тёплый закат, синяя ночь
function WorldBuilder.updateSky(clock: number, rain: number?, mist: number?)
	local r = math.clamp(rain or 0, 0, 1)
	local elev = math.sin((clock - 6) / 24 * math.pi * 2)
	local day = math.clamp(elev * 3 + 0.25, 0, 1)
	local dusk = if elev > -0.25 then math.clamp(1 - math.abs(elev) * 4, 0, 1) else 0
	local atm, cc, clouds = skyFx.atm, skyFx.cc, skyFx.clouds
	if atm then
		atm.Color = mix(mix(Color3.fromRGB(28, 36, 64), Color3.fromRGB(199, 215, 235), day), Color3.fromRGB(255, 168, 120), dusk * 0.55)
		atm.Decay = mix(mix(Color3.fromRGB(16, 20, 40), Color3.fromRGB(106, 130, 160), day), Color3.fromRGB(196, 104, 78), dusk * 0.6)
		atm.Glare = (0.3 + dusk * 0.9) * (1 - r)
		atm.Haze = 1.2 + dusk * 0.8 + r * 1.5
		-- дождь: серая плотная дымка, хуже видимость
		atm.Color = mix(atm.Color, Color3.fromRGB(150, 156, 166):Lerp(Color3.fromRGB(30, 34, 44), 1 - day), r * 0.75)
		atm.Density = 0.28 + r * 0.22
		-- утренний туман: молочная плотная дымка у земли (с высотой атмосфера движка сама редеет)
		local m = math.clamp(mist or 0, 0, 1)
		if m > 0 then
			atm.Color = mix(atm.Color, Color3.fromRGB(223, 227, 232):Lerp(Color3.fromRGB(60, 64, 72), 1 - day), m * 0.7)
			atm.Density = math.min(0.75, atm.Density + m * 0.36)
			atm.Haze = atm.Haze + m * 2.5
			atm.Glare = atm.Glare * (1 - 0.7 * m)
		end
	end
	if clouds then
		clouds.Color = mix(mix(mix(Color3.fromRGB(60, 66, 88), Color3.new(1, 1, 1), day), Color3.fromRGB(255, 186, 150), dusk * 0.6), Color3.fromRGB(110, 116, 126), r * 0.7)
		clouds.Cover = 0.55 + r * 0.4
		clouds.Density = 0.6 + r * 0.35
	end
	for _, l in skyFx.cabs do
		l.Brightness = 2.2 * (1 - day)
	end
	if cc then
		cc.TintColor = mix(mix(Color3.fromRGB(196, 206, 255), Color3.new(1, 1, 1), day), Color3.fromRGB(255, 222, 196), dusk * 0.7)
		cc.Brightness = -0.08 * r
		cc.Saturation = 0.08 - 0.25 * r
	end
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

	part(f, Vector3.new(W, 0.5, L), cf(0, 0.25, 0), ASPHALT, Enum.Material.Asphalt, true).Name = "RunwaySurface" -- в дождь блестит (клиент)
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
		-- огни подхода (ALS): 15 стоек через 60 stud (900 stud) со светящейся планкой, поперечины на 300 и 600,
		-- красные боковые ряды у торца и бегущие вспышки «Rabbit» (их переключает клиент)
		local WARMW = Color3.fromRGB(255, 243, 208)
		for k = 1, 15 do
			local z = e * (L / 2 + 60 * k)
			part(f, Vector3.new(0.8, 2.6, 0.8), cf(0, 1.3, z), Color3.fromRGB(80, 84, 92), Enum.Material.Metal).CastShadow = false
			neon(f, Vector3.new(18, 1.4, 2), cf(0, 3, z), WARMW)
			if k <= 5 then
				for _, s2 in { -1, 1 } do
					neon(f, Vector3.new(10, 1.4, 2), cf(s2 * 26, 3, z), Color3.fromRGB(255, 48, 48))
				end
			else
				local r = neon(f, Vector3.new(3.4, 2.6, 3.4), cf(0, 4.6, z), Color3.new(1, 1, 1))
				r.Name = "Rabbit"
				r:SetAttribute("Seq", 15 - k)
				r.Transparency = 1
			end
		end
		for _, zc in { 300, 600 } do
			for _, s2 in { -1, 1 } do
				neon(f, Vector3.new(54, 1.4, 2), cf(s2 * 39, 3, e * (L / 2 + zc)), WARMW)
			end
		end
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
	-- синие огни по краям рулёжек
	local BLUE = Color3.fromRGB(58, 108, 255)
	for z = -L / 2, L / 2, 150 do
		for _, s2 in { -1, 1 } do
			neon(f, Vector3.new(1.4, 1.2, 1.4), cf(W / 2 + 250 + s2 * 31, 0.6, z), BLUE)
		end
	end
	for _, zc in { -L / 2 + 150, 0, L / 2 - 150 } do
		for x = W / 2 + 20, W / 2 + 215, 65 do
			for _, s2 in { -1, 1 } do
				neon(f, Vector3.new(1.4, 1.2, 1.4), cf(x, 0.6, zc + s2 * 31), BLUE)
			end
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
	-- терминал: крыша-волна со световыми фонарями, навес над подъездом, дорога и парковка с машинами
	for k = -4, 4 do
		local roof = part(f, Vector3.new(172, 1.6, 101), cf(tx + 4, 45, k * 100) * CFrame.Angles(if k % 2 == 0 then 0.1 else -0.1, 0, 0), Color3.fromRGB(214, 218, 224), Enum.Material.Metal)
		roof.CastShadow = true
		if k < 4 then
			local sky = part(f, Vector3.new(150, 0.8, 6), cf(tx + 4, 49.6 + (if k % 2 == 0 then 0 else -0.1), k * 100 + 50), Color3.fromRGB(120, 170, 210), Enum.Material.Glass)
			sky.Transparency = 0.3
			sky.CastShadow = false
		end
	end
	part(f, Vector3.new(26, 1.4, 760), cf(tx + 84, 21, 0), Color3.fromRGB(200, 204, 212), Enum.Material.Metal).CastShadow = true
	for z = -360, 360, 80 do
		part(f, Vector3.new(2, 20, 2), cf(tx + 94, 10.5, z), Color3.fromRGB(150, 156, 164), Enum.Material.Metal)
	end
	part(f, Vector3.new(34, 0.1, 1240), cf(tx + 114, 0.52, 0), Color3.fromRGB(52, 54, 58), Enum.Material.Asphalt)
	for z = -600, 600, 36 do
		part(f, Vector3.new(0.8, 0.05, 14), cf(tx + 114, 0.58, z), PAINT).CastShadow = false
	end
	part(f, Vector3.new(170, 0.1, 620), cf(tx + 220, 0.52, 0), Color3.fromRGB(60, 62, 66), Enum.Material.Asphalt)
	local CAR = { Color3.fromRGB(235, 236, 238), Color3.fromRGB(28, 30, 34), Color3.fromRGB(150, 156, 164), Color3.fromRGB(160, 30, 36), Color3.fromRGB(30, 70, 140), Color3.fromRGB(210, 210, 200) }
	local rnd = Random.new(#ap.id * 97 + string.byte(ap.id))
	for _, rx in { 165, 215, 265 } do
		for z = -288, 288, 16 do
			part(f, Vector3.new(16, 0.05, 0.5), cf(tx + rx, 0.58, z - 8), PAINT).CastShadow = false
			if rnd:NextNumber() < 0.55 then
				local car = part(f, Vector3.new(8, 3.2, 4.4), cf(tx + rx + rnd:NextNumber(-0.6, 0.6), 2.2, z), CAR[rnd:NextInteger(1, #CAR)], Enum.Material.SmoothPlastic)
				car.Reflectance = 0.12
			end
		end
	end

	-- телетрапы: ротонда на колонне у терминала, телескопические секции, кабина с окном, гармошка к двери, опора на колёсах
	local JW = Color3.fromRGB(196, 201, 208)
	local JD = Color3.fromRGB(70, 76, 86)
	local JG = Color3.fromRGB(34, 52, 72)
	local function cylX(size: Vector3, c: CFrame, color: Color3, mat: Enum.Material?)
		local p = part(f, size, c, color, mat or Enum.Material.Metal)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	for _, p in ap.parked do
		local c = PlaneConfigs.PLANES[p[1]]
		if c.windows and c.length >= 100 then
			local doorX = W / 2 + 760 - c.length * 0.12
			local zb = p[2] - c.diameter * 0.5 - 6
			local y = 0.5 + c.gearHeight + c.diameter * 0.1
			local xR = tx - 84
			cylX(Vector3.new(y, 6, 6), cf(xR, y / 2, zb) * CFrame.Angles(0, 0, math.pi / 2), JD)
			cylX(Vector3.new(11, 15, 15), cf(xR, y + 1, zb) * CFrame.Angles(0, 0, math.pi / 2), JW)
			part(f, Vector3.new(14, 8, 8), cf((xR + tx - 70) / 2, y + 1, zb), JW, Enum.Material.Metal)
			local x0, x1 = xR - 7, doorX + 7
			local len = x0 - x1
			for k = 0, 2 do
				local a = x0 - len * k / 3
				local b = x0 - len * (k + 1) / 3 - (if k < 2 then 2 else 0)
				local sz = 9 - k * 0.6
				part(f, Vector3.new(a - b, sz, sz), cf((a + b) / 2, y + 1, zb), JW, Enum.Material.Metal)
				part(f, Vector3.new(a - b - 1, 2, sz + 0.2), cf((a + b) / 2, y + 2, zb), JG, Enum.Material.Glass)
			end
			part(f, Vector3.new(12, 10, 12), cf(doorX + 2, y + 1.5, zb + 2), JW, Enum.Material.Metal)
			part(f, Vector3.new(10, 3, 12.2), cf(doorX + 2, y + 3, zb + 2), JG, Enum.Material.Glass)
			part(f, Vector3.new(9, 8, 3), cf(doorX, y + 1, zb + 9), JD, Enum.Material.Fabric)
			local legX = x1 + len * 0.3
			for _, dz in { -3, 3 } do
				part(f, Vector3.new(1.4, y - 2, 1.4), cf(legX, (y - 2) / 2 + 1.5, zb + dz), JD, Enum.Material.Metal)
			end
			part(f, Vector3.new(3, 1.4, 9), cf(legX, 1.5, zb), JD, Enum.Material.Metal)
			for _, dz in { -4, 4 } do
				cylX(Vector3.new(2, 3, 3), cf(legX, 1.5, zb + dz) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(24, 24, 26), Enum.Material.Rubber)
			end
		end
	end
	-- служебные машины у самолётов: буксир, багажный тягач с тележками, топливозаправщик
	local YEL = Color3.fromRGB(242, 190, 40)
	local WHEEL = Color3.fromRGB(24, 24, 26)
	local function wheels(x: number, z: number, lenX: number, wid: number)
		for _, dx in { -lenX / 2 + 1.4, lenX / 2 - 1.4 } do
			for _, dz in { -wid / 2, wid / 2 } do
				cylX(Vector3.new(1, 2.4, 2.4), cf(x + dx, 1.2, z + dz) * CFrame.Angles(0, math.pi / 2, 0), WHEEL, Enum.Material.Rubber)
			end
		end
	end
	for _, p in ap.parked do
		local c = PlaneConfigs.PLANES[p[1]]
		local z = p[2]
		local noseX = W / 2 + 760
		-- буксир у носовой стойки
		part(f, Vector3.new(10, 2.6, 6), cf(noseX + 8, 1.8, z), YEL, Enum.Material.SmoothPlastic)
		part(f, Vector3.new(3, 2, 5), cf(noseX + 11, 4, z), Color3.fromRGB(40, 46, 56), Enum.Material.Glass)
		wheels(noseX + 8, z, 10, 6.2)
		if c.windows and c.length >= 100 then
			-- багажный тягач и три тележки у заднего грузового люка
			local bx = noseX - c.length * 0.72
			local bz = z + c.diameter * 0.5 + 10
			part(f, Vector3.new(7, 3, 5), cf(bx, 2, bz), YEL, Enum.Material.SmoothPlastic)
			part(f, Vector3.new(3, 2.5, 5), cf(bx + 1.5, 4.6, bz), Color3.fromRGB(40, 46, 56), Enum.Material.Glass)
			wheels(bx, bz, 7, 5.2)
			for k = 1, 3 do
				local cx = bx - 3 - k * 8
				part(f, Vector3.new(6.5, 0.6, 5), cf(cx, 1.8, bz), Color3.fromRGB(120, 126, 134), Enum.Material.Metal)
				part(f, Vector3.new(5.5, 2.4, 4.2), cf(cx, 3.3, bz), ({ Color3.fromRGB(58, 74, 110), Color3.fromRGB(140, 60, 50), Color3.fromRGB(70, 70, 76) })[k], Enum.Material.Fabric)
				wheels(cx, bz, 6.5, 4.6)
			end
			-- топливозаправщик под крылом
			local fx, fz = noseX - c.length * 0.45, z + c.span * 0.3
			part(f, Vector3.new(6, 5, 7), cf(fx + 11, 3.2, fz), Color3.fromRGB(230, 232, 236), Enum.Material.SmoothPlastic)
			part(f, Vector3.new(2, 2.2, 6.4), cf(fx + 13.6, 4.4, fz), Color3.fromRGB(40, 46, 56), Enum.Material.Glass)
			cylX(Vector3.new(18, 7, 7), cf(fx - 1, 4.6, fz), Color3.fromRGB(236, 238, 240), Enum.Material.Metal)
			part(f, Vector3.new(18, 0.8, 7.2), cf(fx - 1, 3.6, fz), Color3.fromRGB(200, 40, 40), Enum.Material.SmoothPlastic)
			wheels(fx + 4, fz, 26, 6.4)
		end
	end
	-- мачты освещения перрона: ночью лампы светятся (клиент переключает детали «ApronLamp»)
	for _, mz in { -900, -300, 300, 900 } do
		local mx = W / 2 + 300
		part(f, Vector3.new(2.4, 70, 2.4), cf(mx, 35, mz), Color3.fromRGB(150, 156, 164), Enum.Material.Metal)
		part(f, Vector3.new(4, 2, 18), cf(mx + 1, 70, mz), Color3.fromRGB(70, 76, 86), Enum.Material.Metal)
		for _, dz in { -6, 0, 6 } do
			local lamp = part(f, Vector3.new(3, 1.2, 4), cf(mx + 2.5, 69, mz + dz), Color3.fromRGB(255, 238, 200), Enum.Material.SmoothPlastic)
			lamp.Name = "ApronLamp"
			lamp.CastShadow = false
			local sl = Instance.new("SpotLight")
			sl.Face = Enum.NormalId.Bottom
			sl.Angle = 100
			sl.Range = 60
			sl.Brightness = 2.5
			sl.Color = Color3.fromRGB(255, 226, 180)
			sl.Enabled = false
			sl.Parent = lamp
		end
	end
	-- грузовой терминал (как в веб-версии, tools/web_cargo.py): склад с восемью доками и вывеской,
	-- площадка, ряды авиаконтейнеров, тягач с тележками, погрузчик-платформа
	do
		local CX, CZ = W / 2 + 1010, 1260
		local YEL = Color3.fromRGB(242, 190, 40)
		local ULD = { Color3.fromRGB(196, 201, 207), Color3.fromRGB(47, 95, 168), Color3.fromRGB(212, 106, 42), Color3.fromRGB(154, 160, 168) }
		part(f, Vector3.new(430, 0.2, 520), cf(W / 2 + 915, 0.53, CZ), Color3.fromRGB(165, 165, 160), Enum.Material.Concrete)
		part(f, Vector3.new(200, 30, 260), cf(CX, 15, CZ), Color3.fromRGB(217, 221, 226), Enum.Material.Concrete, true)
		part(f, Vector3.new(204, 2, 264), cf(CX, 31, CZ), Color3.fromRGB(107, 116, 128), Enum.Material.Metal)
		for k = 0, 7 do
			local z = CZ - 105 + k * 30
			part(f, Vector3.new(1, 14, 22), cf(CX - 100.6, 7.5, z), Color3.fromRGB(43, 48, 56), Enum.Material.Metal)
			part(f, Vector3.new(1.2, 2, 24), cf(CX - 100.8, 15.5, z), YEL)
			part(f, Vector3.new(6, 1.2, 22), cf(CX - 103, 1.2, z), Color3.fromRGB(80, 86, 94), Enum.Material.Concrete)
		end
		local sign = part(f, Vector3.new(1, 11, 90), cf(CX - 101, 24, CZ), Color3.fromRGB(31, 79, 154))
		textDecal(sign, Enum.NormalId.Left, "CARGO TERMINAL", Color3.new(1, 1, 1), Color3.fromRGB(31, 79, 154))
		local n = 0
		for r = 0, 3 do
			for k = 0, 8 do
				if (r * 9 + k) % 7 ~= 3 then
					local x, z = W / 2 + 735 + r * 30, CZ - 170 + k * 14
					for t = 0, (if (r + k) % 3 == 0 then 1 else 0) do
						part(f, Vector3.new(9, 0.6, 9), cf(x, 0.9 + t * 8.2, z), Color3.fromRGB(48, 52, 58))
						n += 1
						part(f, Vector3.new(9, 7.4, 9), cf(x, 4.9 + t * 8.2, z), ULD[(n - 1) % 4 + 1], Enum.Material.Metal)
					end
				end
			end
		end
		local tz, tx0 = CZ + 120, W / 2 + 760
		part(f, Vector3.new(8, 3, 5), cf(tx0, 2, tz), YEL)
		part(f, Vector3.new(3, 2.5, 5), cf(tx0 + 1.5, 4.6, tz), Color3.fromRGB(40, 48, 56), Enum.Material.Glass)
		for k = 1, 3 do
			local x = tx0 - 3 - k * 11
			part(f, Vector3.new(10, 0.8, 9), cf(x, 1.8, tz), Color3.fromRGB(120, 126, 134), Enum.Material.Metal)
			part(f, Vector3.new(9, 7.4, 9), cf(x, 6, tz), ULD[k % 4 + 1], Enum.Material.Metal)
		end
		local kx, kz = CX - 120, CZ - 75
		part(f, Vector3.new(14, 2, 10), cf(kx, 1.8, kz), YEL)
		part(f, Vector3.new(14, 1, 10), cf(kx, 10, kz), YEL)
		part(f, Vector3.new(9, 7.4, 9), cf(kx, 14.7, kz), ULD[2], Enum.Material.Metal)
		for _, s in { -1, 1 } do
			part(f, Vector3.new(15, 0.8, 0.8), cf(kx, 6, kz + s * 4.6) * CFrame.Angles(0, 0, s * 0.55), Color3.fromRGB(80, 86, 94), Enum.Material.Metal)
		end
	end
	-- пожарная станция, топливный склад, указатели рулёжек, ветроуказатель (конус поворачивает клиент по ветру)
	do
		local fx, fz = W / 2 + 420, 1260
		part(f, Vector3.new(90, 18, 50), cf(fx, 9, fz), Color3.fromRGB(226, 228, 232), Enum.Material.Concrete, true)
		part(f, Vector3.new(92, 2, 52), cf(fx, 19, fz), Color3.fromRGB(70, 76, 86), Enum.Material.Metal)
		for k = -1, 1 do
			part(f, Vector3.new(1, 13, 24), cf(fx - 45.6, 7, fz + k * 15), Color3.fromRGB(196, 40, 36), Enum.Material.Metal)
		end
		local sgn = part(f, Vector3.new(1, 5, 40), cf(fx - 45.6, 16, fz), Color3.fromRGB(196, 40, 36))
		textDecal(sgn, Enum.NormalId.Left, "FIRE · RESCUE", Color3.new(1, 1, 1), Color3.fromRGB(196, 40, 36))
		part(f, Vector3.new(14, 8, 7), cf(fx - 58, 4.5, fz + 15), Color3.fromRGB(210, 40, 34), Enum.Material.SmoothPlastic)
		local tx2, tz2 = W / 2 + 560, 1380
		for k = 0, 2 do
			local tank = part(f, Vector3.new(16, 34, 34), cf(tx2 + k * 46, 8, tz2) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(236, 238, 240), Enum.Material.Metal, true)
			tank.Shape = Enum.PartType.Cylinder
		end
		part(f, Vector3.new(150, 3, 60), cf(tx2 + 46, 1.5, tz2), Color3.fromRGB(150, 150, 146), Enum.Material.Concrete)
		for k, zc in { -L / 2 + 150, 0, L / 2 - 150 } do
			for _, s2 in { -1, 1 } do
				local board = part(f, Vector3.new(2, 4, 9), cf(W / 2 + 16, 3.6, zc + s2 * 42), Color3.fromRGB(240, 200, 30), Enum.Material.SmoothPlastic)
				board.CastShadow = false
				textDecal(board, Enum.NormalId.Left, ap.id .. tostring(k), Color3.new(0, 0, 0), Color3.fromRGB(240, 200, 30))
				textDecal(board, Enum.NormalId.Right, ap.id .. tostring(k), Color3.new(0, 0, 0), Color3.fromRGB(240, 200, 30))
				part(f, Vector3.new(0.5, 1.6, 0.5), cf(W / 2 + 16, 0.8, zc + s2 * 42), Color3.fromRGB(60, 60, 60), Enum.Material.Metal)
			end
		end
		local wx, wz = -(W / 2 + 110), L / 2 - 500
		part(f, Vector3.new(0.8, 22, 0.8), cf(wx, 11, wz), Color3.fromRGB(200, 200, 205), Enum.Material.Metal)
		local cone = part(f, Vector3.new(3, 3, 14), cf(wx, 21.5, wz), Color3.fromRGB(255, 110, 20), Enum.Material.Fabric)
		cone.Name = "WindsockCone"
		cone:SetAttribute("PoleCF", cf(wx, 21.5, wz))
		for i = 1, 2 do -- белые полосы
			local band = part(f, Vector3.new(3.1, 3.1, 2), cone.CFrame * CFrame.new(0, 0, -7 + i * 4.6), Color3.new(1, 1, 1), Enum.Material.Fabric)
			band.Name = "WindsockBand"
			band:SetAttribute("Offset", -7 + i * 4.6)
			band.Parent = cone
		end
	end
	-- диспетчерская вышка (как в веб-версии, tools/web_tower.py): двухъярусный ствол, балкон, стеклянная кабина
	-- со стойками (ночью светится — свет включает updateSky), крыша с антеннами и красным огнём
	do
		local X, Z = tx + 20, 560
		local TW, DARK = Color3.fromRGB(223, 226, 230), Color3.fromRGB(61, 67, 76)
		local function cyl(h: number, d: number, y: number, color: Color3, mat: Enum.Material): Part
			local p = part(f, Vector3.new(h, d, d), cf(X, y, Z) * CFrame.Angles(0, 0, math.pi / 2), color, mat, true)
			p.Shape = Enum.PartType.Cylinder
			return p
		end
		cyl(50, 27, 25, TW, Enum.Material.Concrete)
		cyl(50, 21, 75, TW, Enum.Material.Concrete)
		cyl(30, 16, 115, Color3.fromRGB(201, 206, 213), Enum.Material.Concrete)
		cyl(1.5, 34, 130.5, DARK, Enum.Material.Metal)
		local cab = cyl(15, 38, 139, GLASS, Enum.Material.Glass)
		local cl = Instance.new("PointLight")
		cl.Name = "CabLight"
		cl.Color = Color3.fromRGB(255, 217, 160)
		cl.Range = 40
		cl.Brightness = 0
		cl.Parent = cab
		table.insert(skyFx.cabs, cl)
		for i = 0, 7 do
			local a0 = (i + 0.5) / 8 * math.pi * 2
			part(f, Vector3.new(0.8, 15.5, 0.8), cf(X + math.cos(a0) * 18.6, 139, Z + math.sin(a0) * 18.6), DARK, Enum.Material.Metal)
		end
		cyl(2.5, 46, 148, DARK, Enum.Material.Metal)
		cyl(4, 24, 151.2, TW, Enum.Material.Concrete)
		part(f, Vector3.new(0.6, 14, 0.6), cf(X - 4, 160, Z), Color3.fromRGB(208, 212, 218), Enum.Material.Metal)
		part(f, Vector3.new(0.6, 10, 0.6), cf(X + 5, 158, Z), Color3.fromRGB(208, 212, 218), Enum.Material.Metal)
		neon(f, Vector3.new(2, 2, 2), cf(X - 4, 167.5, Z), Color3.fromRGB(255, 48, 48))
	end
	-- обзорный радар на решётчатой мачте по другую сторону полосы (антенну вращает клиент: атрибуты RadarPivot/RadarOff)
	do
		local RX, RZ = -(W / 2 + 320), -900
		local STEEL = Color3.fromRGB(185, 191, 199)
		part(f, Vector3.new(44, 1, 44), cf(RX, 0.5, RZ), Color3.fromRGB(165, 165, 160), Enum.Material.Concrete)
		for _, sx in { -6, 6 } do
			for _, sz in { -6, 6 } do
				part(f, Vector3.new(1.2, 40, 1.2), cf(RX + sx, 20, RZ + sz), STEEL, Enum.Material.Metal, true)
			end
		end
		for k = 1, 4 do
			for _, b2 in { { 12, 0.6, 0, -6 }, { 12, 0.6, 0, 6 }, { 0.6, 12, -6, 0 }, { 0.6, 12, 6, 0 } } do
				part(f, Vector3.new(b2[1], 0.6, b2[2]), cf(RX + b2[3], k * 9, RZ + b2[4]), STEEL, Enum.Material.Metal)
			end
		end
		part(f, Vector3.new(16, 1.5, 16), cf(RX, 41, RZ), Color3.fromRGB(90, 96, 104), Enum.Material.Metal, true)
		local pivot = cf(RX, 46, RZ)
		for _, d in { { Vector3.new(34, 9, 1.2), CFrame.new(0, 3, -1.5) * CFrame.Angles(-0.25, 0, 0), Color3.fromRGB(232, 235, 239) }, { Vector3.new(1, 1, 7), CFrame.new(0, 0.5, 2.5), STEEL } } do
			local p = part(f, d[1], pivot * d[2], d[3], Enum.Material.Metal)
			p.Name = "RadarDish"
			p:SetAttribute("RadarPivot", pivot)
			p:SetAttribute("RadarOff", d[2])
		end
	end
	-- ангары техобслуживания (как в веб-версии, tools/web_hangar.py): открытые ворота, полая арочная крыша из панелей,
	-- задняя стена-полукруг, сдвинутые створки, светлый пол с разметкой, лампы, внутри самолёт на обслуживании со стремянками
	do
		local HW = Color3.fromRGB(183, 190, 200)
		local YEL = Color3.fromRGB(242, 190, 40)
		local R0, N, HX = 105, 12, W / 2 + 790
		local pw = 2 * R0 * math.sin(math.pi / N / 2) + 0.6
		for _, h in { { -1130, "B737" }, { -1370, "A220" } } do
			local z, pid = h[1], h[2]
			for _, s in { -1, 1 } do
				part(f, Vector3.new(170, 30, 2), cf(HX, 15, z + s * R0), HW, Enum.Material.Metal, true)
			end
			for i = 0, N - 1 do
				local th = -math.pi / 2 + (i + 0.5) * math.pi / N
				part(f, Vector3.new(170, 2, pw), cf(HX, 30 + R0 * math.cos(th), z + R0 * math.sin(th)) * CFrame.Angles(th, 0, 0), HW, Enum.Material.Metal, true)
			end
			part(f, Vector3.new(2, 30, 210), cf(HX + 85, 15, z), HW, Enum.Material.Metal, true)
			-- задняя стена: диск, нижняя половина уходит под землю
			local back = part(f, Vector3.new(2, R0 * 2, R0 * 2), cf(HX + 85, 30, z), HW, Enum.Material.Metal, true)
			back.Shape = Enum.PartType.Cylinder
			-- фронтон над воротами (полосы по форме арки) и боковые стойки
			local y0 = 92
			while y0 < 30 + R0 do
				local half = math.sqrt(math.max(0, R0 * R0 - (y0 - 30) ^ 2))
				if half > 1 then
					part(f, Vector3.new(2, 3.5, half * 2), cf(HX - 85, y0 + 1.75, z), HW, Enum.Material.Metal, true)
				end
				y0 += 3.5
			end
			for _, s in { -1, 1 } do
				for _, zc in { 88.5, 95.5, 102 } do
					local hh = 30 + math.sqrt(math.max(0, R0 * R0 - (zc + 3.5) ^ 2))
					part(f, Vector3.new(2, hh, 7), cf(HX - 85, hh / 2, z + s * zc), HW, Enum.Material.Metal, true)
				end
				-- створки ворот, сдвинутые к краям
				for k = 0, 2 do
					local dx, dz = HX - 87 - k * 1.6, z + s * (96 - k * 3)
					part(f, Vector3.new(1, 84, 24), cf(dx, 42.5, dz), Color3.fromRGB(211, 216, 222), Enum.Material.Metal, true)
					part(f, Vector3.new(1.1, 4, 24), cf(dx, 12, dz), Color3.fromRGB(31, 79, 154))
				end
			end
			part(f, Vector3.new(1.5, 4, 172), cf(HX - 86, 92, z), Color3.fromRGB(74, 82, 94), Enum.Material.Metal)
			-- пол, разметка, лампы
			part(f, Vector3.new(166, 0.2, 206), cf(HX, 0.58, z), Color3.fromRGB(205, 209, 214), Enum.Material.SmoothPlastic)
			for _, s in { -1, 1 } do
				part(f, Vector3.new(150, 0.05, 1.2), cf(HX, 0.7, z + s * 80), YEL)
			end
			for _, zo in { -50, 0, 50 } do
				local lamp = neon(f, Vector3.new(150, 0.6, 2.4), cf(HX, 30 + math.sqrt(R0 * R0 - zo * zo) - 3, z + zo), Color3.fromRGB(255, 244, 220))
				if zo == 0 then
					local pl = Instance.new("PointLight")
					pl.Range = 60
					pl.Brightness = 1.2
					pl.Color = Color3.fromRGB(255, 240, 215)
					pl.Parent = lamp
				end
			end
			-- самолёт на обслуживании (носом к воротам) и стремянки
			local c = PlaneConfigs.PLANES[pid]
			local m = PlaneBuilder.build(c, { static = true })
			m:PivotTo(cf(HX - 10, 0.5 + c.gearHeight, z, math.pi / 2))
			m.Parent = f
			local sx = HX - 10 - c.length * 0.03
			for _, s in { -1, 1 } do
				local sz = z + s * c.span * 0.17
				part(f, Vector3.new(10, 1, 9), cf(sx, 7, sz), YEL)
				for _, a in { -4, 4 } do
					for _, bb in { -3.5, 3.5 } do
						part(f, Vector3.new(0.6, 7, 0.6), cf(sx + a, 3.5, sz + bb), YEL)
					end
				end
			end
			local nx = HX - 10 - c.length * 0.5 + 6
			part(f, Vector3.new(7, 1, 7), cf(nx, c.gearHeight + 0.5, z + c.diameter * 0.7), YEL)
			for k = 0, 3 do
				part(f, Vector3.new(7, 0.5, 2), cf(nx, 0.5 + (k + 0.5) * (c.gearHeight / 4), z + c.diameter * 0.7 + 4 + k * 2), YEL)
			end
		end
	end
	-- стоящие самолёты
	for _, p in ap.parked do
		local c = PlaneConfigs.PLANES[p[1]]
		local lx = W / 2 + 760 - c.length / 2
		local m = PlaneBuilder.build(c, { static = true })
		m:PivotTo(cf(lx, 0.5 + c.gearHeight, p[2], -math.pi / 2))
		m.Parent = f
	end
	-- стоянки: жёлтая осевая, стоп-линия и номер
	for _, st in World.STANDS[ap.id] or {} do
		part(f, Vector3.new(260, 0.05, 1.4), cf(st.lx - 60, 0.51, st.lz), YELLOW)
		part(f, Vector3.new(1.4, 0.05, 40), cf(st.lx + 60, 0.51, st.lz), YELLOW)
		local pad = part(f, Vector3.new(60, 0.05, 30), cf(st.lx - 150, 0.52, st.lz, -math.pi / 2), Color3.fromRGB(40, 42, 48))
		textDecal(pad, Enum.NormalId.Top, st.id, YELLOW, Color3.fromRGB(40, 42, 48))
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

-- Настоящая вода движка (Terrain Water: волны, отражения, прозрачность) вместо плоского стекла.
-- top — высота поверхности; заливаем слой глубиной 7 stud вниз (ниже — под деталями земли).
local function terrainWaterBlock(cframe: CFrame, size: Vector3, top: number): boolean
	local depth = 7
	return pcall(function()
		local c = CFrame.new(cframe.Position.X, top - depth / 2, cframe.Position.Z) * cframe.Rotation
		workspace.Terrain:FillBlock(c, Vector3.new(size.X, depth, size.Z), Enum.Material.Water)
	end)
end
local function terrainWaterDisc(x: number, z: number, diameter: number, top: number): boolean
	local depth = 7
	return pcall(function()
		workspace.Terrain:FillCylinder(CFrame.new(x, top - depth / 2, z), depth, diameter / 2, Enum.Material.Water)
	end)
end

-- Города из CityData: каждая запись — деталь (коробка, цилиндр, шар, эллипсоид, клин)
local function buildCity(folder: Folder)
	local data = World.CityData
	local f = Instance.new("Folder")
	f.Name = "Cities"
	f.Parent = folder
	for i, d in data.props do
		local kind = d[1]
		-- вода (тонкое стекло без столкновений): Босфор, Темза, море, озёра, фонтаны
		if d[12] == "Glass" and d[13] ~= 1 then
			if kind == "box" and d[6] < 1 then
				if terrainWaterBlock(CFrame.new(d[2], d[3], d[4]) * CFrame.Angles(d[8], d[9], d[10]), Vector3.new(d[5], d[6], d[7]), d[3] + d[6] / 2 + 0.05) then
					continue
				end
			elseif kind == "cyl" and d[5] < 1 then
				if terrainWaterDisc(d[2], d[4], d[6], d[3] + d[5] / 2 + 0.05) then
					continue
				end
			end
		end
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
		-- тени — самое дорогое: их не отбрасывают неон, мелочь и весь декор (деревья, разметка, вода)
		local decor = d[13] ~= 1 and math.max(size.X, size.Y, size.Z) < 40
		if decor then
			p.CanQuery = false
		end
		if p.Material == Enum.Material.Neon or math.max(size.X, size.Z) < 2 or decor or p.Material == Enum.Material.LeafyGrass then
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
	local avoid = {}
	for _, ap in World.AIRPORTS do
		table.insert(avoid, { ap.cx + (if ap.rot == 1 then 0 else 500), ap.cz - (if ap.rot == 1 then 500 else 0), 3700 })
	end
	for _, c in World.CITIES do
		table.insert(avoid, { c.x, c.z, c.r })
	end
	table.insert(avoid, { 5500, -9800, 3300 }) -- море у Дубая
	for _, lk in World.LAKES do
		if World.terrainH(lk[1], lk[2]) <= 5 then
			local water = Instance.new("Part")
			local usedTerrain = terrainWaterDisc(lk[1], lk[2], lk[3], 0.7)
			water.Shape = Enum.PartType.Cylinder
			water.Anchored = true
			water.CanCollide = false
			water.Size = Vector3.new(0.2, lk[3], lk[3])
			water.CFrame = CFrame.new(lk[1], 0.6, lk[2]) * CFrame.Angles(0, 0, math.pi / 2)
			water.Color = Color3.fromRGB(31, 90, 134)
			water.Material = Enum.Material.Glass
			water.Reflectance = 0.35
			if not usedTerrain then
				water.Parent = f
			end
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
					crown.CastShadow = false
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
