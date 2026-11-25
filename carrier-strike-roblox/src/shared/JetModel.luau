--!strict
-- Настоящие 3D-модели самолётов.
-- Импортируй в Studio файлы F16.glb, FA18.glb, SU33.glb, RAFALE.glb, MIG29.glb, F35.glb
-- (Home → Import 3D). Модели появятся в Workspace с этими именами — сервер сам перенесёт их
-- в ReplicatedStorage/CarrierStrike/JetModels и игра будет использовать их вместо простых самолётов.
-- Если модели нет — самолёт собирается из деталей (PlaneBuilder), как раньше.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PlaneBuilder = require(script.Parent.PlaneBuilder)

local JetModel = {}

local function folder(): Folder
	local shared = script.Parent
	local f = shared:FindFirstChild("JetModels")
	if not f then
		f = Instance.new("Folder")
		f.Name = "JetModels"
		f.Parent = shared
	end
	return f :: Folder
end

-- сервер: забрать импортированные модели из Workspace в общую папку
function JetModel.collect(ids: { string })
	if not RunService:IsServer() then
		return
	end
	local f = folder()
	for _, id in ids do
		if not f:FindFirstChild(id) then
			local m = workspace:FindFirstChild(id)
			if m and (m:IsA("Model") or m:IsA("BasePart")) then
				m.Parent = f
			end
		end
	end
	f:SetAttribute("Ready", true)
end

-- клиент: подождать, пока сервер разложит модели (не дольше timeout)
function JetModel.wait(timeout: number)
	local f = ReplicatedStorage:WaitForChild("CarrierStrike"):FindFirstChild("JetModels")
	local t = os.clock()
	while (not f or not f:GetAttribute("Ready")) and os.clock() - t < timeout do
		task.wait(0.1)
		f = ReplicatedStorage.CarrierStrike:FindFirstChild("JetModels")
	end
end

function JetModel.has(id: string): boolean
	local f = script.Parent:FindFirstChild("JetModels")
	return f ~= nil and f:FindFirstChild(id) ~= nil
end

local function isDetail(p: BasePart): boolean
	-- стекло фонаря и тёмные детали (сопла, шины) не перекрашиваем
	if p.Transparency > 0.05 or p.Material == Enum.Material.Glass then
		return true
	end
	local c = p.Color
	return (c.R + c.G + c.B) / 3 < 0.16
end

