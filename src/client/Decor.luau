--!strict
-- Decoração comprada na loja, construída com Parts só para o jogador (cada um tem o seu café).
-- Alguns itens têm animaçãozinha: gato respirando, disco girando, fogo piscando, lanternas balançando.
-- Clicar no gato faz carinho: ele mia e solta um balãozinho de coração. O gato tem várias pelagens (Decor.CatCoats).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Layout = require(ReplicatedStorage.Shared.Layout)
local Sfx = require(script.Parent.Sfx)
local Bubble = require(script.Parent.UI.Bubble)

local rgb = Color3.fromRGB
local Decor = {}

local container: Folder
local built: { [string]: Model } = {}
local animators: { { Id: string, Fn: (t: number) -> () } } = {}
local appearing: { [string]: boolean } = {}
local currentId = ""
-- partes clicáveis no mundo: parte -> o que fazer no clique
local clickables: { [BasePart]: () -> () } = {}

local function addAnimator(fn: (t: number) -> ())
	table.insert(animators, { Id = currentId, Fn = fn })
end

-- Para onde a câmera olha quando a decoração é comprada: { câmera, alvo }
Decor.Focus = {
	Rug = { Vector3.new(7.5, 7.5, -3), Vector3.new(12.5, 0.5, -11.5) },
	HangingPlants = { Vector3.new(-3, 7.5, -8), Vector3.new(-3, 10, -19.8) },
	Paintings = { Vector3.new(7, 7.5, -12), Vector3.new(17.8, 7, -14) },
	Cat = { Vector3.new(0.5, 7.2, 5.5), Vector3.new(-2.6, 5.4, 0) },
	Lanterns = { Vector3.new(-1, 6.5, 3), Vector3.new(-1, 9.6, -10) },
	Record = { Vector3.new(10, 6, -7), Vector3.new(16.8, 3, -12.5) },
	Stove = { Vector3.new(-6, 5.5, -11), Vector3.new(-12, 2.2, -19.8) },
} :: { [string]: { Vector3 } }

local function part(parent: Instance, size: Vector3, cf: CFrame | Vector3, color: Color3, props: { [string]: any }?): BasePart
	local p = Instance.new("Part")
	if props and props.Shape then
		p.Shape = props.Shape
	end
	p.Anchored = true
	p.CanCollide = false
	p.Size = size
	p.CFrame = if typeof(cf) == "Vector3" then CFrame.new(cf) else cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in props do
			if k ~= "Shape" then
				(p :: any)[k] = v
			end
		end
	end
	p.Parent = parent
	return p
end

local function upright(pos: Vector3): CFrame
	return CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
end

local BUILDERS: { [string]: (Model) -> () } = {}

BUILDERS.Rug = function(m)
	local c = Vector3.new(12.5, 0, -11.5)
	part(m, Vector3.new(7, 0.1, 5), c + Vector3.new(0, 0.05, 0), rgb(214, 110, 100))
	part(m, Vector3.new(6, 0.12, 4), c + Vector3.new(0, 0.06, 0), rgb(246, 210, 130))
	part(m, Vector3.new(5, 0.14, 3), c + Vector3.new(0, 0.07, 0), rgb(214, 110, 100))
	for i = -2, 2 do
		part(m, Vector3.new(0.6, 0.15, 0.6), c + Vector3.new(i * 0.9, 0.08, 0), rgb(250, 244, 230))
	end
	for x = -3, 3 do
		part(m, Vector3.new(0.2, 0.08, 0.5), c + Vector3.new(x, 0.04, 2.7), rgb(250, 244, 230))
		part(m, Vector3.new(0.2, 0.08, 0.5), c + Vector3.new(x, 0.04, -2.7), rgb(250, 244, 230))
	end
end

