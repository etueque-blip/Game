--!strict
-- Локальная анимация всех самолётов (своих, чужих и ИИ): винт, огни, шасси, закрылки,
-- инверсионный след, форсаж. Состояние приходит атрибутами модели от сервера,
-- а для своего самолёта — прямо из локальной физики (без задержки сети).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("SkyPilot")
local PlaneBuilder = require(Shared:WaitForChild("PlaneBuilder"))
local World = require(Shared:WaitForChild("World"))

local Animator = {}

type Cache = {
	lights: { BasePart }, trails: { Trail }, prop: Weld?, propBase: CFrame?, disc: BasePart?, ab: BasePart?,
	angle: number, gear: boolean?, flaps: number?,
}
local caches: { [Model]: Cache } = {}
local localModel: Model? = nil
local localState: { gear: boolean, flaps: number, throttle: number } = { gear = true, flaps = 0, throttle = 0 }

function Animator.setLocal(model: Model?, gear: boolean?, flaps: number?, throttle: number?)
	localModel = model
	if gear ~= nil then
		localState.gear = gear
	end
	if flaps ~= nil then
		localState.flaps = flaps
	end
	if throttle ~= nil then
		localState.throttle = throttle
	end
end

local function cacheFor(m: Model): Cache
	local c = caches[m]
	if c then
		return c
	end
	local lights, trails = {}, {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("LightKind") then
			table.insert(lights, d)
		elseif d:IsA("Trail") then
			table.insert(trails, d)
		end
	end
	local engines = m:FindFirstChild("Engines")
	local propPart = engines and engines:FindFirstChild("Prop")
	local prop = propPart and propPart:FindFirstChild("PropWeld") :: Weld?
	c = {
		lights = lights, trails = trails, prop = prop,
		propBase = prop and prop:GetAttribute("Base") :: CFrame?,
		disc = engines and engines:FindFirstChild("PropDisc") :: BasePart?,
		ab = engines and engines:FindFirstChild("Afterburner") :: BasePart?,
		angle = 0, gear = nil, flaps = nil,
	}
	caches[m] = c
	m.Destroying:Connect(function()
		caches[m] = nil
	end)
	return c
end

function Animator.step(dt: number, now: number)
	local folder = workspace:FindFirstChild("Planes")
	if not folder then
		return
	end
	for _, m in folder:GetChildren() do
		if not m:IsA("Model") or m.Name == "Wreck" then
			continue
		end
		local root = m.PrimaryPart
		if not root then
			continue
		end
		local c = cacheFor(m)
		local gear, flaps, thr
		if m == localModel then
			gear, flaps, thr = localState.gear, localState.flaps, localState.throttle
		else
			gear = m:GetAttribute("Gear") ~= false
			flaps = (m:GetAttribute("Flaps") or 0) :: number
			thr = (m:GetAttribute("Throttle") or 0) :: number
		end
		if c.gear ~= gear then
			c.gear = gear
			PlaneBuilder.setGearVisible(m, gear)
		end
		if c.flaps ~= flaps then
			c.flaps = flaps
			PlaneBuilder.setFlaps(m, flaps)
		end
		-- винт
		if c.prop and c.propBase then
			c.angle = (c.angle + dt * (8 + thr * 70)) % (math.pi * 2)
			c.prop.C0 = c.propBase * CFrame.Angles(0, 0, c.angle)
			if c.disc then
				c.disc.Transparency = 1 - math.min(0.18, thr * 0.25)
			end
		end
		if c.ab then
			c.ab.Transparency = if thr > 0.92 then 0.15 + math.random() * 0.2 else 1
		end
		-- огни: навигация горит, строб / маяк мигают
		for _, l in c.lights do
			local kind = l:GetAttribute("LightKind")
			local on = true
			if kind == "strobe" then
				on = (now % 1.2) < 0.06 or ((now - 0.15) % 1.2) < 0.05
			elseif kind == "beacon" then
				on = (now % 1.0) < 0.12
			end
			l.Transparency = if on then 0 else 0.85
		end
		-- инверсионный след выше 18 000 ft
		local contrail = root.Position.Y * World.FT > 18000 and thr > 0.3
		for _, t in c.trails do
			if t.Enabled ~= contrail then
				t.Enabled = contrail
			end
		end
	end
end

return Animator
