--!strict
-- Строит модель самолёта из обычных деталей Roblox по PlaneConfigs.
-- Оси модели: нос -Z, верх +Y, правое крыло +X. Корень (Root) — центр фюзеляжа,
-- он стоит на высоте gearHeight над землёй, когда шасси касается полосы.
local PlaneBuilder = {}

type Ctx = { model: Model, root: BasePart, static: boolean, cfg: any }

local DARK = Color3.fromRGB(28, 32, 40)
local TIRE = Color3.fromRGB(25, 25, 25)
local METAL = Color3.fromRGB(150, 155, 162)

local function basePart(ctx: Ctx, cls: string, name: string, color: Color3, material: Enum.Material?): BasePart
	local p = Instance.new(cls) :: BasePart
	p.Name = name
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = true
	p.Anchored = ctx.static
	p.Massless = true
	return p
end

local function attach(ctx: Ctx, p: BasePart, parent: Instance?)
	p.Parent = parent or ctx.model
	if not ctx.static then
		local w = Instance.new("WeldConstraint")
		w.Part0 = ctx.root
		w.Part1 = p
		w.Parent = p
	end
end

local function block(ctx: Ctx, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, parent: Instance?): BasePart
	local p = basePart(ctx, "Part", name, color, material)
	p.Size = size
	p.CFrame = ctx.root.CFrame * cf
	attach(ctx, p, parent)
	return p
end

-- Эллипсоид: шар с SpecialMesh, можно любые полуоси
local function ellipsoid(ctx: Ctx, name: string, semi: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, parent: Instance?): BasePart
	local p = basePart(ctx, "Part", name, color, material)
	p.Size = semi * 2
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = p
	p.CFrame = ctx.root.CFrame * cf
	attach(ctx, p, parent)
	return p
end

-- Цилиндр вдоль оси Z модели
local function cylZ(ctx: Ctx, name: string, length: number, diameter: number, pos: Vector3, color: Color3, material: Enum.Material?, parent: Instance?): BasePart
	local p = basePart(ctx, "Part", name, color, material)
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(length, diameter, diameter)
	p.CFrame = ctx.root.CFrame * CFrame.new(pos) * CFrame.Angles(0, math.pi / 2, 0)
	attach(ctx, p, parent)
	return p
end

-- Цилиндр вдоль оси Y модели (стойки шасси)
local function cylY(ctx: Ctx, name: string, length: number, diameter: number, pos: Vector3, color: Color3, parent: Instance?): BasePart
	local p = basePart(ctx, "Part", name, color, Enum.Material.Metal)
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(length, diameter, diameter)
	p.CFrame = ctx.root.CFrame * CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2)
	attach(ctx, p, parent)
	return p
end

-- Треугольник из двух клиньев (классический приём для произвольных плоскостей)
local function triangle(ctx: Ctx, name: string, a: Vector3, b: Vector3, c: Vector3, thick: number, color: Color3, parent: Instance?)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local cross = ac:Cross(ab)
	if cross.Magnitude < 1e-6 then
		return
	end
	local rightV = cross.Unit
	local upV = bc:Cross(rightV).Unit
	local backV = bc.Unit
	local height = math.abs(ab:Dot(upV))
	local w1 = basePart(ctx, "WedgePart", name, color)
	w1.Size = Vector3.new(thick, math.max(height, 0.05), math.max(math.abs(ab:Dot(backV)), 0.05))
	w1.CFrame = ctx.root.CFrame * CFrame.fromMatrix((a + b) / 2, rightV, upV, backV)
	attach(ctx, w1, parent)
	local w2 = basePart(ctx, "WedgePart", name, color)
	w2.Size = Vector3.new(thick, math.max(height, 0.05), math.max(math.abs(ac:Dot(backV)), 0.05))
	w2.CFrame = ctx.root.CFrame * CFrame.fromMatrix((a + c) / 2, -rightV, upV, -backV)
	attach(ctx, w2, parent)
end

-- Трапециевидная плоскость: корневая/концевая передние кромки и хорды (хорда идёт в +Z)
local function panel(ctx: Ctx, name: string, rootLE: Vector3, rootChord: number, tipLE: Vector3, tipChord: number, thick: number, color: Color3)
	local rootTE = rootLE + Vector3.new(0, 0, rootChord)
	local tipTE = tipLE + Vector3.new(0, 0, tipChord)
	triangle(ctx, name, rootLE, rootTE, tipTE, thick, color)
	triangle(ctx, name, rootLE, tipTE, tipLE, thick, color)
end

local function light(ctx: Ctx, kind: string, pos: Vector3, color: Color3, size: number)
	local p = block(ctx, "Light", Vector3.one * size, CFrame.new(pos), color, Enum.Material.Neon)
	p.CastShadow = false
	p:SetAttribute("LightKind", kind)
	return p
end