BUILDERS.HangingPlants = function(m)
	local greens = { rgb(96, 150, 84), rgb(134, 186, 104), rgb(66, 116, 64) }
	for i, x in { -10, -5.5, -1, 3.5 } do
		local top = Layout.Room.Height
		local y = 11.4 - (i % 2) * 0.6
		local z = Layout.Room.MinZ + 2.2
		part(m, Vector3.new(0.08, top - y, 0.08), Vector3.new(x, (top + y) / 2 + 0.4, z), rgb(60, 50, 44))
		part(m, Vector3.new(0.9, 1, 1), upright(Vector3.new(x, y, z)), rgb(196, 110, 76), { Shape = Enum.PartType.Cylinder })
		part(m, Vector3.new(1.2, 0.5, 1.2), Vector3.new(x, y + 0.6, z), greens[1])
		for v = 1, 4 do
			local dx = (v - 2.5) * 0.35
			local len = 1 + (v % 3) * 0.6
			part(m, Vector3.new(0.25, len, 0.25), Vector3.new(x + dx, y - 0.4 - len / 2, z + ((v % 2) - 0.5) * 0.4), greens[(v % 3) + 1])
		end
	end
end

BUILDERS.Paintings = function(m)
	local specs = {
		{ z = Layout.Room.MinZ + 3, color = rgb(170, 210, 230), accent = rgb(255, 210, 100) },
		{ z = -8, color = rgb(250, 214, 200), accent = rgb(214, 110, 100) },
	}
	for _, spec in specs do
		local x = Layout.Room.MaxX - 0.15
		local cf = CFrame.new(x, 7, spec.z) * CFrame.Angles(0, math.rad(-90), 0)
		part(m, Vector3.new(2.8, 2.2, 0.15), cf, rgb(92, 58, 40))
		part(m, Vector3.new(2.4, 1.8, 0.18), cf * CFrame.new(0, 0, 0.02), spec.color)
		part(m, Vector3.new(1.6, 0.6, 0.2), cf * CFrame.new(-0.2, -0.4, 0.03), rgb(120, 176, 100))
		part(m, Vector3.new(0.5, 0.5, 0.2), cf * CFrame.new(0.6, 0.4, 0.03), spec.accent)
	end
end

-- Pelagens do gatinho (ids em Catalog.CatColors). Fur = corpo/cabeça/orelhas; Stripes = listras (opcional);
-- Patches = manchas extras (tamanho, posição no espaço do gato, cor, se mexe com a cabeça).
type Patch = { Size: Vector3, At: Vector3, Color: Color3, Head: boolean? }
type Coat = {
	Fur: Color3,
	Stripes: Color3?,
	Tail: Color3,
	Muzzle: Color3,
	Paws: Color3,
	Eyes: Color3,
	Ears: { Color3 }?, -- cor de cada orelha (esquerda, direita); padrão = Fur
	Patches: { Patch }?,
	Swatch: { { Color3 } }, -- quadradinho do pop-up: faixas verticais de cor (cada faixa: cores de cima pra baixo)
}

local CAT_WHITE = rgb(246, 244, 240)
local CAT_BLACK = rgb(44, 42, 50)
local CAT_ORANGE = rgb(236, 150, 72)
local CAT_EYES = rgb(40, 30, 34)
local CAT_EYES_DARK = rgb(150, 140, 150) -- olhinhos fechados visíveis em pelo escuro

