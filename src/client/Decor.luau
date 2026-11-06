--!strict
-- Decoração comprada na loja, construída com Parts só para o jogador (cada um tem o seu café).
-- Alguns itens têm animaçãozinha: gato respirando, disco girando, fogo piscando, lanternas balançando,
-- pisca-pisca de Natal, abóboras tremulando, fantasminhas flutuando, coelhinho espiando da planta. Cada uma pode ser desligada na loja (Decor.setHidden).
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
	ChristmasTree = { Vector3.new(-8, 6.5, -4), Vector3.new(-15.2, 3.8, -12.5) },
	ChristmasWreath = { Vector3.new(3.2, 8.5, 7), Vector3.new(0, 7.5, -16) },
	ChristmasGarland = { Vector3.new(2, 8, 2), Vector3.new(0, 12, -9) },
	HalloweenPumpkins = { Vector3.new(10, 4.5, -13), Vector3.new(12.6, 1, -20.5) },
	HalloweenWall = { Vector3.new(3.2, 8.5, 7), Vector3.new(4, 9.5, -16) },
	HalloweenWebs = { Vector3.new(3.2, 8.5, 7), Vector3.new(2, 8, -12) },
	HalloweenGhosts = { Vector3.new(0.5, 8.5, 2), Vector3.new(-1.5, 11.2, -6.5) },
	EasterWreath = { Vector3.new(5, 6.5, -14), Vector3.new(5.45, 7.2, -21.8) },
	EasterBunting = { Vector3.new(1, 8, -3), Vector3.new(0, 12.2, -14) },
	EasterBasket = { Vector3.new(6, 6.2, 5), Vector3.new(7.55, 3.9, 0.55) },
	EasterWindowGarland = { Vector3.new(3.2, 8.5, 7), Vector3.new(0, 8.5, -16) },
	EasterPlantBunny = { Vector3.new(-6.5, 5.6, 6.5), Vector3.new(-9, 3.8, 1.5) },
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

---------------------------------------------------------------- festas (Páscoa, Halloween, Natal)
-- Cada enfeite é um item separado: pode ser ligado/desligado na loja (Decor.setHidden).

local NEON = { Material = Enum.Material.Neon, CastShadow = false }
local BALL = { Shape = Enum.PartType.Ball }
local WALL_Z = Layout.Room.MinZ + 0.15 -- enfeites de parede: colados na parede da porta (fundo)
local BEAM_Y = Layout.Room.Height - 0.8 -- parte de baixo das vigas do teto

-- Janelas do café (as mesmas do Scenery). Frame: centro da janela na face de dentro da parede, com +X para a
-- direita de quem olha a janela de dentro e +Z apontando pra dentro da sala. São as que mais aparecem na tela
-- (inclusive no celular), então os enfeites de festa ficam nelas.
type Window = { Frame: CFrame, Width: number, Height: number }
local WINDOWS: { [string]: Window } = {}
-- da esquerda pra direita na tela: lateral esquerda (frente, fundo), fundo (esquerda, direita), lateral direita (fundo, frente)
local WINDOW_ORDER = { "LeftFront", "LeftBack", "BackLeft", "BackRight", "RightBack", "RightFront" }
do
	local R = Layout.Room
	local function add(id: string, center: Vector3, width: number, normal: Vector3)
		WINDOWS[id] = { Frame = CFrame.fromMatrix(center, Vector3.yAxis:Cross(normal), Vector3.yAxis), Width = width, Height = 6.5 }
	end
	add("BackLeft", Vector3.new(-7.5, 7.25, R.MinZ), 7, Vector3.zAxis)
	add("BackRight", Vector3.new(1, 7.25, R.MinZ), 6, Vector3.zAxis)
	add("LeftBack", Vector3.new(R.MinX, 7.25, -13), 6, Vector3.xAxis)
	add("LeftFront", Vector3.new(R.MinX, 7.25, -3), 6, Vector3.xAxis)
	add("RightBack", Vector3.new(R.MaxX, 7.25, -13), 6, -Vector3.xAxis)
	add("RightFront", Vector3.new(R.MaxX, 7.25, -3), 6, -Vector3.xAxis)
end

-- frame de parede (+Z pra dentro da sala) num ponto colado na parede lateral (side = -1 esquerda, 1 direita)
local function sideWall(side: number, y: number, z: number): CFrame
	local normal = Vector3.new(-side, 0, 0)
	return CFrame.fromMatrix(Vector3.new(side * (Layout.Room.MaxX - 0.15), y, z), Vector3.yAxis:Cross(normal), Vector3.yAxis)
end

-- peça fina entre dois pontos (cordões, fios, teias)
local function beam(parent: Instance, a: Vector3, b: Vector3, thick: number, color: Color3, props: { [string]: any }?): BasePart
	local d = b - a
	return part(parent, Vector3.new(thick, thick, d.Magnitude), CFrame.lookAt((a + b) / 2, b), color, props)
end

-- vira a frente (+Z) da peça para a câmera do café
local function faceCamera(pos: Vector3): CFrame
	local cam = Layout.Camera.Position
	return CFrame.new(pos) * CFrame.Angles(0, math.atan2(cam.X - pos.X, cam.Z - pos.Z), 0)
end

-- grupo de peças que se mexe junto em volta de um pivô: guarda a posição de cada uma relativa ao pivô
type Rig = { Pivot: CFrame, Parts: { BasePart }, Rel: { CFrame } }
local function rig(pivot: CFrame, parts: { BasePart }): Rig
	local rel = {}
	for i, p in parts do
		rel[i] = pivot:ToObjectSpace(p.CFrame)
	end
	return { Pivot = pivot, Parts = parts, Rel = rel }
end
local function moveRig(r: Rig, offset: CFrame)
	local pivot = r.Pivot * offset
	for i, p in r.Parts do
		p.CFrame = pivot * r.Rel[i]
	end
end