-- Собрать самолёт. opts — как у PlaneBuilder.build: { static, seat, label }
function JetModel.build(cfg: any, opts: { static: boolean?, seat: boolean?, label: string? }?): Model
	local f = script.Parent:FindFirstChild("JetModels")
	local src = f and f:FindFirstChild(cfg.id)
	if not src then
		return PlaneBuilder.build(cfg, opts)
	end
	local o = opts or {}
	local static = o.static == true

	local inner: Model
	if src:IsA("Model") then
		inner = src:Clone()
	else
		inner = Instance.new("Model")
		src:Clone().Parent = inner
	end
	local parts: { BasePart } = {}
	for _, d in inner:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		elseif d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	if #parts == 0 then
		inner:Destroy()
		return PlaneBuilder.build(cfg, opts)
	end
	for _, p in parts do
		p.Anchored = true
	end

	-- ориентация: в файлах нос смотрит в −Z. Если модель легла боком (длиннее по X) — повернуть.
	local bcf, size = inner:GetBoundingBox()
	inner.WorldPivot = CFrame.new(bcf.Position)
	local yaw = 0
	if size.X > size.Z * 1.15 then
		yaw = math.pi / 2
	end
	inner:PivotTo(CFrame.Angles(0, yaw, 0))
	local len = if yaw == 0 then size.Z else size.X
	if len > 0.01 then
		inner:ScaleTo(inner:GetScale() * cfg.length / len)
	end
	-- снова по центру
	local bcf2 = inner:GetBoundingBox()
	inner:PivotTo(inner:GetPivot() - bcf2.Position)

	local model = Instance.new("Model")
	model.Name = cfg.name
	model:SetAttribute("PlaneId", cfg.id)
	model:SetAttribute("Imported", true)
	local D, L = cfg.diameter, cfg.length
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(D * 0.5, D * 0.5, L * 0.5)
	root.Transparency = 1
	root.CanCollide, root.CanTouch, root.CanQuery = false, false, false
	root.Anchored = true
	root.CFrame = CFrame.identity
	root.Parent = model
	model.PrimaryPart = root
	inner.Name = "Body"
	inner.Parent = model

	-- раскраска: однотонный цвет корпуса вместо текстуры (кроме стекла и тёмных деталей)
	local col = cfg.colors
	local painted = cfg.paintId ~= nil and cfg.paintId ~= "team" and col and col.body
	for _, p in parts do
		p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
		p.Massless = true
		p.CastShadow = true
		if painted and not isDetail(p) then
			for _, sa in p:GetChildren() do
				if sa:IsA("SurfaceAppearance") then
					sa:Destroy()
				end
			end
			if p:IsA("MeshPart") then
				p.TextureID = ""
			end
			p.Color = col.body
		end
		if not static then
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = p
			w.Parent = p
			p.Anchored = false
		end
	end

	-- огни команды на законцовках и форсаж
	local engines = Instance.new("Folder")
	engines.Name = "Engines"
	engines.Parent = model
	local ab = Instance.new("Part")
	ab.Name = "Afterburner"
	ab.Shape = Enum.PartType.Ball
	ab.Size = Vector3.new(D * 0.6, D * 0.6, D * 0.6)
	ab.Material = Enum.Material.Neon
	ab.Color = Color3.fromRGB(255, 150, 60)
	ab.Transparency = 1
	ab.CanCollide, ab.CanTouch, ab.CanQuery, ab.CastShadow = false, false, false, false
	ab.Massless = true
	ab.CFrame = CFrame.new(0, 0, L * 0.52)
	ab.Anchored = static
	ab.Parent = engines
	if not static then
		local w = Instance.new("WeldConstraint")
		w.Part0 = root
		w.Part1 = ab
		w.Parent = ab
	end
	if col and col.tail then
		for _, s in { -1, 1 } do
			local l = Instance.new("Part")
			l.Name = "TeamLight"
			l.Shape = Enum.PartType.Ball
			l.Size = Vector3.new(1.4, 1.4, 1.4)
			l.Material = Enum.Material.Neon
			l.Color = col.tail
			l.CanCollide, l.CanTouch, l.CanQuery, l.CastShadow = false, false, false, false
			l.Massless = true
			l.CFrame = CFrame.new(s * cfg.span * 0.48, 0, L * 0.12)
			l.Anchored = static
			l.Parent = model
			if not static then
				local w = Instance.new("WeldConstraint")
				w.Part0 = root
				w.Part1 = l
				w.Parent = l
			end
		end
	end

	-- кресло пилота и подпись — как у PlaneBuilder
	if o.seat and not static then
		local seat = Instance.new("Seat")
		seat.Name = "PilotSeat"
		seat.Size = Vector3.new(2, 0.4, 2)
		seat.Transparency = 1
		seat.CanCollide, seat.CanTouch = false, false
		seat.Massless = true
		seat.CFrame = CFrame.new(0, -D * 0.3, -L * 0.28)
		seat.Parent = model
		local w = Instance.new("WeldConstraint")
		w.Part0 = root
		w.Part1 = seat
		w.Parent = seat
	end
	if o.label then
		local bb = Instance.new("BillboardGui")
		bb.Name = "Tag"
		bb.Size = UDim2.fromOffset(220, 40)
		bb.StudsOffsetWorldSpace = Vector3.new(0, D + cfg.finHeight + 6, 0)
		bb.MaxDistance = 4000
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
	return model
end

return JetModel
