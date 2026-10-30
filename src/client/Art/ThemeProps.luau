--!strict
-- Peças extras dos temas da fachada (client/OutsideTheme): neve acumulada, folhas no chão, poças,
-- enfeites de Natal e de Halloween. Tudo bloquinho, montado só no cliente.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.Layout)

local rgb = Color3.fromRGB

export type Ctx = {
	Folder: Folder,
	Rng: Random,
	part: (size: Vector3, cf: CFrame | Vector3, color: Color3, props: { [string]: any }?) -> BasePart,
	tagged: (role: string) -> { BasePart },
	animate: (fn: (t: number, dt: number) -> ()) -> (),
	light: (parent: BasePart, brightness: number, range: number, color: Color3) -> PointLight,
}

local R = Layout.Room
local DOOR_X = Layout.DoorX
local FACE_Z = R.MinZ - 1 -- face externa da fachada
local FENCE_Z = R.MinZ - 10.3
local GROUND = -0.12 -- topo da grama
local BED_TOP = 0.125 -- topo dos canteiros
local TREE = Vector3.new(23, 0, R.MinZ - 4.5) -- árvore grande do balanço

local SNOW = rgb(246, 249, 255)
local SNOW_SHADE = rgb(222, 232, 246)
local ICE = rgb(196, 228, 248)

local ThemeProps = {}

-- altura do chão num ponto do jardim (canteiros são mais altos que a grama)
local function groundAt(x: number, z: number): number
	local inFrontBed = z > R.MinZ - 3.2 and z < R.MinZ - 1.4 and (x < DOOR_X - 3 or x > DOOR_X + 3)
	local inFenceBed = z > FENCE_Z + 0.6 and z < FENCE_Z + 1.8 and ((x > -8 and x < DOOR_X - 2.8) or (x > DOOR_X + 2.8 and x < 15))
	return if inFrontBed or inFenceBed then BED_TOP else GROUND
end

-- peça inclinada entre dois pontos
local function beam(ctx: Ctx, a: Vector3, b: Vector3, thickness: number, color: Color3): BasePart
	local mid = (a + b) / 2
	local dir = b - a
	return ctx.part(Vector3.new(thickness, thickness, dir.Magnitude), CFrame.lookAt(mid, b), color)
end

-- partes de um modelo animado: guarda o offset de cada peça em relação ao pivô
type Rig = { Parts: { BasePart }, Offsets: { CFrame } }

local function rig(parts: { BasePart }, pivot: CFrame): Rig
	local offsets = {}
	for i, p in parts do
		offsets[i] = pivot:ToObjectSpace(p.CFrame)
	end
	return { Parts = parts, Offsets = offsets }
end

local function placeRig(r: Rig, pivot: CFrame, cfs: { CFrame }, all: { BasePart })
	for i, p in r.Parts do
		table.insert(all, p)
		table.insert(cfs, pivot * r.Offsets[i])
	end
end

---------------------------------------------------------------- inverno

local function mound(ctx: Ctx, pos: Vector3, w: number, d: number, h: number)
	ctx.part(Vector3.new(w, h * 0.5, d), pos + Vector3.new(0, h * 0.25, 0), SNOW_SHADE)
	ctx.part(Vector3.new(w * 0.75, h * 0.4, d * 0.7), pos + Vector3.new(w * 0.05, h * 0.65, 0), SNOW)
	ctx.part(Vector3.new(w * 0.4, h * 0.3, d * 0.4), pos + Vector3.new(-w * 0.08, h * 0.95, 0), SNOW)
end

local function snowman(ctx: Ctx, base: Vector3)
	local face = -1 -- olha pra rua (-Z)
	ctx.part(Vector3.new(2.4, 2, 2.4), base + Vector3.new(0, 1, 0), SNOW)
	ctx.part(Vector3.new(1.8, 1.6, 1.8), base + Vector3.new(0, 2.75, 0), SNOW)
	ctx.part(Vector3.new(1.3, 1.2, 1.3), base + Vector3.new(0, 4.1, 0), SNOW)
	-- botões de carvão
	for i = 0, 2 do
		ctx.part(Vector3.new(0.22, 0.22, 0.1), base + Vector3.new(0, 2.3 + i * 0.4, face * 0.92), rgb(50, 46, 52))
	end
	-- olhinhos, bochechas e nariz de cenoura
	for _, dx in { -0.28, 0.28 } do
		ctx.part(Vector3.new(0.18, 0.18, 0.1), base + Vector3.new(dx, 4.3, face * 0.67), rgb(40, 36, 42))
		ctx.part(Vector3.new(0.2, 0.12, 0.08), base + Vector3.new(dx * 1.45, 4.0, face * 0.67), rgb(250, 170, 180))
	end
	ctx.part(Vector3.new(0.2, 0.2, 0.7), base + Vector3.new(0, 4.1, face * 0.95), rgb(240, 140, 60))
	-- cachecol vermelho com a pontinha caindo
	ctx.part(Vector3.new(1.45, 0.3, 1.45), base + Vector3.new(0, 3.55, 0), rgb(214, 70, 70))
	ctx.part(Vector3.new(0.35, 0.9, 0.12), base + Vector3.new(0.4, 3.15, face * 0.8), rgb(214, 70, 70))
	ctx.part(Vector3.new(0.35, 0.12, 0.13), base + Vector3.new(0.4, 2.85, face * 0.8), rgb(250, 240, 230))
	-- gorrinho
	ctx.part(Vector3.new(1.2, 0.45, 1.2), base + Vector3.new(0, 4.85, 0), rgb(110, 150, 200))
	ctx.part(Vector3.new(0.8, 0.35, 0.8), base + Vector3.new(0, 5.2, 0), rgb(110, 150, 200))
	ctx.part(Vector3.new(0.4, 0.4, 0.4), base + Vector3.new(0, 5.55, 0), rgb(250, 248, 244))
	-- bracinhos de galho
	local twig = rgb(110, 76, 52)
	beam(ctx, base + Vector3.new(0.8, 2.9, 0), base + Vector3.new(2, 3.7, 0), 0.15, twig)
	beam(ctx, base + Vector3.new(-0.8, 2.9, 0), base + Vector3.new(-2, 3.5, 0), 0.15, twig)
	beam(ctx, base + Vector3.new(1.7, 3.5, 0), base + Vector3.new(1.95, 4.05, 0), 0.12, twig)
end

-- janelas da frente (vidro visto de fora): x0, x1, y0, y1 e o plano do lado de fora do vidro
local FRONT_WINDOWS = { { -11, -4, 4, 10.5 }, { -2, 4, 4, 10.5 } }
local GLASS_Z = R.MinZ - 0.85

