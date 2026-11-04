--!strict
-- Радар: курс вверх, радиус 12 000 stud (~6 км). Аэропорты, города, самолёты, следующее кольцо.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("SkyPilot")
local World = require(Shared:WaitForChild("World"))

local Radar = {}

local SIZE = 150
local RANGE = 12000

function Radar.new(parent: Instance, colors: any)
	local self: any = {}
	local frame = Instance.new("CanvasGroup")
	frame.Name = "Radar"
	frame.Size = UDim2.fromOffset(SIZE, SIZE)
	frame.Position = UDim2.fromOffset(0, 128)
	frame.BackgroundColor3 = colors.panel
	frame.BackgroundTransparency = 0.25
	frame.Visible = false
	frame.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = frame
	local st = Instance.new("UIStroke")
	st.Color = colors.line
	st.Transparency = 0.5
	st.Parent = frame
	for _, k in { 0.33, 0.66 } do
		local ring = Instance.new("Frame")
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.fromScale(0.5, 0.5)
		ring.Size = UDim2.fromScale(k, k)
		ring.BackgroundTransparency = 1
		local rc = Instance.new("UICorner")
		rc.CornerRadius = UDim.new(0.5, 0)
		rc.Parent = ring
		local rs = Instance.new("UIStroke")
		rs.Color = colors.line
		rs.Transparency = 0.75
		rs.Parent = ring
		ring.Parent = frame
	end
	local me = Instance.new("TextLabel")
	me.AnchorPoint = Vector2.new(0.5, 0.5)
	me.Position = UDim2.fromScale(0.5, 0.5)
	me.Size = UDim2.fromOffset(16, 16)
	me.BackgroundTransparency = 1
	me.Text = "✈"
	me.Rotation = -90
	me.TextColor3 = colors.amber
	me.TextSize = 16
	me.Font = Enum.Font.GothamBold
	me.ZIndex = 5
	me.Parent = frame

	local function blip(text: string, color: Color3, size: number): TextLabel
		local t = Instance.new("TextLabel")
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		t.Size = UDim2.fromOffset(if #text > 1 then 70 else size, size)
		t.BackgroundTransparency = 1
		t.Text = text
		t.TextColor3 = color
		t.TextSize = size
		t.Font = Enum.Font.GothamBold
		t.TextStrokeTransparency = 0.5
		t.Parent = frame
		return t
	end

	-- аэропорт: буква в кружке (прижимается к краю, если далеко); город: точка и подпись под ней,
	-- только в радиусе — подписи города и его аэропорта не слипаются
	local fixed: { { label: TextLabel, x: number, z: number, edge: boolean, dot: TextLabel?, airport: boolean? } } = {}
	for _, ap in World.AIRPORTS do
		local b = blip(ap.id, Color3.new(1, 1, 1), 12)
		b.Size = UDim2.fromOffset(18, 18)
		b.BackgroundColor3 = colors.magenta
		b.BackgroundTransparency = 0.6
		b.ZIndex = 3
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0.5, 0)
		bc.Parent = b
		local bs = Instance.new("UIStroke")
		bs.Color = Color3.new(1, 1, 1)
		bs.Transparency = 0.5
		bs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		bs.Parent = b
		table.insert(fixed, { label = b, x = ap.cx, z = ap.cz, edge = true, airport = true })
	end
	for _, city in World.CITIES do
		local RU = { DUBAI = "Дубай", LONDON = "Лондон", TASHKENT = "Ташкент", ISTANBUL = "Стамбул", RIYADH = "Эр-Рияд", SAMARKAND = "Самарканд" }
		local name = RU[city.name] or city.name
		local t = blip(name, colors.dim, 10)
		t.AnchorPoint = Vector2.new(0.5, -0.35)
		table.insert(fixed, { label = t, x = city.x, z = city.z, edge = false, dot = blip("•", colors.fg, 12) })
	end
	local ringBlip = blip("◎", colors.magenta, 14)
	local planeBlips: { [Instance]: TextLabel } = {}

	local lastClamped = false
	local function place(label: TextLabel, pos: Vector3, x: number, z: number, hdg: number, edge: boolean): boolean
		lastClamped = false
		local east, north = x - pos.X, -(z - pos.Z)
		local h = math.rad(hdg)
		local right = east * math.cos(h) - north * math.sin(h)
		local up = east * math.sin(h) + north * math.cos(h)
		local d = math.sqrt(right * right + up * up)
		local maxR = RANGE * (if #label.Text > 2 then 0.62 else 0.85)
		if d > maxR then
			if not edge then
				label.Visible = false
				return false
			end
			right, up = right / d * maxR, up / d * maxR
			lastClamped = true
		end
		local k = (SIZE / 2) / RANGE
		label.Position = UDim2.fromOffset(SIZE / 2 + right * k, SIZE / 2 - up * k)
		label.Visible = true
		return true
	end

	function self.setVisible(on: boolean)
		frame.Visible = on
	end

	function self.update(pos: Vector3, hdg: number, ownModel: Instance?, ringPos: Vector3?)
		-- ближние аэропорты первыми; далёкие (на краю) не рисуем поверх уже показанных
		table.sort(fixed, function(a, b)
			if (a.airport == true) ~= (b.airport == true) then
				return a.airport == true
			end
			return (a.x - pos.X) ^ 2 + (a.z - pos.Z) ^ 2 < (b.x - pos.X) ^ 2 + (b.z - pos.Z) ^ 2
		end)
		local drawn: { UDim2 } = {}
		for _, f in fixed do
			local shown = place(f.label, pos, f.x, f.z, hdg, f.edge)
			if shown and f.airport then
				local p = f.label.Position
				if lastClamped then
					for _, q in drawn do
						if math.abs(q.X.Offset - p.X.Offset) < 15 and math.abs(q.Y.Offset - p.Y.Offset) < 15 then
							f.label.Visible = false
							shown = false
							break
						end
					end
				end
				if shown then
					table.insert(drawn, p)
				end
			end
			if f.dot then
				if shown then
					place(f.dot, pos, f.x, f.z, hdg, false)
				else
					f.dot.Visible = false
				end
			end
		end
		if ringPos then
			place(ringBlip, pos, ringPos.X, ringPos.Z, hdg, true)
		else
			ringBlip.Visible = false
		end
		local folder = workspace:FindFirstChild("Planes")
		local seen: { [Instance]: boolean } = {}
		if folder then
			for _, m in folder:GetChildren() do
				local root = m:IsA("Model") and m.PrimaryPart
				if root and m ~= ownModel and m.Name ~= "Wreck" then
					seen[m] = true
					local b = planeBlips[m]
					if not b then
						local isPlayer = m:GetAttribute("Owner") ~= nil
						b = blip("•", if isPlayer then colors.green else Color3.fromRGB(255, 230, 120), 18)
						planeBlips[m] = b
					end
					place(b, pos, root.Position.X, root.Position.Z, hdg, false)
				end
			end
		end
		for m, b in planeBlips do
			if not seen[m] then
				b:Destroy()
				planeBlips[m] = nil
			end
		end
	end

	return self
end

return Radar
