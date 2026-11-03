--!strict
-- Интерфейс Sky Pilot: верхняя панель, приборы, авиагоризонт, ангар, справка,
-- экран крушения и сенсорное управление (штурвал, РУД, кнопки).
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("SkyPilot")
local PlaneConfigs = require(Shared:WaitForChild("PlaneConfigs"))
local World = require(Shared:WaitForChild("World"))

local C = {
	bg = Color3.fromRGB(7, 13, 24),
	panel = Color3.fromRGB(9, 17, 33),
	panelSolid = Color3.fromRGB(14, 26, 48),
	line = Color3.fromRGB(120, 170, 255),
	fg = Color3.fromRGB(228, 238, 255),
	dim = Color3.fromRGB(142, 163, 196),
	magenta = Color3.fromRGB(255, 79, 216),
	green = Color3.fromRGB(77, 255, 149),
	amber = Color3.fromRGB(255, 191, 60),
	red = Color3.fromRGB(255, 77, 94),
	dark = Color3.fromRGB(26, 2, 22),
}
local FONT = Enum.Font.GothamBold
local FONT_BODY = Enum.Font.Gotham
local FONT_NUM = Enum.Font.RobotoMono

local Ui = {}
Ui.Colors = C

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

local function corner(parent: Instance, r: number)
	new("UICorner", { CornerRadius = UDim.new(0, r) }, parent)
end
local function stroke(parent: Instance, color: Color3?, transp: number?)
	new("UIStroke", { Color = color or C.line, Transparency = transp or 0.78, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, parent)
end
local function glass(parent: Instance, props: { [string]: any }): Frame
	local f = new("Frame", props, parent)
	f.BackgroundColor3 = C.panel
	f.BackgroundTransparency = 0.28
	f.BorderSizePixel = 0
	corner(f, 8)
	stroke(f)
	return f
end
local function button(parent: Instance, text: string, props: { [string]: any }?): TextButton
	local b = new("TextButton", {
		Text = text, Font = FONT, TextSize = 14, TextColor3 = C.fg, AutoButtonColor = true,
		BackgroundColor3 = C.panel, BackgroundTransparency = 0.28, BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, 32), AutomaticSize = Enum.AutomaticSize.X,
	}, parent)
	new("UIPadding", { PaddingLeft = UDim.new(0, 11), PaddingRight = UDim.new(0, 11) }, b)
	corner(b, 8)
	stroke(b)
	if props then
		for k, v in props do
			(b :: any)[k] = v
		end
	end
	return b
end
local function primary(b: TextButton)
	b.BackgroundColor3 = C.magenta
	b.BackgroundTransparency = 0
	b.TextColor3 = C.dark
	local s = b:FindFirstChildOfClass("UIStroke")
	if s then
		s.Transparency = 1
	end
end

export type Callbacks = {
	onPick: (planeId: string, mode: string, destination: string?) -> (),
	onAction: (name: string) -> (),
	onAgain: () -> (),
	onToHangar: () -> (),
	onExit: () -> (),
}

