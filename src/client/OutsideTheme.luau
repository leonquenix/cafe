--!strict
-- Temas da fachada (Catalog.Themes), só no cliente. O servidor marca as peças de fora (workspace.Cafe.Outside)
-- com o atributo "Theme": Bloom (flores: somem), Foliage (folhas: mudam de cor e ganham neve), Cap (ganha neve
-- em cima), Roof, Grass e Soil. Cada tema troca cores, monta peças extras (Art/ThemeProps), muda o clima e solta
-- "partículas" de bloquinhos: um pool pequeno de Parts movido com BulkMoveTo (leve no celular).
-- Natal herda o Inverno e Halloween herda o Outono (Base).

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Layout = require(ReplicatedStorage.Shared.Layout)
local DayCycle = require(script.Parent.DayCycle)
local ThemeProps = require(script.Parent.Art.ThemeProps)

local rgb = Color3.fromRGB

type Spec = {
	Base: string?,
	HideBlooms: boolean?,
	Grass: Color3?,
	Soil: Color3?,
	Foliage: ((color: Color3, rng: Random) -> Color3)?,
	Fall: string?, -- FALL[...]
	Weather: DayCycle.Weather?,
	Clouds: { Cover: number, Density: number, Color: Color3 }?,
	Atmosphere: { [string]: any }?,
	Saturation: number?, -- ColorCorrection (somada à do cenário)
	Build: ((ctx: ThemeProps.Ctx) -> ())?,
}

local AUTUMN_LEAVES = { rgb(232, 124, 52), rgb(214, 76, 50), rgb(242, 184, 64), rgb(204, 104, 42), rgb(180, 64, 46) }

