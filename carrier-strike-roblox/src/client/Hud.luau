--!strict
-- Интерфейс: меню (ангар, задания, топ, магазин), ежедневная награда, итоги раунда,
-- приборы, радар, метки, лента, всплывающие награды, обучение, сенсорное управление.
-- Всё масштабируется под экран (телефон / планшет / ПК). Тексты — через L() (русский / английский).
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Hud = {}

local C = {
	bg = Color3.fromRGB(8, 14, 24),
	panel = Color3.fromRGB(16, 26, 40),
	panel2 = Color3.fromRGB(22, 40, 60),
	line = Color3.fromRGB(46, 72, 100),
	text = Color3.fromRGB(230, 238, 248),
	dim = Color3.fromRGB(140, 160, 184),
	accent = Color3.fromRGB(92, 200, 255),
	cyan = Color3.fromRGB(92, 200, 255),
	amber = Color3.fromRGB(255, 190, 70),
	gold = Color3.fromRGB(255, 206, 84),
	red = Color3.fromRGB(255, 92, 86),
	green = Color3.fromRGB(110, 230, 150),
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
local function stroke(p: Instance, col: Color3?, th: number?): UIStroke
	return new("UIStroke", { Color = col or C.line, Thickness = th or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, p)
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
local function button(parent: Instance, text: string, size: UDim2, pos: UDim2, col: Color3?, textCol: Color3?): TextButton
	local b = new("TextButton", {
		Size = size, Position = pos, BackgroundColor3 = col or C.panel, BackgroundTransparency = 0.05,
		Text = text, TextColor3 = textCol or C.text, Font = Enum.Font.GothamBold, TextSize = 16, AutoButtonColor = true,
	}, parent)
	corner(b, 10)
	stroke(b, C.line)
	return b
end
local function bar(parent: Instance, size: UDim2, pos: UDim2, col: Color3): Frame
	local bg = new("Frame", { Size = size, Position = pos, BackgroundColor3 = C.panel, BorderSizePixel = 0 }, parent)
	corner(bg, 4)
	local fill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = col, BorderSizePixel = 0 }, bg)
	corner(fill, 4)
	return bg
end
local function setBar(bg: Frame, k: number)
	(bg:FindFirstChild("Fill") :: Frame).Size = UDim2.fromScale(math.clamp(k, 0, 1), 1)
end
local function fmt(n: number): string
	local s = tostring(math.floor(math.abs(n)))
	local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "")
	return (if n < 0 then "-" else "") .. out
end
Hud.fmt = fmt