-- pisca-pisca: cada luzinha passa pelas cores da lista, em passos (só troca quando muda o passo)
local function twinkle(bulbs: { BasePart }, colors: { Color3 }, speed: number)
	local last = -1
	addAnimator(function(t)
		local step = math.floor(t * speed)
		if step == last then
			return
		end
		last = step
		for i, b in bulbs do
			b.Color = colors[(i + step) % #colors + 1]
		end
	end)
end

local XMAS_LIGHTS = { rgb(255, 214, 140), rgb(255, 120, 120), rgb(140, 220, 150), rgb(150, 190, 255) }
local PASTELS = { rgb(246, 178, 200), rgb(250, 226, 140), rgb(166, 206, 240), rgb(176, 226, 190), rgb(204, 182, 240) }

local function gift(m: Model, pos: Vector3, size: Vector3, color: Color3, ribbon: Color3)
	local c = pos + Vector3.new(0, size.Y / 2, 0)
	part(m, size, c, color)
	part(m, Vector3.new(size.X + 0.04, size.Y + 0.02, 0.14), c, ribbon)
	part(m, Vector3.new(0.14, size.Y + 0.02, size.Z + 0.04), c, ribbon)
	part(m, Vector3.new(0.34, 0.18, 0.34), CFrame.new(pos + Vector3.new(0, size.Y + 0.09, 0)) * CFrame.Angles(0, math.rad(45), 0), ribbon)
end

-- Árvore de Natal: no canto da esquerda, na frente da janela de trás (longe do caminho dos clientes)
BUILDERS.ChristmasTree = function(m)
	local base = Vector3.new(-15.2, 0, -12.5)
	part(m, Vector3.new(1.7, 1, 1.7), base + Vector3.new(0, 0.5, 0), rgb(196, 70, 64)) -- vaso
	part(m, Vector3.new(1.9, 0.2, 1.9), base + Vector3.new(0, 1.05, 0), rgb(236, 220, 196))
	part(m, Vector3.new(0.6, 0.7, 0.6), base + Vector3.new(0, 1.45, 0), rgb(110, 70, 46)) -- tronco
	local greens = { rgb(66, 130, 80), rgb(84, 150, 92) }
	local balls = { rgb(214, 70, 70), rgb(240, 196, 90), rgb(110, 150, 220), rgb(236, 236, 240) }
	local faces = { Vector3.new(0, 0, 1), Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1) }
	local bulbs = {}
	-- andares (largura, altura, centro Y), do maior pro menor
	local tiers = { { 3.3, 1.3, 2.4 }, { 2.7, 1.2, 3.5 }, { 2.1, 1.1, 4.5 }, { 1.5, 1, 5.4 }, { 0.8, 0.9, 6.2 } }
	for i, tier in tiers do
		local w, h, y = tier[1], tier[2], tier[3]
		part(m, Vector3.new(w, h, w), base + Vector3.new(0, y, 0), greens[i % 2 + 1])
		-- galhos mais largos embaixo de cada andar: dá a silhueta de pinheirinho
		part(m, Vector3.new(w + 0.5, 0.3, w + 0.5), base + Vector3.new(0, y - h / 2 + 0.15, 0), rgb(54, 108, 70))
		if i == #tiers then
			continue
		end
		for k, dir in faces do
			local side = Vector3.new(dir.Z, 0, -dir.X)
			local off = ((k + i) % 3 - 1) * w * 0.25
			local at = base + Vector3.new(0, y - 0.15, 0) + dir * (w / 2 + 0.08) + side * off
			part(m, Vector3.new(0.38, 0.38, 0.38), at, balls[(i + k) % #balls + 1], BALL)
			for _, s in { -1, 1 } do
				local b = part(m, Vector3.new(0.2, 0.2, 0.2), base + Vector3.new(0, y + h * 0.25, 0) + dir * (w / 2 + 0.06) + side * (s * w * 0.3), XMAS_LIGHTS[1], NEON)
				table.insert(bulbs, b)
			end
		end
	end
	-- estrela no topo (dois quadrados girando devagar) com luz
	local starAt = base + Vector3.new(0, 7.15, 0)
	local star1 = part(m, Vector3.new(0.75, 0.75, 0.2), CFrame.new(starAt) * CFrame.Angles(0, 0, math.rad(45)), rgb(255, 214, 90), NEON)
	local star2 = part(m, Vector3.new(0.75, 0.75, 0.2), starAt, rgb(255, 236, 150), NEON)
	local glow = Instance.new("PointLight")
	glow.Color = rgb(255, 214, 140)
	glow.Range = 10
	glow.Brightness = 0.7
	glow.Parent = star1
	-- presentes embaixo
	gift(m, base + Vector3.new(1.9, 0, 1.2), Vector3.new(0.9, 0.7, 0.9), rgb(214, 90, 90), rgb(250, 230, 160))
	gift(m, base + Vector3.new(1.1, 0, 2.2), Vector3.new(0.7, 0.5, 0.7), rgb(120, 170, 220), rgb(246, 246, 246))
	gift(m, base + Vector3.new(-0.4, 0, 2.1), Vector3.new(0.6, 0.6, 0.6), rgb(150, 200, 130), rgb(214, 90, 90))

	twinkle(bulbs, XMAS_LIGHTS, 1.5)
	addAnimator(function(t)
		local spin = CFrame.Angles(0, t * 0.8, 0)
		star1.CFrame = CFrame.new(starAt) * spin * CFrame.Angles(0, 0, math.rad(45))
		star2.CFrame = CFrame.new(starAt) * spin
		glow.Brightness = 0.6 + math.sin(t * 2) * 0.2
	end)
end

-- guirlanda pendurada por uma fita no meio da janela (na frente do vidro); as luzinhas vão para `bulbs`
local function xmasWreath(m: Model, frame: CFrame, bulbs: { BasePart })
	local c = frame * CFrame.new(0, 1.05, 0.5)
	local function at(x: number, y: number, z: number): CFrame
		return c * CFrame.new(x, y, z)
	end
	part(m, Vector3.new(0.22, 0.9, 0.06), at(0, 1.65, 0), rgb(214, 64, 64)) -- fita até o topo da janela
	part(m, Vector3.new(0.5, 0.16, 0.2), at(0, 2.05, 0), rgb(186, 50, 54))
	local greens = { rgb(66, 130, 80), rgb(84, 150, 92), rgb(54, 108, 70) }
	local red = rgb(214, 64, 64)
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		local dx, dy = math.cos(a), math.sin(a)
		part(m, Vector3.new(0.75, 0.55, 0.3), at(dx, dy, 0) * CFrame.Angles(0, 0, a + math.pi / 2), greens[i % 3 + 1])
		part(m, Vector3.new(0.45, 0.35, 0.32), at(dx * 1.3, dy * 1.3, 0) * CFrame.Angles(0, 0, a + 0.5), greens[(i + 1) % 3 + 1])
		if i % 3 == 0 then
			part(m, Vector3.new(0.2, 0.2, 0.2), at(dx * 0.85 + 0.08, dy * 0.85, 0.2), red, BALL)
			part(m, Vector3.new(0.2, 0.2, 0.2), at(dx * 0.85 - 0.08, dy * 0.85 - 0.12, 0.2), red, BALL)
		elseif i % 3 == 1 then
			table.insert(bulbs, part(m, Vector3.new(0.18, 0.18, 0.18), at(dx * 1.08, dy * 1.08, 0.2), XMAS_LIGHTS[1], NEON))
		end
	end
	-- laço vermelho embaixo
	local b = at(0, -1.05, 0.25)
	part(m, Vector3.new(0.34, 0.34, 0.22), b, red)
	part(m, Vector3.new(0.6, 0.45, 0.16), b * CFrame.new(-0.42, 0.05, 0) * CFrame.Angles(0, 0, math.rad(-15)), red)
	part(m, Vector3.new(0.6, 0.45, 0.16), b * CFrame.new(0.42, 0.05, 0) * CFrame.Angles(0, 0, math.rad(15)), red)
	part(m, Vector3.new(0.2, 0.7, 0.14), b * CFrame.new(-0.18, -0.45, 0) * CFrame.Angles(0, 0, math.rad(-15)), rgb(186, 50, 54))
	part(m, Vector3.new(0.2, 0.7, 0.14), b * CFrame.new(0.18, -0.45, 0) * CFrame.Angles(0, 0, math.rad(15)), rgb(186, 50, 54))
end

-- Guirlandas de Natal: uma em cada janela do café, com laço vermelho e pisca-pisca
BUILDERS.ChristmasWreath = function(m)
	local bulbs = {}
	for _, id in WINDOW_ORDER do
		xmasWreath(m, WINDOWS[id].Frame, bulbs)
	end
	twinkle(bulbs, XMAS_LIGHTS, 2)
end

-- Festão de Natal: pendurado na viga do meio da sala, com bolinhas balançando entre as lanternas
BUILDERS.ChristmasGarland = function(m)
	local z = Layout.Room.MinZ + 13 -- viga em z = -9
	local anchors = { -17.5, -15, -11, -7, -3, 1, 5, 9, 13, 17.5 }
	local greens = { rgb(66, 130, 80), rgb(84, 150, 92), rgb(54, 108, 70) }
	local bulbs = {}
	local ornaments: { Rig } = {}
	local ballColors = { rgb(214, 70, 70), rgb(240, 196, 90), rgb(110, 150, 220), rgb(236, 236, 240) }
	for s = 1, #anchors - 1 do
		local a, b = anchors[s], anchors[s + 1]
		local n = math.max(4, math.floor((b - a) / 0.4))
		for k = 0, n do
			local u = k / n
			local p = Vector3.new(a + (b - a) * u, BEAM_Y - 0.15 - 0.8 * math.sin(math.pi * u), z)
			part(m, Vector3.new(0.5, 0.42, 0.42), CFrame.new(p) * CFrame.Angles(k * 0.7, k * 1.3, k * 0.4), greens[k % 3 + 1])
			if k % 3 == 1 then
				table.insert(bulbs, part(m, Vector3.new(0.17, 0.17, 0.17), p + Vector3.new(0, -0.18, 0.24), XMAS_LIGHTS[1], NEON))
			end
		end
	end
	-- lacinho em cada ponto de apoio + bolinha pendurada (entre as lanternas)
	for i = 2, #anchors - 1 do
		local top = Vector3.new(anchors[i], BEAM_Y - 0.15, z)
		part(m, Vector3.new(0.5, 0.3, 0.2), top + Vector3.new(0, 0, 0.3), rgb(214, 64, 64))
		local len = 0.7 + (i % 3) * 0.3
		local pivot = CFrame.new(top)
		local thread = part(m, Vector3.new(0.04, len, 0.04), top - Vector3.new(0, len / 2, 0), rgb(210, 200, 170))
		local cap = part(m, Vector3.new(0.16, 0.12, 0.16), top - Vector3.new(0, len + 0.05, 0), rgb(220, 190, 110))
		local ball = part(m, Vector3.new(0.5, 0.5, 0.5), top - Vector3.new(0, len + 0.34, 0), ballColors[i % #ballColors + 1], BALL)
		local shine = part(m, Vector3.new(0.12, 0.12, 0.05), top - Vector3.new(0.1, len + 0.24, -0.25), rgb(255, 255, 255))
		table.insert(ornaments, rig(pivot, { thread, cap, ball, shine }))
	end
	twinkle(bulbs, XMAS_LIGHTS, 1.6)
	addAnimator(function(t)
		for i, o in ornaments do
			moveRig(o, CFrame.Angles(math.sin(t * 1.1 + i) * 0.08, 0, math.sin(t * 0.9 + i * 1.7) * 0.06))
		end
	end)
end

-- abóbora com carinha acesa virada pra câmera; retorna a carinha e a luz (para tremular)
local function pumpkin(m: Model, pos: Vector3, s: number): ({ BasePart }, PointLight)
	local cf = faceCamera(pos)
	local orange, dark = rgb(236, 138, 54), rgb(206, 108, 40)
	part(m, Vector3.new(1.3, 1, 1.2) * s, cf * CFrame.new(0, 0.5 * s, 0), orange)
	for _, sx in { -1, 1 } do
		part(m, Vector3.new(0.35, 0.85, 1.05) * s, cf * CFrame.new(sx * 0.75 * s, 0.45 * s, 0), dark)
		part(m, Vector3.new(0.12, 0.96, 1.22) * s, cf * CFrame.new(sx * 0.5 * s, 0.5 * s, 0), dark) -- gomos
	end
	part(m, Vector3.new(0.22, 0.32, 0.22) * s, cf * CFrame.new(0, 1.12 * s, 0) * CFrame.Angles(0, 0, 0.25), rgb(100, 130, 60)) -- cabinho
	local glow = rgb(255, 200, 90)
	local face = {}
	for _, dx in { -0.28, 0.28 } do
		table.insert(face, part(m, Vector3.new(0.24, 0.22, 0.05) * s, cf * CFrame.new(dx * s, 0.66 * s, 0.61 * s), glow, NEON))
	end
	table.insert(face, part(m, Vector3.new(0.12, 0.1, 0.05) * s, cf * CFrame.new(0, 0.5 * s, 0.61 * s), glow, NEON)) -- narizinho
	table.insert(face, part(m, Vector3.new(0.66, 0.14, 0.05) * s, cf * CFrame.new(0, 0.3 * s, 0.61 * s), glow, NEON)) -- boca
	for _, dx in { -0.14, 0.14 } do
		part(m, Vector3.new(0.1, 0.07, 0.06) * s, cf * CFrame.new(dx * s, 0.35 * s, 0.615 * s), orange) -- dentinhos
	end
	local light = Instance.new("PointLight")
	light.Color = rgb(255, 150, 60)
	light.Range = 5 + s * 2
	light.Brightness = 0.8
	light.Parent = face[#face]
	return face, light
end

-- Abóboras: três do lado direito da porta (na frente do quadro-negro) e uma pequenininha do lado esquerdo
BUILDERS.HalloweenPumpkins = function(m)
	local z = Layout.Room.MinZ
	local spots = {
		{ Vector3.new(12.6, 0, z + 1.5), 1.25 },
		{ Vector3.new(14.6, 0, z + 1.2), 0.9 },
		{ Vector3.new(13.4, 0, z + 2.8), 0.65 },
		{ Vector3.new(5.95, 0, z + 1.6), 0.6 },
	}
	local lit = {}
	for i, spot in spots do
		local face, light = pumpkin(m, spot[1], spot[2])
		table.insert(lit, { face = face, light = light, seed = i * 3.7 })
	end
	addAnimator(function(t)
		for _, l in lit do
			local n = math.noise(t * 3, l.seed)
			l.light.Brightness = 0.75 + n * 0.6
			local c = rgb(255, 180 + math.floor(n * 50), 70 + math.floor(n * 30))
			for _, p in l.face do
				p.Color = c
			end
		end
	end)
end

-- teia num canto de cima da janela: `side` = -1 canto esquerdo (abre pra direita), 1 canto direito; r = tamanho.
-- Retorna o canto (no mundo) e as direções dos fios (no mundo)
local function web(m: Model, win: Window, side: number, r: number): (Vector3, { Vector3 })
	local col = rgb(236, 232, 240)
	local props = { Transparency = 0.15, CastShadow = false }
	local f = win.Frame
	local corner = f:PointToWorldSpace(Vector3.new(side * (win.Width / 2 + 0.1), win.Height / 2 + 0.1, 0.4))
	local dirs = {}
	for i, a in { -6, -30, -55, -82 } do
		dirs[i] = f:VectorToWorldSpace(Vector3.new(-side * math.cos(math.rad(a)), math.sin(math.rad(a)), 0))
		beam(m, corner, corner + dirs[i] * r, 0.09, col, props)
	end
	for _, k in { 0.3, 0.58, 0.85 } do
		for i = 1, #dirs - 1 do
			beam(m, corner + dirs[i] * r * k, corner + dirs[i + 1] * r * k, 0.08, col, props)
		end
	end
	return corner, dirs
end

-- aranhinha pendurada num fio que desce e sobe; `normal` = pra dentro da sala (ela fica na frente da teia)
local function spider(m: Model, hang: Vector3, normal: Vector3, phase: number)
	local thread = part(m, Vector3.new(0.03, 1, 0.03), hang, rgb(236, 232, 240), { CastShadow = false })
	local face = CFrame.lookAt(hang, hang - normal) -- +Z da aranha = pra dentro da sala
	local body = { part(m, Vector3.new(0.3, 0.3, 0.3), hang, rgb(44, 40, 52), BALL) }
	for _, sx in { -1, 1 } do
		for _, dy in { -0.05, 0.08 } do
			table.insert(body, part(m, Vector3.new(0.34, 0.05, 0.05), face * CFrame.new(sx * 0.22, dy, 0), rgb(44, 40, 52)))
		end
		table.insert(body, part(m, Vector3.new(0.06, 0.06, 0.04), face * CFrame.new(sx * 0.06, 0.04, 0.15), rgb(255, 255, 255)))
	end
	local spiderRig = rig(face, body)
	addAnimator(function(t)
		local len = 1.1 + math.sin(t * 0.7 + phase) * 0.5
		thread.Size = Vector3.new(0.03, len, 0.03)
		thread.CFrame = CFrame.new(hang - Vector3.new(0, len / 2, 0))
		moveRig(spiderRig, CFrame.new(0, -len - 0.12, 0))
	end)
end

-- Teias de Aranha: na primeira janela da esquerda e na segunda da direita (as duas que aparecem inteiras
-- na tela, inclusive no celular): uma teia grande e uma pequena em cada, e uma aranhinha descendo e subindo
BUILDERS.HalloweenWebs = function(m)
	-- { janela, canto da teia grande, canto da pequena }: os cantos que a luminária e o festão menos cobrem
	for i, spec in { { "LeftBack", 1, -1 }, { "RightFront", -1, 1 } } do
		local win = WINDOWS[spec[1]]
		local corner, dirs = web(m, win, spec[2], 2.7)
		web(m, win, spec[3], 1.5)
		local normal = win.Frame.LookVector * -1
		spider(m, corner + dirs[3] * 1.6 + normal * 0.1, normal, i * 2.3)
	end
end

-- morceguinho de parede (frame com +Z pra dentro da sala); as asas batem devagar (pivô no ombro)
local function bat(m: Model, cf: CFrame, s: number, flaps: { any }, phase: number)
	local dark, darker = rgb(96, 76, 120), rgb(70, 56, 92)
	part(m, Vector3.new(0.4, 0.5, 0.2) * s, cf, dark)
	part(m, Vector3.new(0.36, 0.3, 0.22) * s, cf * CFrame.new(0, 0.36 * s, 0), dark)
	for _, sx in { -1, 1 } do
		part(m, Vector3.new(0.1, 0.16, 0.18) * s, cf * CFrame.new(sx * 0.12 * s, 0.56 * s, 0), dark) -- orelhinha
		part(m, Vector3.new(0.07, 0.07, 0.05) * s, cf * CFrame.new(sx * 0.08 * s, 0.38 * s, 0.12 * s), rgb(255, 214, 110), NEON) -- olhinho
		local shoulder = cf * CFrame.new(sx * 0.2 * s, 0.1 * s, 0)
		local wing = {
			part(m, Vector3.new(0.45, 0.3, 0.12) * s, shoulder * CFrame.new(sx * 0.22 * s, 0, 0), darker),
			part(m, Vector3.new(0.4, 0.22, 0.12) * s, shoulder * CFrame.new(sx * 0.6 * s, 0.07 * s, 0), darker),
			part(m, Vector3.new(0.22, 0.14, 0.12) * s, shoulder * CFrame.new(sx * 0.32 * s, -0.17 * s, 0), darker),
			part(m, Vector3.new(0.2, 0.14, 0.12) * s, shoulder * CFrame.new(sx * 0.68 * s, -0.1 * s, 0), darker),
		}
		table.insert(flaps, { r = rig(shoulder, wing), side = sx, phase = phase })
	end
end

-- Morceguinhos: em cima do quadro-negro, em cima da estante e nas paredes laterais (entre as janelas e em
-- cima delas), batendo as asas devagar
BUILDERS.HalloweenWall = function(m)
	local flaps = {}
	local spots: { { any } } = {
		{ CFrame.new(12.4, 10.6, WALL_Z), 1.1 },
		{ CFrame.new(14.2, 11.7, WALL_Z), 1 },
		{ CFrame.new(16, 10.5, WALL_Z), 1.1 },
		{ CFrame.new(-13.6, 10.9, WALL_Z), 1 },
		{ sideWall(-1, 9.6, -7.2), 1.2 },
		{ sideWall(-1, 11, -8.6), 1 },
		{ sideWall(-1, 11.6, -14.2), 1 },
		{ sideWall(1, 9.6, -8.6), 1.2 },
		{ sideWall(1, 10.9, -7.1), 1 },
		{ sideWall(1, 11.6, -12), 1 },
	}
	for i, b in spots do
		bat(m, b[1], b[2], flaps, i * 1.3)
	end
	addAnimator(function(t)
		for _, f in flaps do
			local amount = 0.5 + 0.5 * math.sin(t * 0.6 + f.phase)
			moveRig(f.r, CFrame.Angles(0, 0, f.side * math.sin(t * 5 + f.phase) * 0.35 * amount))
		end
	end)
end

-- fantasminha pendurado num fio, carinha pra câmera; retorna as peças com o pivô no topo
local function ghost(m: Model, top: Vector3, s: number): Rig
	local white = rgb(248, 246, 252)
	local cf = faceCamera(top)
	local props = { Transparency = 0.08 }
	local parts = {
		-- o fio entra no teto: quando o fantasma flutua pra baixo não aparece buraco
		part(m, Vector3.new(0.04, Layout.Room.Height + 0.5 - top.Y, 0.04), top + Vector3.new(0, (Layout.Room.Height + 0.5 - top.Y) / 2, 0), rgb(210, 200, 190)),
		part(m, Vector3.new(0.8, 0.3, 0.7) * s, cf * CFrame.new(0, -0.15 * s, 0), white, props),
		part(m, Vector3.new(1.1, 1, 0.9) * s, cf * CFrame.new(0, -0.8 * s, 0), white, props),
	}
	for i, dx in { -0.385, 0, 0.385 } do
		local h = if i == 2 then 0.18 else 0.32
		table.insert(parts, part(m, Vector3.new(0.33, h, 0.9) * s, cf * CFrame.new(dx * s, (-1.3 - h / 2) * s, 0), white, props))
	end
	for _, sx in { -1, 1 } do
		table.insert(parts, part(m, Vector3.new(0.25, 0.3, 0.3) * s, cf * CFrame.new(sx * 0.65 * s, -0.85 * s, 0.1 * s), white, props)) -- bracinho
		table.insert(parts, part(m, Vector3.new(0.14, 0.2, 0.05) * s, cf * CFrame.new(sx * 0.2 * s, -0.6 * s, 0.46 * s), rgb(58, 36, 30))) -- olho
		table.insert(parts, part(m, Vector3.new(0.16, 0.08, 0.05) * s, cf * CFrame.new(sx * 0.38 * s, -0.8 * s, 0.46 * s), rgb(246, 170, 190))) -- bochecha
	end
	table.insert(parts, part(m, Vector3.new(0.16, 0.12, 0.05) * s, cf * CFrame.new(0, -0.86 * s, 0.46 * s), rgb(120, 70, 80))) -- boquinha "o"
	return rig(cf, parts)
end

-- Fantasminhas: entre as vigas da frente, flutuando devagar (longe das luminárias)
BUILDERS.HalloweenGhosts = function(m)
	local z = -6.5
	local ghosts = {}
	for i, g in { { -15.5, 11.6, 1 }, { -8, 12, 0.9 }, { -1.5, 11.4, 1 }, { 8, 11.8, 0.9 }, { 15.8, 11.5, 1 } } do
		table.insert(ghosts, ghost(m, Vector3.new(g[1], g[2], z), g[3]))
	end
	addAnimator(function(t)
		for i, g in ghosts do
			moveRig(g, CFrame.new(0, math.sin(t * 1.3 + i * 1.9) * 0.25, 0) * CFrame.Angles(0, math.sin(t * 0.8 + i) * 0.18, 0))
		end
	end)
end

-- Guirlanda de Páscoa: na parede da porta, entre a janela e a porta; o coelhinho mexe a orelha de vez em quando
BUILDERS.EasterWreath = function(m)
	local c = Vector3.new(5.45, 7.3, WALL_Z)
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		local dir = Vector3.new(math.cos(a), math.sin(a), 0)
		local leaf = a + math.pi / 10
		part(m, Vector3.new(0.36, 0.22, 0.24), CFrame.new(c + Vector3.new(math.cos(leaf), math.sin(leaf), 0) * 0.74) * CFrame.Angles(0, 0, leaf + math.pi / 2), rgb(134, 186, 104))
		local cf = CFrame.new(c + dir * 0.72) * CFrame.Angles(0, 0, a - math.pi / 2)
		part(m, Vector3.new(0.36, 0.48, 0.28), cf, PASTELS[i % #PASTELS + 1])
		part(m, Vector3.new(0.37, 0.08, 0.29), cf, rgb(252, 250, 250)) -- listrinha
	end
	-- coelhinho no meio
	local white, pink = rgb(252, 250, 250), rgb(240, 160, 180)
	local h = c + Vector3.new(0, -0.08, 0.06)
	part(m, Vector3.new(0.55, 0.45, 0.25), h, white)
	for _, sx in { -1, 1 } do
		part(m, Vector3.new(0.07, 0.07, 0.04), h + Vector3.new(sx * 0.12, 0.05, 0.14), rgb(58, 36, 30))
		part(m, Vector3.new(0.12, 0.06, 0.04), h + Vector3.new(sx * 0.2, -0.08, 0.14), rgb(246, 190, 200))
	end
	part(m, Vector3.new(0.08, 0.06, 0.04), h + Vector3.new(0, -0.05, 0.14), pink)
	local ears = {}
	for _, sx in { -1, 1 } do
		local base = CFrame.new(h + Vector3.new(sx * 0.14, 0.2, 0))
		local ear = {
			part(m, Vector3.new(0.14, 0.42, 0.2), base * CFrame.new(0, 0.21, 0), white),
			part(m, Vector3.new(0.07, 0.3, 0.04), base * CFrame.new(0, 0.2, 0.1), pink),
		}
		table.insert(ears, { r = rig(base, ear), side = sx })
	end
	-- lacinho lilás embaixo
	local b = c + Vector3.new(0, -0.95, 0.15)
	part(m, Vector3.new(0.24, 0.24, 0.16), b, rgb(184, 160, 230))
	part(m, Vector3.new(0.4, 0.3, 0.12), CFrame.new(b + Vector3.new(-0.28, 0.03, 0)) * CFrame.Angles(0, 0, math.rad(-15)), rgb(204, 182, 240))
	part(m, Vector3.new(0.4, 0.3, 0.12), CFrame.new(b + Vector3.new(0.28, 0.03, 0)) * CFrame.Angles(0, 0, math.rad(15)), rgb(204, 182, 240))
	addAnimator(function(t)
		for i, e in ears do
			local cycle = (t + i * 0.9) % 3.4
			local flick = if cycle < 0.3 then math.sin(cycle / 0.3 * math.pi) * 0.5 else 0
			moveRig(e.r, CFrame.Angles(0, 0, -e.side * flick))
		end
	end)
end

-- Bandeirinhas de Páscoa: varal de bandeirinhas pastel pendurado na viga do fundo, com ovinhos nos apoios
BUILDERS.EasterBunting = function(m)
	local z = Layout.Room.MinZ + 8 -- viga em z = -14
	local anchors = { -17.5, -12, -6, 0, 6, 12, 17.5 }
	local rope = rgb(236, 220, 196)
	local flags: { Rig } = {}
	local eggs: { Rig } = {}
	local count = 0
	for s = 1, #anchors - 1 do
		local a, b = anchors[s], anchors[s + 1]
		local function at(u: number): Vector3
			return Vector3.new(a + (b - a) * u, BEAM_Y - 0.1 - 0.9 * math.sin(math.pi * u), z)
		end
		for k = 0, 7 do
			beam(m, at(k / 8), at((k + 1) / 8), 0.06, rope)
		end
		local n = math.floor((b - a) / 0.9)
		for f = 1, n - 1 do
			count += 1
			local p = at(f / n)
			local color = PASTELS[count % #PASTELS + 1]
			local pieces = {}
			for row, w in { 0.7, 0.46, 0.22 } do
				table.insert(pieces, part(m, Vector3.new(w, 0.2, 0.05), p - Vector3.new(0, row * 0.2 - 0.06, 0), color))
			end
			table.insert(flags, rig(CFrame.new(p), pieces))
		end
	end
	for i = 2, #anchors - 1 do
		local top = Vector3.new(anchors[i], BEAM_Y - 0.1, z)
		local len = 0.6 + (i % 2) * 0.35
		local color = PASTELS[(i + 2) % #PASTELS + 1]
		local thread = part(m, Vector3.new(0.04, len, 0.04), top - Vector3.new(0, len / 2, 0), rope)
		local egg = part(m, Vector3.new(0.42, 0.56, 0.42), top - Vector3.new(0, len + 0.28, 0), color)
		local band = part(m, Vector3.new(0.44, 0.1, 0.44), top - Vector3.new(0, len + 0.3, 0), rgb(252, 250, 250))
		local dot = part(m, Vector3.new(0.12, 0.12, 0.05), top - Vector3.new(0, len + 0.12, -0.22), PASTELS[(i + 4) % #PASTELS + 1])
		table.insert(eggs, rig(CFrame.new(top), { thread, egg, band, dot }))
	end
	addAnimator(function(t)
		for i, f in flags do
			moveRig(f, CFrame.Angles(math.sin(t * 1.4 + i * 0.6) * 0.14, 0, 0))
		end
		for i, e in eggs do
			moveRig(e, CFrame.Angles(math.sin(t * 1 + i) * 0.07, 0, math.sin(t * 0.8 + i * 2) * 0.06))
		end
	end)
end

-- Cesta de Ovinhos: no canto direito do balcão, atrás do pote de gorjetas; o pintinho espia de vez em quando
BUILDERS.EasterBasket = function(m)
	local base = Vector3.new(7.55, Layout.CounterHeight, Layout.CounterZ + 0.55)
	local straw, strawDark = rgb(222, 178, 110), rgb(190, 142, 82)
	part(m, Vector3.new(1.2, 0.55, 0.8), base + Vector3.new(0, 0.28, 0), straw)
	for i = -2, 2 do
		part(m, Vector3.new(0.12, 0.57, 0.82), base + Vector3.new(i * 0.24, 0.28, 0), strawDark) -- trançado
	end
	part(m, Vector3.new(1.28, 0.12, 0.88), base + Vector3.new(0, 0.58, 0), strawDark) -- borda
	part(m, Vector3.new(1.1, 0.1, 0.7), base + Vector3.new(0, 0.64, 0), rgb(150, 200, 110)) -- palhinha
	local last = base + Vector3.new(0.55, 0.62, 0)
	for k = 1, 8 do
		local a = k / 8 * math.pi
		local p = base + Vector3.new(math.cos(a) * 0.55, 0.62 + math.sin(a) * 0.6, 0)
		beam(m, last, p, 0.1, strawDark)
		last = p
	end
	for i, e in { { -0.36, 0.1, 0 }, { -0.05, -0.12, 0.3 }, { 0.12, 0.16, -0.25 } } do
		part(m, Vector3.new(0.26, 0.34, 0.26), CFrame.new(base + Vector3.new(e[1], 0.82, e[2])) * CFrame.Angles(0, 0, e[3]), PASTELS[i * 2 % #PASTELS + 1])
	end
	-- pintinho
	local chickAt = base + Vector3.new(0.36, 0.7, 0.05)
	local yellow = rgb(250, 220, 90)
	local chick = {
		part(m, Vector3.new(0.3, 0.26, 0.28), chickAt + Vector3.new(0, 0.13, 0), yellow),
		part(m, Vector3.new(0.24, 0.22, 0.22), chickAt + Vector3.new(0, 0.36, 0.02), yellow),
		part(m, Vector3.new(0.09, 0.06, 0.08), chickAt + Vector3.new(0, 0.34, 0.15), rgb(240, 150, 60)),
		part(m, Vector3.new(0.05, 0.05, 0.03), chickAt + Vector3.new(-0.06, 0.4, 0.13), rgb(58, 36, 30)),
		part(m, Vector3.new(0.05, 0.05, 0.03), chickAt + Vector3.new(0.06, 0.4, 0.13), rgb(58, 36, 30)),
	}
	local chickRig = rig(faceCamera(chickAt), chick)
	addAnimator(function(t)
		local cycle = t % 4
		local pop = if cycle < 0.6 then math.sin(cycle / 0.6 * math.pi) * 0.12 else 0
		moveRig(chickRig, CFrame.new(0, pop, 0) * CFrame.Angles(0, 0, math.sin(t * 2) * 0.08))
	end)
end

-- penduricalhos do festão de Páscoa: montados a partir do ponto onde o fio prende (cf), pendurados pra baixo.
-- Cada um devolve as peças (para balançar junto com o fio)
local CARROT, CARROT_DARK, LEAF = rgb(240, 140, 60), rgb(214, 108, 40), rgb(120, 180, 90)
local BUNNY_WHITE, BUNNY_PINK, EYE = rgb(252, 250, 250), rgb(240, 160, 180), rgb(58, 36, 30)

local function carrot(m: Model, cf: CFrame, len: number): { BasePart }
	local ps = { part(m, Vector3.new(0.04, len, 0.04), cf * CFrame.new(0, -len / 2, 0), rgb(236, 220, 196)) }
	local top = cf * CFrame.new(0, -len, 0)
	for i, dx in { -0.09, 0, 0.09 } do
		table.insert(ps, part(m, Vector3.new(0.09, 0.26, 0.08), top * CFrame.new(dx, -0.1, 0) * CFrame.Angles(0, 0, -dx * 3), if i == 2 then LEAF else rgb(96, 150, 84)))
	end
	for row, w in { 0.36, 0.3, 0.22, 0.14 } do
		local y = -0.3 - (row - 1) * 0.16
		table.insert(ps, part(m, Vector3.new(w, 0.17, 0.2), top * CFrame.new(0, y, 0), CARROT))
		if row < 4 then
			table.insert(ps, part(m, Vector3.new(w * 0.45, 0.04, 0.21), top * CFrame.new((row % 2 - 0.5) * w * 0.3, y - 0.04, 0), CARROT_DARK)) -- risquinho
		end
	end
	return ps
end

local function bunnyHead(m: Model, cf: CFrame, len: number): { BasePart }
	local ps = { part(m, Vector3.new(0.04, len, 0.04), cf * CFrame.new(0, -len / 2, 0), rgb(236, 220, 196)) }
	local top = cf * CFrame.new(0, -len, 0)
	for _, sx in { -1, 1 } do
		table.insert(ps, part(m, Vector3.new(0.13, 0.4, 0.16), top * CFrame.new(sx * 0.12, -0.2, 0) * CFrame.Angles(0, 0, sx * 0.15), BUNNY_WHITE))
		table.insert(ps, part(m, Vector3.new(0.06, 0.28, 0.04), top * CFrame.new(sx * 0.12, -0.2, 0.08) * CFrame.Angles(0, 0, sx * 0.15), BUNNY_PINK))
	end
	local h = top * CFrame.new(0, -0.6, 0)
	table.insert(ps, part(m, Vector3.new(0.52, 0.42, 0.22), h, BUNNY_WHITE))
	for _, sx in { -1, 1 } do
		table.insert(ps, part(m, Vector3.new(0.07, 0.07, 0.04), h * CFrame.new(sx * 0.12, 0.05, 0.12), EYE))
		table.insert(ps, part(m, Vector3.new(0.1, 0.05, 0.04), h * CFrame.new(sx * 0.19, -0.07, 0.12), rgb(246, 190, 200)))
	end
	table.insert(ps, part(m, Vector3.new(0.08, 0.06, 0.04), h * CFrame.new(0, -0.04, 0.12), BUNNY_PINK))
	return ps
end

local function eggCharm(m: Model, cf: CFrame, len: number, color: Color3, dots: Color3): { BasePart }
	local ps = { part(m, Vector3.new(0.04, len, 0.04), cf * CFrame.new(0, -len / 2, 0), rgb(236, 220, 196)) }
	local e = cf * CFrame.new(0, -len - 0.3, 0)
	table.insert(ps, part(m, Vector3.new(0.26, 0.1, 0.2), e * CFrame.new(0, 0.24, 0), color))
	table.insert(ps, part(m, Vector3.new(0.38, 0.4, 0.22), e, color))
	table.insert(ps, part(m, Vector3.new(0.28, 0.1, 0.2), e * CFrame.new(0, -0.24, 0), color))
	table.insert(ps, part(m, Vector3.new(0.39, 0.08, 0.23), e * CFrame.new(0, 0.02, 0), rgb(252, 250, 250))) -- faixa
	for _, d in { { -0.1, 0.13 }, { 0.1, -0.12 } } do
		table.insert(ps, part(m, Vector3.new(0.08, 0.08, 0.24), e * CFrame.new(d[1], d[2], 0), dots))
	end
	return ps
end

-- Festão de Páscoa: em todas as janelas, um festão de folhinhas com florzinhas pastel no alto da janela e
-- cenouras, coelhinhos e ovinhos pendurados balançando
BUILDERS.EasterWindowGarland = function(m)
	local charms: { Rig } = {}
	local count = 0
	for w, id in WINDOW_ORDER do
		local win = WINDOWS[id]
		local f = win.Frame
		local half, topY = win.Width / 2 + 0.15, win.Height / 2 + 0.05
		-- duas barrigas (da ponta até o meio da janela e do meio até a outra ponta)
		local anchors = { -half, 0, half }
		for s = 1, 2 do
			local a, b = anchors[s], anchors[s + 1]
			local function at(u: number): CFrame
				return f * CFrame.new(a + (b - a) * u, topY - 0.7 * math.sin(math.pi * u), 0.45)
			end
			local n = math.floor((b - a) / 0.38)
			for k = 0, n do
				local cf = at(k / n)
				part(m, Vector3.new(0.42, 0.34, 0.3), cf * CFrame.Angles(k * 0.7, k * 1.3, k * 0.5), if k % 2 == 0 then rgb(134, 186, 104) else rgb(96, 150, 84))
				if k % 3 == 1 then
					part(m, Vector3.new(0.2, 0.2, 0.12), cf * CFrame.new(0, 0.06, 0.18), PASTELS[(k + w) % #PASTELS + 1]) -- florzinha
				end
			end
			-- penduricalhos no meio de cada barriga: cenoura, coelhinho, ovinho (vai alternando de janela pra janela)
			for j, u in { 0.3, 0.7 } do
				count += 1
				local hang = at(u) * CFrame.new(0, -0.12, 0.05)
				local len = 0.25 + ((count % 3) * 0.12)
				local kind = (count + w) % 3
				local ps = if kind == 0
					then carrot(m, hang, len)
					elseif kind == 1 then bunnyHead(m, hang, len)
					else eggCharm(m, hang, len, PASTELS[(count + j) % #PASTELS + 1], PASTELS[(count + j + 2) % #PASTELS + 1])
				table.insert(charms, rig(hang, ps))
			end
		end
		-- lacinhos nos três pontos de apoio
		for i, x in anchors do
			local b = f * CFrame.new(x, topY + 0.05, 0.55)
			local color = PASTELS[(i + w) % #PASTELS + 1]
			part(m, Vector3.new(0.2, 0.2, 0.14), b, color)
			part(m, Vector3.new(0.3, 0.24, 0.1), b * CFrame.new(-0.2, 0.02, 0) * CFrame.Angles(0, 0, math.rad(-15)), color)
			part(m, Vector3.new(0.3, 0.24, 0.1), b * CFrame.new(0.2, 0.02, 0) * CFrame.Angles(0, 0, math.rad(15)), color)
		end
	end
	addAnimator(function(t)
		for i, c in charms do
			moveRig(c, CFrame.Angles(math.sin(t * 1.2 + i * 0.8) * 0.08, 0, math.sin(t * 0.9 + i * 1.7) * 0.12))
		end
	end)
end

-- Coelhinho Espião: mora dentro da planta do lado esquerdo do balcão; de tempos em tempos sobe pra espiar
-- por cima das folhas, olha pros lados, mexe a orelha e se esconde de novo (tudo com tweens).
-- Tocar nele faz ele se esconder na hora.
BUILDERS.EasterPlantBunny = function(m)
	local id = currentId
	local RISE = 1.05 -- quanto ele desce pra sumir no meio das folhas
	local peek = Vector3.new(-9, 4.12, 1.55) -- centro da cabeça quando está espiando
	local cf = faceCamera(peek)
	local ps = {}
	local function add(size: Vector3, at: CFrame, color: Color3): BasePart
		local p = part(m, size, cf * at, color)
		table.insert(ps, p)
		return p
	end
	local head = add(Vector3.new(0.66, 0.52, 0.5), CFrame.new(), BUNNY_WHITE)
	add(Vector3.new(0.5, 0.14, 0.04), CFrame.new(0, -0.14, 0.26), rgb(246, 238, 236)) -- focinho
	add(Vector3.new(0.1, 0.07, 0.04), CFrame.new(0, -0.06, 0.28), BUNNY_PINK)
	local eyes = {}
	for _, sx in { -1, 1 } do
		table.insert(eyes, add(Vector3.new(0.09, 0.11, 0.04), CFrame.new(sx * 0.15, 0.06, 0.26), EYE))
		add(Vector3.new(0.12, 0.06, 0.04), CFrame.new(sx * 0.24, -0.1, 0.26), rgb(246, 190, 200)) -- bochecha
		add(Vector3.new(0.16, 0.12, 0.14), CFrame.new(sx * 0.2, -0.3, 0.22), BUNNY_WHITE) -- patinha segurando a folha
	end
	-- orelhas: a da direita dobra de vez em quando
	local ears: { { Base: CFrame, R: Rig } } = {}
	for _, sx in { -1, 1 } do
		local base = CFrame.new(sx * 0.17, 0.24, 0) -- pé da orelha, no espaço da cabeça
		local e = {
			part(m, Vector3.new(0.16, 0.56, 0.16), cf * base * CFrame.new(0, 0.28, 0), BUNNY_WHITE),
			part(m, Vector3.new(0.08, 0.4, 0.04), cf * base * CFrame.new(0, 0.28, 0.08), BUNNY_PINK),
		}
		table.insert(ears, { Base = base, R = rig(cf * base, e) })
	end
	local body = rig(cf, ps)

	-- tweens mexem nesses valores; o rig acompanha
	local up = Instance.new("NumberValue") -- 1 = espiando, 0 = escondido
	up.Value = 1
	up.Parent = m
	local turn = Instance.new("NumberValue") -- vira a cabecinha (radianos)
	turn.Parent = m
	local ear = Instance.new("NumberValue") -- dobra a orelha (radianos)
	ear.Parent = m
	local function pose()
		local offset = CFrame.new(0, (up.Value - 1) * RISE, 0) * CFrame.Angles(0, turn.Value, 0)
		moveRig(body, offset)
		for i, e in ears do
			local target = cf * offset * e.Base * CFrame.Angles(0, 0, if i == 2 then -ear.Value else 0)
			moveRig(e.R, e.R.Pivot:Inverse() * target)
		end
	end
	for _, v in { up, turn, ear } do
		v.Changed:Connect(function()
			if not appearing[id] then
				pose()
			end
		end)
	end

	local function tween(v: NumberValue, goal: number, time: number, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
		local tw = TweenService:Create(v, TweenInfo.new(time, style or Enum.EasingStyle.Sine, dir or Enum.EasingDirection.InOut), { Value = goal })
		tw:Play()
		task.wait(time)
	end
	local function alive(): boolean
		return built[id] == m
	end
	local hiding = false
	clickables[head] = function()
		if hiding or appearing[id] or up.Value < 0.5 then
			return
		end
		hiding = true
		Sfx.play("CutePop")
		TweenService:Create(turn, TweenInfo.new(0.15), { Value = 0 }):Play()
		TweenService:Create(up, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = 0 }):Play()
	end
	task.spawn(function()
		local t0 = os.clock()
		repeat
			task.wait(0.2)
		until (built[id] == m and not appearing[id]) or os.clock() - t0 > 30
		task.wait(1.2)
		while alive() do
			-- escondido
			if not hiding then
				tween(up, 0, 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			end
			task.wait(2.5 + math.random() * 3)
			hiding = false
			if not alive() then
				break
			end
			-- sobe devagarinho até os olhos, para, e aparece de vez
			tween(up, 0.72, 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			task.wait(0.5)
			if hiding or not alive() then
				continue
			end
			tween(up, 1, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			-- olha pros lados e mexe a orelha
			for _, a in { 0.45, -0.45, 0 } do
				if hiding or not alive() then
					break
				end
				tween(turn, a, 0.3)
				task.wait(0.45)
			end
			if not hiding and alive() then
				tween(ear, 0.8, 0.15)
				tween(ear, 0, 0.2)
				task.wait(0.9)
			end
		end
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

-- Desmonta uma decoração (sem animação): tira as animações e os cliques dela
local function unbuild(id: string)
	local old = built[id]
	if not old then
		return
	end
	for i = #animators, 1, -1 do
		if animators[i].Id == id then
			table.remove(animators, i)
		end
	end
	for p in clickables do
		if p:IsDescendantOf(old) then
			clickables[p] = nil
		end
	end
	old:Destroy()
	built[id] = nil
end

-- decorações compradas que o jogador desligou na loja (não aparecem no café)
local hidden: { [string]: boolean } = {}

function Decor.setHidden(list: { [string]: boolean })
	hidden = list
end

-- Deixa o café igual ao que foi comprado e está ligado: constrói (sem animação) o que falta, exceto os ids
-- em `skip`, e desmonta o que foi desligado
function Decor.apply(owned: { [string]: boolean }, skip: { [string]: boolean }?)
	for id in BUILDERS do
		local wanted = owned[id] and not hidden[id]
		if wanted and not built[id] and not (skip and skip[id]) then
			build(id)
		elseif not wanted and built[id] and not appearing[id] then
			unbuild(id)
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
	unbuild("Cat")
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
