--!strict
-- Интерфейс: меню вылета, приборы, радар, метки целей, лента событий, сенсорное управление.
-- Стиль: тёмно-синие панели, сталь и голубой акцент (как в обновлённой веб-версии).
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Hud = {}

local C = {
	bg = Color3.fromRGB(10, 16, 26),
	panel = Color3.fromRGB(16, 26, 40),
	line = Color3.fromRGB(46, 72, 100),
	text = Color3.fromRGB(226, 236, 248),
	dim = Color3.fromRGB(140, 160, 184),
	accent = Color3.fromRGB(92, 200, 255),
	cyan = Color3.fromRGB(92, 200, 255),
	amber = Color3.fromRGB(255, 186, 72),
	red = Color3.fromRGB(255, 92, 86),
	green = Color3.fromRGB(120, 230, 160),
	Blue = Color3.fromRGB(92, 200, 255),
	Red = Color3.fromRGB(255, 96, 86),
}
Hud.C = C

local function new(cls: string, props: { [string]: any }, parent: Instance?): any
	local o = Instance.new(cls)
	for k, v in props do
		(o :: any)[k] = v
	end
	if parent then
		o.Parent = parent
	end
	return o
end
local function corner(p: Instance, r: number?)
	new("UICorner", { CornerRadius = UDim.new(0, r or 10) }, p)
end
local function stroke(p: Instance, col: Color3?, th: number?)
	new("UIStroke", { Color = col or C.line, Thickness = th or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, p)
end
local function label(parent: Instance, text: string, size: number, col: Color3?, bold: boolean?, props: { [string]: any }?): TextLabel
	local l = new("TextLabel", {
		BackgroundTransparency = 1, Text = text, TextSize = size, TextColor3 = col or C.text,
		Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, size + 6),
	}, parent)
	for k, v in props or {} do
		(l :: any)[k] = v
	end
	return l
end
local function button(parent: Instance, text: string, size: UDim2, pos: UDim2, col: Color3?): TextButton
	local b = new("TextButton", {
		Size = size, Position = pos, BackgroundColor3 = col or C.panel, BackgroundTransparency = 0.1,
		Text = text, TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 16, AutoButtonColor = true,
	}, parent)
	corner(b, 10)
	stroke(b, C.line)
	return b
end