function PlaneBuilder.build(cfg: any, opts: { static: boolean?, seat: boolean?, label: string? }?): Model
	local o = opts or {}
	local model = Instance.new("Model")
	model.Name = cfg.name
	model:SetAttribute("PlaneId", cfg.id)

	local L, D, span, chord = cfg.length, cfg.diameter, cfg.span, cfg.chord
	local col = cfg.colors
	local static = o.static == true

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(D * 0.5, D * 0.5, L * 0.5)
	root.Transparency = 1
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Anchored = true
	root.Massless = false
	root.CFrame = CFrame.identity
	root.Parent = model
	model.PrimaryPart = root

	local ctx: Ctx = { model = model, root = root, static = static, cfg = cfg }

	-- ===== фюзеляж
	local Ln = math.max(D * 1.1, L * 0.12)
	local Lt = L * 0.24
	local cylLen = L - Ln - Lt
	local cylMid = -L / 2 + Ln + cylLen / 2
	local glossy = cfg.engines ~= "jet1" and cfg.engines ~= "prop"
	local fus = cylZ(ctx, "Fuselage", cylLen + 0.02, D, Vector3.new(0, 0, cylMid), col.body)
	local nose = ellipsoid(ctx, "Nose", Vector3.new(D / 2, D / 2, Ln), CFrame.new(0, 0, -L / 2 + Ln), col.body)
	local tcone = ellipsoid(ctx, "TailCone", Vector3.new(D / 2, D / 2, Lt), CFrame.new(0, 0, L / 2 - Lt), col.body)
	if glossy then
		-- лаковая краска: лёгкое отражение неба
		for _, part in { fus, nose, tcone } do
			part.Reflectance = 0.07
		end
	end
	if cfg.hump then
		ellipsoid(ctx, "Hump", Vector3.new(D * 0.4, D * 0.45, L * 0.2), CFrame.new(0, D * 0.28, -L / 2 + L * 0.24), col.body)
	end
	-- кабина
	if cfg.canopy then
		local cp = ellipsoid(ctx, "Canopy", Vector3.new(D * 0.3, D * 0.32, L * 0.13), CFrame.new(0, D * 0.42, -L / 2 + L * 0.3), Color3.fromRGB(60, 80, 100), Enum.Material.Glass)
		cp.Transparency = 0.25
	else
		-- остекление кабины: 3 панели на сторону по поверхности носового эллипсоида
		local z0 = -L / 2 + Ln
		for i, f in { 0.8, 0.7, 0.58 } do
			local zc = z0 - Ln * f
			local r = D / 2 * math.sqrt(1 - f * f)
			for _, s in { -1, 1 } do
				local ang = math.rad(18 + (i - 1) * 24)
				local x, y = s * r * math.sin(ang), r * math.cos(ang) * 0.92
				local mk = if cfg.mask then 1.45 else 1
				local pane = block(ctx, "CockpitWindow", Vector3.new(r * 0.42 * mk, 0.08 * D * mk, Ln * 0.11 * mk), CFrame.new(x, y, zc) * CFrame.Angles(math.rad(-38 + i * 8), 0, -s * ang), DARK, Enum.Material.Glass)
				pane.CastShadow = false
				pane.Reflectance = 0.25
			end
		end
	end
	-- иллюминаторы и двери (как у настоящих лайнеров), полоса ливреи
	for _, s in { -1, 1 } do
		if cfg.windows then
			local pitch = math.max(D * 0.11, 1.1)
			local z0 = -L / 2 + Ln * 1.05
			local z1 = L / 2 - Lt * 0.95
			local n = math.min(math.floor((z1 - z0) / pitch), 70)
			local step = (z1 - z0) / math.max(n, 1)
			-- двухпалубный (тип A380): два ряда иллюминаторов по всей длине
			local rows = if cfg.doubleDeck then { -0.02, 0.3 } else { 0.13 }
			local wx = s * math.sqrt(0.25 - 0.0169) * D
			for _, ry in rows do
				local wy = D * ry
				local rx = s * math.sqrt(0.25 - ry * ry) * D
				for i = 0, n do
					local z = z0 + i * step
					if i ~= 1 and i ~= n - 1 then
						local w = block(ctx, "Window", Vector3.new(D * 0.025, D * 0.055, D * 0.04), CFrame.new(rx, wy, z), DARK, Enum.Material.Glass)
						w.CastShadow = false
					end
				end
			end
			for _, z in { z0 + step * 1, z1 - step * 1 } do
				local door = block(ctx, "Door", Vector3.new(D * 0.02, D * 0.2, D * 0.085), CFrame.new(wx * 1.005, D * 0.05, z), Color3.fromRGB(170, 175, 182))
				door.CastShadow = false
			end
		end
		block(ctx, "Cheatline", Vector3.new(D * 0.04, D * 0.05, cylLen), CFrame.new(s * D * 0.49, -D * 0.06, cylMid), col.accent)
		-- «волна» ливреи: полоса фирменного цвета поднимается от брюха к хвосту
		if glossy and L > 50 then
			local zA, zB = cylMid + cylLen * 0.08, L / 2 - Lt * 0.55
			local N = 9
			for i = 0, N - 1 do
				local t0 = i / N
				local tm = (i + 0.5) / N
				local z = zA + (zB - zA) * tm
				local phi = math.rad(-62 + 92 * tm ^ 1.3) -- угол на окружности: снизу вверх
				local rad = D / 2 * (if z > L / 2 - Lt then math.max(0.35, (L / 2 - z) / Lt) ^ 0.6 else 1) + 0.03
				local seg = (zB - zA) / N * 1.08
				local band = block(ctx, "LiverySwoosh", Vector3.new(D * 0.02, D * (0.2 - 0.08 * t0), seg),
					CFrame.new(s * rad * math.cos(phi), rad * math.sin(phi), z) * CFrame.Angles(0, 0, if s == 1 then phi else math.pi - phi),
					if tm < 0.5 then col.accent else col.tail)
				band.CastShadow = false
				band.Reflectance = 0.07
			end
		end
	end
	-- брюхо светло-серое, как у настоящих лайнеров
	if L > 50 then
		local belly = ellipsoid(ctx, "Belly", Vector3.new(D * 0.47, D * 0.22, cylLen * 0.5), CFrame.new(0, -D * 0.3, cylMid), Color3.fromRGB(205, 210, 216))
		belly.CastShadow = false
	end

	-- ===== крыло
	local wy = if cfg.wing == "high" then D * 0.42 elseif cfg.wing == "low" then -D * 0.32 else 0
	local wz = -L / 2 + L * cfg.wingPos
	local taper = if cfg.sweep > 5 then 0.32 else 0.7
	local tipChord = chord * taper
	local half = span / 2
	local rootX = D * 0.35
	local l = half - rootX
	local tanS, tanD = math.tan(math.rad(cfg.sweep)), math.tan(math.rad(cfg.dihedral))
	local wingThick = math.clamp(chord * 0.09, 0.35, 3)
	local rootLEz = wz - chord / 2

	local function wingPoint(s: number, frac: number): (Vector3, number)
		-- передняя кромка и хорда на доле размаха frac (0 = корень, 1 = законцовка)
		local d = l * frac
		return Vector3.new(s * (rootX + d), wy + d * tanD, rootLEz + d * tanS), chord + (tipChord - chord) * frac
	end

	local flapsFolder = Instance.new("Folder")
	flapsFolder.Name = "Flaps"
	flapsFolder.Parent = model
	-- рули: элероны, руль высоты, руль направления (поворачивает Animator по управлению)
	local controlsFolder = Instance.new("Folder")
	controlsFolder.Name = "Controls"
	controlsFolder.Parent = model
	local function controlSurface(kind: string, pA: Vector3, pB: Vector3, fc: number, thick: number, color: Color3, vertical: boolean?)
		local sgn = if vertical then 1 else (if pB.X >= pA.X then 1 else -1)
		local u = ((pB - pA) * sgn).Unit
		local back = Vector3.zAxis - u * Vector3.zAxis:Dot(u)
		back = back.Unit
		local upV = back:Cross(u)
		local hinge = CFrame.fromMatrix((pA + pB) / 2, u, upV, back)
		local cp = basePart(ctx, "Part", "Control", color)
		cp.Size = Vector3.new((pB - pA).Magnitude, thick, fc)
		local c0 = hinge * CFrame.new(0, 0, fc / 2)
		cp.CFrame = root.CFrame * c0
		cp.CastShadow = false
		cp.Parent = controlsFolder
		if not static then
			local w = Instance.new("Weld")
			w.Name = "ControlWeld"
			w.Part0 = root
			w.Part1 = cp
			w.C0 = c0
			w:SetAttribute("Hinge", hinge)
			w:SetAttribute("Chord", fc)
			w:SetAttribute("Kind", kind)
			w.Parent = cp
		end
	end
	local gearFolder = Instance.new("Folder")
	gearFolder.Name = "Gear"
	gearFolder.Parent = model

	for _, s in { -1, 1 } do
		local rLE = Vector3.new(s * rootX, wy, rootLEz)
		local tLE, tChord = wingPoint(s, 1)
		local WINGC = if cfg.id == "F16" then col.body else Color3.fromRGB(214, 218, 224)
		panel(ctx, "Wing", rLE, chord, tLE, tChord, wingThick, WINGC)
		-- обтекатели механизации закрылков под задней кромкой
		if L > 80 then
			for _, fr in { 0.22, 0.42, 0.62 } do
				local le, ch = wingPoint(s, fr)
				ellipsoid(ctx, "FlapFairing", Vector3.new(chord * 0.03, chord * 0.045, ch * 0.28), CFrame.new(le.X, le.Y - wingThick * 0.6, le.Z + ch * 0.95), WINGC)
			end
		end
		-- подкосы крыла у лёгкого самолёта
		if cfg.wing == "high" then
			local a0 = Vector3.new(s * D * 0.45, -D * 0.3, wz)
			local tipP = wingPoint(s, 0.55)
			local a1 = Vector3.new(tipP.X, tipP.Y - wingThick * 0.5, wz)
			local mid = (a0 + a1) / 2
			local dir = (a1 - a0).Unit
			local strut = block(ctx, "Strut", Vector3.new((a1 - a0).Magnitude, 0.3, 0.6), CFrame.fromMatrix(mid, dir, Vector3.zAxis:Cross(dir).Unit), col.body)
			strut.CastShadow = false
		end
		-- элерон на внешней части крыла
		do
			local ai, cai = wingPoint(s, 0.6)
			local ao, cao = wingPoint(s, 0.92)
			local afc = math.min(cai, cao) * 0.26
			controlSurface(if s > 0 then "ailR" else "ailL", ai + Vector3.new(0, 0, cai - afc), ao + Vector3.new(0, 0, cao - afc), afc, wingThick * 0.6, Color3.fromRGB(214, 218, 224))
		end
		-- закрылки на внутренней половине
		if not cfg.noFlaps then
			local fi, ci = wingPoint(s, 0.04)
			local fo, co = wingPoint(s, 0.5)
			local fc = math.min(ci, co) * 0.24
			local pIn = fi + Vector3.new(0, 0, ci - fc)
			local pOut = fo + Vector3.new(0, 0, co - fc)
			local u = ((pOut - pIn) * s).Unit -- всегда в +X, чтобы ось Y шарнира смотрела вверх
			local back = Vector3.zAxis - u * Vector3.zAxis:Dot(u)
			back = back.Unit
			local upV = back:Cross(u)
			local hinge = CFrame.fromMatrix((pIn + pOut) / 2, u, upV, back)
			local flap = basePart(ctx, "Part", "Flap", col.body)
			flap.Size = Vector3.new((pOut - pIn).Magnitude, wingThick * 0.7, fc)
			local c0 = hinge * CFrame.new(0, 0, fc / 2)
			flap.CFrame = root.CFrame * c0
			flap.Parent = flapsFolder
			if not static then
				local w = Instance.new("Weld")
				w.Name = "FlapWeld"
				w.Part0 = root
				w.Part1 = flap
				w.C0 = c0
				w:SetAttribute("Hinge", hinge)
				w:SetAttribute("Chord", fc)
				w.Parent = flap
			end
		end
		-- законцовки
		if cfg.winglets then
			local wlH = math.max(2, span * 0.045)
			local wlLE = tLE + Vector3.new(0, 0, tChord * 0.1)
			panel(ctx, "Winglet", wlLE, tChord * 0.8, wlLE + Vector3.new(s * wlH * 0.15, wlH, wlH * 0.6), tChord * 0.35, wingThick * 0.6, col.tail)
		end
		-- навигационные огни и стробы
		light(ctx, "nav", tLE + Vector3.new(0, 0, tChord * 0.3), if s < 0 then Color3.fromRGB(255, 40, 40) else Color3.fromRGB(40, 255, 90), math.max(0.6, D * 0.08))
		light(ctx, "strobe", tLE + Vector3.new(0, 0, tChord * 0.8), Color3.new(1, 1, 1), math.max(0.5, D * 0.06))
		-- след с законцовок (инверсионный след включает клиент на высоте)
		if not static then
			local a0 = Instance.new("Attachment")
			a0.Name = "TrailA"
			a0.Position = tLE + Vector3.new(0, 0.3, tChord)
			a0.Parent = root
			local a1 = Instance.new("Attachment")
			a1.Name = "TrailB"
			a1.Position = tLE + Vector3.new(0, -0.3, tChord)
			a1.Parent = root
			local tr = Instance.new("Trail")
			tr.Name = "Contrail"
			tr.Attachment0 = a0
			tr.Attachment1 = a1
			tr.Lifetime = 5
			tr.MinLength = 2
			tr.FaceCamera = true
			tr.WidthScale = NumberSequence.new(1, 6)
			tr.Transparency = NumberSequence.new(0.35, 1)
			tr.Color = ColorSequence.new(Color3.new(1, 1, 1))
			tr.LightEmission = 0.2
			tr.Enabled = false
			tr.Parent = root
		end
	end

	-- обтекатель стыка крыла и фюзеляжа
	if cfg.wing == "low" and L > 50 then
		ellipsoid(ctx, "WingFairing", Vector3.new(D * 0.46, D * 0.28, chord * 0.85), CFrame.new(0, -D * 0.28, wz + chord * 0.1), Color3.fromRGB(205, 210, 216))
	end

	-- ===== хвостовое оперение
	local finRoot = math.max(cfg.finHeight * 0.95, L * 0.1)
	local finLE = Vector3.new(0, D * 0.3, L / 2 - finRoot - L * 0.02)
	local finTanS = math.tan(math.rad(cfg.finSweep))
	local finTipLE = finLE + Vector3.new(0, cfg.finHeight, cfg.finHeight * finTanS)
	local finTip = finRoot * 0.5
	local finThick = math.clamp(finRoot * 0.08, 0.3, 2.5)
	-- плоскость киля вертикальная: строим треугольники напрямую
	triangle(ctx, "Fin", finLE, finLE + Vector3.new(0, 0, finRoot), finTipLE + Vector3.new(0, 0, finTip), finThick, col.tail)
	triangle(ctx, "Fin", finLE, finTipLE + Vector3.new(0, 0, finTip), finTipLE, finThick, col.tail)
	light(ctx, "beacon", finTipLE + Vector3.new(0, 0.4, finTip * 0.5), Color3.fromRGB(255, 40, 40), math.max(0.5, D * 0.07))
	do -- руль направления у задней кромки киля
		local rcB, rcT = finRoot * 0.3, finTip * 0.3
		local rb = finLE + Vector3.new(0, cfg.finHeight * 0.08, finRoot - rcB)
		local rt = finTipLE + Vector3.new(0, -cfg.finHeight * 0.08, finTip - rcT)
		controlSurface("rud", rb, rt, (rcB + rcT) / 2, finThick * 0.7, col.tail, true)
	end
	-- форкиль и выхлоп ВСУ
	triangle(ctx, "Dorsal", finLE + Vector3.new(0, 0, -finRoot * 0.45), finLE, finLE + Vector3.new(0, cfg.finHeight * 0.18, finRoot * 0.12), finThick * 0.8, col.tail)
	if L > 50 then
		cylZ(ctx, "APU", 0.4, D * 0.09, Vector3.new(0, 0, L / 2 - 0.1), DARK, Enum.Material.Metal)
	end
	light(ctx, "beacon", Vector3.new(0, -D / 2 - 0.2, cylMid), Color3.fromRGB(255, 40, 40), math.max(0.5, D * 0.07))

	local hsRootChord = math.max(cfg.hstabSpan * 0.3, D * 0.6)
	local hsHalf = cfg.hstabSpan / 2
	local hsY, hsLEz, hsRootX
	if cfg.tail == "T" then
		hsY = finTipLE.Y - 0.2
		hsLEz = finTipLE.Z - finTip * 0.1
		hsRootX = 0
		hsRootChord = math.max(finTip * 1.1, hsRootChord * 0.8)
	else
		hsY = D * 0.08
		hsLEz = L / 2 - hsRootChord - L * 0.03
		hsRootX = D * 0.2
	end
	local hsTan = math.tan(math.rad(cfg.finSweep * 0.85))
	for _, s in { -1, 1 } do
		local r = Vector3.new(s * hsRootX, hsY, hsLEz)
		local d = hsHalf - hsRootX
		local t = Vector3.new(s * hsHalf, hsY + d * 0.05, hsLEz + d * hsTan)
		panel(ctx, "HStab", r, hsRootChord, t, hsRootChord * 0.45, math.clamp(hsRootChord * 0.08, 0.25, 2), col.body)
		local efcR, efcT = hsRootChord * 0.3, hsRootChord * 0.45 * 0.3
		local ea = r + Vector3.new(s * 0.2, 0, hsRootChord - efcR)
		local eb = t + Vector3.new(-s * 0.5, 0, hsRootChord * 0.45 - efcT)
		controlSurface("elev", ea, eb, (efcR + efcT) / 2, math.clamp(hsRootChord * 0.08, 0.25, 2) * 0.7, col.body)
	end

	-- ===== двигатели
	local engines = Instance.new("Folder")
	engines.Name = "Engines"
	engines.Parent = model
	local eD = cfg.engineD or D * 0.4
	local eL = cfg.engineLen or eD * 2

	-- турбовентиляторный двигатель: губа воздухозаборника, вентилятор, кок, мотогондола, сопло и конус
	local function nacelle(pos: Vector3)
		cylZ(ctx, "Nacelle", eL * 0.78, eD, pos + Vector3.new(0, 0, eL * 0.02), col.engine, Enum.Material.SmoothPlastic, engines)
		cylZ(ctx, "Lip", eL * 0.08, eD * 1.02, pos + Vector3.new(0, 0, -eL * 0.4), Color3.fromRGB(225, 228, 232), Enum.Material.Metal, engines)
		-- вентилятор: тёмный диск + вращающийся ротор с 8 лопатками (Weld «FanWeld», крутит Animator)
		cylZ(ctx, "Fan", 0.2, eD * 0.86, pos + Vector3.new(0, 0, -eL * 0.36), Color3.fromRGB(32, 34, 40), Enum.Material.Metal, engines)
		local hub = basePart(ctx, "Part", "FanRotor", Color3.fromRGB(150, 156, 164), Enum.Material.Metal)
		hub.Shape = Enum.PartType.Cylinder
		hub.Size = Vector3.new(0.25, eD * 0.22, eD * 0.22)
		local hc0 = CFrame.new(pos + Vector3.new(0, 0, -eL * 0.385)) * CFrame.Angles(0, math.pi / 2, 0)
		hub.CFrame = ctx.root.CFrame * hc0
		hub.Parent = engines
		if not ctx.static then
			local w = Instance.new("Weld")
			w.Name = "FanWeld"
			w.Part0 = ctx.root
			w.Part1 = hub
			w.C0 = hc0
			w:SetAttribute("Base", hc0)
			w.Parent = hub
		end
		for i = 0, 7 do
			local blade = basePart(ctx, "Part", "FanBlade", Color3.fromRGB(140, 147, 156), Enum.Material.Metal)
			blade.Size = Vector3.new(0.12, eD * 0.3, eD * 0.1)
			blade.CFrame = hub.CFrame * CFrame.Angles(i / 8 * math.pi * 2, 0, 0) * CFrame.new(0, eD * 0.24, 0) * CFrame.Angles(0, 0.55, 0)
			blade.CastShadow = false
			blade.Parent = engines
			if not ctx.static then
				local wc = Instance.new("WeldConstraint")
				wc.Part0 = hub
				wc.Part1 = blade
				wc.Parent = blade
			end
		end
		ellipsoid(ctx, "Spinner", Vector3.new(eD * 0.15, eD * 0.15, eD * 0.2), CFrame.new(pos + Vector3.new(0, 0, -eL * 0.38)), Color3.fromRGB(200, 204, 210), Enum.Material.Metal, engines)
		cylZ(ctx, "Nozzle", eL * 0.2, eD * 0.72, pos + Vector3.new(0, 0, eL * 0.5), Color3.fromRGB(150, 154, 160), Enum.Material.Metal, engines)
		ellipsoid(ctx, "Plug", Vector3.new(eD * 0.22, eD * 0.22, eL * 0.18), CFrame.new(pos + Vector3.new(0, 0, eL * 0.6)), Color3.fromRGB(70, 72, 78), Enum.Material.Metal, engines)
		if cfg.id == "B787" then
			-- «шевроны» на сопле (зубцы против шума), как у Boeing 787
			for i = 0, 11 do
				local a = i / 12 * math.pi * 2
				block(ctx, "Chevron", Vector3.new(eD * 0.09, eD * 0.09, 0.15), CFrame.new(pos + Vector3.new(math.cos(a) * eD * 0.37, math.sin(a) * eD * 0.37, eL * 0.6)) * CFrame.Angles(0, 0, a + math.pi / 4), col.engine, Enum.Material.Metal, engines)
			end
		end
	end

	if cfg.engines == "wing2" or cfg.engines == "wing4" then
		local fracs = if cfg.engines == "wing2" then { 0.3 } else { 0.28, 0.58 }
		for _, s in { -1, 1 } do
			for _, fr in fracs do
				local le, ch = wingPoint(s, fr)
				local pos = Vector3.new(le.X, le.Y - eD * 0.65, le.Z - eL * 0.35)
				nacelle(pos)
				block(ctx, "Pylon", Vector3.new(eD * 0.15, eD * 0.5, math.min(eL * 0.8, ch)), CFrame.new(le.X, le.Y - eD * 0.3, le.Z + ch * 0.15), col.engine, Enum.Material.Metal, engines)
			end
		end
	elseif cfg.engines == "tail2" then
		for _, s in { -1, 1 } do
			local pos = Vector3.new(s * (D / 2 + eD * 0.55), D * 0.18, L / 2 - Lt - eL * 0.2)
			nacelle(pos)
			block(ctx, "Pylon", Vector3.new(eD * 0.6, eD * 0.2, eL * 0.5), CFrame.new(s * (D / 2), D * 0.18, pos.Z), col.engine, Enum.Material.Metal, engines)
		end
	elseif cfg.engines == "jet1" then
		cylZ(ctx, "Nozzle", eL * 0.6, eD, Vector3.new(0, 0, L / 2 - 0.5), DARK, Enum.Material.Metal, engines)
		local ab = cylZ(ctx, "Afterburner", 0.4, eD * 0.75, Vector3.new(0, 0, L / 2 + eL * 0.3 - 0.3), Color3.fromRGB(255, 140, 50), Enum.Material.Neon, engines)
		ab.Transparency = 1
		ab.CastShadow = false
		-- подфюзеляжные гребни и пусковые на законцовках
		for _, s in { -1, 1 } do
			triangle(ctx, "Ventral", Vector3.new(s * D * 0.25, -D * 0.45, L / 2 - L * 0.2), Vector3.new(s * D * 0.25, -D * 0.45, L / 2 - L * 0.08), Vector3.new(s * D * 0.35, -D * 0.85, L / 2 - L * 0.09), 0.25, col.body)
			local tLE2, tC2 = wingPoint(s, 1)
			cylZ(ctx, "Rail", tC2 * 1.6, 0.6, Vector3.new(tLE2.X + s * 0.4, tLE2.Y, tLE2.Z + tC2 * 0.4), Color3.fromRGB(220, 220, 220), Enum.Material.Metal, engines)
		end
		-- воздухозаборник под фюзеляжем
		block(ctx, "Intake", Vector3.new(D * 0.6, D * 0.4, L * 0.12), CFrame.new(0, -D * 0.45, wz - chord * 0.6), DARK, Enum.Material.Metal, engines)
	elseif cfg.engines == "turboprop2" then
		-- турбовинтовые: гондолы под высоким крылом, шестилопастные винты (вращает Animator), выхлоп сбоку
		for _, s in { -1, 1 } do
			local le = wingPoint(s, 0.3)
			local p = Vector3.new(le.X, le.Y - eD * 0.45, le.Z + eL * 0.1)
			ellipsoid(ctx, "Nacelle", Vector3.new(eD * 0.5, eD * 0.6, eL * 0.55), CFrame.new(p), col.engine, Enum.Material.SmoothPlastic, engines)
			cylZ(ctx, "Exhaust", eD * 0.5, eD * 0.28, p + Vector3.new(s * eD * 0.45, -eD * 0.1, eL * 0.05), DARK, Enum.Material.Metal, engines)
			local pc0 = CFrame.new(p + Vector3.new(0, 0, -eL * 0.55 - 0.25))
			local hub = basePart(ctx, "Part", "Prop", Color3.fromRGB(230, 232, 236), Enum.Material.Metal)
			hub.Size = Vector3.new(eD * 0.6, eD * 0.6, eD * 0.75)
			local hm = Instance.new("SpecialMesh")
			hm.MeshType = Enum.MeshType.Sphere
			hm.Parent = hub
			hub.CFrame = root.CFrame * pc0
			hub.Parent = engines
			if not static then
				local w = Instance.new("Weld")
				w.Name = "PropWeld"
				w.Part0 = root
				w.Part1 = hub
				w.C0 = pc0
				w:SetAttribute("Base", pc0)
				w.Parent = hub
			end
			for i = 0, 5 do
				local a = i / 6 * math.pi * 2
				local bl = basePart(ctx, "Part", "Blade", DARK, Enum.Material.Metal)
				bl.Size = Vector3.new(eD * 0.16, eD * 1.55, 0.2)
				bl.CFrame = hub.CFrame * CFrame.Angles(0, 0, a - math.pi / 2) * CFrame.new(0, eD * 0.82, 0) * CFrame.Angles(0, 0.35, 0)
				bl.Parent = engines
				if not static then
					local wc = Instance.new("WeldConstraint")
					wc.Part0 = hub
					wc.Part1 = bl
					wc.Parent = bl
				end
			end
			local disc = basePart(ctx, "Part", "PropDisc", Color3.fromRGB(200, 200, 200), Enum.Material.Glass)
			disc.Shape = Enum.PartType.Cylinder
			disc.Size = Vector3.new(0.05, eD * 3.3, eD * 3.3)
			disc.CFrame = root.CFrame * pc0 * CFrame.Angles(0, math.pi / 2, 0)
			disc.Transparency = 1
			disc.CastShadow = false
			attach(ctx, disc, engines)
		end
	elseif cfg.engines == "prop" then
		ellipsoid(ctx, "Spinner", Vector3.new(D * 0.16, D * 0.16, D * 0.22), CFrame.new(0, 0, -L / 2 - D * 0.05), Color3.fromRGB(230, 230, 230), Enum.Material.Metal, engines)
		local prop = basePart(ctx, "Part", "Prop", DARK, Enum.Material.Metal)
		prop.Size = Vector3.new(D * 1.15, 0.35, 0.18)
		local pc0 = CFrame.new(0, 0, -L / 2 - D * 0.08)
		prop.CFrame = root.CFrame * pc0
		prop.Parent = engines
		if not static then
			local w = Instance.new("Weld")
			w.Name = "PropWeld"
			w.Part0 = root
			w.Part1 = prop
			w.C0 = pc0
			w:SetAttribute("Base", pc0)
			w.Parent = prop
		end
		local disc = basePart(ctx, "Part", "PropDisc", Color3.fromRGB(200, 200, 200), Enum.Material.Glass)
		disc.Shape = Enum.PartType.Cylinder
		disc.Size = Vector3.new(0.05, D * 1.15, D * 1.15)
		disc.CFrame = root.CFrame * pc0 * CFrame.Angles(0, math.pi / 2, 0)
		disc.Transparency = 1
		disc.CastShadow = false
		attach(ctx, disc, engines)
	end

	-- ===== шасси
	local gearLen = cfg.gearLen
	local wheelR = math.max(0.7, gearLen * 0.32)
	local wheelW = math.max(0.6, wheelR * 0.8)
	local wheelY = -cfg.gearHeight + wheelR
	local mainGear = {}
	local function leg(x: number, z: number, wheels: number, bogie: boolean?)
		local top = -D * 0.35
		cylY(ctx, "Strut", top - wheelY, math.max(0.25, wheelR * 0.35), Vector3.new(x, (top + wheelY) / 2, z), METAL, gearFolder)
		local rows = if bogie then { -wheelR * 1.15, wheelR * 1.15 } else { 0 }
		if bogie then
			block(ctx, "Bogie", Vector3.new(wheelW * 0.5, wheelR * 0.4, wheelR * 3.2), CFrame.new(x, wheelY, z), METAL, Enum.Material.Metal, gearFolder)
		end
		for _, dzz in rows do
			for k = 1, wheels do
				local off = if wheels == 1 then 0 else (k - 1.5) * wheelW * 1.15
				local w = basePart(ctx, "Part", "Wheel", TIRE, Enum.Material.Rubber)
				w.Shape = Enum.PartType.Cylinder
				w.Size = Vector3.new(wheelW, wheelR * 2, wheelR * 2)
				w.CFrame = root.CFrame * CFrame.new(x + off, wheelY, z + dzz)
				attach(ctx, w, gearFolder)
				local hub = basePart(ctx, "Part", "Hub", Color3.fromRGB(190, 192, 196), Enum.Material.Metal)
				hub.Shape = Enum.PartType.Cylinder
				hub.Size = Vector3.new(wheelW * 1.02, wheelR * 1.1, wheelR * 1.1)
				hub.CFrame = w.CFrame
				hub.CastShadow = false
				attach(ctx, hub, gearFolder)
			end
		end
	end
	local big = L > 100
	local noseZ = -L / 2 + math.max(L * 0.12, Ln * 0.9)
	leg(0, noseZ, if big then 2 else 1)
	-- посадочная фара на передней стойке
	local lampPart = block(ctx, "LandingLight", Vector3.one * math.max(0.4, wheelR * 0.4), CFrame.new(0, -D * 0.4 - gearLen * 0.3, noseZ - 0.5), Color3.fromRGB(255, 250, 230), Enum.Material.Neon, gearFolder)
	lampPart.CastShadow = false
	if not static then
		local sl = Instance.new("SpotLight")
		sl.Brightness = 4
		sl.Range = 60
		sl.Angle = 40
		sl.Face = Enum.NormalId.Front
		sl.Parent = lampPart
	end
	-- посадочные фары у корней крыльев (горят при выпущенном шасси — их включает setGearVisible)
	if cfg.engines ~= "jet1" and cfg.engines ~= "prop" then
		for _, s in { -1, 1 } do
			local le = wingPoint(s, 0.1)
			local wl = block(ctx, "LandingLight", Vector3.one * math.max(0.4, D * 0.05), CFrame.new(le.X, le.Y - wingThick * 0.3, le.Z + 0.3), Color3.fromRGB(255, 250, 230), Enum.Material.Neon, gearFolder)
			wl.CastShadow = false
			if not static then
				local wsl = Instance.new("SpotLight")
				wsl.Brightness = 3
				wsl.Range = 90
				wsl.Angle = 30
				wsl.Face = Enum.NormalId.Front
				wsl.Color = Color3.fromRGB(255, 241, 214)
				wsl.Parent = wl
			end
		end
	end
	local mainZ = wz + chord * 0.25
	local turboprop = cfg.engines == "turboprop2"
	local mainX = if turboprop then D * 0.42 elseif cfg.wing == "high" then D * 0.75 else math.max(D * 0.55, span * 0.08)
	for _, s in { -1, 1 } do
		leg(s * mainX, mainZ, if big then 2 else 1, L > 130 or turboprop)
		if turboprop then
			-- обтекатель ниши основной стойки сбоку фюзеляжа
			ellipsoid(ctx, "Sponson", Vector3.new(D * 0.2, D * 0.17, L * 0.09), CFrame.new(s * D * 0.44, -D * 0.36, mainZ), col.body)
		end
		table.insert(mainGear, Vector3.new(s * mainX, -cfg.gearHeight, mainZ))
		if cfg.id == "B747" then
			leg(s * D * 0.3, mainZ + chord * 0.15, 2, true)
		end
	end
	-- створки шасси: открытые у стоек (в папке шасси), закрытые панели — в папке GearDoorsUp (видны, когда шасси убрано)
	if not cfg.fixedGear and cfg.engines ~= "jet1" and cfg.engines ~= "prop" then
		local doorsUp = Instance.new("Folder")
		doorsUp.Name = "GearDoorsUp"
		doorsUp.Parent = model
		local SEAM = col.body:Lerp(Color3.new(0, 0, 0), 0.12)
		local bayY = if mainX > D * 0.5 then wy - wingThick * 0.6 else -D * 0.46
		for _, s in { -1, 1 } do
			block(ctx, "GearDoor", Vector3.new(0.16, gearLen * 0.6, wheelR * 2.4), CFrame.new(s * (mainX + wheelW * 1.5), bayY - gearLen * 0.32, mainZ), col.body, Enum.Material.SmoothPlastic, gearFolder)
			block(ctx, "GearDoor", Vector3.new(0.12, D * 0.17, wheelR * 2.2), CFrame.new(s * wheelW * 0.9, -D * 0.43, noseZ), col.body, Enum.Material.SmoothPlastic, gearFolder)
			local pnl = block(ctx, "BayPanel", Vector3.new(wheelR * 2.6, 0.12, wheelR * 3.2), CFrame.new(s * mainX, bayY - 0.08, mainZ), SEAM, Enum.Material.SmoothPlastic, doorsUp)
			pnl.CastShadow = false
		end
		local np = block(ctx, "BayPanel", Vector3.new(wheelR * 1.5, 0.1, wheelR * 2.6), CFrame.new(0, -D * 0.485, noseZ), SEAM, Enum.Material.SmoothPlastic, doorsUp)
		np.CastShadow = false
		for _, p in doorsUp:GetChildren() do
			if p:IsA("BasePart") then
				p.Transparency = 1 -- по умолчанию шасси выпущено; при уборке панели показывает setGearVisible
			end
		end
	end
	if not static then
		for i, p in mainGear do
			local a = Instance.new("Attachment")
			a.Name = "MainGear" .. i
			a.Position = p
			a.Parent = root
		end
	end

	-- ===== кресло пилота
	if o.seat and not static then
		local seat = Instance.new("Seat")
		seat.Name = "PilotSeat"
		seat.Size = Vector3.new(2, 0.4, 2)
		seat.Transparency = 1
		seat.CanCollide = false
		seat.CanTouch = false
		seat.Massless = true
		local seatY = if D < 8 then -D * 0.3 else -D * 0.15
		seat.CFrame = root.CFrame * CFrame.new(0, seatY, -L / 2 + Ln * 0.85 + 1.5)
		seat.Parent = model
		local w = Instance.new("WeldConstraint")
		w.Part0 = root
		w.Part1 = seat
		w.Parent = seat
	end

	-- ===== подпись
	if o.label then
		local bb = Instance.new("BillboardGui")
		bb.Name = "Tag"
		bb.Size = UDim2.fromOffset(220, 40)
		bb.StudsOffsetWorldSpace = Vector3.new(0, D + cfg.finHeight + 6, 0)
		bb.MaxDistance = 4000
		bb.AlwaysOnTop = false
		bb.LightInfluence = 0
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Text = o.label
		t.TextColor3 = Color3.fromRGB(228, 238, 255)
		t.TextStrokeTransparency = 0.4
		t.Font = Enum.Font.GothamBold
		t.TextScaled = true
		t.Parent = bb
		bb.Parent = root
	end

	if static then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
	end
	return model