function Ui.new(cb: Callbacks)
	local self: any = {}
	local player = Players.LocalPlayer
	local gui = new("ScreenGui", { Name = "SkyPilotUI", ResetOnSpawn = false, IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 5 }, player:WaitForChild("PlayerGui"))
	self.gui = gui
	local uiScale = new("UIScale", {}, gui)
	local function rescale()
		local cam = workspace.CurrentCamera
		local v = cam and cam.ViewportSize or Vector2.new(1280, 720)
		uiScale.Scale = math.clamp(math.min(v.X / 1100, v.Y / 680), 0.62, 1.25)
	end
	rescale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	local root = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, gui)
	new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, root)

	-- ================= верхняя панель
	local top = new("Frame", { Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 0), BackgroundTransparency = 1 }, root)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center }, top)
	local bHangar = button(top, "✈ Ангар")
	primary(bHangar)
	local bCam = button(top, "Камера: сзади")
	local bMouse = button(top, "Мышь-штурвал: выкл")
	local bAP = button(top, "Автопилот")
	local bNav = button(top, "Навигация")
	local bDebug = button(top, "Отладка")
	local bHelp = button(top, "Клавиши")
	local planeName = new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromOffset(200, 32), Font = FONT, TextSize = 14, TextColor3 = C.fg, TextXAlignment = Enum.TextXAlignment.Left, Text = "", TextStrokeTransparency = 0.6 }, top)
	self.bCam, self.bMouse, self.bAP = bCam, bMouse, bAP

	-- ================= приборы
	local hud = new("Frame", { Size = UDim2.fromOffset(560, 62), Position = UDim2.new(0.5, 0, 0, 44), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Visible = false }, root)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center }, hud)
	local cells: { [string]: any } = {}
	local function cell(id: string, k: string, u: string)
		local f = glass(hud, { Size = UDim2.fromOffset(90, 62), ClipsDescendants = true })
		local fill = new("Frame", { Name = "Fill", BackgroundColor3 = C.magenta, BackgroundTransparency = 0.72, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), Visible = id == "thr" }, f)
		new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 4), Font = FONT, TextSize = 10, TextColor3 = C.dim, Text = string.upper(k) }, f)
		local v = new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 17), Font = FONT_NUM, TextSize = 23, TextColor3 = C.green, Text = "0" }, f)
		local uu = new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, -4, 0, 13), Position = UDim2.fromOffset(2, 44), Font = FONT_NUM, TextSize = 10, TextColor3 = C.dim, Text = u, TextTruncate = Enum.TextTruncate.AtEnd }, f)
		cells[id] = { v = v, u = uu, fill = fill }
	end
	cell("spd", "Скорость", "kt")
	cell("alt", "Высота", "ft")
	cell("vs", "Верт.", "ft/min")
	cell("hdg", "Курс", "°")
	cell("thr", "Тяга", "%")
	cell("flaps", "Закрылки", "шасси ▼")

	-- авиагоризонт
	local adi = new("CanvasGroup", { Size = UDim2.fromOffset(96, 96), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -2, 0, 116), BackgroundColor3 = C.panel, Visible = false, GroupTransparency = 0 }, root)
	corner(adi, 48)
	stroke(adi, C.line, 0.5)
	local horizon = new("Frame", { Size = UDim2.fromOffset(400, 400), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1 }, adi)
	new("Frame", { Size = UDim2.new(1, 0, 0.5, 0), BackgroundColor3 = Color3.fromRGB(47, 111, 191), BorderSizePixel = 0 }, horizon)
	new("Frame", { Size = UDim2.new(1, 0, 0.5, 0), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = Color3.fromRGB(122, 82, 50), BorderSizePixel = 0 }, horizon)
	new("Frame", { Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 0.5, -1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, horizon)
	local PPD = 96 / 60
	for _, d in { -20, -10, 10, 20 } do
		local w = if math.abs(d) == 10 then 36 else 60
		new("Frame", { Size = UDim2.fromOffset(w, 2), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -d * PPD), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, horizon)
	end
	for _, x in { -27, 27 } do
		new("Frame", { Size = UDim2.fromOffset(30, 4), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, x, 0.5, 0), BackgroundColor3 = C.amber, BorderSizePixel = 0, ZIndex = 3 }, adi)
	end
	new("Frame", { Size = UDim2.fromOffset(8, 8), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = C.amber, BorderSizePixel = 0, ZIndex = 3 }, adi)

	-- гонка через кольца: таймер
	-- погода и время: время суток по Lighting, температура за бортом по стандартной атмосфере
	local wx = glass(root, { Size = UDim2.fromOffset(176, 50), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -2, 0, 278), Visible = false })
	local wxTop = new("TextLabel", { Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(10, 4), BackgroundTransparency = 1, Font = FONT, TextSize = 14, TextColor3 = C.fg, TextXAlignment = Enum.TextXAlignment.Left, Text = "" }, wx)
	local wxBot = new("TextLabel", { Size = UDim2.new(1, -16, 0, 18), Position = UDim2.fromOffset(10, 26), BackgroundTransparency = 1, Font = FONT_NUM, TextSize = 12, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, Text = "" }, wx)
	function self.setWeather(altFt: number)
		wx.Visible = hud.Visible
		local t = game:GetService("Lighting").ClockTime
		local phase, icon
		if t >= 5 and t < 10 then
			phase, icon = "Утро", "◐"
		elseif t >= 10 and t < 14 then
			phase, icon = "Полдень", "☀"
		elseif t >= 14 and t < 18 then
			phase, icon = "День", "☀"
		elseif t >= 18 and t < 21 then
			phase, icon = "Вечер", "◑"
		else
			phase, icon = "Ночь", "☾"
		end
		wxTop.Text = string.format("%s  %s · %02d:%02d", icon, phase, math.floor(t), math.floor((t % 1) * 60))
		local temp = math.max(-56.5, 15 - 1.98 * altFt / 1000)
		wxBot.Text = string.format("за бортом %+d °C · ясно", math.round(temp))
	end

	local raceTag = new("TextLabel", { Size = UDim2.fromOffset(170, 24), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -2, 0, 246), BackgroundColor3 = C.magenta, Font = FONT_NUM, TextSize = 13, TextColor3 = C.dark, Text = "", Visible = false }, root)
	corner(raceTag, 6)
	self.root = root

	-- автопилот-индикатор
	local apTag = new("TextLabel", { Size = UDim2.fromOffset(96, 22), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -2, 0, 218), BackgroundColor3 = C.green, Font = FONT, TextSize = 13, TextColor3 = C.dark, Text = "АВТОПИЛОТ", Visible = false }, root)
	corner(apTag, 6)

	-- шкала курса: лента с делениями, текущий курс в центре
	local TAPE_W, PPD_T = 440, 4
	local tape = glass(root, { Size = UDim2.fromOffset(TAPE_W, 34), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 112), ClipsDescendants = true, Visible = false })
	local tapeMarks: { { label: TextLabel, tick: Frame } } = {}
	for _ = 1, 15 do
		local tk = new("Frame", { Size = UDim2.fromOffset(2, 7), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = C.dim, BorderSizePixel = 0 }, tape)
		local lb = new("TextLabel", { Size = UDim2.fromOffset(40, 20), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(0, 10), BackgroundTransparency = 1, Font = FONT_NUM, TextSize = 14, TextColor3 = C.dim, Text = "" }, tape)
		table.insert(tapeMarks, { label = lb, tick = tk })
	end
	local tapeNow = new("TextLabel", { Size = UDim2.fromOffset(58, 30), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2), BackgroundColor3 = C.panelSolid, Font = FONT_NUM, TextSize = 20, TextColor3 = C.fg, Text = "000", ZIndex = 3 }, tape)
	corner(tapeNow, 6)
	new("Frame", { Size = UDim2.fromOffset(26, 3), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), BackgroundColor3 = C.magenta, BorderSizePixel = 0, ZIndex = 4 }, tape)
	function self.setHeading(hdg: number)
		tape.Visible = hud.Visible
		tapeNow.Text = string.format("%03d", math.round(hdg) % 360)
		local base = math.floor(hdg / 10) * 10
		for i, m in tapeMarks do
			local h = base + (i - 8) * 10
			local x = TAPE_W / 2 + (h - hdg) * PPD_T
			m.tick.Position = UDim2.fromOffset(x, 0)
			m.label.Position = UDim2.fromOffset(x, 11)
			m.label.Text = string.format("%03d", h % 360)
			m.label.Visible = math.abs(h - hdg) > 9
		end
	end

	-- навигация: стрелка на цель + расстояние и курс
	local nav = glass(root, { Size = UDim2.fromOffset(300, 30), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 150), Visible = false })
	local navArrow = new("TextLabel", { Size = UDim2.fromOffset(30, 30), BackgroundTransparency = 1, Font = FONT, TextSize = 22, TextColor3 = C.magenta, Text = "↑" }, nav)
	local navText = new("TextLabel", { Size = UDim2.new(1, -36, 1, 0), Position = UDim2.fromOffset(32, 0), BackgroundTransparency = 1, Font = FONT_NUM, TextSize = 13, TextColor3 = C.fg, TextXAlignment = Enum.TextXAlignment.Left, Text = "" }, nav)

	local banner = new("TextButton", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -200), Size = UDim2.fromOffset(0, 46), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Color3.fromRGB(120, 20, 30), BackgroundTransparency = 0.15, Font = FONT, TextSize = 16, TextColor3 = C.fg, Text = "", Visible = false, AutoButtonColor = true, RichText = true }, root)
	corner(banner, 23)
	stroke(banner, C.red, 0.2)
	new("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18) }, banner)
	banner.Activated:Connect(function()
		cb.onAction("park")
	end)
	function self.setBanner(text: string?)
		banner.Visible = text ~= nil and hud.Visible
		if text then
			banner.Text = text
		end
	end

	local warn = new("TextLabel", { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromScale(0, 0.32), BackgroundTransparency = 1, Font = FONT, TextSize = 32, TextColor3 = C.red, Text = "", TextStrokeTransparency = 0.4 }, root)
	local toastF = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 188), Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = C.panelSolid, BackgroundTransparency = 0.05, Font = FONT, TextSize = 15, TextColor3 = C.fg, Text = "", Visible = false }, root)
	corner(toastF, 8)
	stroke(toastF)
	new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, toastF)

	local debug = glass(root, { Size = UDim2.fromOffset(330, 250), Position = UDim2.fromOffset(0, 276), Visible = false })
	local debugText = new("TextLabel", { Size = UDim2.new(1, -16, 1, -12), Position = UDim2.fromOffset(8, 6), BackgroundTransparency = 1, Font = FONT_NUM, TextSize = 12, TextColor3 = C.fg, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = "", RichText = true }, debug)

	-- ================= сенсорное управление
	local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local touch = { x = 0, y = 0, rl = 0, rr = 0, brake = false, throttle = nil :: number?, active = isTouch }
	self.touch = touch
	local touchF = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, root)
	local stick = glass(touchF, { Size = UDim2.fromOffset(140, 140), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 6, 1, -48) })
	corner(stick, 70)
	new("Frame", { Size = UDim2.new(0, 1, 0.8, 0), Position = UDim2.fromScale(0.5, 0.1), BackgroundColor3 = C.line, BackgroundTransparency = 0.7, BorderSizePixel = 0 }, stick)
	new("Frame", { Size = UDim2.new(0.8, 0, 0, 1), Position = UDim2.fromScale(0.1, 0.5), BackgroundColor3 = C.line, BackgroundTransparency = 0.7, BorderSizePixel = 0 }, stick)
	local knob = new("Frame", { Size = UDim2.fromOffset(54, 54), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = C.magenta, BorderSizePixel = 0 }, stick)
	corner(knob, 27)
	local rudderRow = new("Frame", { Size = UDim2.fromOffset(140, 38), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 6, 1, -4), BackgroundTransparency = 1 }, touchF)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }, rudderRow)

	local function holdBtn(parent: Instance, text: string, size: Vector2, on: () -> (), off: () -> ()): TextButton
		local b = button(parent, text, { AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.fromOffset(size.X, size.Y), TextSize = 12, Font = FONT_NUM })
		b.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
				b.BackgroundColor3 = C.magenta
				on()
			end
		end)
		b.InputEnded:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
				b.BackgroundColor3 = C.panel
				off()
			end
		end)
		return b
	end
	holdBtn(rudderRow, "◀ РУЛЬ", Vector2.new(67, 38), function() touch.rl = 1 end, function() touch.rl = 0 end)
	holdBtn(rudderRow, "РУЛЬ ▶", Vector2.new(67, 38), function() touch.rr = 1 end, function() touch.rr = 0 end)

	local btns = new("Frame", { Size = UDim2.fromOffset(140, 140), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -76, 1, -4), BackgroundTransparency = 1 }, touchF)
	new("UIGridLayout", { CellSize = UDim2.fromOffset(66, 40), CellPadding = UDim2.fromOffset(6, 6) }, btns)
	local function tapBtn(text: string, action: string)
		local b = button(btns, text, { AutomaticSize = Enum.AutomaticSize.None, TextSize = 12, Font = FONT_NUM })
		b.Activated:Connect(function()
			cb.onAction(action)
		end)
	end
	tapBtn("ШАССИ", "gear")
	holdBtn(btns, "ТОРМОЗ", Vector2.new(66, 40), function() touch.brake = true end, function() touch.brake = false end)
	tapBtn("ЗАКР −", "flapUp")
	tapBtn("ЗАКР +", "flapDn")
	tapBtn("РЕВЕРС", "rev")
	tapBtn("МАЛ.ГАЗ", "idle")

	local thrWrap = new("Frame", { Size = UDim2.fromOffset(60, 190), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -6, 1, -4), BackgroundTransparency = 1 }, touchF)
	new("TextLabel", { Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Font = FONT, TextSize = 10, TextColor3 = C.dim, Text = "ТЯГА" }, thrWrap)
	local thr = glass(thrWrap, { Size = UDim2.new(1, 0, 1, -18), Position = UDim2.fromOffset(0, 18), ClipsDescendants = true })
	local thrLevel = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), BackgroundColor3 = C.magenta, BackgroundTransparency = 0.5, BorderSizePixel = 0 }, thr)
	local thrHandle = new("Frame", { AnchorPoint = Vector2.new(0, 1), Size = UDim2.new(1, -8, 0, 14), Position = UDim2.new(0, 4, 1, 0), BackgroundColor3 = C.magenta, BorderSizePixel = 0 }, thr)
	corner(thrHandle, 4)
	local function setThrottleUI(v: number)
		thrLevel.Size = UDim2.fromScale(1, v)
		thrHandle.Position = UDim2.new(0, 4, 1 - v, v * 14)
	end
	self.setThrottleUI = setThrottleUI

	-- перетаскивание: штурвал и РУД
	local stickInput: InputObject? = nil
	local thrInput: InputObject? = nil
	local function isPress(i: InputObject): boolean
		return i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1
	end
	local function moveStick(pos: Vector3)
		local c = stick.AbsolutePosition + stick.AbsoluteSize / 2
		local rad = stick.AbsoluteSize.X / 2 - 10
		local d = Vector2.new(pos.X, pos.Y) - c
		if d.Magnitude > rad then
			d = d.Unit * rad
		end
		touch.x, touch.y = d.X / rad, d.Y / rad
		knob.Position = UDim2.new(0.5, d.X / uiScale.Scale, 0.5, d.Y / uiScale.Scale)
	end
	local function moveThr(pos: Vector3)
		local v = math.clamp(1 - (pos.Y - thr.AbsolutePosition.Y) / thr.AbsoluteSize.Y, 0, 1)
		touch.throttle = v
		setThrottleUI(v)
	end
	stick.InputBegan:Connect(function(i)
		if isPress(i) then
			stickInput = i
			moveStick(i.Position)
		end
	end)
	thr.InputBegan:Connect(function(i)
		if isPress(i) then
			thrInput = i
			moveThr(i.Position)
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		local mouseMove = i.UserInputType == Enum.UserInputType.MouseMovement
		if stickInput and (i == stickInput or (mouseMove and stickInput.UserInputType == Enum.UserInputType.MouseButton1)) then
			moveStick(i.Position)
		end
		if thrInput and (i == thrInput or (mouseMove and thrInput.UserInputType == Enum.UserInputType.MouseButton1)) then
			moveThr(i.Position)
		end
	end)
	UserInputService.InputEnded:Connect(function(i)
		if stickInput and (i == stickInput or (i.UserInputType == Enum.UserInputType.MouseButton1 and stickInput.UserInputType == i.UserInputType)) then
			stickInput = nil
			touch.x, touch.y = 0, 0
			knob.Position = UDim2.fromScale(0.5, 0.5)
		end
		if thrInput and (i == thrInput or (i.UserInputType == Enum.UserInputType.MouseButton1 and thrInput.UserInputType == i.UserInputType)) then
			thrInput = nil
		end
	end)
	function self.isTouchingControls(): boolean
		return stickInput ~= nil or thrInput ~= nil
	end

	-- ================= оверлеи
	local function overlay(name: string, w: number): (Frame, Frame)
		local o = new("Frame", { Name = name, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(4, 8, 16), BackgroundTransparency = 0.55, Visible = false, ZIndex = 20, Active = true }, gui)
		local sheet = new("Frame", { Size = UDim2.fromOffset(w, 0), AutomaticSize = Enum.AutomaticSize.Y, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = C.panelSolid, BackgroundTransparency = 0.08, ZIndex = 21 }, o)
		corner(sheet, 14)
		stroke(sheet)
		new("UIPadding", { PaddingTop = UDim.new(0, 16), PaddingBottom = UDim.new(0, 16), PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18) }, sheet)
		new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, sheet)
		new("UISizeConstraint", { MaxSize = Vector2.new(w, 640) }, sheet)
		return o, sheet
	end
	local function h2(parent: Instance, text: string, color: Color3?, order: number): TextLabel
		return new("TextLabel", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, Font = FONT, TextSize = 21, TextColor3 = color or C.fg, TextXAlignment = Enum.TextXAlignment.Left, Text = text, LayoutOrder = order, ZIndex = 22 }, parent)
	end
	local function para(parent: Instance, text: string, order: number): TextLabel
		return new("TextLabel", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Font = FONT_BODY, TextSize = 14, TextColor3 = C.dim, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Text = text, LayoutOrder = order, ZIndex = 22 }, parent)
	end

	-- ангар: главное меню → самолёт → аэропорт вылета → (рейс) аэропорт назначения
	local hangar, hs = overlay("Hangar", 800)
	local title = h2(hs, "Sky Pilot", nil, 1)
	local scoreLine = para(hs, "", 2)
	local pages = new("Frame", { Size = UDim2.new(1, 0, 0, 380), BackgroundTransparency = 1, LayoutOrder = 3, ZIndex = 22, ClipsDescendants = true }, hs)
	local navRow = new("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, LayoutOrder = 4, ZIndex = 22 }, hs)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder }, navRow)
	local bClose = button(navRow, "Закрыть", { ZIndex = 23, LayoutOrder = 0 })
	bClose.Activated:Connect(function()
		hangar.Visible = false
	end)
	local bExit = button(navRow, "Выйти из самолёта", { ZIndex = 23, Visible = false, LayoutOrder = 1 })
	local bBack = button(navRow, "Назад", { ZIndex = 23, LayoutOrder = 2 })
	local bNext = button(navRow, "Далее →", { ZIndex = 23, LayoutOrder = 3 })
	bNext.BackgroundColor3 = Color3.fromRGB(46, 160, 80)
	bNext.BackgroundTransparency = 0
	self.bExit = bExit

	local function page(name: string): ScrollingFrame
		local pg = new("ScrollingFrame", { Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, ZIndex = 22 }, pages)
		new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, pg)
		new("UIPadding", { PaddingRight = UDim.new(0, 8) }, pg)
		return pg
	end
	local function section(parent: Instance, text: string, order: number)
		new("TextLabel", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 20, TextColor3 = C.fg, TextXAlignment = Enum.TextXAlignment.Left, Text = text, LayoutOrder = order, ZIndex = 23 }, parent)
	end
	local function grid(parent: Instance, order: number, cell: UDim2): Frame
		local g = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 22 }, parent)
		new("UIGridLayout", { CellSize = cell, CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }, g)
		return g
	end
	-- фото-фон карточки (если ID загружен) с затемнением снизу
	local function photoBg(parent: Instance, key: string): boolean
		local id = (PlaneConfigs :: any).PHOTOS and (PlaneConfigs :: any).PHOTOS[key]
		if type(id) ~= "string" or id == "" then
			return false
		end
		new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = id, ScaleType = Enum.ScaleType.Crop, ZIndex = 23 }, parent)
		local shade = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(4, 8, 16), BorderSizePixel = 0, ZIndex = 23 }, parent)
		new("UIGradient", { Rotation = -90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.6, 0.85), NumberSequenceKeypoint.new(1, 1) }) }, shade)
		return true
	end
	local selectables: { [string]: { TextButton } } = {}
	local function selectCard(group: string, card: TextButton)
		for _, c in selectables[group] or {} do
			local on = c == card
			c.BackgroundColor3 = if on then Color3.fromRGB(235, 240, 250) else Color3.fromRGB(22, 34, 58)
			local st = c:FindFirstChildOfClass("UIStroke")
			if st then
				st.Thickness = if on then 3 else 1
				st.Color = if on then Color3.new(1, 1, 1) else C.line
				st.Transparency = if on then 0 else 0.78
			end
			for _, t in c:GetDescendants() do
				if t:IsA("TextLabel") and t:GetAttribute("Role") then
					t.TextColor3 = if on then C.dark elseif t:GetAttribute("Role") == "title" then C.fg else C.dim
				end
			end
		end
	end
	local function card(parent: Instance, group: string, order: number): TextButton
		local c = new("TextButton", { Text = "", AutoButtonColor = true, BackgroundColor3 = Color3.fromRGB(22, 34, 58), BorderSizePixel = 0, LayoutOrder = order, ZIndex = 23, ClipsDescendants = true }, parent)
		corner(c, 14)
		stroke(c)
		selectables[group] = selectables[group] or {}
		table.insert(selectables[group], c)
		return c
	end

	-- состояние мастера
	local flow = { mode = "free", plane = nil :: string?, from = "A", to = nil :: string? }
	local step = "menu"
	local pg: { [string]: ScrollingFrame } = {}

	-- 1. меню режимов
	pg.menu = page("Menu")
	local modes = grid(pg.menu, 1, UDim2.new(1 / 3, -7, 0, 200))
	for i, m in {
		{ "free", "Свободный полёт", "Любой самолёт, любой аэропорт. Посадки дают очки.", "✈" },
		{ "career", "Рейс", "Вылет из одного аэропорта, посадка в другом: +1000 за выполненный рейс.", "⇄" },
		{ "race", "Гонка колец", "13 колец: Дубай → Ташкент → Лондон и под Тауэрским мостом. +1500.", "◎" },
	} do
		local c = card(modes, "mode", i)
		photoBg(c, "mode_" .. m[1])
		new("TextLabel", { Size = UDim2.new(1, -24, 0, 60), Position = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, Font = FONT, TextSize = 44, TextColor3 = C.magenta, TextXAlignment = Enum.TextXAlignment.Right, Text = m[4], ZIndex = 24 }, c)
		new("TextLabel", { Size = UDim2.new(1, -24, 0, 30), Position = UDim2.new(0, 12, 1, -100), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 22, TextColor3 = C.fg, TextXAlignment = Enum.TextXAlignment.Left, Text = m[2], ZIndex = 24 }, c):SetAttribute("Role", "title")
		new("TextLabel", { Size = UDim2.new(1, -24, 0, 54), Position = UDim2.new(0, 12, 1, -64), BackgroundTransparency = 1, Font = FONT_BODY, TextSize = 13, TextColor3 = C.dim, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = m[3], ZIndex = 24 }, c):SetAttribute("Role", "text")
		c.Activated:Connect(function()
			flow.mode = m[1]
			selectCard("mode", c)
		end)
		if i == 1 then
			selectCard("mode", c)
		end
	end

	-- 2. ангар: категории и 3D-превью
	pg.planes = page("Planes")
	local PlaneBuilder = require(Shared:WaitForChild("PlaneBuilder"))
	local cats = {
		{ "ЛЁГКИЕ И БИЗНЕС-ДЖЕТЫ", { "C172", "LEAR75", "G650", "GL7500" } },
		{ "УЗКОФЮЗЕЛЯЖНЫЕ", { "B737", "A220", "A320" } },
		{ "ШИРОКОФЮЗЕЛЯЖНЫЕ", { "B787", "A330", "A350", "B777", "B747", "A380" } },
		{ "ВОЕННЫЕ", { "F16" } },
	}
	local order = 0
	for _, cat in cats do
		order += 1
		section(pg.planes, cat[1], order)
		order += 1
		local g = grid(pg.planes, order, UDim2.new(1 / 3, -7, 0, 150))
		for i, id in cat[2] do
			local c = PlaneConfigs.PLANES[id]
			if c then
				local cd = card(g, "plane", i)
				local hasPhoto = photoBg(cd, "plane_" .. id)
				local vp = new("ViewportFrame", { Size = UDim2.new(1, 0, 1, -40), BackgroundTransparency = 1, Ambient = Color3.fromRGB(170, 175, 190), LightColor = Color3.fromRGB(255, 250, 240), LightDirection = Vector3.new(-0.4, -1, -0.3), ZIndex = 24 }, cd)
				local m = PlaneBuilder.build(c, { static = true })
				m.Parent = vp
				local camV = Instance.new("Camera")
				camV.FieldOfView = 32
				local dist = math.max(c.span, c.length) * 1.55
				camV.CFrame = CFrame.lookAt(Vector3.new(-0.78, 0.36, -0.62).Unit * dist, Vector3.new(0, -c.diameter * 0.2, 0))
				camV.Parent = vp
				vp.CurrentCamera = camV
				vp.Visible = not hasPhoto
				new("TextLabel", { Size = UDim2.new(1, -20, 0, 20), Position = UDim2.new(0, 10, 1, -40), BackgroundTransparency = 1, Font = FONT, TextSize = 16, TextColor3 = C.fg, TextXAlignment = Enum.TextXAlignment.Left, Text = c.name, ZIndex = 25 }, cd):SetAttribute("Role", "title")
				new("TextLabel", { Size = UDim2.new(1, -20, 0, 16), Position = UDim2.new(0, 10, 1, -20), BackgroundTransparency = 1, Font = FONT_NUM, TextSize = 11, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = string.format("%s · %d kt", c.cls, c.maxKts), ZIndex = 25 }, cd):SetAttribute("Role", "text")
				cd.Activated:Connect(function()
					flow.plane = id
					selectCard("plane", cd)
				end)
			end
		end
	end

	-- 3–4. аэропорты (вылет / назначение)
	local function airportPage(name: string, group: string, onSelect: (string) -> ()): ScrollingFrame
		local p = page(name)
		local regions: { [string]: Frame } = {}
		local n = 0
		for _, ap in World.AIRPORTS do
			local g = regions[ap.region]
			if not g then
				n += 1
				section(p, ap.region, n)
				n += 1
				g = grid(p, n, UDim2.new(1, -4, 0, 84))
				regions[ap.region] = g
			end
			local cd = card(g, group, 1)
			cd:SetAttribute("Airport", ap.id)
			new("TextLabel", { Size = UDim2.new(1, -24, 0, 36), Position = UDim2.fromOffset(16, 8), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 30, TextColor3 = C.fg, TextXAlignment = Enum.TextXAlignment.Left, Text = ap.code .. " · " .. ap.id, ZIndex = 24 }, cd):SetAttribute("Role", "title")
			new("TextLabel", { Size = UDim2.new(1, -24, 0, 18), Position = UDim2.fromOffset(16, 44), BackgroundTransparency = 1, Font = FONT_BODY, TextSize = 14, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, Text = ap.title .. string.format(" · полоса %s/%s · %d м", ap.south, ap.north, math.round(ap.L * World.METERS_PER_STUD)), ZIndex = 24 }, cd):SetAttribute("Role", "text")
			cd.Activated:Connect(function()
				onSelect(ap.id)
				selectCard(group, cd)
			end)
		end
		return p
	end
	pg.from = airportPage("From", "from", function(id)
		flow.from = id
	end)
	pg.to = airportPage("To", "to", function(id)
		flow.to = id
	end)

	local titles = { menu = "Sky Pilot · режим", planes = "Ангар · выберите самолёт", from = "Аэропорт вылета", to = "Аэропорт назначения" }
	local function show(st: string)
		step = st
		for k, v in pg do
			v.Visible = k == st
		end
		title.Text = titles[st]
		bBack.Visible = st ~= "menu"
		bNext.Text = if (st == "to") or (st == "from" and flow.mode ~= "career") or (st == "planes" and flow.mode == "race") then "Полёт ✈" else "Далее →"
		-- в рейсе нельзя выбрать аэропорт назначения, совпадающий с аэропортом вылета
		if st == "to" then
			for _, c in selectables.to or {} do
				c.Visible = c:GetAttribute("Airport") ~= flow.from
			end
		end
	end
	local function selectAirportCard(group: string, id: string)
		for _, c in selectables[group] or {} do
			if c:GetAttribute("Airport") == id then
				selectCard(group, c)
			end
		end
	end
	selectAirportCard("from", "A")
	local function launch()
		hangar.Visible = false
		local mode = if flow.mode == "race" then "race" else "runway:" .. flow.from
		cb.onPick(flow.plane :: string, mode, if flow.mode == "career" then flow.to else nil)
	end
	bNext.Activated:Connect(function()
		if step == "menu" then
			show("planes")
		elseif step == "planes" then
			if not flow.plane then
				self.toast("Выберите самолёт", "amber")
			elseif flow.mode == "race" then
				launch()
			else
				show("from")
			end
		elseif step == "from" then
			if flow.mode == "career" then
				if flow.to == flow.from then
					flow.to = nil
				end
				show("to")
			else
				launch()
			end
		elseif step == "to" then
			if not flow.to then
				self.toast("Выберите аэропорт назначения", "amber")
			else
				launch()
			end
		end
	end)
	bBack.Activated:Connect(function()
		show(if step == "to" then "from" elseif step == "from" then "planes" else "menu")
	end)
	bExit.Activated:Connect(function()
		hangar.Visible = false
		cb.onExit()
	end)
	show("menu")
	self.showStep = show

	-- справка
	local help, hp = overlay("Help", 640)
	h2(hp, "Управление", nil, 1)
	para(hp, table.concat({
		"W / S — нос вниз / вверх      A / D — крен (на земле руление)",
		"Q / E — руль направления      Shift / Ctrl — тяга + / −,  Z — малый газ",
		"F / R — закрылки выпустить / убрать      G — шасси      B — тормоз (держать)",
		"T — реверс на земле      P — автопилот (держит курс, высоту, скорость)      Пробел — стояночный тормоз",
		"V — камера (сзади / кабина / орбита)      M — ангар      C — мышь-штурвал",
		"N — навигация: стрелка на аэропорт или город; с выбранной целью автопилот (P) летит к ней сам",
		"Гонка: пролети сквозь розовое кольцо у Skyport — маршрут Дубай → Ташкент → Лондон → домой, 13 колец, +1500 очков",
		"",
		"Геймпад: левый стик — штурвал, R2/L2 — тяга, R1/L1 — руль, Y — шасси,",
		"крестовина ↑/↓ — закрылки, → — навигация, X — реверс, B — тормоз, A — автопилот, Select — камера.",
		"",
		"Телефон: левый круг — штурвал (тяни вниз = нос вверх), справа — рычаг тяги.",
		"Орбита: крути вид пальцем или правой кнопкой мыши, колесо — зум.",
		"",
		"Взлёт: тяга 100%, на скорости Vr плавно тяни на себя. Посадка: шасси вниз,",
		"закрылки 2–3, вертикальная < 600 ft/min. Перелёт A → B даёт +500 очков.",
	}, "\n"), 2)
	local hb = new("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = 3, ZIndex = 22 }, hp)
	local helpClose = button(hb, "Понятно", { ZIndex = 23 })
	primary(helpClose)
	helpClose.Activated:Connect(function()
		help.Visible = false
	end)

	-- крушение
	local crash, cs = overlay("Crash", 440)
	h2(cs, "Крушение", C.red, 1)
	local crashReason = para(cs, "", 2)
	local cr = new("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = 3, ZIndex = 22 }, cs)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }, cr)
	local again = button(cr, "Снова", { ZIndex = 23 })
	primary(again)
	local toH = button(cr, "В ангар", { ZIndex = 23 })
	again.Activated:Connect(function()
		crash.Visible = false
		cb.onAgain()
	end)
	toH.Activated:Connect(function()
		crash.Visible = false
		cb.onToHangar()
	end)

	-- ================= кнопки панели
	bHangar.Activated:Connect(function()
		cb.onAction("hangar")
	end)
	bCam.Activated:Connect(function()
		cb.onAction("cam")
	end)
	bMouse.Activated:Connect(function()
		cb.onAction("mouse")
	end)
	bAP.Activated:Connect(function()
		cb.onAction("autopilot")
	end)
	bNav.Activated:Connect(function()
		cb.onAction("nav")
	end)
	bHelp.Activated:Connect(function()
		help.Visible = true
	end)
	bDebug.Activated:Connect(function()
		debug.Visible = not debug.Visible
		bDebug.TextColor3 = if debug.Visible then C.green else C.fg
	end)

	-- ================= API
	local toastT = 0
	function self.toast(text: string, color: string?)
		toastF.Text = text
		toastF.TextColor3 = (color and (C :: any)[color]) or C.fg
		toastF.Visible = true
		toastT = 3
	end
	function self.tick(dt: number)
		if toastT > 0 then
			toastT -= dt
			if toastT <= 0 then
				toastF.Visible = false
			end
		end
	end
	function self.setFlying(on: boolean, name: string?)
		hud.Visible = on
		adi.Visible = on
		touchF.Visible = on and touch.active
		planeName.Text = if on and name then string.upper(name) else ""
		self.bExit.Visible = on
		if not on then
			warn.Text = ""
			apTag.Visible = false
			nav.Visible = false
			tape.Visible = false
			wx.Visible = false
			raceTag.Visible = false
			banner.Visible = false
		end
	end
	function self.showHangar(on: boolean?)
		if on == nil then
			on = not hangar.Visible
		end
		local d = player:FindFirstChild("leaderstats")
		local sc = d and d:FindFirstChild("Очки") :: IntValue?
		local ld = d and d:FindFirstChild("Посадки") :: IntValue?
		local best = player:GetAttribute("BestFpm")
		scoreLine.Text = string.format("Ваши очки: %d · посадок: %d · лучшее касание: %s. Та же физика, что в тестовом полигоне: посадки, сваливание, крушения.",
			sc and sc.Value or 0, ld and ld.Value or 0, if type(best) == "number" and best > 0 then tostring(best) .. " fpm" else "—")
		if on then
			show("menu")
		end
		hangar.Visible = on :: boolean
	end
	function self.hangarVisible(): boolean
		return hangar.Visible
	end
	function self.showCrash(reason: string)
		crashReason.Text = reason
		crash.Visible = true
	end
	function self.hideCrash()
		crash.Visible = false
	end
	function self.setMouseLabel(on: boolean)
		bMouse.Text = "Мышь-штурвал: " .. (if on then "вкл" else "выкл")
		bMouse.TextColor3 = if on then C.green else C.fg
	end
	function self.setCamLabel(name: string)
		bCam.Text = "Камера: " .. name
	end
	function self.setRace(text: string?)
		raceTag.Visible = text ~= nil and hud.Visible
		if text then
			raceTag.Text = text
		end
	end
	function self.setNav(text: string?, relDeg: number?)
		nav.Visible = text ~= nil and hud.Visible
		if text then
			navText.Text = text
			navArrow.Rotation = relDeg or 0
		end
	end
	function self.setAutopilot(on: boolean)
		apTag.Visible = on
		bAP.TextColor3 = if on then C.green else C.fg
	end
	function self.setWarn(text: string, color: Color3?)
		warn.Text = text
		warn.TextColor3 = color or C.red
	end
	function self.debugVisible(): boolean
		return debug.Visible
	end
	function self.setDebug(text: string)
		debugText.Text = text
	end
	function self.setAdi(pitchDeg: number, bankDeg: number)
		local th = math.rad(-bankDeg)
		local t = math.clamp(pitchDeg, -60, 60) * PPD
		horizon.Rotation = -bankDeg
		horizon.Position = UDim2.new(0.5, -math.sin(th) * t, 0.5, math.cos(th) * t)
	end
	function self.setCells(v: { [string]: { string } })
		for id, data in v do
			local c = cells[id]
			if c then
				c.v.Text = data[1]
				if data[2] then
					c.u.Text = data[2]
				end
				if data[3] then
					c.v.TextColor3 = (C :: any)[data[3]] or C.green
				end
				if data[4] then
					c.u.TextColor3 = (C :: any)[data[4]] or C.dim
				end
			end
		end
	end
	function self.setThrottleFill(v: number)
		cells.thr.fill.Size = UDim2.fromScale(1, v)
		setThrottleUI(v)
	end
	return self
end

return Ui