-- geada nas bordas dos vidros: bloquinhos que entram mais nos cantos, em escadinha (pixel)
local function frostWindows(ctx: Ctx)
	local cell = 0.4
	local tones = { rgb(250, 253, 255), rgb(200, 226, 248) }
	for _, w in FRONT_WINDOWS do
		local x0, x1, y0, y1 = w[1], w[2], w[3], w[4]
		local function depth(a: number, len: number): number
			local fromCorner = math.min(a, len - a)
			local n = ctx.Rng:NextInteger(1, 2) + (if fromCorner < 1 then 2 elseif fromCorner < 1.8 then 1 else 0)
			return n * cell
		end
		local i = 0
		local x = x0
		while x < x1 - 0.01 do
			local wd = math.min(cell, x1 - x)
			for _, edge in { { y1, -1 }, { y0, 1 } } do
				local d = depth(x - x0 + wd / 2, x1 - x0) * (if edge[2] > 0 then 0.7 else 1)
				i += 1
				ctx.part(Vector3.new(wd, d, 0.06), Vector3.new(x + wd / 2, edge[1] + edge[2] * d / 2, GLASS_Z), tones[i % 2 + 1], { Transparency = 0.05 })
			end
			x += cell
		end
		local y = y0
		while y < y1 - 0.01 do
			local hd = math.min(cell, y1 - y)
			for _, edge in { { x0, 1 }, { x1, -1 } } do
				local d = depth(y - y0 + hd / 2, y1 - y0)
				i += 1
				ctx.part(Vector3.new(d, hd, 0.06), Vector3.new(edge[1] + edge[2] * d / 2, y + hd / 2, GLASS_Z - 0.01), tones[i % 2 + 1], { Transparency = 0.05 })
			end
			y += cell
		end
	end
end

function ThemeProps.winter(ctx: Ctx)
	-- neve em cima das folhagens e do que é reto (cerca, floreiras, banco, placa...)
	for _, role in { "Foliage", "Cap" } do
		for _, p in ctx.tagged(role) do
			if p.CFrame.UpVector.Y < 0.95 then
				continue
			end
			local s = p.Size
			local h = math.clamp(math.min(s.X, s.Z) * 0.12, 0.1, 0.45)
			ctx.part(Vector3.new(s.X + 0.12, h, s.Z + 0.12), p.CFrame * CFrame.new(0, s.Y / 2 + h / 2 - 0.02, 0), SNOW)
			if s.X >= 3 and s.Z >= 3 then
				local o = Vector3.new(ctx.Rng:NextNumber(-0.15, 0.15) * s.X, s.Y / 2 + h * 1.3, ctx.Rng:NextNumber(-0.15, 0.15) * s.Z)
				ctx.part(Vector3.new(s.X * 0.6, h * 0.8, s.Z * 0.55), p.CFrame * CFrame.new(o), SNOW)
			end
		end
	end
	-- telhado coberto e pingentes de gelo na beirada da frente
	for _, roof in ctx.tagged("Roof") do
		local s = roof.Size
		ctx.part(Vector3.new(s.X + 0.2, 0.45, s.Z + 0.3), roof.CFrame * CFrame.new(0, 0.62, -0.1), SNOW)
		local u = -s.X / 2 + 0.8
		while u < s.X / 2 - 0.4 do
			local edge = (roof.CFrame * CFrame.new(u, -0.6, -s.Z / 2 - 0.25)).Position
			local len = ctx.Rng:NextNumber(0.35, 1.1)
			ctx.part(Vector3.new(0.18, len, 0.18), edge - Vector3.new(0, len / 2, 0), ICE, { Transparency = 0.15 })
			u += ctx.Rng:NextNumber(0.7, 1.2)
		end
	end
	-- montinhos de neve pelo jardim e na calçada
	for _, m in {
		{ Vector3.new(-9, GROUND, FENCE_Z + 2.6), 3, 1.6, 0.9 },
		{ Vector3.new(3.5, GROUND, FENCE_Z + 2.3), 2.4, 1.4, 0.7 },
		{ Vector3.new(16, GROUND, FENCE_Z + 2.4), 3.2, 1.5, 0.8 },
		{ Vector3.new(DOOR_X - 2.3, GROUND, R.MinZ - 7), 1.6, 1.2, 0.6 },
		{ Vector3.new(DOOR_X + 2.4, GROUND, R.MinZ - 6.3), 1.8, 1.2, 0.6 },
		{ Vector3.new(-16, -0.05, R.MinZ - 14), 3, 1.4, 0.8 },
		{ Vector3.new(24, -0.05, R.MinZ - 13.6), 2.6, 1.3, 0.7 },
	} do
		mound(ctx, m[1], m[2], m[3], m[4])
	end
	frostWindows(ctx)
end

---------------------------------------------------------------- outono

local LEAVES = { rgb(232, 124, 52), rgb(214, 76, 50), rgb(242, 184, 64), rgb(204, 104, 42), rgb(180, 64, 46) }