Decor.CatCoats = {
	Gray = {
		Fur = rgb(160, 160, 172),
		Stripes = rgb(96, 96, 110),
		Tail = rgb(96, 96, 110),
		Muzzle = CAT_WHITE,
		Paws = CAT_WHITE,
		Eyes = CAT_EYES,
		Swatch = { { rgb(160, 160, 172) }, { rgb(96, 96, 110) }, { rgb(160, 160, 172) }, { rgb(96, 96, 110) } },
	},
	Orange = {
		Fur = CAT_ORANGE,
		Stripes = rgb(200, 104, 44),
		Tail = rgb(200, 104, 44),
		Muzzle = CAT_WHITE,
		Paws = CAT_WHITE,
		Eyes = CAT_EYES,
		Swatch = { { CAT_ORANGE }, { rgb(200, 104, 44) }, { CAT_ORANGE }, { rgb(200, 104, 44) } },
	},
	Black = {
		Fur = CAT_BLACK,
		Tail = CAT_BLACK,
		Muzzle = rgb(62, 60, 70),
		Paws = CAT_BLACK,
		Eyes = CAT_EYES_DARK,
		Swatch = { { CAT_BLACK } },
	},
	White = {
		Fur = CAT_WHITE,
		Tail = CAT_WHITE,
		Muzzle = rgb(255, 255, 255),
		Paws = CAT_WHITE,
		Eyes = CAT_EYES,
		Swatch = { { CAT_WHITE } },
	},
	Calico = {
		Fur = CAT_WHITE,
		Tail = CAT_ORANGE,
		Muzzle = rgb(255, 255, 255),
		Paws = CAT_WHITE,
		Eyes = CAT_EYES,
		Ears = { CAT_BLACK, CAT_ORANGE },
		Patches = {
			{ Size = Vector3.new(0.55, 0.5, 0.94), At = Vector3.new(-0.5, 0.57, 0), Color = CAT_BLACK },
			{ Size = Vector3.new(0.45, 0.4, 0.94), At = Vector3.new(0.05, 0.62, 0), Color = CAT_ORANGE },
			{ Size = Vector3.new(0.4, 0.2, 0.79), At = Vector3.new(0.65, 1.04, 0.15), Color = CAT_BLACK, Head = true },
			{ Size = Vector3.new(0.4, 0.2, 0.79), At = Vector3.new(1.05, 1.04, 0.15), Color = CAT_ORANGE, Head = true },
		},
		Swatch = { { CAT_BLACK, CAT_WHITE }, { CAT_WHITE }, { CAT_ORANGE, CAT_WHITE } },
	},
	Tuxedo = {
		Fur = CAT_BLACK,
		Tail = CAT_BLACK,
		Muzzle = CAT_WHITE,
		Paws = CAT_WHITE,
		Eyes = CAT_EYES_DARK,
		Patches = {
			-- peitinho branco embaixo da carinha; a máscara preta é a própria cabeça
			{ Size = Vector3.new(0.7, 0.55, 0.1), At = Vector3.new(0.75, 0.3, 0.43), Color = CAT_WHITE },
			{ Size = Vector3.new(0.7, 0.2, 0.1), At = Vector3.new(0.85, 0.48, 0.5), Color = CAT_WHITE, Head = true },
		},
		Swatch = { { CAT_BLACK }, { CAT_BLACK, CAT_WHITE }, { CAT_BLACK } },
	},
} :: { [string]: Coat }

local catColor = "Gray" -- pelagem escolhida
local builtCatColor = "" -- pelagem do gato que está no balcão agora

-- Monta o gatinho (pelagem `coatId`) em `m`, deitado em cima da vitrine. Retorna a cabeça e a animação de respirar.
local function buildCat(m: Model, coatId: string): (BasePart, (t: number) -> (), (x: number, y: number, z: number) -> Vector3)
	local coat = Decor.CatCoats[coatId] or Decor.CatCoats.Gray
	local base = Vector3.new(-3, Layout.CounterHeight + 1.63, Layout.CounterZ - 0.1)
	local S = 1.3
	local fur = coat.Fur
	local function at(x: number, y: number, z: number): Vector3
		return base + Vector3.new(x, y, z) * S
	end
	local body = part(m, Vector3.new(1.6, 0.8, 0.9) * S, at(0, 0.4, 0), fur)
	local head = part(m, Vector3.new(0.85, 0.75, 0.75) * S, at(0.85, 0.75, 0.15), fur)
	local muzzle = part(m, Vector3.new(0.45, 0.25, 0.1) * S, at(0.85, 0.6, 0.55), coat.Muzzle)
	local nose = part(m, Vector3.new(0.12, 0.08, 0.06) * S, at(0.85, 0.7, 0.6), rgb(240, 140, 150))
	local eyes = {}
	for _, dx in { -0.2, 0.2 } do
		table.insert(eyes, part(m, Vector3.new(0.16, 0.05, 0.05) * S, at(0.85 + dx, 0.88, 0.54), coat.Eyes)) -- olhinhos fechados
	end
	local ears = {}
	for i, dx in { -0.25, 0.25 } do
		table.insert(ears, part(m, Vector3.new(0.22, 0.28, 0.2) * S, at(0.85 + dx, 1.25, 0.15), if coat.Ears then coat.Ears[i] else fur))
		table.insert(ears, part(m, Vector3.new(0.12, 0.16, 0.05) * S, at(0.85 + dx, 1.22, 0.26), rgb(240, 170, 180)))
	end
	if coat.Stripes then
		for i = -1, 1 do
			part(m, Vector3.new(0.2, 0.84, 0.94) * S, at(i * 0.35 - 0.1, 0.4, 0), coat.Stripes)
		end
	end
	local headParts = { head, muzzle, nose, eyes[1], eyes[2], ears[1], ears[2], ears[3], ears[4] }
	local bodyParts = { body }
	for _, patch in coat.Patches or {} do
		local p = part(m, patch.Size * S, at(patch.At.X, patch.At.Y, patch.At.Z), patch.Color)
		table.insert(if patch.Head then headParts else bodyParts, p)
	end
	part(m, Vector3.new(1.2, 0.1, 0.1) * S, at(-0.3, 0.1, 0.46), coat.Paws) -- patinhas
	local tail = part(m, Vector3.new(0.9, 0.22, 0.22) * S, at(-0.95, 0.2, 0.35), coat.Tail)

	local head0 = {}
	for i, p in headParts do
		head0[i] = p.CFrame
	end
	local body0 = {}
	for i, p in bodyParts do
		body0[i] = p.CFrame
	end
	local t0 = tail.CFrame
	local function animate(t: number)
		local breathe = math.sin(t * 1.6) * 0.04
		for i, p in bodyParts do
			p.CFrame = body0[i] + Vector3.new(0, breathe, 0)
		end
		for i, p in headParts do
			p.CFrame = head0[i] + Vector3.new(0, breathe * 0.6, 0)
		end
		tail.CFrame = t0 * CFrame.Angles(0, math.sin(t * 1.2) * 0.25, 0)
	end
	return head, animate, at