function Hud.new(): any
	local ui: any = {}
	local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	ui.isTouch = isTouch
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = new("ScreenGui", { Name = "CarrierStrikeUI", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, pg)

	-- ================= МЕНЮ =================
	local menu = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, gui)
	local shade = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.bg, BackgroundTransparency = 0.35, BorderSizePixel = 0 }, menu)
	new("UIGradient", { Rotation = 0, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.55, 0.4), NumberSequenceKeypoint.new(1, 1) }) }, shade)
	local col = new("ScrollingFrame", {
		Size = UDim2.new(0, math.min(460, 9999), 1, -40), Position = UDim2.fromOffset(24, 20), BackgroundTransparency = 1,
		ScrollBarThickness = 4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, BorderSizePixel = 0,
	}, menu)
	new("UISizeConstraint", { MaxSize = Vector2.new(460, math.huge) }, col)
	col.Size = UDim2.new(0.9, 0, 1, -40)
	new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, col)
	label(col, "CARRIER STRIKE", 34, C.text, true, { LayoutOrder = 1 })
	local teamLbl = label(col, "Команда: —", 18, C.accent, true, { LayoutOrder = 2 })
	local scoreLbl = label(col, "", 15, C.dim, false, { LayoutOrder = 3 })
	label(col, "1 · САМОЛЁТ", 14, C.dim, true, { LayoutOrder = 4 })
	local jetGrid = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 5 }, col)
	new("UIGridLayout", { CellSize = UDim2.new(0.5, -5, 0, 62), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }, jetGrid)
	label(col, "2 · ТОЧКА ВЫЛЕТА", 14, C.dim, true, { LayoutOrder = 6 })
	local spawnList = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 7 }, col)
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, spawnList)
	local go = button(col, "В БОЙ  ▶", UDim2.new(1, 0, 0, 56), UDim2.new(), C.accent)
	go.LayoutOrder = 8
	go.TextColor3 = C.bg
	go.TextSize = 22
	local help = label(col, "", 13, C.dim, false, { LayoutOrder = 9, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
	help.Text = if isTouch
		then "Левый стик — штурвал (к себе = вверх). Справа: ОГОНЬ (держать), РАКЕТА (нужен захват), ЛОВУШКИ. Ползунок справа — тяга. С палубы: тяга на максимум — катапульта разгонит сама."
		else "W/S — нос вниз/вверх · A/D — крен · Q/E — рули · Shift/Ctrl — тяга\nЛКМ или Пробел — пушка · F или ПКМ — ракета (держи цель в круге) · X — ловушки\nG — шасси · V — камера · C — мышь-штурвал · B — тормоз · M — в меню (на земле)\nС палубы: тяга 100% — катапульта. Садись на свою палубу или базу — ремонт и перезарядка."

	local selJet = "F16"
	local selSpawn = ""
	local jetBtns: { [string]: TextButton } = {}
	local spawnBtns: { [string]: TextButton } = {}
	local function paintSel()
		for id, b in jetBtns do
			(b:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = if id == selJet then C.accent else C.line
			b.BackgroundColor3 = if id == selJet then Color3.fromRGB(22, 46, 70) else C.panel
		end
		for id, b in spawnBtns do
			(b:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = if id == selSpawn then C.accent else C.line
			b.BackgroundColor3 = if id == selSpawn then Color3.fromRGB(22, 46, 70) else C.panel
		end
	end
	function ui.setJets(order: { string }, jets: { [string]: any })
		for i, id in order do
			local j = jets[id]
			local b = button(jetGrid, "", UDim2.new(), UDim2.new())
			b.LayoutOrder = i
			label(b, j.name, 15, C.text, true, { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -16, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd })
			label(b, string.format("%s · %d HP · %d ракет", j.role, j.hp, j.missiles), 12, C.dim, false, { Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -16, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
			b.MouseButton1Click:Connect(function()
				selJet = id
				paintSel()
			end)
			jetBtns[id] = b
		end
		paintSel()
	end
	-- spawns: { {id, title, sub, ok} }
	function ui.setSpawns(list: { any })
		local seen = {}
		for i, s in list do
			seen[s.id] = true
			local b = spawnBtns[s.id]
			if not b then
				b = button(spawnList, "", UDim2.new(1, 0, 0, 48), UDim2.new())
				label(b, "", 15, C.text, true, { Name = "T", Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -20, 0, 20) })
				label(b, "", 12, C.dim, false, { Name = "S", Position = UDim2.fromOffset(14, 26), Size = UDim2.new(1, -20, 0, 16) })
				local id = s.id
				b.MouseButton1Click:Connect(function()
					if b:GetAttribute("Ok") then
						selSpawn = id
						paintSel()
					end
				end)
				spawnBtns[s.id] = b
			end
			b.LayoutOrder = i
			b:SetAttribute("Ok", s.ok)
			;(b:FindFirstChild("T") :: TextLabel).Text = s.title
			;(b:FindFirstChild("S") :: TextLabel).Text = s.sub
			b.TextTransparency = 0
			b.BackgroundTransparency = if s.ok then 0.1 else 0.6
			;(b:FindFirstChild("T") :: TextLabel).TextColor3 = if s.ok then C.text else C.dim
		end
		for id, b in spawnBtns do
			if not seen[id] then
				b:Destroy()
				spawnBtns[id] = nil
			end
		end
		local cur = spawnBtns[selSpawn]
		if not cur or not cur:GetAttribute("Ok") then
			selSpawn = list[1] and list[1].id or ""
		end
		paintSel()
	end
	function ui.setTeam(side: string, name: string)
		teamLbl.Text = "Команда: " .. name
		teamLbl.TextColor3 = C[side] or C.accent
	end
	function ui.setScoreLine(t: string)
		scoreLbl.Text = t
	end
	local launchCb: ((string, string) -> ())? = nil
	function ui.onLaunch(cb: (string, string) -> ())
		launchCb = cb
	end
	go.MouseButton1Click:Connect(function()
		if launchCb and selSpawn ~= "" then
			launchCb(selJet, selSpawn)
		end
	end)
	function ui.showMenu(v: boolean)
		menu.Visible = v
	end

	-- ================= ПРИБОРЫ =================
	local hud = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, gui)
	-- счёт сверху
	local top = new("Frame", { Size = UDim2.fromOffset(420, 58), Position = UDim2.new(0.5, -210, 0, 8), BackgroundColor3 = C.bg, BackgroundTransparency = 0.25 }, gui)
	corner(top, 12)
	stroke(top)
	local tBlue = label(top, "250", 22, C.Blue, true, { Position = UDim2.fromOffset(14, 4), Size = UDim2.fromOffset(70, 28) })
	local tRed = label(top, "250", 22, C.Red, true, { Position = UDim2.new(1, -84, 0, 4), Size = UDim2.fromOffset(70, 28), TextXAlignment = Enum.TextXAlignment.Right })
	local baseRow = new("Frame", { Size = UDim2.fromOffset(240, 26), Position = UDim2.new(0.5, -120, 0, 6), BackgroundTransparency = 1 }, top)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center }, baseRow)
	local baseChips: { [string]: Frame } = {}
	function ui.setBases(list: { any })
		for i, b in list do
			local chip = baseChips[b.id]
			if not chip then
				chip = new("Frame", { Size = UDim2.fromOffset(40, 26), BackgroundColor3 = C.panel, LayoutOrder = i }, baseRow)
				corner(chip, 6)
				new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Blue, BorderSizePixel = 0 }, chip)
				corner(chip:FindFirstChild("Fill") :: Instance, 6)
				label(chip, b.id, 15, C.text, true, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 2 })
				baseChips[b.id] = chip
			end
			local fill = chip:FindFirstChild("Fill") :: Frame
			fill.Size = UDim2.fromScale(math.abs(b.cap), 1)
			fill.BackgroundColor3 = if b.cap >= 0 then C.Blue else C.Red
			fill.BackgroundTransparency = if b.owner == "" then 0.55 else 0.1
		end
	end
	local topSub = label(top, "очки команд · базы", 11, C.dim, false, { Position = UDim2.new(0, 0, 1, -18), Size = UDim2.new(1, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Center })
	function ui.setTickets(b: number, r: number)
		tBlue.Text = tostring(b)
		tRed.Text = tostring(r)
	end
	function ui.setTopHint(t: string)
		topSub.Text = t
	end

	-- приборная панель слева снизу
	local dash = new("Frame", { Size = UDim2.fromOffset(230, 132), Position = UDim2.new(0, 16, 1, -148), BackgroundColor3 = C.bg, BackgroundTransparency = 0.3 }, hud)
	corner(dash, 12)
	stroke(dash)
	local spdL = label(dash, "0", 30, C.text, true, { Position = UDim2.fromOffset(14, 6), Size = UDim2.fromOffset(110, 34) })
	label(dash, "СКОР kt", 11, C.dim, true, { Position = UDim2.fromOffset(14, 40), Size = UDim2.fromOffset(100, 14) })
	local altL = label(dash, "0", 30, C.text, true, { Position = UDim2.fromOffset(120, 6), Size = UDim2.fromOffset(100, 34) })
	label(dash, "ВЫС ft", 11, C.dim, true, { Position = UDim2.fromOffset(120, 40), Size = UDim2.fromOffset(100, 14) })
	local function bar(y: number, name: string, colr: Color3): (Frame, TextLabel)
		label(dash, name, 11, C.dim, true, { Position = UDim2.fromOffset(14, y), Size = UDim2.fromOffset(60, 14) })
		local bg = new("Frame", { Size = UDim2.fromOffset(150, 8), Position = UDim2.fromOffset(66, y + 4), BackgroundColor3 = C.panel }, dash)
		corner(bg, 4)
		local fill = new("Frame", { Size = UDim2.fromScale(0.5, 1), BackgroundColor3 = colr, BorderSizePixel = 0 }, bg)
		corner(fill, 4)
		local v = label(dash, "", 11, C.dim, false, { Position = UDim2.fromOffset(66, y + 12), Size = UDim2.fromOffset(150, 12) })
		return fill, v
	end
	local thrFill = bar(62, "ТЯГА", C.accent)
	local hpFill, hpTxt = bar(88, "КОРПУС", C.green)
	local ammoL = label(dash, "", 12, C.text, true, { Position = UDim2.fromOffset(14, 112), Size = UDim2.fromOffset(210, 16) })

	-- прицел и захват
	local cross = new("Frame", { Size = UDim2.fromOffset(34, 34), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1 }, hud)
	local crossRing = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, cross)
	corner(crossRing, 17)
	stroke(crossRing, C.accent, 2)
	new("Frame", { Size = UDim2.fromOffset(4, 4), Position = UDim2.new(0.5, -2, 0.5, -2), BackgroundColor3 = C.accent, BorderSizePixel = 0 }, cross)
	local lockBox = new("Frame", { Size = UDim2.fromOffset(46, 46), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false }, hud)
	local lockStroke = new("UIStroke", { Color = C.amber, Thickness = 2 }, lockBox)
	local lockTxt = label(lockBox, "", 12, C.amber, true, { Position = UDim2.new(0, -20, 1, 4), Size = UDim2.new(1, 40, 0, 14), TextXAlignment = Enum.TextXAlignment.Center })

	local warnL = label(hud, "", 22, C.red, true, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 78), Size = UDim2.fromOffset(500, 28), TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.4 })
	local infoL = label(hud, "", 16, C.amber, true, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 108), Size = UDim2.fromOffset(560, 22), TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.5 })
	local hitL = label(hud, "", 16, C.amber, true, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 46), Size = UDim2.fromOffset(200, 20), TextXAlignment = Enum.TextXAlignment.Center })

	-- метки самолётов (пул)
	local markers: { Frame } = {}
	for i = 1, 28 do
		local m = new("Frame", { Size = UDim2.fromOffset(18, 18), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false }, hud)
		new("UIStroke", { Name = "S", Color = C.Red, Thickness = 2 }, m)
		label(m, "", 11, C.Red, true, { Name = "D", Position = UDim2.new(0, -30, 1, 2), Size = UDim2.new(1, 60, 0, 13), TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.5 })
		markers[i] = m
	end
	-- list: {x, y, color, text, size}
	function ui.setMarkers(list: { any })
		for i, m in markers do
			local it = list[i]
			if it then
				m.Visible = true
				m.Position = UDim2.fromOffset(it.x, it.y)
				m.Size = UDim2.fromOffset(it.size, it.size)
				;(m:FindFirstChild("S") :: UIStroke).Color = it.color
				local d = m:FindFirstChild("D") :: TextLabel
				d.Text = it.text
				d.TextColor3 = it.color
			else
				m.Visible = false
			end
		end
	end

	-- радар справа сверху
	local radar = new("Frame", { Size = UDim2.fromOffset(150, 150), Position = UDim2.new(1, -166, 0, 76), BackgroundColor3 = C.bg, BackgroundTransparency = 0.3 }, hud)
	corner(radar, 75)
	stroke(radar)
	new("Frame", { Size = UDim2.new(0, 1, 1, -16), Position = UDim2.new(0.5, 0, 0, 8), BackgroundColor3 = C.line, BorderSizePixel = 0 }, radar)
	new("Frame", { Size = UDim2.new(1, -16, 0, 1), Position = UDim2.new(0, 8, 0.5, 0), BackgroundColor3 = C.line, BorderSizePixel = 0 }, radar)
	local me = new("Frame", { Size = UDim2.fromOffset(8, 8), Position = UDim2.new(0.5, -4, 0.5, -4), BackgroundColor3 = C.text, BorderSizePixel = 0 }, radar)
	corner(me, 4)
	local dots: { Frame } = {}
	for i = 1, 40 do
		local d = new("Frame", { Size = UDim2.fromOffset(6, 6), AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, Visible = false }, radar)
		corner(d, 3)
		dots[i] = d
	end
	-- list: {dx, dy (−1..1), color, big}
	function ui.setRadar(list: { any })
		for i, d in dots do
			local it = list[i]
			if it then
				d.Visible = true
				d.Position = UDim2.new(0.5 + it.dx * 0.45, 0, 0.5 + it.dy * 0.45, 0)
				d.BackgroundColor3 = it.color
				local s = if it.big then 11 else 6
				d.Size = UDim2.fromOffset(s, s)
			else
				d.Visible = false
			end
		end
	end

	-- лента событий
	local feed = new("Frame", { Size = UDim2.fromOffset(340, 160), Position = UDim2.new(1, -356, 0, 236), BackgroundTransparency = 1 }, gui)
	new("UIListLayout", { Padding = UDim.new(0, 4), VerticalAlignment = Enum.VerticalAlignment.Top, HorizontalAlignment = Enum.HorizontalAlignment.Right }, feed)
	function ui.feed(text: string, colr: Color3)
		local l = label(feed, text, 13, colr, true, { TextXAlignment = Enum.TextXAlignment.Right, BackgroundTransparency = 0.35, BackgroundColor3 = C.bg, Size = UDim2.new(1, 0, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd })
		new("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8) }, l)
		corner(l, 6)
		local kids = feed:GetChildren()
		local n = 0
		for _, k in kids do
			if k:IsA("TextLabel") then
				n += 1
			end
		end
		if n > 6 then
			for _, k in kids do
				if k:IsA("TextLabel") and k ~= l then
					k:Destroy()
					break
				end
			end
		end
		task.delay(9, function()
			if l.Parent then
				TweenService:Create(l, TweenInfo.new(0.6), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
				task.wait(0.7)
				l:Destroy()
			end
		end)
	end

	-- всплывающие подсказки
	local toastL = label(gui, "", 17, C.text, true, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -170), Size = UDim2.fromOffset(620, 30), TextXAlignment = Enum.TextXAlignment.Center, BackgroundColor3 = C.bg, BackgroundTransparency = 1, TextTransparency = 1, TextWrapped = true })
	corner(toastL, 8)
	local toastSeq = 0
	function ui.toast(text: string, colr: string?)
		toastSeq += 1
		local s = toastSeq
		toastL.Text = text
		toastL.TextColor3 = (colr and C[colr]) or C.text
		toastL.TextTransparency = 0
		toastL.BackgroundTransparency = 0.3
		task.delay(3.5, function()
			if s == toastSeq then
				TweenService:Create(toastL, TweenInfo.new(0.5), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
			end
		end)
	end

	-- экран «сбит»
	local dead = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(30, 6, 6), BackgroundTransparency = 0.45, Visible = false }, gui)
	local deadT = label(dead, "", 34, C.text, true, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(700, 44), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true })
	label(dead, "Возврат на авианосец…", 16, C.dim, false, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.53), Size = UDim2.fromOffset(500, 20), TextXAlignment = Enum.TextXAlignment.Center })
	function ui.showDead(text: string?)
		dead.Visible = text ~= nil
		deadT.Text = text or ""
	end

	-- ================= СЕНСОРНОЕ УПРАВЛЕНИЕ =================
	ui.touch = { x = 0, y = 0, rr = 0, rl = 0, brake = false, throttle = nil :: number?, fire = false }
	local touchBtns: { [string]: TextButton } = {}
	local activeTouches: { [InputObject]: boolean } = {}
	function ui.isTouchingControls(): boolean
		return next(activeTouches) ~= nil
	end
	local actionCb: ((string) -> ())? = nil
	function ui.onAction(cb: (string) -> ())
		actionCb = cb
	end
	local touchLayer = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, hud)
	if isTouch then
		touchLayer.Visible = true
		-- стик
		local stickBase = new("Frame", { Size = UDim2.fromOffset(170, 170), Position = UDim2.new(0, 36, 1, -330), BackgroundColor3 = C.bg, BackgroundTransparency = 0.5 }, touchLayer)
		corner(stickBase, 85)
		stroke(stickBase, C.line, 2)
		local knob = new("Frame", { Size = UDim2.fromOffset(70, 70), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = C.accent, BackgroundTransparency = 0.25 }, stickBase)
		corner(knob, 35)
		local stickInput: InputObject? = nil
		stickBase.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.Touch and not stickInput then
				stickInput = i
				activeTouches[i] = true
			end
		end)
		UserInputService.TouchMoved:Connect(function(i)
			if i == stickInput then
				local c = stickBase.AbsolutePosition + stickBase.AbsoluteSize / 2
				local d = Vector2.new(i.Position.X, i.Position.Y) - c
				local r = stickBase.AbsoluteSize.X / 2
				if d.Magnitude > r then
					d = d.Unit * r
				end
				knob.Position = UDim2.new(0.5, d.X, 0.5, d.Y)
				ui.touch.x = d.X / r
				ui.touch.y = d.Y / r -- вниз = на себя = нос вверх
			end
		end)
		UserInputService.TouchEnded:Connect(function(i)
			activeTouches[i] = nil
			if i == stickInput then
				stickInput = nil
				knob.Position = UDim2.fromScale(0.5, 0.5)
				ui.touch.x, ui.touch.y = 0, 0
			end
		end)
		-- тяга: вертикальный ползунок у правого края
		local thrBar = new("Frame", { Size = UDim2.fromOffset(46, 220), Position = UDim2.new(1, -70, 1, -330), BackgroundColor3 = C.bg, BackgroundTransparency = 0.4 }, touchLayer)
		corner(thrBar, 12)
		stroke(thrBar, C.line, 2)
		local thrKnob = new("Frame", { Size = UDim2.new(1, -8, 0, 30), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, -15), BackgroundColor3 = C.accent }, thrBar)
		corner(thrKnob, 8)
		label(thrBar, "ТЯГА", 11, C.dim, true, { Position = UDim2.new(0, 0, 1, 4), Size = UDim2.new(1, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Center })
		local thrInput: InputObject? = nil
		local function setThr(y: number)
			local a = thrBar.AbsolutePosition.Y + 15
			local b = thrBar.AbsolutePosition.Y + thrBar.AbsoluteSize.Y - 15
			local v = math.clamp((b - y) / (b - a), 0, 1)
			ui.touch.throttle = v
			ui.setThrottleKnob(v)
		end
		function ui.setThrottleKnob(v: number)
			thrKnob.Position = UDim2.new(0.5, 0, 1 - v, 15 - v * 30)
		end
		thrBar.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.Touch then
				thrInput = i
				activeTouches[i] = true
				setThr(i.Position.Y)
			end
		end)
		UserInputService.TouchMoved:Connect(function(i)
			if i == thrInput then
				setThr(i.Position.Y)
			end
		end)
		UserInputService.TouchEnded:Connect(function(i)
			if i == thrInput then
				thrInput = nil
			end
		end)
		-- кнопки оружия
		local function tbtn(name: string, text: string, size: number, pos: UDim2, colr: Color3, hold: boolean)
			local b = new("TextButton", { Size = UDim2.fromOffset(size, size), Position = pos, BackgroundColor3 = colr, BackgroundTransparency = 0.25, Text = text, TextColor3 = C.bg, Font = Enum.Font.GothamBold, TextSize = 15, AutoButtonColor = false }, touchLayer)
			corner(b, size // 2)
			stroke(b, C.text, 1)
			b.InputBegan:Connect(function(i)
				if i.UserInputType == Enum.UserInputType.Touch then
					activeTouches[i] = true
					if hold then
						ui.touch.fire = true
					elseif actionCb then
						actionCb(name)
					end
					b.BackgroundTransparency = 0.05
				end
			end)
			b.InputEnded:Connect(function(i)
				if i.UserInputType == Enum.UserInputType.Touch then
					activeTouches[i] = nil
					if hold then
						ui.touch.fire = false
					end
					b.BackgroundTransparency = 0.25
				end
			end)
			touchBtns[name] = b
		end
		tbtn("gun", "ОГОНЬ", 110, UDim2.new(1, -200, 1, -230), C.red, true)
		tbtn("missile", "РАКЕТА", 74, UDim2.new(1, -290, 1, -300), C.amber, false)
		tbtn("flare", "ЛОВУШ.", 64, UDim2.new(1, -170, 1, -320), C.text, false)
		-- верхние мелкие
		local small = { { "cam", "КАМЕРА" }, { "gear", "ШАССИ" }, { "brake", "ТОРМОЗ" }, { "menu", "МЕНЮ" } }
		for k, s in small do
			local b = new("TextButton", { Size = UDim2.fromOffset(84, 34), Position = UDim2.new(0, 16 + (k - 1) * 92, 0, 76), BackgroundColor3 = C.bg, BackgroundTransparency = 0.3, Text = s[2], TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 13 }, touchLayer)
			corner(b, 17)
			stroke(b, C.line)
			b.Activated:Connect(function()
				if actionCb then
					actionCb(s[1])
				end
			end)
		end
	else
		function ui.setThrottleKnob(_v: number) end
	end

	-- ================= ОБНОВЛЕНИЕ ПРИБОРОВ =================
	function ui.setFlying(v: boolean)
		hud.Visible = v
	end
	local hitT = 0
	function ui.hit(kill: boolean)
		hitT = os.clock()
		hitL.Text = if kill then "✖ СБИТ!" else "✕ попадание"
		hitL.TextColor3 = if kill then C.green else C.amber
	end
	function ui.update(d: any)
		spdL.Text = tostring(math.round(d.speed))
		altL.Text = tostring(math.round(d.alt))
		thrFill.Size = UDim2.fromScale(d.thr, 1)
		thrFill.BackgroundColor3 = if d.thr > 0.92 then C.amber else C.accent
		local hpk = math.clamp(d.hp / math.max(d.maxHp, 1), 0, 1)
		hpFill.Size = UDim2.fromScale(hpk, 1)
		hpFill.BackgroundColor3 = if hpk > 0.5 then C.green elseif hpk > 0.25 then C.amber else C.red
		hpTxt.Text = string.format("%d / %d", math.ceil(d.hp), d.maxHp)
		ammoL.Text = string.format("РАКЕТЫ %d   ЛОВУШКИ %d   %s", d.missiles, d.flares, if d.gear then "ШАССИ ▼" else "")
		cross.Position = UDim2.fromOffset(d.aim.X, d.aim.Y)
		if d.lock then
			lockBox.Visible = true
			lockBox.Position = UDim2.fromOffset(d.lock.x, d.lock.y)
			lockStroke.Color = if d.lock.locked then C.red else C.amber
			lockTxt.TextColor3 = lockStroke.Color
			lockTxt.Text = if d.lock.locked then "ЗАХВАТ — ПУСК!" else string.format("захват %d%%", math.floor(d.lock.k * 100))
		else
			lockBox.Visible = false
		end
		warnL.Text = d.warn or ""
		infoL.Text = d.info or ""
		if os.clock() - hitT > 0.6 then
			hitL.Text = ""
		end
	end

	return ui
end

return Hud