local function leaf(ctx: Ctx, x: number, y: number, z: number, tilt: number?)
	local c = LEAVES[ctx.Rng:NextInteger(1, #LEAVES)]
	ctx.part(Vector3.new(0.6, 0.06, 0.45), CFrame.new(x, y, z) * CFrame.Angles(tilt or 0, ctx.Rng:NextNumber(0, math.pi), 0), c)
end

local function leafPile(ctx: Ctx, center: Vector3, radius: number, height: number)
	for _ = 1, math.floor(radius * radius * 9) do
		local a = ctx.Rng:NextNumber(0, math.pi * 2)
		local r = math.sqrt(ctx.Rng:NextNumber()) * radius
		local y = center.Y + 0.05 + (1 - r / radius) * height + ctx.Rng:NextNumber(0, 0.12)
		leaf(ctx, center.X + math.cos(a) * r, y, center.Z + math.sin(a) * r, ctx.Rng:NextNumber(-0.4, 0.4))
	end
end

function ThemeProps.autumn(ctx: Ctx)
	-- folhas espalhadas pelo gramado (mais embaixo da árvore grande)
	local placed = 0
	while placed < 110 do
		local x = ctx.Rng:NextNumber(-12, 27)
		local z = ctx.Rng:NextNumber(FENCE_Z + 0.4, R.MinZ - 1.6)
		if x > DOOR_X - 1.4 and x < DOOR_X + 1.4 then
			continue
		end
		leaf(ctx, x, groundAt(x, z) + 0.04, z)
		placed += 1
	end
	for _ = 1, 40 do
		local a = ctx.Rng:NextNumber(0, math.pi * 2)
		local r = ctx.Rng:NextNumber(1.5, 7)
		local x, z = TREE.X + math.cos(a) * r, TREE.Z + math.sin(a) * r * 0.6
		leaf(ctx, x, groundAt(x, z) + 0.04, z)
	end
	-- algumas na calçada e na rua
	for _ = 1, 24 do
		leaf(ctx, ctx.Rng:NextNumber(-30, 34), -0.02, ctx.Rng:NextNumber(R.MinZ - 17, R.MinZ - 13))
	end
	-- montes de folhas
	leafPile(ctx, Vector3.new(TREE.X - 4, GROUND, TREE.Z - 2), 1.5, 0.7)
	leafPile(ctx, Vector3.new(-8.5, GROUND, FENCE_Z + 2.4), 1.2, 0.5)
	leafPile(ctx, Vector3.new(3, GROUND, FENCE_Z + 2.4), 1, 0.45)
	leafPile(ctx, Vector3.new(-16, -0.05, R.MinZ - 14), 1.3, 0.55)
	-- folhas no telhado
	for _, roof in ctx.tagged("Roof") do
		local s = roof.Size
		for _ = 1, 14 do
			local cf = roof.CFrame * CFrame.new(ctx.Rng:NextNumber(-s.X / 2 + 1, s.X / 2 - 1), 0.62, ctx.Rng:NextNumber(-s.Z / 2 + 0.5, -s.Z / 2 + 8))
			ctx.part(Vector3.new(0.6, 0.06, 0.45), cf * CFrame.Angles(0, ctx.Rng:NextNumber(0, math.pi), 0), LEAVES[ctx.Rng:NextInteger(1, #LEAVES)])
		end
	end
end

---------------------------------------------------------------- chuva

function ThemeProps.rain(ctx: Ctx)
	local water = rgb(126, 146, 172)
	local puddles = {
		{ Vector3.new(DOOR_X + 0.4, 0.06, R.MinZ - 6.8), Vector2.new(2, 1.2) },
		{ Vector3.new(DOOR_X - 0.6, -0.03, R.MinZ - 12.2), Vector2.new(1.8, 1.4) },
		{ Vector3.new(-6, -0.03, R.MinZ - 15.4), Vector2.new(3, 1.6) },
		{ Vector3.new(17, -0.03, R.MinZ - 14.6), Vector2.new(2.6, 1.4) },
		{ Vector3.new(-3, -0.1, R.MinZ - 6), Vector2.new(2.4, 1.4) },
		{ Vector3.new(15, -0.1, R.MinZ - 7.4), Vector2.new(2, 1.2) },
		{ Vector3.new(2, -0.06, R.MinZ - 21), Vector2.new(4, 2) },
		{ Vector3.new(26, -0.06, R.MinZ - 22.4), Vector2.new(3.4, 1.6) },
	}
	for _, pd in puddles do
		local c, s = pd[1], pd[2]
		ctx.part(Vector3.new(s.X, 0.04, s.Y), c, water, { Transparency = 0.25, Reflectance = 0.3 })
		ctx.part(Vector3.new(s.X * 0.6, 0.04, s.Y * 1.35), c + Vector3.new(s.X * 0.1, 0.002, 0), water, { Transparency = 0.25, Reflectance = 0.3 })
	end

	-- ondinhas quadradas (pixel) crescendo nas poças
	local ripples = {}
	for i = 1, 10 do
		local sides = {}
		for _ = 1, 4 do
			table.insert(sides, ctx.part(Vector3.new(0.1, 0.03, 0.1), Vector3.zero, rgb(220, 232, 244), { Transparency = 1 }))
		end
		table.insert(ripples, { Sides = sides, Start = -i * 0.17, At = Vector3.zero })
	end
	ctx.animate(function(t)
		for _, r in ripples do
			local age = t - r.Start
			if age > 0.9 or age < 0 then
				local pd = puddles[ctx.Rng:NextInteger(1, #puddles)]
				r.At = pd[1] + Vector3.new(ctx.Rng:NextNumber(-0.3, 0.3) * pd[2].X, 0.04, ctx.Rng:NextNumber(-0.3, 0.3) * pd[2].Y)
				r.Start = t + ctx.Rng:NextNumber(0, 0.3)
				age = t - r.Start
			end
			local k = math.clamp(age / 0.9, 0, 1)
			local half = 0.12 + k * 0.45
			local alpha = if age < 0 then 1 else 0.2 + k * 0.8
			local s = r.Sides
			s[1].Size = Vector3.new(half * 2, 0.03, 0.06)
			s[2].Size = Vector3.new(half * 2, 0.03, 0.06)
			s[3].Size = Vector3.new(0.06, 0.03, half * 2)
			s[4].Size = Vector3.new(0.06, 0.03, half * 2)
			s[1].CFrame = CFrame.new(r.At + Vector3.new(0, 0, half))
			s[2].CFrame = CFrame.new(r.At - Vector3.new(0, 0, half))
			s[3].CFrame = CFrame.new(r.At + Vector3.new(half, 0, 0))
			s[4].CFrame = CFrame.new(r.At - Vector3.new(half, 0, 0))
			for _, p in s do
				p.Transparency = alpha
			end
		end
	end)
end

---------------------------------------------------------------- natal

local XMAS = { rgb(236, 64, 64), rgb(80, 196, 110), rgb(255, 206, 80), rgb(90, 150, 240), rgb(250, 140, 200) }
local PINE = rgb(56, 112, 74)
local PINE_LIGHT = rgb(76, 140, 92)

-- pisca-pisca: lâmpadas que alternam acesas/apagadas em grupos
local function bulbs(ctx: Ctx, points: { Vector3 }, list: { { Part: BasePart, Color: Color3, Group: number } })
	for _, pos in points do
		local i = #list + 1
		local color = XMAS[(i - 1) % #XMAS + 1]
		local p = ctx.part(Vector3.new(0.3, 0.38, 0.3), pos, color, { Material = Enum.Material.Neon })
		table.insert(list, { Part = p, Color = color, Group = i % 2 })
	end
end

local function pineInPot(ctx: Ctx, base: Vector3, lights: { { Part: BasePart, Color: Color3, Group: number } })
	ctx.part(Vector3.new(1.1, 0.9, 1.1), base + Vector3.new(0, 0.45, 0), rgb(196, 110, 76))
	ctx.part(Vector3.new(1.25, 0.2, 1.25), base + Vector3.new(0, 0.95, 0), rgb(176, 96, 66))
	local layers = { { 1.8, 1.3 }, { 1.4, 2.1 }, { 1, 2.8 }, { 0.6, 3.4 } }
	for i, l in layers do
		ctx.part(Vector3.new(l[1], 0.75, l[1]), base + Vector3.new(0, l[2], 0), if i % 2 == 0 then PINE_LIGHT else PINE)
		ctx.part(Vector3.new(l[1] * 0.8, 0.12, l[1] * 0.8), base + Vector3.new(0, l[2] + 0.42, 0), SNOW)
	end
	ctx.part(Vector3.new(0.35, 0.35, 0.12), base + Vector3.new(0, 3.95, 0), rgb(255, 214, 90), { Material = Enum.Material.Neon })
	local pts = {}
	for i, l in layers do
		if i < #layers then
			for _, o in { Vector3.new(-l[1] / 2, 0, -l[1] / 2 + 0.1), Vector3.new(l[1] / 2 - 0.1, -0.15, -l[1] / 2), Vector3.new(0, 0.1, -l[1] / 2 - 0.05) } do
				table.insert(pts, base + Vector3.new(0, l[2] - 0.2, 0) + o)
			end
		end
	end
	bulbs(ctx, pts, lights)
end

local function gift(ctx: Ctx, base: Vector3, size: Vector3, color: Color3, ribbon: Color3)
	ctx.part(size, base + Vector3.new(0, size.Y / 2, 0), color)
	ctx.part(Vector3.new(size.X + 0.04, size.Y + 0.04, 0.18), base + Vector3.new(0, size.Y / 2, 0), ribbon)
	ctx.part(Vector3.new(0.18, size.Y + 0.04, size.Z + 0.04), base + Vector3.new(0, size.Y / 2, 0), ribbon)
	ctx.part(Vector3.new(0.5, 0.22, 0.22), base + Vector3.new(0, size.Y + 0.11, 0), ribbon)
end

local function candyCane(ctx: Ctx, base: Vector3)
	local h = 1.6
	for i = 0, 7 do
		ctx.part(Vector3.new(0.22, h / 8, 0.22), base + Vector3.new(0, (i + 0.5) * h / 8, 0), if i % 2 == 0 then rgb(240, 70, 70) else rgb(252, 250, 246))
	end
	ctx.part(Vector3.new(0.5, 0.22, 0.22), base + Vector3.new(0.14, h + 0.1, 0), rgb(252, 250, 246))
	ctx.part(Vector3.new(0.22, 0.4, 0.22), base + Vector3.new(0.39, h - 0.1, 0), rgb(240, 70, 70))
end

-- trenó do Papai Noel com as renas, montado em volta da origem olhando +X
local function sleigh(ctx: Ctx): { BasePart }
	local parts: { BasePart } = {}
	local S = 1.8 -- escala do conjunto (precisa ser visível lá do fundo)
	local function add(size: Vector3, pos: Vector3, color: Color3, props: { [string]: any }?)
		table.insert(parts, ctx.part(size * S, pos * S, color, props))
	end
	local red, gold, white, brown = rgb(220, 56, 60), rgb(248, 196, 70), rgb(252, 250, 246), rgb(150, 96, 62)
	-- trenó
	add(Vector3.new(3.2, 1.2, 1.9), Vector3.new(0, 0.8, 0), red)
	add(Vector3.new(0.6, 2, 1.9), Vector3.new(-1.5, 1.3, 0), red)
	add(Vector3.new(3.3, 0.2, 2), Vector3.new(0, 1.45, 0), gold)
	for _, z in { -0.8, 0.8 } do
		add(Vector3.new(4, 0.18, 0.18), Vector3.new(0.3, -0.05, z), gold)
		add(Vector3.new(0.18, 0.6, 0.18), Vector3.new(2.3, 0.15, z), gold)
	end
	-- saco de presentes
	add(Vector3.new(1.2, 1.3, 1.3), Vector3.new(-1.2, 2.3, 0), rgb(150, 100, 70))
	add(Vector3.new(0.5, 0.5, 0.5), Vector3.new(-1.1, 3.1, 0.2), rgb(80, 196, 110))
	-- Papai Noel
	add(Vector3.new(1, 1.2, 1.1), Vector3.new(0.3, 2.1, 0), red)
	add(Vector3.new(1.05, 0.25, 1.15), Vector3.new(0.3, 1.75, 0), rgb(40, 34, 36))
	add(Vector3.new(0.8, 0.75, 0.8), Vector3.new(0.4, 3.05, 0), rgb(250, 210, 180))
	add(Vector3.new(0.45, 0.6, 0.9), Vector3.new(0.75, 2.75, 0), white) -- barba
	add(Vector3.new(0.15, 0.15, 0.15), Vector3.new(0.82, 3.12, 0), rgb(240, 140, 140)) -- nariz
	add(Vector3.new(0.85, 0.35, 0.85), Vector3.new(0.4, 3.55, 0), red)
	add(Vector3.new(0.9, 0.15, 0.9), Vector3.new(0.4, 3.38, 0), white)
	add(Vector3.new(0.3, 0.3, 0.3), Vector3.new(0.05, 3.75, 0), white)
	add(Vector3.new(0.9, 0.25, 0.3), Vector3.new(1, 2.3, 0.45), red) -- braço segurando a rédea
	-- renas (a da frente com o nariz brilhando)
	local deer = {
		{ Vector3.new(5, 0.8, -0.8), false },
		{ Vector3.new(5, 0.8, 0.8), false },
		{ Vector3.new(7.6, 1.1, -0.8), false },
		{ Vector3.new(7.6, 1.1, 0.8), false },
		{ Vector3.new(10.2, 1.4, 0), true },
	}
	for _, d in deer do
		local p: Vector3 = d[1]
		add(Vector3.new(1.6, 0.8, 0.7), p, brown)
		add(Vector3.new(0.5, 0.8, 0.5), p + Vector3.new(0.9, 0.6, 0), brown)
		add(Vector3.new(0.7, 0.5, 0.5), p + Vector3.new(1.25, 1.05, 0), brown)
		add(Vector3.new(0.2, 0.2, 0.2), p + Vector3.new(1.65, 1, 0), if d[2] then rgb(255, 60, 60) else rgb(60, 40, 36), if d[2] then { Material = Enum.Material.Neon } else nil)
		for _, dz in { -0.2, 0.2 } do
			add(Vector3.new(0.12, 0.6, 0.12), p + Vector3.new(1.1, 1.55, dz * 1.5), rgb(220, 196, 150)) -- chifres
			add(Vector3.new(0.35, 0.12, 0.12), p + Vector3.new(1.2, 1.75, dz * 1.5), rgb(220, 196, 150))
		end
		for _, o in { Vector3.new(-0.55, -0.6, -0.2), Vector3.new(0.55, -0.6, 0.2) } do
			add(Vector3.new(0.18, 0.6, 0.18), p + o, rgb(110, 70, 46))
		end
		add(Vector3.new(0.3, 0.2, 0.8), p + Vector3.new(0.9, 0.25, 0), red) -- coleira
	end
	-- rédeas
	add(Vector3.new(9, 0.08, 0.08), Vector3.new(5.6, 1.7, -0.6), gold)
	add(Vector3.new(9, 0.08, 0.08), Vector3.new(5.6, 1.7, 0.6), gold)
	return parts
end

function ThemeProps.christmas(ctx: Ctx)
	snowman(ctx, Vector3.new(-4.5, GROUND, R.MinZ - 7.5))
	local lights: { { Part: BasePart, Color: Color3, Group: number } } = {}

	-- pisca-pisca na beirada do telhado
	for _, roof in ctx.tagged("Roof") do
		local s = roof.Size
		local pts = {}
		local u = -s.X / 2 + 0.5
		while u < s.X / 2 - 0.3 do
			local sag = math.abs(math.sin(u * 0.9)) * 0.25
			table.insert(pts, (roof.CFrame * CFrame.new(u, 0, -s.Z / 2 - 0.45)).Position - Vector3.new(0, 0.9 + sag, 0))
			u += 0.9
		end
		bulbs(ctx, pts, lights)
	end
	-- pisca-pisca na cerca
	local fencePts = {}
	for _, seg in { { -11.6, DOOR_X - 2.8 }, { DOOR_X + 2.8, 25.6 } } do
		local x = seg[1]
		while x <= seg[2] do
			table.insert(fencePts, Vector3.new(x, 1.32 - math.abs(math.sin(x * 1.3)) * 0.12, FENCE_Z - 0.15))
			x += 1.1
		end
	end
	bulbs(ctx, fencePts, lights)

	-- festão verde com laços e bolinhas no toldo da porta
	local awningZ = FACE_Z - 2.15
	for i = 0, 10 do
		local x = DOOR_X - 2.5 + i * 0.5
		local y = 9.15 - math.sin(i / 10 * math.pi) * 0.45
		ctx.part(Vector3.new(0.6, 0.45, 0.45), Vector3.new(x, y, awningZ), if i % 2 == 0 then PINE else PINE_LIGHT)
		if i % 2 == 1 then
			ctx.part(Vector3.new(0.28, 0.28, 0.28), Vector3.new(x, y - 0.3, awningZ - 0.15), XMAS[(i // 2) % #XMAS + 1], { Shape = Enum.PartType.Ball })
		end
	end
	for _, x in { DOOR_X - 2.6, DOOR_X + 2.6 } do
		ctx.part(Vector3.new(0.6, 0.4, 0.2), Vector3.new(x, 9.3, awningZ - 0.25), rgb(220, 50, 56))
		ctx.part(Vector3.new(0.18, 0.8, 0.15), Vector3.new(x - 0.12, 8.8, awningZ - 0.27), rgb(220, 50, 56))
		ctx.part(Vector3.new(0.18, 0.7, 0.15), Vector3.new(x + 0.14, 8.85, awningZ - 0.27), rgb(220, 50, 56))
	end
	-- guirlanda na porta aberta (presa na face de fora da folha da porta)
	local wreath = Vector3.new(DOOR_X + 2.5, 5.6, R.MinZ - 3.1)
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		ctx.part(Vector3.new(0.3, 0.5, 0.5), wreath + Vector3.new(0, math.cos(a) * 0.85, math.sin(a) * 0.85), if i % 2 == 0 then PINE else PINE_LIGHT)
		if i % 3 == 0 then
			ctx.part(Vector3.new(0.32, 0.22, 0.22), wreath + Vector3.new(0.05, math.cos(a + 0.4) * 0.85, math.sin(a + 0.4) * 0.85), rgb(236, 64, 64))
		end
	end
	ctx.part(Vector3.new(0.3, 0.35, 0.6), wreath + Vector3.new(0.05, -0.85, 0), rgb(220, 50, 56))

	-- pinheirinhos com pisca nos dois lados da porta, presentes e bengalinhas no caminho
	-- (a folha da porta aberta fica em x = DOOR_X + 2.2, saindo da parede: o pinheiro da direita fica antes dela)
	pineInPot(ctx, Vector3.new(DOOR_X - 2.4, GROUND, R.MinZ - 2), lights)
	pineInPot(ctx, Vector3.new(DOOR_X + 1.5, GROUND, R.MinZ - 2), lights)
	gift(ctx, Vector3.new(DOOR_X - 2.5, GROUND, R.MinZ - 3.3), Vector3.new(0.8, 0.7, 0.8), rgb(80, 150, 220), rgb(255, 214, 90))
	gift(ctx, Vector3.new(DOOR_X - 1.8, GROUND, R.MinZ - 3.4), Vector3.new(0.6, 0.5, 0.6), rgb(236, 90, 110), rgb(252, 250, 246))
	gift(ctx, Vector3.new(DOOR_X + 1.75, GROUND, R.MinZ - 3.7), Vector3.new(0.7, 0.8, 0.7), rgb(90, 180, 110), rgb(236, 64, 64))
	for i = 0, 2 do
		local z = R.MinZ - 4.8 - i * 2.2
		candyCane(ctx, Vector3.new(DOOR_X - 1.5, GROUND, z))
		candyCane(ctx, Vector3.new(DOOR_X + 1.5, GROUND, z))
	end

	-- bolinhas coloridas e estrela na árvore grande
	for _, p in ctx.tagged("Foliage") do
		if not (p.Parent and p.Parent.Name == "BigTree") or p.Size.X < 4 then
			continue
		end
		local s = p.Size
		local n = math.floor(s.X * s.Y / 7)
		for k = 1, n do
			local onFront = k % 3 ~= 0
			local pos
			if onFront then
				pos = p.Position + Vector3.new(ctx.Rng:NextNumber(-0.42, 0.42) * s.X, ctx.Rng:NextNumber(-0.4, 0.4) * s.Y, -s.Z / 2 - 0.2)
			else
				pos = p.Position + Vector3.new(-s.X / 2 - 0.2, ctx.Rng:NextNumber(-0.4, 0.4) * s.Y, ctx.Rng:NextNumber(-0.42, 0.42) * s.Z)
			end
			if k % 4 == 0 then
				local b = ctx.part(Vector3.new(0.3, 0.38, 0.3), pos, XMAS[ctx.Rng:NextInteger(1, #XMAS)], { Material = Enum.Material.Neon })
				table.insert(lights, { Part = b, Color = b.Color, Group = k % 2 })
			else
				ctx.part(Vector3.new(0.7, 0.7, 0.7), pos, XMAS[ctx.Rng:NextInteger(1, #XMAS)], { Shape = Enum.PartType.Ball, Reflectance = 0.15 })
				ctx.part(Vector3.new(0.2, 0.2, 0.2), pos + Vector3.new(0, 0.4, 0), rgb(255, 214, 90))
			end
		end
	end
	local top = TREE + Vector3.new(2, 24, -1)
	local star = rgb(255, 214, 80)
	ctx.part(Vector3.new(0.6, 1.8, 0.3), top, star, { Material = Enum.Material.Neon })
	ctx.part(Vector3.new(1.8, 0.6, 0.3), top, star, { Material = Enum.Material.Neon })
	ctx.part(Vector3.new(1, 1, 0.32), CFrame.new(top) * CFrame.Angles(0, 0, math.rad(45)), star, { Material = Enum.Material.Neon })
	local glow = ctx.part(Vector3.new(0.2, 0.2, 0.2), top, star, { Transparency = 1 })
	ctx.light(glow, 1, 12, star)

	-- pisca: alterna os grupos a cada meio segundo (só muda quando troca, não todo frame)
	local lastTick = -1
	ctx.animate(function(t)
		local tick = math.floor(t / 0.55)
		if tick == lastTick then
			return
		end
		lastTick = tick
		for _, l in lights do
			local on = (l.Group + tick) % 2 == 0 or (tick % 6 == 0)
			l.Part.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
			l.Part.Color = if on then l.Color else l.Color:Lerp(Color3.new(0, 0, 0), 0.45)
		end
	end)

	-- Papai Noel cruzando o céu atrás da loja de tempos em tempos
	local parts = sleigh(ctx)
	local santa = rig(parts, CFrame.new())
	local hidden = CFrame.new(0, -200, 0)
	local PERIOD, CROSS = 36, 20
	local cfs: { CFrame } = {}
	local all: { BasePart } = {}
	-- começa escondido (senão aparece um frame montado no meio do café)
	placeRig(santa, hidden, cfs, all)
	workspace:BulkMoveTo(all, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	ctx.animate(function(t)
		local k = ((t + 8) % PERIOD) / CROSS
		local pivot
		if k > 1 then
			pivot = hidden
		else
			local x = -110 + k * 230
			-- logo atrás da loja, alto o bastante pra passar por cima do telhado visto da tela de início
			pivot = CFrame.new(x, 47 + math.sin(t * 2) * 1.2 + k * 3, R.MaxZ + 5) * CFrame.Angles(0, 0, math.rad(6 + math.sin(t * 2) * 3))
		end
		table.clear(cfs)
		table.clear(all)
		placeRig(santa, pivot, cfs, all)
		workspace:BulkMoveTo(all, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end)
end

---------------------------------------------------------------- halloween

local PUMPKIN = rgb(238, 132, 44)
local PUMPKIN_DARK = rgb(204, 100, 34)
local FLAME = rgb(255, 196, 90)

-- abóbora com carinha acesa virada pra -Z; retorna a peça da luz
local function jackOLantern(ctx: Ctx, base: Vector3, scale: number, lit: boolean): BasePart
	local s = scale
	ctx.part(Vector3.new(1.5, 1.1, 1.4) * s, base + Vector3.new(0, 0.55 * s, 0), PUMPKIN)
	for _, dx in { -0.45, 0, 0.45 } do
		ctx.part(Vector3.new(0.14, 1.12, 1.42) * s, base + Vector3.new(dx * s, 0.55 * s, 0), PUMPKIN_DARK)
	end
	ctx.part(Vector3.new(0.2, 0.35, 0.2) * s, base + Vector3.new(0.05 * s, 1.25 * s, 0), rgb(96, 120, 56))
	ctx.part(Vector3.new(0.35, 0.12, 0.25) * s, base + Vector3.new(0.25 * s, 1.15 * s, 0), rgb(110, 150, 70))
	local face = if lit then FLAME else rgb(60, 36, 24)
	local props = if lit then { Material = Enum.Material.Neon } else nil
	local fz = base.Z - 0.71 * s
	for _, dx in { -0.32, 0.32 } do
		ctx.part(Vector3.new(0.26, 0.22, 0.05) * s, Vector3.new(base.X + dx * s, base.Y + 0.75 * s, fz), face, props)
		ctx.part(Vector3.new(0.12, 0.12, 0.05) * s, Vector3.new(base.X + dx * s, base.Y + 0.9 * s, fz), face, props)
	end
	ctx.part(Vector3.new(0.75, 0.14, 0.05) * s, Vector3.new(base.X, base.Y + 0.38 * s, fz), face, props)
	for _, dx in { -0.25, 0, 0.25 } do
		ctx.part(Vector3.new(0.12, 0.12, 0.05) * s, Vector3.new(base.X + dx * s, base.Y + 0.48 * s, fz), face, props)
	end
	return ctx.part(Vector3.new(0.3, 0.3, 0.3) * s, base + Vector3.new(0, 0.6 * s, -0.3 * s), FLAME, { Transparency = 1 })
end

local function candle(ctx: Ctx, base: Vector3, h: number): BasePart
	ctx.part(Vector3.new(0.28, h, 0.28), base + Vector3.new(0, h / 2, 0), rgb(250, 240, 216))
	ctx.part(Vector3.new(0.04, 0.12, 0.04), base + Vector3.new(0, h + 0.06, 0), rgb(50, 40, 36))
	return ctx.part(Vector3.new(0.16, 0.24, 0.16), base + Vector3.new(0, h + 0.2, 0), FLAME, { Material = Enum.Material.Neon })
end

-- vassoura de bruxa encostada na parede: base no chão, topo do cabo apoiado na fachada
local function broom(ctx: Ctx, foot: Vector3, top: Vector3)
	local handle = rgb(156, 104, 64)
	local dir = (top - foot).Unit
	beam(ctx, foot + dir * 1.2, top, 0.24, handle)
	-- nozinho torto na ponta do cabo
	ctx.part(Vector3.new(0.26, 0.26, 0.26), top, rgb(80, 52, 36))
	-- cerdas: blocos de palha abrindo pra baixo, amarrados com fita roxa
	local up = CFrame.lookAt(foot, top) -- -Z local aponta pro topo
	local straw = { rgb(220, 176, 92), rgb(196, 150, 70), rgb(236, 196, 110) }
	for i, o in { Vector3.new(-0.22, 0, -0.1), Vector3.new(0.22, 0, -0.1), Vector3.new(0, 0.18, -0.1), Vector3.new(0, -0.18, -0.1), Vector3.new(0, 0, 0) } do
		ctx.part(Vector3.new(0.3, 0.3, 1.1), up * CFrame.new(o.X, o.Y, -0.45 + o.Z), straw[(i - 1) % #straw + 1])
	end
	ctx.part(Vector3.new(0.55, 0.55, 0.18), up * CFrame.new(0, 0, -1.05), rgb(140, 80, 170))
	ctx.part(Vector3.new(0.3, 0.3, 0.2), up * CFrame.new(0.32, 0.12, -1.05), rgb(170, 110, 200)) -- lacinho
end

-- teia em leque no plano da fachada: centro, raio e ângulos (graus; 0 = direita, 90 = cima)
local function web(ctx: Ctx, center: Vector3, radius: number, a0: number, a1: number, spokes: number)
	local silk = rgb(246, 246, 252)
	local pts: { { Vector3 } } = {}
	for i = 0, spokes - 1 do
		local a = math.rad(a0 + (a1 - a0) * i / (spokes - 1))
		local dir = Vector3.new(math.cos(a), math.sin(a), 0)
		beam(ctx, center, center + dir * radius, 0.09, silk)
		local ring = {}
		for k, f in { 0.32, 0.6, 0.88 } do
			-- fio que cede um pouquinho entre os raios (fofo, não geométrico demais)
			ring[k] = center + dir * radius * f
		end
		pts[i + 1] = ring
	end
	for i = 1, spokes - 1 do
		for k = 1, 3 do
			local a, b = pts[i][k], pts[i + 1][k]
			local mid = (a + b) / 2 + (center - (a + b) / 2) * 0.12
			beam(ctx, a, mid, 0.07, silk)
			beam(ctx, mid, b, 0.07, silk)
		end
	end
end

-- aranhinha fofa (olhões) descendo e subindo num fio; retorna a função de animação
local function spider(ctx: Ctx, anchor: Vector3, length: number, phase: number): (t: number) -> ()
	local body = rgb(58, 46, 70)
	local parts: { BasePart } = {}
	local offsets: { CFrame } = {}
	local function add(size: Vector3, offset: Vector3, color: Color3)
		table.insert(parts, ctx.part(size, Vector3.zero, color))
		table.insert(offsets, CFrame.new(offset))
	end
	add(Vector3.new(0.5, 0.42, 0.45), Vector3.new(0, 0, 0), body)
	add(Vector3.new(0.34, 0.3, 0.3), Vector3.new(0, -0.08, -0.32), body)
	for _, dx in { -0.09, 0.09 } do
		add(Vector3.new(0.12, 0.12, 0.04), Vector3.new(dx, -0.02, -0.48), rgb(250, 250, 250))
		add(Vector3.new(0.06, 0.06, 0.04), Vector3.new(dx, -0.04, -0.5), rgb(30, 24, 36))
	end
	for side = -1, 1, 2 do
		for k = 0, 3 do
			add(Vector3.new(0.34, 0.06, 0.06), Vector3.new(side * 0.36, -0.05 - (k % 2) * 0.05, -0.18 + k * 0.13), body)
			add(Vector3.new(0.06, 0.2, 0.06), Vector3.new(side * 0.52, -0.15, -0.18 + k * 0.13), body)
		end
	end
	local thread = ctx.part(Vector3.new(0.03, length, 0.03), anchor, rgb(236, 236, 246), { Transparency = 0.2 })
	local cfs: { CFrame } = {}
	return function(t: number)
		local len = length * (0.72 + 0.28 * (0.5 + 0.5 * math.sin(t * 0.7 + phase)))
		local pos = anchor - Vector3.new(0, len + 0.2, 0)
		local pivot = CFrame.new(pos) * CFrame.Angles(0, math.sin(t * 0.9 + phase) * 0.4, 0)
		for i, o in offsets do
			cfs[i] = pivot * o
		end
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		thread.Size = Vector3.new(0.03, len, 0.03)
		thread.CFrame = CFrame.new(anchor - Vector3.new(0, len / 2, 0))
	end
end

local function scarecrow(ctx: Ctx, base: Vector3)
	local wood, straw = rgb(120, 82, 56), rgb(236, 200, 100)
	ctx.part(Vector3.new(0.3, 4.6, 0.3), base + Vector3.new(0, 2.3, 0), wood)
	ctx.part(Vector3.new(3.6, 0.25, 0.25), base + Vector3.new(0, 3.6, 0), wood)
	-- camisa xadrez e calça remendada
	local plaid = { rgb(214, 80, 60), rgb(240, 150, 80) }
	for i = -2, 2 do
		ctx.part(Vector3.new(0.4, 1.4, 0.75), base + Vector3.new(i * 0.24, 3.2, 0), plaid[(i + 2) % 2 + 1])
	end
	for _, side in { -1, 1 } do
		ctx.part(Vector3.new(1.1, 0.5, 0.55), base + Vector3.new(side * 1.05, 3.6, 0), plaid[1])
		ctx.part(Vector3.new(0.35, 0.5, 0.5), base + Vector3.new(side * 1.75, 3.6, 0), straw) -- palha das mãos
		ctx.part(Vector3.new(0.35, 0.9, 0.5), base + Vector3.new(side * 0.25, 2.1, 0), rgb(96, 120, 170))
		ctx.part(Vector3.new(0.3, 0.35, 0.4), base + Vector3.new(side * 0.25, 1.5, 0), straw)
	end
	ctx.part(Vector3.new(0.3, 0.3, 0.05), base + Vector3.new(-0.2, 2.2, -0.27), rgb(240, 200, 90)) -- remendo
	-- cabeça de saco com carinha costurada
	local head = base + Vector3.new(0, 4.55, 0)
	ctx.part(Vector3.new(1.1, 1.05, 1), head, rgb(222, 194, 140))
	for _, dx in { -0.22, 0.22 } do
		ctx.part(Vector3.new(0.16, 0.16, 0.05), head + Vector3.new(dx, 0.12, -0.52), rgb(50, 40, 40))
	end
	ctx.part(Vector3.new(0.5, 0.06, 0.05), head + Vector3.new(0, -0.22, -0.52), rgb(110, 70, 50))
	for _, dx in { -0.2, 0, 0.2 } do
		ctx.part(Vector3.new(0.04, 0.14, 0.05), head + Vector3.new(dx, -0.22, -0.53), rgb(110, 70, 50))
	end
	for _, dx in { -0.36, 0.36 } do
		ctx.part(Vector3.new(0.18, 0.1, 0.04), head + Vector3.new(dx, -0.08, -0.52), rgb(240, 150, 140))
	end
	-- chapéu de palha
	ctx.part(Vector3.new(1.8, 0.14, 1.7), head + Vector3.new(0, 0.6, 0), rgb(200, 150, 70))
	ctx.part(Vector3.new(0.95, 0.6, 0.9), head + Vector3.new(0, 0.95, 0), rgb(200, 150, 70))
	ctx.part(Vector3.new(0.97, 0.15, 0.92), head + Vector3.new(0, 0.75, 0), rgb(170, 60, 60))
	-- corvinho no braço
	local crow = base + Vector3.new(1.4, 4.05, 0)
	ctx.part(Vector3.new(0.55, 0.4, 0.35), crow, rgb(44, 40, 52))
	ctx.part(Vector3.new(0.3, 0.3, 0.3), crow + Vector3.new(-0.3, 0.25, 0), rgb(44, 40, 52))
	ctx.part(Vector3.new(0.2, 0.08, 0.1), crow + Vector3.new(-0.5, 0.22, 0), rgb(240, 180, 60))
end

function ThemeProps.halloween(ctx: Ctx)
	-- abóboras acesas na porta e nos pilares do portão
	local glows = {
		jackOLantern(ctx, Vector3.new(DOOR_X - 3.1, GROUND, R.MinZ - 3.9), 1.15, true),
		jackOLantern(ctx, Vector3.new(DOOR_X + 1.2, GROUND, R.MinZ - 2), 1, true),
		jackOLantern(ctx, Vector3.new(DOOR_X - 0.6 - 2, 2.55, FENCE_Z), 0.55, true),
		jackOLantern(ctx, Vector3.new(DOOR_X + 0.6 + 2, 2.55, FENCE_Z), 0.55, true),
	}
	jackOLantern(ctx, Vector3.new(DOOR_X - 1.6, GROUND, R.MinZ - 3.6), 0.6, false)
	jackOLantern(ctx, Vector3.new(-9, BED_TOP, R.MinZ - 2.4), 0.7, false)
	jackOLantern(ctx, Vector3.new(17, BED_TOP, FENCE_Z + 1.2), 0.8, false)
	local lights = {}
	for i, g in glows do
		table.insert(lights, ctx.light(g, if i <= 2 then 1.2 else 0.6, if i <= 2 then 9 else 6, rgb(255, 150, 60)))
	end

	-- velinhas pelo jardim e nas floreiras
	local flames = {}
	for _, pos in {
		Vector3.new(-7, GROUND, R.MinZ - 5),
		Vector3.new(-6.4, GROUND, R.MinZ - 5.3),
		Vector3.new(2.5, GROUND, R.MinZ - 5.4),
		Vector3.new(DOOR_X - 1.4, GROUND, R.MinZ - 6.5),
		Vector3.new(DOOR_X + 1.4, GROUND, R.MinZ - 6.5),
		Vector3.new(DOOR_X - 1.4, GROUND, R.MinZ - 8.6),
		Vector3.new(DOOR_X + 1.4, GROUND, R.MinZ - 8.6),
		Vector3.new(15.5, GROUND, R.MinZ - 6),
		Vector3.new(16.1, GROUND, R.MinZ - 6.3),
		Vector3.new(20, GROUND, R.MinZ - 8.5),
		Vector3.new(-1.5, BED_TOP, FENCE_Z + 1.2),
		Vector3.new(13, BED_TOP, FENCE_Z + 1.2),
	} do
		table.insert(flames, candle(ctx, pos, ctx.Rng:NextNumber(0.4, 0.9)))
	end
	for _, x in { -10.6, -4.6, -1.5, 3.4 } do
		table.insert(flames, candle(ctx, Vector3.new(x, 3.9, FACE_Z - 0.65), 0.35))
	end
	local flameBase = {}
	for i, f in flames do
		flameBase[i] = f.CFrame
	end
	ctx.animate(function(t)
		for i, f in flames do
			local n = math.noise(t * 4, i * 1.7)
			f.Size = Vector3.new(0.16, 0.24 + n * 0.08, 0.16)
			f.CFrame = flameBase[i] * CFrame.new(n * 0.03, n * 0.04, 0)
		end
		for i, l in lights do
			l.Brightness = (if i <= 2 then 1.2 else 0.6) * (0.85 + math.noise(t * 3, i * 3.1) * 0.4)
		end
	end)

	scarecrow(ctx, Vector3.new(-5, GROUND, R.MinZ - 7))

	-- vassoura de bruxa encostada do lado esquerdo da porta
	broom(ctx, Vector3.new(DOOR_X - 1.7, GROUND + 0.05, R.MinZ - 2.2), Vector3.new(DOOR_X - 2.45, 5.1, FACE_Z - 0.6))

	-- teias nos cantos de cima da fachada, no oitão e numa janela, com aranhinhas penduradas
	local wz = FACE_Z - 0.6
	web(ctx, Vector3.new(R.MinX - 0.3, 13.5, wz), 3.2, -90, 0, 5)
	web(ctx, Vector3.new(R.MaxX + 0.3, 13.5, wz), 3.2, 180, 270, 5)
	web(ctx, Vector3.new(-6.5, 17.6, wz), 1.6, 0, 360, 9)
	web(ctx, Vector3.new(7.5, 16.6, wz), 1.2, 0, 360, 8)
	web(ctx, Vector3.new(-11.25, 10.75, wz - 0.1), 1.4, -90, 0, 4)
	web(ctx, Vector3.new(4.25, 10.75, wz - 0.1), 1.2, 180, 270, 4)
	for i, s in {
		{ Vector3.new(R.MinX + 1.1, 13.2, wz), 2.4 },
		{ Vector3.new(-6.5, 17.4, wz - 0.05), 1.6 },
		{ Vector3.new(R.MaxX - 1.4, 12.9, wz), 3.4 },
		{ Vector3.new(3.4, 10.3, wz - 0.15), 1.2 },
	} do
		ctx.animate(spider(ctx, s[1], s[2], i * 1.9))
	end

	-- morcegos voando em roda (sobre a árvore e o telhado)
	local bats = {}
	local batColor, wingColor = rgb(52, 44, 64), rgb(72, 60, 88)
	for i = 1, 7 do
		local body = ctx.part(Vector3.new(0.5, 0.45, 0.4), Vector3.zero, batColor)
		local earL = ctx.part(Vector3.new(0.12, 0.2, 0.1), Vector3.zero, batColor)
		local earR = ctx.part(Vector3.new(0.12, 0.2, 0.1), Vector3.zero, batColor)
		local wingL = ctx.part(Vector3.new(0.9, 0.08, 0.5), Vector3.zero, wingColor)
		local wingR = ctx.part(Vector3.new(0.9, 0.08, 0.5), Vector3.zero, wingColor)
		local eyeL = ctx.part(Vector3.new(0.08, 0.08, 0.04), Vector3.zero, rgb(255, 220, 120), { Material = Enum.Material.Neon })
		local eyeR = ctx.part(Vector3.new(0.08, 0.08, 0.04), Vector3.zero, rgb(255, 220, 120), { Material = Enum.Material.Neon })
		local center = if i <= 3 then TREE + Vector3.new(0, 23, -1) elseif i <= 5 then Vector3.new(0, 27, -6) else Vector3.new(-14, 20, R.MinZ - 8)
		table.insert(bats, {
			Parts = { body, earL, earR, wingL, wingR, eyeL, eyeR },
			Center = center,
			Radius = ctx.Rng:NextNumber(4, 9),
			Speed = ctx.Rng:NextNumber(0.6, 1.1) * (if i % 2 == 0 then 1 else -1),
			Phase = ctx.Rng:NextNumber(0, math.pi * 2),
			Scale = ctx.Rng:NextNumber(0.9, 1.4),
		})
	end
	local all: { BasePart } = {}
	local cfs: { CFrame } = {}
	for _, b in bats do
		for _, p in b.Parts do
			p.Size *= b.Scale
			table.insert(all, p)
		end
	end
	ctx.animate(function(t)
		table.clear(cfs)
		for _, b in bats do
			local a = t * b.Speed + b.Phase
			local pos = b.Center + Vector3.new(math.cos(a) * b.Radius, math.sin(t * 1.7 + b.Phase) * 1.2, math.sin(a) * b.Radius * 0.6)
			local vel = Vector3.new(-math.sin(a), 0, math.cos(a) * 0.6) * b.Speed
			local root = CFrame.lookAt(pos, pos + vel)
			local flap = math.sin(t * 14 + b.Phase) * 0.7
			local s = b.Scale
			table.insert(cfs, root)
			table.insert(cfs, root * CFrame.new(-0.14 * s, 0.3 * s, 0))
			table.insert(cfs, root * CFrame.new(0.14 * s, 0.3 * s, 0))
			table.insert(cfs, root * CFrame.Angles(0, 0, flap) * CFrame.new(-0.65 * s, 0, 0.05 * s))
			table.insert(cfs, root * CFrame.Angles(0, 0, -flap) * CFrame.new(0.65 * s, 0, 0.05 * s))
			table.insert(cfs, root * CFrame.new(-0.12 * s, 0.06 * s, -0.21 * s))
			table.insert(cfs, root * CFrame.new(0.12 * s, 0.06 * s, -0.21 * s))
		end
		workspace:BulkMoveTo(all, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end)
end

return ThemeProps