end

BUILDERS.Cat = function(m)
	-- gatinho dormindo em cima da vitrine de doces, carinha virada pra câmera (+Z), na pelagem escolhida
	local head, animate, at = buildCat(m, catColor)
	builtCatColor = catColor
	local S = 1.3

	-- carinho: área invisível cobrindo o gato inteiro, clique = miado + coração
	local hitbox = part(m, Vector3.new(2.6, 1.7, 1.4) * S, at(0.05, 0.7, 0.15), head.Color, { Transparency = 1 })
	hitbox.Name = "PetArea"
	local heart: BillboardGui? = nil
	local lastPet = 0
	clickables[hitbox] = function()
		local now = os.clock()
		if now - lastPet < 0.4 or appearing.Cat then
			return
		end
		lastPet = now
		Sfx.play("Meow")
		if heart then
			Bubble.pop(heart)
		end
		local b = Bubble.love(head)
		heart = b
		task.delay(1.6, function()
			if heart == b then
				heart = nil
				Bubble.pop(b)
			end
		end)
	end

	addAnimator(animate)
end

BUILDERS.Lanterns = function(m)
	local colors = { rgb(250, 150, 120), rgb(246, 210, 130), rgb(170, 210, 150), rgb(200, 170, 230) }
	local lanterns = {}
	for i = 0, 6 do
		local x = -13 + i * 4
		local y = 9.4 + (i % 2) * 0.5
		local z = -10
		part(m, Vector3.new(0.06, Layout.Room.Height - y, 0.06), Vector3.new(x, (Layout.Room.Height + y) / 2, z), rgb(60, 50, 44))
		local body = part(m, Vector3.new(1.2, 1.3, 1.3), upright(Vector3.new(x, y, z)), colors[i % #colors + 1], {
			Shape = Enum.PartType.Cylinder,
			Transparency = 0.15,
		})
		local core = part(m, Vector3.new(0.5, 0.5, 0.5), Vector3.new(x, y, z), rgb(255, 214, 150), { Material = Enum.Material.Neon, Shape = Enum.PartType.Ball })
		if i % 2 == 0 then
			local l = Instance.new("PointLight")
			l.Range = 9
			l.Brightness = 0.5
			l.Color = colors[i % #colors + 1]
			l.Parent = core
		end
		table.insert(lanterns, { body = body, core = core, cf = body.CFrame, ccf = core.CFrame, phase = i })
	end
	addAnimator(function(t)
		for _, l in lanterns do
			local sway = CFrame.Angles(math.sin(t * 0.9 + l.phase) * 0.05, 0, 0)
			l.body.CFrame = l.cf * sway
			l.core.CFrame = l.ccf * sway
		end
	end)
end

BUILDERS.Record = function(m)
	local base = Vector3.new(Layout.Room.MaxX - 1.2, 0, -12.5)
	part(m, Vector3.new(1.8, 2.6, 2.8), base + Vector3.new(0, 1.3, 0), rgb(150, 98, 62))
	part(m, Vector3.new(1.9, 0.15, 2.9), base + Vector3.new(0, 2.65, 0), rgb(196, 146, 98))
	for _, dz in { -0.7, 0.7 } do
		part(m, Vector3.new(0.05, 1.8, 1.1), base + Vector3.new(-0.92, 1.2, dz), rgb(120, 78, 52))
	end
	part(m, Vector3.new(1.4, 0.3, 1.8), base + Vector3.new(0, 2.85, 0), rgb(92, 58, 40))
	local disc = part(m, Vector3.new(0.06, 1.3, 1.3), upright(base + Vector3.new(0, 3.03, 0)), rgb(30, 28, 32), { Shape = Enum.PartType.Cylinder })
	local label = part(m, Vector3.new(0.07, 0.4, 0.4), upright(base + Vector3.new(0, 3.04, 0)), rgb(220, 80, 80), { Shape = Enum.PartType.Cylinder })
	part(m, Vector3.new(0.12, 0.12, 0.9), base + Vector3.new(-0.5, 3.1, 0.4), rgb(210, 210, 214))
	-- corneta
	part(m, Vector3.new(0.15, 1.2, 0.15), base + Vector3.new(0.4, 3.6, -0.6), rgb(212, 170, 80))
	part(m, Vector3.new(0.9, 0.9, 0.9), upright(base + Vector3.new(0.4, 4.4, -0.6)) * CFrame.Angles(0, 0, math.rad(25)), rgb(236, 196, 100), {
		Shape = Enum.PartType.Cylinder,
	})
	local d0, l0 = disc.CFrame, label.CFrame
	addAnimator(function(t)
		local spin = CFrame.Angles(t * 3, 0, 0)
		disc.CFrame = d0 * spin
		label.CFrame = l0 * spin
	end)
	-- notinhas musicais subindo
	local note = part(m, Vector3.new(0.25, 0.25, 0.1), base + Vector3.new(0.4, 5, -0.6), rgb(60, 50, 60))
	local n0 = note.CFrame
	addAnimator(function(t)
		local a = (t * 0.5) % 1
		note.CFrame = n0 + Vector3.new(math.sin(t * 3) * 0.3, a * 2, 0)
		note.Transparency = a
	end)
end

BUILDERS.Stove = function(m)
	local base = Vector3.new(-12, 0, Layout.Room.MinZ + 2.2)
	local iron = rgb(76, 76, 86)
	part(m, Vector3.new(2.4, 2.4, 2), base + Vector3.new(0, 1.5, 0), iron)
	part(m, Vector3.new(2.6, 0.2, 2.2), base + Vector3.new(0, 2.8, 0), rgb(60, 60, 68))
	for _, dx in { -1, 1 } do
		for _, dz in { -0.8, 0.8 } do
			part(m, Vector3.new(0.3, 0.4, 0.3), base + Vector3.new(dx, 0.2, dz), rgb(50, 50, 56))
		end
	end
	part(m, Vector3.new(1.4, 1, 0.1), base + Vector3.new(0, 1.4, 1.02), rgb(40, 34, 36))
	local fire = part(m, Vector3.new(1.1, 0.7, 0.12), base + Vector3.new(0, 1.3, 1.03), rgb(255, 150, 60), { Material = Enum.Material.Neon })
	part(m, Vector3.new(0.5, Layout.Room.Height - 2.9, 0.5), base + Vector3.new(0, 2.9 + (Layout.Room.Height - 2.9) / 2, -0.3), iron)
	-- lenha ao lado
	for i = 0, 2 do
		part(m, Vector3.new(1.2, 0.35, 0.35), upright(base + Vector3.new(2, 0.2 + i * 0.35, 0.3 * (i % 2))) * CFrame.Angles(0, 0, math.rad(90)), rgb(120, 76, 50), {
			Shape = Enum.PartType.Cylinder,
		})
	end
	local light = Instance.new("PointLight")
	light.Color = rgb(255, 150, 80)
	light.Range = 12
	light.Brightness = 1
	light.Parent = fire
	addAnimator(function(t)
		local flicker = 0.8 + math.noise(t * 3, 0.5) * 0.6
		light.Brightness = flicker
		fire.Color = rgb(255, 130 + math.floor(math.noise(t * 4) * 40), 60)
	end)
end

local function build(id: string): Model
	local m = Instance.new("Model")
	m.Name = id
	currentId = id
	BUILDERS[id](m)
	currentId = ""
	m.Parent = container
	built[id] = m
	return m
end

-- Constrói (sem animação) tudo que já foi comprado, exceto os ids em `skip`
function Decor.apply(owned: { [string]: boolean }, skip: { [string]: boolean }?)
	for id in BUILDERS do
		if owned[id] and not built[id] and not (skip and skip[id]) then
			build(id)
		end
	end
end

function Decor.isBuilt(id: string): boolean
	return built[id] ~= nil
end

-- Constrói com animação: as peças caem no lugar uma a uma, com brilhinhos. Retorna a duração.
function Decor.reveal(id: string): number
	if built[id] or not BUILDERS[id] then
		return 0
	end
	appearing[id] = true
	local m = build(id)
	local parts = {}
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			table.insert(parts, p)
		end
	end
	table.sort(parts, function(a, b)
		return a.Position.Y < b.Position.Y
	end)

	local step = math.min(0.06, 1.2 / math.max(#parts, 1))
	local center = m:GetPivot().Position
	for i, p in parts do
		local goalCF, goalT = p.CFrame, p.Transparency
		p.CFrame = goalCF + Vector3.new(0, 2.5, 0)
		p.Transparency = 1
		task.delay((i - 1) * step, function()
			TweenService:Create(p, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				CFrame = goalCF,
				Transparency = goalT,
			}):Play()
		end)
	end

	local total = (#parts - 1) * step + 0.4

	-- brilhinhos no final
	task.delay(total, function()
		local anchor = Instance.new("Part")
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(1, 1, 1)
		anchor.Position = center
		anchor.Parent = container
		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(rgb(255, 230, 150), rgb(255, 180, 200))
		emitter.LightEmission = 1
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		emitter.Speed = NumberRange.new(4, 9)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Lifetime = NumberRange.new(0.6, 1.1)
		emitter.Rate = 0
		emitter.Parent = anchor
		emitter:Emit(40)
		appearing[id] = nil
		if id == "Cat" then
			Decor.setCatColor(catColor)
		end
		task.delay(2, function()
			anchor:Destroy()
		end)
	end)
	return total
end

-- Gatinho solto (fora do café) para a prévia do pop-up de cores. Retorna o modelo, a animação e
-- o ponto da carinha (para a câmera mirar).
function Decor.catPreview(coatId: string): (Model, (t: number) -> (), Vector3)
	local m = Instance.new("Model")
	m.Name = "CatPreview"
	local head, animate = buildCat(m, coatId)
	return m, animate, head.Position
end

-- Troca a pelagem do gato do balcão (reconstrói na hora, sem animação de montar)
function Decor.setCatColor(coatId: string)
	if not Decor.CatCoats[coatId] then
		return
	end
	catColor = coatId
	local old = built.Cat
	-- montando agora: a troca acontece quando terminar (ver Decor.reveal)
	if not old or appearing.Cat or builtCatColor == coatId then
		return
	end
	for i = #animators, 1, -1 do
		if animators[i].Id == "Cat" then
			table.remove(animators, i)
		end
	end
	for p in clickables do
		if p:IsDescendantOf(old) then
			clickables[p] = nil
		end
	end
	old:Destroy()
	built.Cat = nil
	build("Cat")
end

function Decor.start()
	container = Instance.new("Folder")
	container.Name = "ClientDecor"
	container.Parent = workspace
	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for _, a in animators do
			if not appearing[a.Id] then
				a.Fn(t)
			end
		end
	end)

	-- clique/toque no mundo (fora da UI): vê se acertou algo clicável da decoração
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local camera = workspace.CurrentCamera
		local ray = camera:ScreenPointToRay(input.Position.X, input.Position.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { Players.LocalPlayer.Character :: any }
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 200, params)
		local fn = hit and clickables[hit.Instance :: BasePart]
		if fn then
			fn()
		end
	end)
end

return Decor