end

-- Положение закрылков (0..3) — меняет C0 сварки, работает локально у каждого клиента
-- p: штурвал на себя (+), r: крен вправо (+), y: педаль вправо (+); значения -1..1
function PlaneBuilder.setControls(model: Model, p: number, r: number, y: number)
	local f = model:FindFirstChild("Controls")
	if not f then
		return
	end
	for _, part in f:GetChildren() do
		local w = part:FindFirstChild("ControlWeld") :: Weld?
		if w then
			local hinge = w:GetAttribute("Hinge") :: CFrame?
			local fc = w:GetAttribute("Chord") :: number?
			local kind = w:GetAttribute("Kind")
			if hinge and fc then
				local deg = if kind == "ailR" then -r * 18 elseif kind == "ailL" then r * 18 elseif kind == "elev" then -p * 20 else y * 25
				w.C0 = hinge * CFrame.Angles(math.rad(deg), 0, 0) * CFrame.new(0, 0, fc / 2)
			end
		end
	end
end

function PlaneBuilder.setFlaps(model: Model, flaps: number)
	local f = model:FindFirstChild("Flaps")
	if not f then
		return
	end
	for _, flap in f:GetChildren() do
		local w = flap:FindFirstChild("FlapWeld") :: Weld?
		if w then
			local hinge = w:GetAttribute("Hinge") :: CFrame?
			local fc = w:GetAttribute("Chord") :: number?
			if hinge and fc then
				w.C0 = hinge * CFrame.Angles(math.rad(flaps * 11), 0, 0) * CFrame.new(0, 0, fc / 2)
			end
		end
	end
end

function PlaneBuilder.setGearVisible(model: Model, visible: boolean)
	local du = model:FindFirstChild("GearDoorsUp")
	if du then
		for _, p in du:GetChildren() do
			if p:IsA("BasePart") then
				p.Transparency = if visible then 1 else 0
			end
		end
	end
	local g = model:FindFirstChild("Gear")
	if not g then
		return
	end
	for _, p in g:GetChildren() do
		if p:IsA("BasePart") then
			p.LocalTransparencyModifier = if visible then 0 else 1
			local sl = p:FindFirstChildOfClass("SpotLight")
			if sl then
				sl.Enabled = visible
			end
		end
	end
end

return PlaneBuilder