local THEMES: { [string]: Spec } = {
	Winter = {
		HideBlooms = true,
		Grass = rgb(236, 242, 250),
		Soil = rgb(228, 236, 248),
		Foliage = function(c)
			return c:Lerp(rgb(58, 92, 84), 0.35)
		end,
		Fall = "Snow",
		Weather = { Brightness = 1, Exposure = -0.08, Tint = rgb(226, 236, 255), Amount = 0.3 },
		Clouds = { Cover = 0.6, Density = 0.35, Color = rgb(238, 240, 246) },
		Atmosphere = { Density = 0.22, Color = rgb(232, 238, 250), Decay = rgb(186, 196, 222), Haze = 1.2 },
		Build = ThemeProps.winter,
	},
	Autumn = {
		HideBlooms = true,
		Grass = rgb(154, 162, 86),
		Foliage = function(_, rng)
			return AUTUMN_LEAVES[rng:NextInteger(1, #AUTUMN_LEAVES)]
		end,
		Fall = "Leaves",
		Weather = { Brightness = 1, Exposure = 0, Tint = rgb(255, 222, 182), Amount = 0.25 },
		Atmosphere = { Density = 0.16, Color = rgb(255, 214, 170), Decay = rgb(214, 140, 100), Haze = 0.8 },
		Build = ThemeProps.autumn,
	},
	Rain = {
		Grass = rgb(96, 142, 84),
		Soil = rgb(74, 54, 42),
		Foliage = function(c)
			return c:Lerp(rgb(40, 70, 56), 0.25)
		end,
		Fall = "Rain",
		Weather = { Brightness = 0.55, Exposure = -0.12, Tint = rgb(196, 200, 210), Amount = 0.55 },
		Clouds = { Cover = 0.9, Density = 0.75, Color = rgb(150, 156, 168) },
		Atmosphere = { Density = 0.42, Color = rgb(188, 192, 200), Decay = rgb(132, 138, 150), Haze = 2.6, Glare = 0 },
		Saturation = -0.22,
		Build = ThemeProps.rain,
	},
	Christmas = {
		Base = "Winter",
		Weather = { Brightness = 0.95, Exposure = -0.08, Tint = rgb(230, 234, 255), Amount = 0.28 },
		Build = ThemeProps.christmas,
	},
	Halloween = {
		Base = "Autumn",
		Weather = { Brightness = 0.85, Exposure = -0.05, Tint = rgb(226, 200, 255), Amount = 0.25 },
		Atmosphere = { Density = 0.2, Color = rgb(214, 186, 230), Decay = rgb(150, 100, 150), Haze = 1 },
		Build = ThemeProps.halloween,
	},
}

-- "Partículas": bloquinhos caindo numa caixa na frente da loja (dá pra ver da janela e da tela de início)
type Fall = {
	Count: number,
	Size: Vector3,
	Colors: { Color3 },
	Speed: { number },
	Drift: number, -- balanço de lado (studs)
	Spin: number,
	Slant: number, -- vento: velocidade em X proporcional à queda
	Transparency: number,
}

local FALL: { [string]: Fall } = {
	Snow = {
		Count = 140,
		Size = Vector3.new(0.32, 0.32, 0.32),
		Colors = { rgb(255, 255, 255), rgb(234, 242, 255) },
		Speed = { 3, 5.5 },
		Drift = 1.1,
		Spin = 0,
		Slant = 0,
		Transparency = 0,
	},
	Leaves = {
		Count = 36,
		Size = Vector3.new(0.55, 0.07, 0.42),
		Colors = AUTUMN_LEAVES,
		Speed = { 2.2, 3.6 },
		Drift = 2.2,
		Spin = 2.4,
		Slant = 0.5,
		Transparency = 0,
	},
	Rain = {
		Count = 150,
		Size = Vector3.new(0.07, 1.7, 0.07),
		Colors = { rgb(204, 218, 236) },
		Speed = { 55, 70 },
		Drift = 0,
		Spin = 0,
		Slant = -0.12,
		Transparency = 0.45,
	},
}

-- (Z0 fica uns studs na frente das câmeras de fora, pra nenhum bloquinho passar colado na lente)
local BOX = { X0 = -46, X1 = 46, Z0 = -44, Z1 = Layout.Room.MinZ - 1.6, Y0 = -0.1, Y1 = 36 }

local OutsideTheme = {}

local outside: Instance? = nil
local wanted = "Original"
local applied = "" -- tema montado agora
local folder: Folder? = nil
local heartbeat: RBXScriptConnection? = nil
local saved: { [BasePart]: { Color: Color3, Transparency: number } } = {}
local savedEffects: { [Instance]: { [string]: any } } = {}

local function tagged(role: string): { BasePart }
	local list = {}
	if outside then
		for _, d in outside:GetDescendants() do
			if d:IsA("BasePart") and d:GetAttribute("Theme") == role then
				table.insert(list, d)
			end
		end
	end
	return list
end

local function change(p: BasePart, color: Color3?, transparency: number?)
	if not saved[p] then
		saved[p] = { Color = p.Color, Transparency = p.Transparency }
	end
	if color then
		p.Color = color
	end
	if transparency then
		p.Transparency = transparency
	end
end

-- muda propriedades de um efeito do Lighting (guardando o valor original pra voltar)
local function setEffect(className: string, props: { [string]: any })
	local effect = Lighting:FindFirstChildOfClass(className)
	if not effect then
		return
	end
	local saved = savedEffects[effect] or {}
	savedEffects[effect] = saved
	for k, v in props do
		if saved[k] == nil then
			saved[k] = (effect :: any)[k]
		end
		(effect :: any)[k] = v
	end
end

local function restoreEffects()
	for effect, props in savedEffects do
		for k, v in props do
			(effect :: any)[k] = v
		end
	end
	table.clear(savedEffects)
end

local function setClouds(spec: { Cover: number, Density: number, Color: Color3 }?)
	local terrain = workspace.Terrain
	local old = terrain:FindFirstChild("ThemeClouds")
	if old then
		old:Destroy()
	end
	if spec then
		local clouds = Instance.new("Clouds")
		clouds.Name = "ThemeClouds"
		clouds.Cover = spec.Cover
		clouds.Density = spec.Density
		clouds.Color = spec.Color
		clouds.Parent = terrain
	end
end

local function clear()
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	if folder then
		folder:Destroy()
		folder = nil
	end
	for p, s in saved do
		p.Color = s.Color
		p.Transparency = s.Transparency
	end
	table.clear(saved)
	restoreEffects()
	setClouds(nil)
end

-- monta o pool de bloquinhos caindo; retorna o passo por frame
local function makeFall(f: Fall, parent: Folder, rng: Random): (t: number, dt: number) -> ()
	local parts: { BasePart } = {}
	local pos: { Vector3 } = {}
	local speed: { number } = {}
	local phase: { number } = {}
	local cfs: { CFrame } = {}
	local function spawnAt(i: number, y: number)
		pos[i] = Vector3.new(rng:NextNumber(BOX.X0, BOX.X1), y, rng:NextNumber(BOX.Z0, BOX.Z1))
		speed[i] = rng:NextNumber(f.Speed[1], f.Speed[2])
	end
	for i = 1, f.Count do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.Size = f.Size
		p.Color = f.Colors[rng:NextInteger(1, #f.Colors)]
		p.Transparency = f.Transparency
		p.Parent = parent
		parts[i] = p
		phase[i] = rng:NextNumber(0, math.pi * 2)
		spawnAt(i, rng:NextNumber(BOX.Y0, BOX.Y1))
	end
	local tilt = CFrame.Angles(0, 0, math.atan(f.Slant))
	return function(t: number, dt: number)
		for i = 1, f.Count do
			local p = pos[i]
			local s = speed[i]
			p = Vector3.new(p.X - s * f.Slant * dt, p.Y - s * dt, p.Z)
			if p.Y < BOX.Y0 then
				spawnAt(i, BOX.Y1 + rng:NextNumber(0, 3))
				p = pos[i]
			end
			pos[i] = p
			local ph = phase[i]
			local shown = p + Vector3.new(math.sin(t * 0.9 + ph) * f.Drift, 0, math.cos(t * 0.7 + ph) * f.Drift * 0.4)
			if f.Spin > 0 then
				cfs[i] = CFrame.new(shown) * CFrame.Angles(t * f.Spin + ph, ph, math.sin(t * f.Spin + ph) * 0.9)
			else
				cfs[i] = CFrame.new(shown) * tilt
			end
		end
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

local function build(id: string)
	local spec = THEMES[id]
	if not spec then
		return
	end
	local chain = { spec }
	if spec.Base and THEMES[spec.Base] then
		table.insert(chain, 1, THEMES[spec.Base])
	end

	local f = Instance.new("Folder")
	f.Name = "ClientTheme"
	folder = f
	local rng = Random.new(20261029)
	local animators: { (t: number, dt: number) -> () } = {}
	local ctx: ThemeProps.Ctx = {
		Folder = f,
		Rng = rng,
		part = function(size, cf, color, props)
			local p = Instance.new("Part")
			if props and props.Shape then
				p.Shape = props.Shape
			end
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Material = Enum.Material.SmoothPlastic
			p.TopSurface = Enum.SurfaceType.Smooth
			p.BottomSurface = Enum.SurfaceType.Smooth
			p.Size = size
			p.CFrame = if typeof(cf) == "Vector3" then CFrame.new(cf) else cf
			p.Color = color
			if props then
				for k, v in props do
					if k ~= "Shape" then
						(p :: any)[k] = v
					end
				end
			end
			p.Parent = f
			return p
		end,
		tagged = tagged,
		animate = function(fn)
			table.insert(animators, fn)
		end,
		light = function(parent, brightness, range, color)
			local l = Instance.new("PointLight")
			l.Brightness = brightness
			l.Range = range
			l.Color = color
			l.Parent = parent
			return l
		end,
	}

	local weather: DayCycle.Weather? = nil
	local fall: string? = nil
	local atmosphere: { [string]: any }? = nil
	local saturation: number? = nil
	local clouds = nil
	for _, s in chain do
		if s.HideBlooms then
			for _, p in tagged("Bloom") do
				change(p, nil, 1)
			end
		end
		if s.Grass then
			for _, p in tagged("Grass") do
				change(p, s.Grass)
			end
		end
		if s.Soil then
			for _, p in tagged("Soil") do
				change(p, s.Soil)
			end
		end
		if s.Foliage then
			for _, p in tagged("Foliage") do
				change(p, s.Foliage(saved[p] and saved[p].Color or p.Color, rng))
			end
		end
		weather = s.Weather or weather
		fall = s.Fall or fall
		atmosphere = s.Atmosphere or atmosphere
		saturation = s.Saturation or saturation
		clouds = s.Clouds or clouds
		if s.Build then
			s.Build(ctx)
		end
	end
	if fall and FALL[fall] then
		table.insert(animators, makeFall(FALL[fall], f, rng))
	end
	if atmosphere then
		setEffect("Atmosphere", atmosphere)
	end
	if saturation then
		local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
		if cc then
			setEffect("ColorCorrectionEffect", { Saturation = cc.Saturation + saturation })
		end
	end
	setClouds(clouds)
	DayCycle.setWeather(weather)
	f.Parent = workspace

	if #animators > 0 then
		heartbeat = RunService.Heartbeat:Connect(function(dt)
			local t = os.clock()
			for _, fn in animators do
				fn(t, dt)
			end
		end)
	end
end

-- Troca o tema lá fora (instantâneo). Antes da fachada chegar no cliente, guarda e aplica quando chegar.
function OutsideTheme.set(id: string)
	wanted = id
	if not outside or applied == id then
		return
	end
	clear()
	applied = id
	if not THEMES[id] then
		DayCycle.setWeather(nil)
	end
	build(id)
end

-- Brilhinhos na fachada (tema novo comprado)
function OutsideTheme.celebrate()
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(16, 8, 1)
	anchor.Position = Vector3.new(Layout.DoorX - 4, 9, Layout.Room.MinZ - 3)
	anchor.Parent = workspace
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(rgb(255, 230, 150), rgb(255, 180, 200))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
	emitter.Speed = NumberRange.new(4, 10)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Lifetime = NumberRange.new(0.7, 1.3)
	emitter.Rate = 0
	emitter.Parent = anchor
	emitter:Emit(80)
	task.delay(2, function()
		anchor:Destroy()
	end)
end

function OutsideTheme.start()
	task.spawn(function()
		local cafe = workspace:WaitForChild("Cafe", 60)
		local out = cafe and cafe:WaitForChild("Outside", 60)
		if not out then
			return
		end
		outside = out
		local id = wanted
		wanted = ""
		OutsideTheme.set(id)
	end)
end

return OutsideTheme