function Hud.new(L: (string, ...any) -> string): any
	local ui: any = {}
	local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	ui.isTouch = isTouch
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = new("ScreenGui", { Name = "CarrierStrikeUI", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, pg)

	-- корневая рамка под масштаб: интерфейс рисуется для 1280×720 и сжимается на маленьких экранах
	local root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, gui)
	local scaler = new("UIScale", { Scale = 1 }, root)
	local function rescale()
		local vs = workspace.CurrentCamera.ViewportSize
		local s = math.clamp(math.min(vs.X / 1280, vs.Y / 720), 0.5, 1.25)
		if isTouch then
			s = math.clamp(s * 1.1, 0.5, 1.25)
		end
		scaler.Scale = s
		root.Size = UDim2.fromScale(1 / s, 1 / s)
		ui.scale = s
	end
	ui.scale = 1
	rescale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

	-- ============================================================ МЕНЮ
	local menu = new("Frame", { Name = "Menu", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, root)
	local shade = new("Frame", { Size = UDim2.fromScale(0.62, 1), BackgroundColor3 = C.bg, BackgroundTransparency = 0.15, BorderSizePixel = 0 }, menu)
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0.2), NumberSequenceKeypoint.new(1, 1) }) }, shade)

	local left = new("Frame", { Size = UDim2.new(0, 470, 1, -24), Position = UDim2.fromOffset(18, 12), BackgroundTransparency = 1 }, menu)
	label(left, "CARRIER STRIKE", 34, C.text, true, { Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 40) })
	local teamLbl = label(left, "", 15, C.accent, true, { Position = UDim2.fromOffset(2, 40), Size = UDim2.new(1, 0, 0, 20) })

	-- профиль: уровень, опыт, монеты
	local prof = new("Frame", { Size = UDim2.new(1, 0, 0, 52), Position = UDim2.fromOffset(0, 66), BackgroundColor3 = C.panel, BackgroundTransparency = 0.1 }, left)
	corner(prof, 12)
	stroke(prof)
	local lvlBox = new("Frame", { Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = C.accent }, prof)
	corner(lvlBox, 20)
	local lvlL = label(lvlBox, "1", 18, C.bg, true, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
	local xpTxt = label(prof, "", 12, C.dim, true, { Position = UDim2.fromOffset(56, 6), Size = UDim2.new(1, -200, 0, 16) })
	local xpBar = bar(prof, UDim2.new(1, -200, 0, 8), UDim2.fromOffset(56, 28), C.accent)
	local coinsL = label(prof, "💰 0", 20, C.gold, true, { Position = UDim2.new(1, -136, 0, 12), Size = UDim2.fromOffset(126, 26), TextXAlignment = Enum.TextXAlignment.Right })

	-- большая кнопка «Играть»
	local quick = button(left, "", UDim2.new(1, 0, 0, 64), UDim2.fromOffset(0, 128), C.accent)
	label(quick, "▶  " .. L("play"), 26, C.bg, true, { Position = UDim2.fromOffset(18, 6), Size = UDim2.new(1, -24, 0, 32) })
	local quickSub = label(quick, L("play_sub"), 13, C.bg, false, { Position = UDim2.fromOffset(20, 38), Size = UDim2.new(1, -24, 0, 16) })

	-- вкладки
	local tabsRow = new("Frame", { Size = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, 202), BackgroundTransparency = 1 }, left)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }, tabsRow)
	local pages: { [string]: ScrollingFrame } = {}
	local tabBtns: { [string]: TextButton } = {}
	local tabDot: { [string]: Frame } = {}
	local function page(name: string): ScrollingFrame
		local sf = new("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, -248), Position = UDim2.fromOffset(0, 246), BackgroundTransparency = 1, BorderSizePixel = 0,
			ScrollBarThickness = 4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false,
		}, left)
		new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, sf)
		new("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 12) }, sf)
		pages[name] = sf
		return sf
	end
	local curTab = "hangar"
	local function showTab(name: string)
		curTab = name
		for n, pgf in pages do
			pgf.Visible = n == name
		end
		for n, b in tabBtns do
			b.BackgroundColor3 = if n == name then C.panel2 else C.panel
			b.TextColor3 = if n == name then C.accent else C.dim
		end
	end
	for i, n in { "hangar", "missions", "top", "shop" } do
		local b = button(tabsRow, L("tab_" .. n), UDim2.new(0.25, -5, 1, 0), UDim2.new(), C.panel, C.dim)
		b.TextSize = 14
		b.LayoutOrder = i
		tabBtns[n] = b
		local dot = new("Frame", { Size = UDim2.fromOffset(10, 10), Position = UDim2.new(1, -12, 0, 2), BackgroundColor3 = C.red, Visible = false }, b)
		corner(dot, 5)
		tabDot[n] = dot
		b.MouseButton1Click:Connect(function()
			showTab(n)
		end)
	end
	local hangar = page("hangar")
	local missions = page("missions")
	local topPage = page("top")
	local shop = page("shop")
	showTab("hangar")

	local function section(parent: Instance, text: string, order: number)
		label(parent, text, 13, C.dim, true, { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 18) })
	end

	-- ---------- АНГАР: самолёты, раскраски, точка вылета, кнопка «В бой»
	section(hangar, L("sec_jet"), 1)
	local jetGrid = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2 }, hangar)
	new("UIGridLayout", { CellSize = UDim2.new(0.5, -5, 0, 112), CellPadding = UDim2.fromOffset(10, 8), SortOrder = Enum.SortOrder.LayoutOrder }, jetGrid)
	section(hangar, L("sec_paint"), 3)
	local paintRow = new("ScrollingFrame", { Size = UDim2.new(1, 0, 0, 74), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollingDirection = Enum.ScrollingDirection.X, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X, LayoutOrder = 4 }, hangar)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, paintRow)
	section(hangar, L("sec_spawn"), 5)
	local spawnList = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 6 }, hangar)
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, spawnList)
	local go = button(hangar, L("launch"), UDim2.new(1, 0, 0, 54), UDim2.new(), C.green, C.bg)
	go.LayoutOrder = 7
	go.TextSize = 22
	label(hangar, if isTouch then L("help_touch") else L("help_pc"), 12, C.dim, false, { LayoutOrder = 8, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })

	-- карточка выбранного самолёта справа внизу
	local card = new("Frame", { Size = UDim2.fromOffset(330, 196), Position = UDim2.new(1, -348, 1, -214), BackgroundColor3 = C.bg, BackgroundTransparency = 0.15 }, menu)
	corner(card, 14)
	stroke(card)
	local cardName = label(card, "", 22, C.text, true, { Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -32, 0, 28), TextXAlignment = Enum.TextXAlignment.Right })
	local cardRole = label(card, "", 13, C.accent, true, { Position = UDim2.fromOffset(16, 38), Size = UDim2.new(1, -32, 0, 18), TextXAlignment = Enum.TextXAlignment.Right })
	local statBars: { Frame } = {}
	for i, n in { "st_speed", "st_agility", "st_armor", "st_missiles" } do
		label(card, L(n), 12, C.dim, true, { Position = UDim2.fromOffset(16, 62 + (i - 1) * 20), Size = UDim2.fromOffset(110, 16) })
		statBars[i] = bar(card, UDim2.new(1, -150, 0, 7), UDim2.fromOffset(134, 67 + (i - 1) * 20), C.accent)
	end
	local cardBuy = button(card, "", UDim2.new(1, -32, 0, 34), UDim2.fromOffset(16, 148), C.gold, C.bg)

	-- пригласить друзей
	local invite = button(menu, "👥 " .. L("invite"), UDim2.fromOffset(220, 40), UDim2.new(1, -238, 0, 14), C.panel, C.text)
	invite.TextSize = 15

	-- ---------- состояние меню
	local jetsOrder: { string } = {}
	local jetsDef: { [string]: any } = {}
	local progDef: any = nil
	local profile: any = nil
	local selJet, selPaint, selSpawn = "F16", "team", ""
	local jetBtns: { [string]: TextButton } = {}
	local paintBtns: { [string]: TextButton } = {}
	local spawnBtns: { [string]: TextButton } = {}
	local cbs: any = {}

	local function level(): number
		if not profile or not progDef then
			return 1
		end
		return (progDef.levelOf(profile.xp))
	end
	local function owned(id: string): boolean
		return profile ~= nil and profile.owned[id] == true
	end
	local function paintOwned(pt: any): boolean
		if not profile then
			return pt.id == "team"
		end
		if pt.vip then
			return profile.vip == true
		end
		return profile.paints[pt.id] == true
	end

	-- 3D-превью в карточках: настоящая модель самолёта в ViewportFrame
	local builder: ((string, string) -> Model?)? = nil
	local views: { [string]: { vp: ViewportFrame, cam: Camera, model: Model?, dist: number, paint: string } } = {}
	local function setView(id: string, paint: string)
		local v = views[id]
		if not v or not builder or v.paint == paint then
			return
		end
		v.paint = paint
		if v.model then
			v.model:Destroy()
		end
		local m = builder(id, paint)
		if not m then
			return
		end
		m:PivotTo(CFrame.identity)
		m.Parent = v.vp
		v.model = m
		local size = m:GetExtentsSize()
		v.dist = math.max(size.X, size.Z) * 0.5 / math.tan(math.rad(v.cam.FieldOfView * 0.5)) * 1.12
	end
	local spin = 0
	RunService.RenderStepped:Connect(function(dt)
		if not menu.Visible or not pages.hangar.Visible then
			return
		end
		spin += dt * 0.6
		for id, v in views do
			local yaw = if id == selJet then spin else 2.4
			v.cam.CFrame = CFrame.fromOrientation(-0.38, yaw, 0) * CFrame.new(0, 0, v.dist)
		end
	end)

	local function refreshCard()
		local j = jetsDef[selJet]
		if not j then
			return
		end
		cardName.Text = j.name
		cardRole.Text = L("role_" .. selJet)
		setBar(statBars[1], (j.maxKts - 600) / 220)
		setBar(statBars[2], (j.rollRate - 2.6) / 1.9)
		setBar(statBars[3], (j.hp - 80) / 60)
		setBar(statBars[4], j.missiles / 6)
		local pj = progDef and progDef.JETS[selJet]
		if owned(selJet) then
			cardBuy.Visible = false
		else
			cardBuy.Visible = true
			if pj and level() < pj.level then
				cardBuy.Text = "🔒 " .. L("need_lvl", pj.level)
				cardBuy.BackgroundColor3 = C.panel2
				cardBuy.TextColor3 = C.dim
			else
				cardBuy.Text = L("buy_for", fmt(pj and pj.cost or 0))
				cardBuy.BackgroundColor3 = C.gold
				cardBuy.TextColor3 = C.bg
			end
		end
	end

	local function paintSel()
		for id, b in jetBtns do
			local s = b:FindFirstChildOfClass("UIStroke") :: UIStroke
			s.Color = if id == selJet then C.accent else C.line
			s.Thickness = if id == selJet then 2 else 1
			b.BackgroundColor3 = if id == selJet then C.panel2 else C.panel
		end
		for id, b in paintBtns do
			local s = b:FindFirstChildOfClass("UIStroke") :: UIStroke
			s.Color = if id == selPaint then C.accent else C.line
			s.Thickness = if id == selPaint then 3 else 1
		end
		for id, b in spawnBtns do
			local s = b:FindFirstChildOfClass("UIStroke") :: UIStroke
			s.Color = if id == selSpawn then C.accent else C.line
			s.Thickness = if id == selSpawn then 2 else 1
			b.BackgroundColor3 = if id == selSpawn then C.panel2 else C.panel
		end
		go.Text = if owned(selJet) then L("launch") else L("launch_locked")
		go.BackgroundColor3 = if owned(selJet) then C.green else C.panel2
		refreshCard()
		for id in views do
			setView(id, if id == selJet then selPaint else "team")
		end
		if cbs.select then
			cbs.select(selJet, selPaint)
		end
	end

	function ui.setJets(order: { string }, jets: { [string]: any }, prog: any, build: ((string, string) -> Model?)?)
		jetsOrder, jetsDef, progDef = order, jets, prog
		builder = build
		for i, id in order do
			local j = jets[id]
			local b = button(jetGrid, "", UDim2.new(), UDim2.new())
			b.LayoutOrder = i
			b.ClipsDescendants = true
			local vp = new("ViewportFrame", {
				Size = UDim2.new(1, -8, 0, 66), Position = UDim2.fromOffset(4, 4), BackgroundTransparency = 1,
				Ambient = Color3.fromRGB(150, 158, 176), LightColor = Color3.fromRGB(255, 236, 214), LightDirection = Vector3.new(-0.5, -1, -0.4),
			}, b)
			local vcam = Instance.new("Camera")
			vcam.FieldOfView = 30
			vcam.Parent = vp
			vp.CurrentCamera = vcam
			views[id] = { vp = vp, cam = vcam, model = nil, dist = 60, paint = "" }
			label(b, j.name, 14, C.text, true, { Position = UDim2.fromOffset(10, 70), Size = UDim2.new(1, -16, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
			label(b, "", 12, C.dim, false, { Name = "Sub", Position = UDim2.fromOffset(10, 90), Size = UDim2.new(1, -16, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd })
			b.MouseButton1Click:Connect(function()
				selJet = id
				paintSel()
			end)
			jetBtns[id] = b
		end
		for i, pt in prog.PAINTS do
			local b = new("TextButton", { Size = UDim2.fromOffset(64, 64), BackgroundColor3 = pt.body or C.Blue, Text = "", AutoButtonColor = true, LayoutOrder = i }, paintRow)
			corner(b, 12)
			stroke(b, C.line)
			if pt.accent then
				new("Frame", { Size = UDim2.new(1, 0, 0.3, 0), Position = UDim2.fromScale(0, 0.7), BackgroundColor3 = pt.accent, BorderSizePixel = 0 }, b)
			end
			label(b, "", 11, C.text, true, { Name = "P", Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -16), TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.3, ZIndex = 2 })
			b.MouseButton1Click:Connect(function()
				if paintOwned(pt) then
					selPaint = pt.id
					paintSel()
				elseif pt.vip then
					if cbs.shop then
						cbs.shop("vip", 0)
					end
				elseif cbs.buy then
					cbs.buy("paint", pt.id)
				end
			end)
			paintBtns[pt.id] = b
		end
		paintSel()
	end

	local function refreshLists()
		if not profile or not progDef then
			return
		end
		local lvl = level()
		for id, b in jetBtns do
			local sub = b:FindFirstChild("Sub") :: TextLabel
			local pj = progDef.JETS[id]
			if owned(id) then
				sub.Text = "✓ " .. L("role_" .. id)
				sub.TextColor3 = C.green
			elseif pj and lvl < pj.level then
				sub.Text = "🔒 " .. L("need_lvl", pj.level)
				sub.TextColor3 = C.dim
			else
				sub.Text = "💰 " .. fmt(pj and pj.cost or 0)
				sub.TextColor3 = C.gold
			end
		end
		for _, pt in progDef.PAINTS do
			local b = paintBtns[pt.id]
			if b then
				local p = b:FindFirstChild("P") :: TextLabel
				p.Text = if paintOwned(pt) then "" elseif pt.vip then "VIP" elseif lvl < pt.level then "🔒" .. pt.level else fmt(pt.cost)
			end
		end
		if not owned(selJet) and owned(profile.jet) then
			selJet = profile.jet
		end
		paintSel()
	end

	function ui.setProfile(p: any)
		local first = profile == nil
		profile = p
		local lvl, into, need = progDef.levelOf(p.xp)
		lvlL.Text = tostring(lvl)
		xpTxt.Text = L("level_xp", lvl, fmt(into), fmt(need))
		setBar(xpBar, into / math.max(need, 1))
		coinsL.Text = "💰 " .. fmt(p.coins)
		if first then
			if owned(p.jet) then
				selJet = p.jet
			end
			local pt = progDef.paint(p.paint)
			if pt and paintOwned(pt) then
				selPaint = p.paint
			end
		end
		refreshLists()
		ui.renderMissions()
		ui.renderShop()
		tabDot.missions.Visible = p.daily.can
	end

	-- точки вылета: { {id, title, sub, ok} }
	function ui.setSpawns(list: { any })
		local seen = {}
		for i, s in list do
			seen[s.id] = true
			local b = spawnBtns[s.id]
			if not b then
				b = button(spawnList, "", UDim2.new(1, 0, 0, 44), UDim2.new())
				label(b, "", 15, C.text, true, { Name = "T", Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -20, 0, 20) })
				label(b, "", 11, C.dim, false, { Name = "S", Position = UDim2.fromOffset(12, 24), Size = UDim2.new(1, -20, 0, 16) })
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
			local t = b:FindFirstChild("T") :: TextLabel
			local sub = b:FindFirstChild("S") :: TextLabel
			t.Text = s.title
			sub.Text = s.sub
			b.BackgroundTransparency = if s.ok then 0.05 else 0.6
			t.TextColor3 = if s.ok then C.text else C.dim
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
	function ui.setTeam(side: string)
		teamLbl.Text = L("team_" .. side)
		teamLbl.TextColor3 = C[side] or C.accent
	end
	function ui.on(name: string, cb: any)
		cbs[name] = cb
	end
	quick.MouseButton1Click:Connect(function()
		if cbs.quick then
			cbs.quick(if owned(selJet) then selJet else "F16", if owned(selJet) then selPaint else "team")
		end
	end)
	go.MouseButton1Click:Connect(function()
		if not owned(selJet) then
			if cbs.buy then
				cbs.buy("jet", selJet)
			end
		elseif cbs.launch and selSpawn ~= "" then
			cbs.launch(selJet, selSpawn, selPaint)
		end
	end)
	cardBuy.MouseButton1Click:Connect(function()
		if cbs.buy then
			cbs.buy("jet", selJet)
		end
	end)
	invite.MouseButton1Click:Connect(function()
		if cbs.invite then
			cbs.invite()
		end
	end)
	function ui.showMenu(v: boolean)
		menu.Visible = v
	end
	function ui.setQuickSub(t: string)
		quickSub.Text = t
	end

	-- ---------- ЗАДАНИЯ
	local dailyBtn: TextButton? = nil
	function ui.renderMissions()
		for _, ch in missions:GetChildren() do
			if ch:IsA("GuiObject") then
				ch:Destroy()
			end
		end
		if not profile then
			return
		end
		section(missions, L("sec_daily"), 1)
		local d = profile.daily
		local row = new("Frame", { Size = UDim2.new(1, 0, 0, 62), BackgroundTransparency = 1, LayoutOrder = 2 }, missions)
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5) }, row)
		for i, coins in progDef.DAILY do
			local got = (not d.can and i <= d.idx) or (d.can and i < d.idx)
			local today = i == d.idx
			local cell = new("Frame", { Size = UDim2.new(1 / 7, -5, 1, 0), BackgroundColor3 = if today then C.panel2 else C.panel, LayoutOrder = i }, row)
			corner(cell, 8)
			stroke(cell, if today then C.gold else C.line, if today then 2 else 1)
			label(cell, L("day_n", i), 11, C.dim, true, { Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 4), TextXAlignment = Enum.TextXAlignment.Center })
			label(cell, if got then "✓" else fmt(coins), 14, if got then C.green else C.gold, true, { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 26), TextXAlignment = Enum.TextXAlignment.Center })
		end
		if d.can then
			local b = button(missions, L("claim_daily", fmt(progDef.DAILY[d.idx])), UDim2.new(1, 0, 0, 44), UDim2.new(), C.gold, C.bg)
			b.LayoutOrder = 3
			b.MouseButton1Click:Connect(function()
				if cbs.daily then
					cbs.daily()
				end
			end)
			dailyBtn = b
		else
			label(missions, L("daily_back"), 12, C.dim, false, { LayoutOrder = 3, TextWrapped = true, Size = UDim2.new(1, 0, 0, 30) })
		end
		section(missions, L("sec_quests"), 4)
		for i, q in profile.quests do
			local f = new("Frame", { Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = C.panel, LayoutOrder = 4 + i }, missions)
			corner(f, 10)
			stroke(f, if q.done then C.green else C.line)
			label(f, L("q_" .. q.id, q.n), 14, if q.done then C.green else C.text, true, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -110, 0, 20) })
			label(f, (if q.done then "✓ " else "") .. "💰 " .. fmt(q.reward), 14, C.gold, true, { Position = UDim2.new(1, -100, 0, 6), Size = UDim2.fromOffset(90, 20), TextXAlignment = Enum.TextXAlignment.Right })
			local pb = bar(f, UDim2.new(1, -24, 0, 8), UDim2.fromOffset(12, 36), if q.done then C.green else C.accent)
			setBar(pb, q.p / q.n)
			label(f, string.format("%d / %d", q.p, q.n), 11, C.dim, true, { Position = UDim2.new(1, -80, 0, 30), Size = UDim2.fromOffset(68, 14), TextXAlignment = Enum.TextXAlignment.Right, Visible = false })
		end
		label(missions, L("quests_reset"), 12, C.dim, false, { LayoutOrder = 20, TextWrapped = true, Size = UDim2.new(1, 0, 0, 30) })
		local st = profile.stats
		section(missions, L("sec_stats"), 21)
		label(missions, L("stats_line", st.kills, st.deaths, st.wins, st.caps, st.sorties), 13, C.text, false, { LayoutOrder = 22, TextWrapped = true, Size = UDim2.new(1, 0, 0, 40) })
	end

	-- ---------- ТОП НЕДЕЛИ
	function ui.setTop(list: { any }, myWeek: number)
		for _, ch in topPage:GetChildren() do
			if ch:IsA("GuiObject") then
				ch:Destroy()
			end
		end
		section(topPage, L("sec_top"), 1)
		if #list == 0 then
			label(topPage, L("top_empty"), 13, C.dim, false, { LayoutOrder = 2, TextWrapped = true, Size = UDim2.new(1, 0, 0, 40) })
		end
		local me = Players.LocalPlayer.Name
		for i, e in list do
			local f = new("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = if e[1] == me then C.panel2 else C.panel, LayoutOrder = 1 + i }, topPage)
			corner(f, 8)
			local medal = if i == 1 then "🥇" elseif i == 2 then "🥈" elseif i == 3 then "🥉" else tostring(i) .. "."
			label(f, medal .. "  " .. tostring(e[1]), 15, C.text, true, { Position = UDim2.fromOffset(12, 7), Size = UDim2.new(1, -120, 0, 22) })
			label(f, fmt(tonumber(e[2]) or 0) .. " ✈", 15, C.gold, true, { Position = UDim2.new(1, -110, 0, 7), Size = UDim2.fromOffset(98, 22), TextXAlignment = Enum.TextXAlignment.Right })
		end
		label(topPage, L("top_mine", myWeek), 13, C.accent, true, { LayoutOrder = 50, Size = UDim2.new(1, 0, 0, 20) })
		label(topPage, L("top_hint"), 12, C.dim, false, { LayoutOrder = 51, TextWrapped = true, Size = UDim2.new(1, 0, 0, 30) })
	end

	-- ---------- МАГАЗИН
	function ui.renderShop()
		for _, ch in shop:GetChildren() do
			if ch:IsA("GuiObject") then
				ch:Destroy()
			end
		end
		if not profile then
			return
		end
		section(shop, L("sec_vip"), 1)
		local v = new("Frame", { Size = UDim2.new(1, 0, 0, 110), BackgroundColor3 = C.panel, LayoutOrder = 2 }, shop)
		corner(v, 12)
		stroke(v, C.gold, 2)
		label(v, "★ VIP", 22, C.gold, true, { Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 26) })
		label(v, L("vip_desc"), 13, C.text, false, { Position = UDim2.fromOffset(14, 38), Size = UDim2.new(1, -28, 0, 36), TextWrapped = true })
		local vb = button(v, if profile.vip then L("vip_have") elseif profile.shop.vip > 0 then L("vip_buy") else L("soon"), UDim2.new(1, -28, 0, 28), UDim2.fromOffset(14, 76), if profile.vip then C.panel2 else C.gold, C.bg)
		vb.Active = profile.shop.vip > 0 and not profile.vip
		vb.MouseButton1Click:Connect(function()
			if cbs.shop and profile.shop.vip > 0 and not profile.vip then
				cbs.shop("vip", profile.shop.vip)
			end
		end)
		section(shop, L("sec_coins"), 3)
		for i, pr in profile.shop.coins do
			local b = button(shop, "💰 " .. fmt(pr.coins) .. (if pr.id > 0 then "" else "  ·  " .. L("soon")), UDim2.new(1, 0, 0, 44), UDim2.new(), C.panel, C.gold)
			b.LayoutOrder = 3 + i
			b.MouseButton1Click:Connect(function()
				if cbs.shop and pr.id > 0 then
					cbs.shop("coins", pr.id)
				end
			end)
		end
		label(shop, L("shop_hint"), 12, C.dim, false, { LayoutOrder = 20, TextWrapped = true, Size = UDim2.new(1, 0, 0, 44) })
	end

	-- ============================================================ ОКНА (ежедневная награда, итоги раунда)
	local modal = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Visible = false, ZIndex = 20 }, root)
	local box = new("Frame", { Size = UDim2.fromOffset(560, 330), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = C.bg, ZIndex = 21 }, modal)
	corner(box, 16)
	stroke(box, C.accent, 2)
	local function clearBox()
		for _, ch in box:GetChildren() do
			if ch:IsA("GuiObject") then
				ch:Destroy()
			end
		end
	end
	local function zall(f: Instance)
		for _, d in f:GetDescendants() do
			if d:IsA("GuiObject") then
				d.ZIndex = 22
			end
		end
	end
	function ui.closeModal()
		modal.Visible = false
	end

	function ui.showDaily()
		if not profile or not profile.daily.can then
			return
		end
		clearBox()
		modal.Visible = true
		local d = profile.daily
		label(box, "🎁 " .. L("daily_title"), 26, C.gold, true, { Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 32), TextXAlignment = Enum.TextXAlignment.Center })
		label(box, L("daily_sub", d.idx), 14, C.dim, false, { Position = UDim2.fromOffset(20, 56), Size = UDim2.new(1, -40, 0, 20), TextXAlignment = Enum.TextXAlignment.Center })
		local row = new("Frame", { Size = UDim2.new(1, -40, 0, 92), Position = UDim2.fromOffset(20, 92), BackgroundTransparency = 1 }, box)
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }, row)
		for i, coins in progDef.DAILY do
			local today = i == d.idx
			local cell = new("Frame", { Size = UDim2.new(1 / 7, -6, 1, 0), BackgroundColor3 = if today then C.panel2 else C.panel, LayoutOrder = i }, row)
			corner(cell, 10)
			stroke(cell, if today then C.gold else C.line, if today then 3 else 1)
			label(cell, L("day_n", i), 12, C.dim, true, { Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 8), TextXAlignment = Enum.TextXAlignment.Center })
			label(cell, if i < d.idx then "✓" else (if i == 7 then "🎁" else "💰"), 22, C.gold, true, { Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 28), TextXAlignment = Enum.TextXAlignment.Center })
			label(cell, fmt(coins), 13, if i < d.idx then C.green else C.gold, true, { Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 64), TextXAlignment = Enum.TextXAlignment.Center })
		end
		local b = button(box, L("claim_daily", fmt(progDef.DAILY[d.idx])), UDim2.new(1, -40, 0, 54), UDim2.fromOffset(20, 210), C.gold, C.bg)
		b.TextSize = 20
		b.MouseButton1Click:Connect(function()
			modal.Visible = false
			if cbs.daily then
				cbs.daily()
			end
		end)
		label(box, L("daily_back"), 12, C.dim, false, { Position = UDim2.fromOffset(20, 276), Size = UDim2.new(1, -40, 0, 36), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center })
		zall(box)
	end

	function ui.showRound(winner: string, mvp: { any }, mySide: string, secs: number)
		clearBox()
		modal.Visible = true
		local won = winner == mySide
		label(box, if won then "🏆 " .. L("victory") else L("defeat"), 34, if won then C.gold else C.red, true, { Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 40), TextXAlignment = Enum.TextXAlignment.Center })
		label(box, L("winner_is", L("team_" .. winner)), 15, C[winner] or C.text, true, { Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Center })
		local row = new("Frame", { Size = UDim2.new(1, -40, 0, 150), Position = UDim2.fromOffset(20, 96), BackgroundTransparency = 1 }, box)
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center }, row)
		if #mvp == 0 then
			label(row, L("no_mvp"), 14, C.dim, false, { Size = UDim2.new(1, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Center })
		end
		for i, e in mvp do
			local f = new("Frame", { Size = UDim2.new(1 / 3, -10, 1, 0), BackgroundColor3 = C.panel, LayoutOrder = i }, row)
			corner(f, 12)
			stroke(f, if i == 1 then C.gold else C.line, if i == 1 then 2 else 1)
			local img = new("ImageLabel", { Size = UDim2.fromOffset(56, 56), Position = UDim2.new(0.5, -28, 0, 8), BackgroundColor3 = C.panel2, Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(e.userId) .. "&w=150&h=150" }, f)
			corner(img, 28)
			label(f, (if i == 1 then "MVP · " else "") .. tostring(e.name), 14, C[e.side] or C.text, true, { Position = UDim2.fromOffset(4, 70), Size = UDim2.new(1, -8, 0, 18), TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd })
			label(f, L("mvp_line", e.kills, e.caps), 12, C.dim, false, { Position = UDim2.fromOffset(4, 94), Size = UDim2.new(1, -8, 0, 16), TextXAlignment = Enum.TextXAlignment.Center })
			label(f, fmt(e.score), 18, C.gold, true, { Position = UDim2.fromOffset(4, 116), Size = UDim2.new(1, -8, 0, 22), TextXAlignment = Enum.TextXAlignment.Center })
		end
		local cd = label(box, "", 13, C.dim, false, { Position = UDim2.fromOffset(0, 262), Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Center })
		local ok = button(box, "OK", UDim2.fromOffset(160, 36), UDim2.new(0.5, -80, 0, 286), C.panel2, C.text)
		ok.MouseButton1Click:Connect(function()
			modal.Visible = false
		end)
		zall(box)
		task.spawn(function()
			local t = secs
			while t > 0 and cd.Parent do
				cd.Text = L("next_round", t)
				task.wait(1)
				t -= 1
			end
			if cd.Parent then
				modal.Visible = false
			end
		end)
	end

	-- ============================================================ ПРИБОРЫ
	local hud = new("Frame", { Name = "Hud", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, root)
	-- урон: красная рамка по краям
	local hurtF = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, hud)
	local hurt = new("UIStroke", { Color = C.red, Thickness = 26, Transparency = 1 }, hurtF)
	local top = new("Frame", { Size = UDim2.fromOffset(420, 58), Position = UDim2.new(0.5, -210, 0, 8), BackgroundColor3 = C.bg, BackgroundTransparency = 0.25 }, hud)
	corner(top, 12)
	stroke(top)
	local tBlue = label(top, "", 22, C.Blue, true, { Position = UDim2.fromOffset(14, 4), Size = UDim2.fromOffset(70, 28) })
	local tRed = label(top, "", 22, C.Red, true, { Position = UDim2.new(1, -84, 0, 4), Size = UDim2.fromOffset(70, 28), TextXAlignment = Enum.TextXAlignment.Right })
	local baseRow = new("Frame", { Size = UDim2.fromOffset(240, 26), Position = UDim2.new(0.5, -120, 0, 6), BackgroundTransparency = 1 }, top)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center }, baseRow)
	local baseChips: { [string]: Frame } = {}
	function ui.setBases(list: { any })
		for i, b in list do
			local chip = baseChips[b.id]
			if not chip then
				chip = new("Frame", { Size = UDim2.fromOffset(40, 26), BackgroundColor3 = C.panel, LayoutOrder = i }, baseRow)
				corner(chip, 6)
				local fill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Blue, BorderSizePixel = 0 }, chip)
				corner(fill, 6)
				label(chip, b.id, 15, C.text, true, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 2 })
				baseChips[b.id] = chip
			end
			local fill = chip:FindFirstChild("Fill") :: Frame
			fill.Size = UDim2.fromScale(math.abs(b.cap), 1)
			fill.BackgroundColor3 = if b.cap >= 0 then C.Blue else C.Red
			fill.BackgroundTransparency = if b.owner == "" then 0.55 else 0.1
		end
	end
	label(top, L("score_sub"), 11, C.dim, false, { Position = UDim2.new(0, 0, 1, -18), Size = UDim2.new(1, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Center })
	function ui.setTickets(b: number, r: number)
		tBlue.Text = tostring(b)
		tRed.Text = tostring(r)
	end

	local dash = new("Frame", { Size = UDim2.fromOffset(230, 132), Position = UDim2.new(0, 16, 1, -148), BackgroundColor3 = C.bg, BackgroundTransparency = 0.3 }, hud)
	corner(dash, 12)
	stroke(dash)
	local spdL = label(dash, "0", 30, C.text, true, { Position = UDim2.fromOffset(14, 6), Size = UDim2.fromOffset(110, 34) })
	label(dash, L("spd"), 11, C.dim, true, { Position = UDim2.fromOffset(14, 40), Size = UDim2.fromOffset(100, 14) })
	local altL = label(dash, "0", 30, C.text, true, { Position = UDim2.fromOffset(120, 6), Size = UDim2.fromOffset(100, 34) })
	label(dash, L("alt"), 11, C.dim, true, { Position = UDim2.fromOffset(120, 40), Size = UDim2.fromOffset(100, 14) })
	local function dbar(y: number, name: string, colr: Color3): (Frame, TextLabel)
		label(dash, name, 11, C.dim, true, { Position = UDim2.fromOffset(14, y), Size = UDim2.fromOffset(60, 14) })
		local bg = bar(dash, UDim2.fromOffset(150, 8), UDim2.fromOffset(66, y + 4), colr)
		local v = label(dash, "", 11, C.dim, false, { Position = UDim2.fromOffset(66, y + 12), Size = UDim2.fromOffset(150, 12) })
		return bg, v
	end
	local thrBar = dbar(62, L("thr"), C.accent)
	local hpBar, hpTxt = dbar(88, L("hull"), C.green)
	local ammoL = label(dash, "", 12, C.text, true, { Position = UDim2.fromOffset(14, 112), Size = UDim2.fromOffset(210, 16) })

	local cross = new("Frame", { Size = UDim2.fromOffset(34, 34), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1 }, hud)
	local crossRing = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, cross)
	corner(crossRing, 17)
	stroke(crossRing, C.accent, 2)
	new("Frame", { Size = UDim2.fromOffset(4, 4), Position = UDim2.new(0.5, -2, 0.5, -2), BackgroundColor3 = C.accent, BorderSizePixel = 0 }, cross)
	local lockBox = new("Frame", { Size = UDim2.fromOffset(46, 46), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false }, hud)
	local lockStroke = stroke(lockBox, C.amber, 2)
	local lockTxt = label(lockBox, "", 12, C.amber, true, { Position = UDim2.new(0, -40, 1, 4), Size = UDim2.new(1, 80, 0, 14), TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.5 })

	local warnL = label(hud, "", 22, C.red, true, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 78), Size = UDim2.fromOffset(600, 28), TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.4 })
	local infoL = label(hud, "", 16, C.amber, true, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 108), Size = UDim2.fromOffset(640, 22), TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.5 })
	local hitL = label(hud, "", 16, C.amber, true, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 46), Size = UDim2.fromOffset(200, 20), TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.5 })
	-- подсказка обучения
	local tutBox = new("Frame", { Size = UDim2.fromOffset(560, 56), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 140), BackgroundColor3 = C.bg, BackgroundTransparency = 0.15, Visible = false }, hud)
	corner(tutBox, 12)
	stroke(tutBox, C.accent, 2)
	local tutL = label(tutBox, "", 16, C.text, true, { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 1, 0), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center })
	function ui.tutorial(text: string?)
		tutBox.Visible = text ~= nil
		tutL.Text = text or ""
	end
	-- крупный баннер (серия сбитий, захват)
	local banner = label(root, "", 30, C.gold, true, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(700, 40), TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.3, TextTransparency = 1 })
	local bannerSeq = 0
	function ui.banner(text: string, colr: Color3?)
		bannerSeq += 1
		local s = bannerSeq
		banner.Text = text
		banner.TextColor3 = colr or C.gold
		banner.TextTransparency = 0
		banner.TextStrokeTransparency = 0.3
		banner.Size = UDim2.fromOffset(700, 40)
		TweenService:Create(banner, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(760, 48) }):Play()
		task.delay(2.2, function()
			if s == bannerSeq then
				TweenService:Create(banner, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			end
		end)
	end
	-- всплывающие награды «+50 💰 +100 XP»
	local rewards = new("Frame", { Size = UDim2.fromOffset(320, 200), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.5, 60, 0.5, 0), BackgroundTransparency = 1 }, root)
	new("UIListLayout", { Padding = UDim.new(0, 4), VerticalAlignment = Enum.VerticalAlignment.Center }, rewards)
	function ui.reward(coins: number, xp: number, text: string)
		local t = text
		if coins > 0 then
			t ..= "  +" .. fmt(coins) .. " 💰"
		end
		if xp > 0 then
			t ..= "  +" .. fmt(xp) .. " XP"
		end
		local l = label(rewards, t, 17, C.gold, true, { TextStrokeTransparency = 0.3, Size = UDim2.new(1, 0, 0, 22) })
		task.delay(2.4, function()
			if l.Parent then
				TweenService:Create(l, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
				task.wait(0.6)
				l:Destroy()
			end
		end)
	end

	local markers: { Frame } = {}
	for i = 1, 28 do
		local m = new("Frame", { Size = UDim2.fromOffset(18, 18), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false }, hud)
		new("UIStroke", { Name = "S", Color = C.Red, Thickness = 2 }, m)
		label(m, "", 11, C.Red, true, { Name = "D", Position = UDim2.new(0, -40, 1, 2), Size = UDim2.new(1, 80, 0, 13), TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.5 })
		markers[i] = m
	end
	-- координаты меток — в пикселях экрана; переводим в координаты масштабированного корня
	function ui.setMarkers(list: { any })
		local s = ui.scale
		for i, m in markers do
			local it = list[i]
			if it then
				m.Visible = true
				m.Position = UDim2.fromOffset(it.x / s, it.y / s)
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
	function ui.setRadar(list: { any })
		for i, d in dots do
			local it = list[i]
			if it then
				d.Visible = true
				d.Position = UDim2.new(0.5 + it.dx * 0.45, 0, 0.5 + it.dy * 0.45, 0)
				d.BackgroundColor3 = it.color
				local sz = if it.big then 11 else 6
				d.Size = UDim2.fromOffset(sz, sz)
			else
				d.Visible = false
			end
		end
	end

	local feed = new("Frame", { Size = UDim2.fromOffset(360, 170), Position = UDim2.new(1, -376, 0, 236), BackgroundTransparency = 1 }, root)
	new("UIListLayout", { Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Right }, feed)
	function ui.feed(text: string, colr: Color3)
		local l = label(feed, text, 13, colr, true, { TextXAlignment = Enum.TextXAlignment.Right, BackgroundTransparency = 0.35, BackgroundColor3 = C.bg, Size = UDim2.new(1, 0, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd })
		new("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8) }, l)
		corner(l, 6)
		local n = 0
		for _, k in feed:GetChildren() do
			if k:IsA("TextLabel") then
				n += 1
			end
		end
		if n > 6 then
			for _, k in feed:GetChildren() do
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

	local toastL = label(root, "", 17, C.text, true, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -170), Size = UDim2.fromOffset(640, 30), TextXAlignment = Enum.TextXAlignment.Center, BackgroundColor3 = C.bg, BackgroundTransparency = 1, TextTransparency = 1, TextWrapped = true, ZIndex = 30 })
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

	local dead = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(30, 6, 6), BackgroundTransparency = 0.45, Visible = false, ZIndex = 10 }, root)
	local deadT = label(dead, "", 34, C.text, true, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(760, 44), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, ZIndex = 11 })
	label(dead, L("back_to_carrier"), 16, C.dim, false, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.53), Size = UDim2.fromOffset(500, 20), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 11 })
	function ui.showDead(text: string?)
		dead.Visible = text ~= nil
		deadT.Text = text or ""
	end

	-- ============================================================ СЕНСОРНОЕ УПРАВЛЕНИЕ
	ui.touch = { x = 0, y = 0, brake = false, throttle = nil :: number?, fire = false, active = false }
	local activeTouches: { [InputObject]: boolean } = {}
	function ui.isTouchingControls(): boolean
		return next(activeTouches) ~= nil
	end
	local actionCb: ((string) -> ())? = nil
	function ui.onAction(cb: (string) -> ())
		actionCb = cb
	end
	local touchLayer = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, hud)
	function ui.setThrottleKnob(_v: number) end
	if isTouch then
		touchLayer.Visible = true
		-- приборы выше, чтобы не мешали стику
		dash.Position = UDim2.new(0, 16, 0, 76)
		local stickBase = new("Frame", { Size = UDim2.fromOffset(190, 190), Position = UDim2.new(0, 40, 1, -230), BackgroundColor3 = C.bg, BackgroundTransparency = 0.5 }, touchLayer)
		corner(stickBase, 95)
		stroke(stickBase, C.line, 2)
		local knob = new("Frame", { Size = UDim2.fromOffset(76, 76), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = C.accent, BackgroundTransparency = 0.25 }, stickBase)
		corner(knob, 38)
		local stickInput: InputObject? = nil
		stickBase.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.Touch and not stickInput then
				stickInput = i
				activeTouches[i] = true
				ui.touch.active = true
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
				knob.Position = UDim2.new(0.5, d.X / ui.scale, 0.5, d.Y / ui.scale)
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
				ui.touch.active = false
			end
		end)
		local thrBg = new("Frame", { Size = UDim2.fromOffset(50, 230), Position = UDim2.new(1, -74, 1, -270), BackgroundColor3 = C.bg, BackgroundTransparency = 0.4 }, touchLayer)
		corner(thrBg, 12)
		stroke(thrBg, C.line, 2)
		local thrKnob = new("Frame", { Size = UDim2.new(1, -8, 0, 30), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, -15), BackgroundColor3 = C.accent }, thrBg)
		corner(thrKnob, 8)
		label(thrBg, L("thr"), 11, C.dim, true, { Position = UDim2.new(0, -10, 1, 4), Size = UDim2.new(1, 20, 0, 14), TextXAlignment = Enum.TextXAlignment.Center })
		local thrInput: InputObject? = nil
		function ui.setThrottleKnob(v: number)
			thrKnob.Position = UDim2.new(0.5, 0, 1 - v, 15 - v * 30)
		end
		local function setThr(y: number)
			local a = thrBg.AbsolutePosition.Y + 15 * ui.scale
			local b = thrBg.AbsolutePosition.Y + thrBg.AbsoluteSize.Y - 15 * ui.scale
			local v = math.clamp((b - y) / (b - a), 0, 1)
			ui.touch.throttle = v
			ui.setThrottleKnob(v)
		end
		thrBg.InputBegan:Connect(function(i)
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
		local function tbtn(name: string, text: string, size: number, pos: UDim2, colr: Color3, hold: boolean)
			local b = new("TextButton", { Size = UDim2.fromOffset(size, size), Position = pos, BackgroundColor3 = colr, BackgroundTransparency = 0.25, Text = text, TextColor3 = C.bg, Font = Enum.Font.GothamBold, TextSize = 15, AutoButtonColor = false, TextWrapped = true }, touchLayer)
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
		end
		tbtn("gun", L("b_fire"), 120, UDim2.new(1, -220, 1, -170), C.red, true)
		tbtn("missile", L("b_msl"), 82, UDim2.new(1, -320, 1, -250), C.amber, false)
		tbtn("flare", L("b_flare"), 70, UDim2.new(1, -196, 1, -262), C.text, false)
		local small = { { "cam", L("b_cam") }, { "gear", L("b_gear") }, { "brake", L("b_brake") }, { "menu", L("b_menu") } }
		for k, s in small do
			local b = new("TextButton", { Size = UDim2.fromOffset(88, 34), Position = UDim2.new(0, 262 + (k - 1) * 96, 0, 76), BackgroundColor3 = C.bg, BackgroundTransparency = 0.3, Text = s[2], TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 13 }, touchLayer)
			corner(b, 17)
			stroke(b, C.line)
			b.Activated:Connect(function()
				if actionCb then
					actionCb(s[1])
				end
			end)
		end
	end

	-- ============================================================ ОБНОВЛЕНИЕ ПРИБОРОВ
	function ui.setFlying(v: boolean)
		hud.Visible = v
	end
	function ui.hideAll(v: boolean)
		root.Visible = not v
	end
	local hitT = 0
	function ui.hit(kill: boolean)
		hitT = os.clock()
		hitL.Text = if kill then "✖ " .. L("downed") else "✕ " .. L("hit")
		hitL.TextColor3 = if kill then C.green else C.amber
	end
	function ui.update(d: any)
		spdL.Text = tostring(math.round(d.speed))
		altL.Text = fmt(d.alt)
		setBar(thrBar, d.thr)
		;(thrBar:FindFirstChild("Fill") :: Frame).BackgroundColor3 = if d.thr > 0.92 then C.amber else C.accent
		local hpk = math.clamp(d.hp / math.max(d.maxHp, 1), 0, 1)
		setBar(hpBar, hpk)
		;(hpBar:FindFirstChild("Fill") :: Frame).BackgroundColor3 = if hpk > 0.5 then C.green elseif hpk > 0.25 then C.amber else C.red
		hpTxt.Text = string.format("%d / %d", math.ceil(d.hp), d.maxHp)
		ammoL.Text = L("ammo", d.missiles, d.flares) .. (if d.gear then "   " .. L("gear_down") else "")
		hurt.Transparency = if hpk < 0.3 then 0.55 + 0.25 * math.sin(os.clock() * 6) else 1
		local s = ui.scale
		cross.Position = UDim2.fromOffset(d.aim.X / s, d.aim.Y / s)
		if d.lock then
			lockBox.Visible = true
			lockBox.Position = UDim2.fromOffset(d.lock.x / s, d.lock.y / s)
			lockStroke.Color = if d.lock.locked then C.red else C.amber
			lockTxt.TextColor3 = lockStroke.Color
			lockTxt.Text = if d.lock.locked then L("locked") else L("locking", math.floor(d.lock.k * 100))
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
