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
	frame.Position = UDim2.fromOffset(0, 116)
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

	local fixed: { { label: TextLabel, x: number, z: number, edge: boolean } } = {}
	for _, ap in World.AIRPORTS do
		table.insert(fixed, { label = blip(ap.id, colors.fg, 13), x = ap.cx, z = ap.cz, edge = true })
	end
	for _, city in World.CITIES do
		local name = if city.name == "DUBAI" then "Дубай" elseif city.name == "LONDON" then "Лондон" else "Ташкент"
		table.insert(fixed, { label = blip(name, colors.dim, 11), x = city.x, z = city.z, edge = true })
	end
	local ringBlip = blip("◎", colors.magenta, 14)
	local planeBlips: { [Instance]: TextLabel } = {}

	local function place(label: TextLabel, pos: Vector3, x: number, z: number, hdg: number, edge: boolean): boolean
		local east, north = x - pos.X, -(z - pos.Z)
		local h = math.rad(hdg)
		local right = east * math.cos(h) - north * math.sin(h)
		local up = east * math.sin(h) + north * math.cos(h)
		local d = math.sqrt(right * right + up * up)
		local maxR = RANGE * (if #label.Text > 1 then 0.6 else 0.85)
		if d > maxR then
			if not edge then
				label.Visible = false
				return false
			end
			right, up = right / d * maxR, up / d * maxR
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
		for _, f in fixed do
			place(f.label, pos, f.x, f.z, hdg, f.edge)
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
