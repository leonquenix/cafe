--!strict
-- Gera o café inteiro com Parts: chão, paredes, janelas, balcão, mesas, plantas e luzes.
-- Tudo minimalista ("pixel 3D"), SmoothPlastic e cores quentes.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.Layout)

local rgb = Color3.fromRGB
local rng = Random.new(20260926)

local C = {
	WoodDark = rgb(92, 58, 40),
	Wood = rgb(140, 92, 60),
	WoodLight = rgb(196, 146, 98),
	WoodPale = rgb(222, 184, 138),
	Plaster = rgb(244, 230, 206),
	PlasterShade = rgb(226, 206, 178),
	Trim = rgb(250, 242, 226),
	Sage = rgb(150, 182, 150),
	Mustard = rgb(224, 172, 84),
	Terracotta = rgb(196, 110, 76),
	Leaf = rgb(96, 150, 84),
	LeafDark = rgb(66, 116, 64),
	LeafLight = rgb(134, 186, 104),
	Glass = rgb(186, 220, 236),
	Chalk = rgb(46, 56, 52),
	Cream = rgb(250, 242, 226),
	Rose = rgb(228, 150, 150),
	Warm = rgb(255, 196, 130),
}

local Scenery = {}

local root: Model
local buildCottage: (Instance) -> ()
local buildGarden: (Instance) -> ()

local function part(parent: Instance, size: Vector3, cf: CFrame | Vector3, color: Color3, props: { [string]: any }?): BasePart
	local p: BasePart
	local shape = props and props.Shape
	p = Instance.new("Part")
	if shape then
		(p :: Part).Shape = shape
	end
	p.Anchored = true
	p.Size = size
	p.CFrame = if typeof(cf) == "Vector3" then CFrame.new(cf) else cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = true
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

local function folder(name: string, parent: Instance?): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent or root
	return m
end

-- cilindro "deitado" em pé (o eixo do cilindro do Roblox é X)
local function upright(pos: Vector3): CFrame
	return CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
end

local function light(parent: BasePart, brightness: number, range: number, color: Color3?, shadows: boolean?)
	local l = Instance.new("PointLight")
	l.Brightness = brightness
	l.Range = range
	l.Color = color or C.Warm
	l.Shadows = shadows or false
	l.Parent = parent
end

---------------------------------------------------------------- chão

local function buildFloor()
	local m = folder("Floor")
	local R = Layout.Room
	local tones = { C.Wood, rgb(150, 100, 66), rgb(128, 84, 56) }
	local z = R.MinZ
	local strip = 0
	while z < R.MaxZ do
		local x = R.MinX - rng:NextNumber(0, 4)
		while x < R.MaxX do
			local len = rng:NextInteger(5, 9)
			local x0 = math.max(x, R.MinX)
			local x1 = math.min(x + len, R.MaxX)
			if x1 - x0 > 0.05 then
				local tone = tones[rng:NextInteger(1, #tones)]
				part(m, Vector3.new(x1 - x0 - 0.12, 1, 1.9), Vector3.new((x0 + x1) / 2, -0.5, z + 1), tone)
			end
			x += len
		end
		-- rejunte escuro por baixo das tábuas
		part(m, Vector3.new(R.MaxX - R.MinX, 0.9, 2), Vector3.new((R.MinX + R.MaxX) / 2, -0.56, z + 1), C.WoodDark)
		z += 2
		strip += 1
	end

	-- tapete aconchegante na área das mesas
	local rug = folder("Rug", m)
	part(rug, Vector3.new(11, 0.1, 13), Vector3.new(-11.5, 0.05, -11), C.Rose)
	part(rug, Vector3.new(9.6, 0.12, 11.6), Vector3.new(-11.5, 0.06, -11), C.Cream)
	part(rug, Vector3.new(8.4, 0.14, 10.4), Vector3.new(-11.5, 0.07, -11), C.Sage)
	for i = -2, 2 do
		part(rug, Vector3.new(0.8, 0.15, 0.8), Vector3.new(-11.5 + i * 1.6, 0.08, -11), C.Mustard)
	end
end

---------------------------------------------------------------- paredes

type Opening = { a0: number, a1: number, y0: number, y1: number, kind: string }

local BANDS = {
	{ 0, 0.4, C.WoodDark }, -- rodapé
	{ 0.4, 3.2, C.Wood }, -- lambri
	{ 3.2, 3.6, C.Trim }, -- moldura
	{ 3.6, 13.2, C.Plaster },
	{ 13.2, 14, C.PlasterShade },
}

-- Constrói uma parede ao longo de um eixo (a), recortando as aberturas.
-- toWorld(a, y) -> Vector3 do centro, e sizeOf(len, h) -> Vector3
local function buildWall(
	parent: Instance,
	a0: number,
	a1: number,
	openings: { Opening },
	toWorld: (number, number) -> Vector3,
	sizeOf: (number, number) -> Vector3,
	bands: { { any } }?
)
	local cuts = { a0, a1 }
	for _, o in openings do
		table.insert(cuts, o.a0)
		table.insert(cuts, o.a1)
	end
	table.sort(cuts)

	for i = 1, #cuts - 1 do
		local ca, cb = cuts[i], cuts[i + 1]
		if cb - ca < 0.01 then
			continue
		end
		local mid = (ca + cb) / 2
		local holes = {}
		for _, o in openings do
			if o.a0 < mid and mid < o.a1 then
				table.insert(holes, { o.y0, o.y1 })
			end
		end
		table.sort(holes, function(h1, h2)
			return h1[1] < h2[1]
		end)

		local solids = {}
		local y = 0
		for _, h in holes do
			if h[1] > y then
				table.insert(solids, { y, h[1] })
			end
			y = math.max(y, h[2])
		end
		if y < Layout.Room.Height then
			table.insert(solids, { y, Layout.Room.Height })
		end

		for _, s in solids do
			for _, band in bands or BANDS do
				local y0 = math.max(s[1], band[1])
				local y1 = math.min(s[2], band[2])
				if y1 - y0 > 0.01 then
					part(parent, sizeOf(cb - ca, y1 - y0), toWorld(mid, (y0 + y1) / 2), band[3])
				end
			end
		end
	end
end

local function windowDressing(parent: Instance, center: Vector3, width: number, height: number, normal: Vector3)
	-- normal aponta para dentro da sala
	local right = Vector3.new(0, 1, 0):Cross(normal).Unit
	local cf = CFrame.fromMatrix(center, right, Vector3.yAxis, -normal)
	part(parent, Vector3.new(width, height, 0.2), cf, C.Glass, { Transparency = 0.6, CastShadow = false })
	local t = 0.35
	part(parent, Vector3.new(width + t * 2, t, 0.6), cf * CFrame.new(0, height / 2 + t / 2, 0), C.Trim)
	part(parent, Vector3.new(width + t * 2, t, 0.6), cf * CFrame.new(0, -height / 2 - t / 2, 0), C.Trim)
	part(parent, Vector3.new(t, height, 0.6), cf * CFrame.new(width / 2 + t / 2, 0, 0), C.Trim)
	part(parent, Vector3.new(t, height, 0.6), cf * CFrame.new(-width / 2 - t / 2, 0, 0), C.Trim)
	part(parent, Vector3.new(0.2, height, 0.3), cf, C.Trim) -- mainel vertical
	part(parent, Vector3.new(width, 0.2, 0.3), cf * CFrame.new(0, height * 0.15, 0), C.Trim)
	-- peitoril com floreira
	local sill = cf * CFrame.new(0, -height / 2 - 0.4, -0.7)
	part(parent, Vector3.new(width + 1, 0.3, 1.2), sill, C.Trim)
	part(parent, Vector3.new(width - 0.6, 0.8, 0.9), sill * CFrame.new(0, 0.55, 0), C.Terracotta)
	local flowerColors = { C.Rose, C.Mustard, rgb(250, 250, 240), rgb(200, 150, 220) }
	local n = math.floor(width / 0.9)
	for i = 0, n - 1 do
		local x = -width / 2 + 0.6 + i * ((width - 1.2) / math.max(n - 1, 1))
		part(parent, Vector3.new(0.5, 0.6, 0.5), sill * CFrame.new(x, 1.2, 0), C.Leaf)
		if i % 2 == 0 then
			part(parent, Vector3.new(0.45, 0.45, 0.45), sill * CFrame.new(x, 1.65, 0), flowerColors[(i // 2) % #flowerColors + 1])
		end
	end
end

local function buildWalls()
	local m = folder("Walls")
	local R = Layout.Room
	local T = 1

	-- parede da porta (fundo, visível da câmera)
	local doorA0, doorA1 = Layout.DoorX - 2, Layout.DoorX + 2
	local backOpenings: { Opening } = {
		{ a0 = -11, a1 = -4, y0 = 4, y1 = 10.5, kind = "window" },
		{ a0 = -2, a1 = 4, y0 = 4, y1 = 10.5, kind = "window" },
		{ a0 = doorA0, a1 = doorA1, y0 = 0, y1 = 8.5, kind = "door" },
	}
	buildWall(m, R.MinX, R.MaxX, backOpenings, function(a, y)
		return Vector3.new(a, y, R.MinZ - T / 2)
	end, function(len, h)
		return Vector3.new(len, h, T)
	end)
	for _, o in backOpenings do
		if o.kind == "window" then
			windowDressing(m, Vector3.new((o.a0 + o.a1) / 2, (o.y0 + o.y1) / 2, R.MinZ - T / 2), o.a1 - o.a0, o.y1 - o.y0, Vector3.new(0, 0, 1))
		end
	end
	-- batente da porta + capacho
	local dz = R.MinZ - T / 2
	part(m, Vector3.new(0.5, 8.9, 1.3), Vector3.new(doorA0 - 0.25, 4.45, dz), C.WoodDark)
	part(m, Vector3.new(0.5, 8.9, 1.3), Vector3.new(doorA1 + 0.25, 4.45, dz), C.WoodDark)
	part(m, Vector3.new(doorA1 - doorA0 + 1, 0.5, 1.3), Vector3.new(Layout.DoorX, 8.75, dz), C.WoodDark)
	-- porta aberta encostada na parede externa
	part(m, Vector3.new(0.3, 8.3, doorA1 - doorA0), CFrame.new(doorA1 + 0.2, 4.15, dz - 0.6 - (doorA1 - doorA0) / 2), C.Sage)
	-- barreira invisível: dá pra ver lá fora, mas não dá pra sair andando
	part(m, Vector3.new(doorA1 - doorA0, 9, 1), Vector3.new(Layout.DoorX, 4.5, dz), C.Trim, {
		Transparency = 1,
		CastShadow = false,
		Name = "DoorBarrier",
	})
	part(m, Vector3.new(3.4, 0.08, 2.2), Vector3.new(Layout.DoorX, 0.04, R.MinZ + 1.4), C.Terracotta)
	part(m, Vector3.new(2.8, 0.1, 1.6), Vector3.new(Layout.DoorX, 0.05, R.MinZ + 1.4), C.Mustard)

	-- paredes laterais
	local sideOpenings: { Opening } = {
		{ a0 = -16, a1 = -10, y0 = 4, y1 = 10.5, kind = "window" },
		{ a0 = -6, a1 = 0, y0 = 4, y1 = 10.5, kind = "window" },
	}
	for _, side in { -1, 1 } do
		local x = if side < 0 then R.MinX - T / 2 else R.MaxX + T / 2
		buildWall(m, R.MinZ, R.MaxZ, sideOpenings, function(a, y)
			return Vector3.new(x, y, a)
		end, function(len, h)
			return Vector3.new(T, h, len)
		end)
		for _, o in sideOpenings do
			windowDressing(m, Vector3.new(x, (o.y0 + o.y1) / 2, (o.a0 + o.a1) / 2), o.a1 - o.a0, o.y1 - o.y0, Vector3.new(-side, 0, 0))
		end
	end

	-- parede atrás do barista
	buildWall(m, R.MinX, R.MaxX, {}, function(a, y)
		return Vector3.new(a, y, R.MaxZ + T / 2)
	end, function(len, h)
		return Vector3.new(len, h, T)
	end)

	-- teto + vigas
	local ceil = folder("Ceiling")
	part(ceil, Vector3.new(R.MaxX - R.MinX + 2, 1, R.MaxZ - R.MinZ + 2), Vector3.new(0, R.Height + 0.5, (R.MinZ + R.MaxZ) / 2), C.PlasterShade)
	local z = R.MinZ + 3
	while z < R.MaxZ do
		part(ceil, Vector3.new(R.MaxX - R.MinX, 0.8, 0.8), Vector3.new(0, R.Height - 0.4, z), C.WoodDark)
		z += 5
	end
end

---------------------------------------------------------------- lado de fora

local function tree(parent: Instance, pos: Vector3, scale: number)
	part(parent, Vector3.new(1, 4, 1) * scale, pos + Vector3.new(0, 2 * scale, 0), C.WoodDark)
	part(parent, Vector3.new(5, 3, 5) * scale, pos + Vector3.new(0, 5 * scale, 0), C.LeafDark)
	part(parent, Vector3.new(4, 2.4, 4) * scale, pos + Vector3.new(0.4, 7 * scale, 0.3), C.Leaf)
	part(parent, Vector3.new(2.6, 1.6, 2.6) * scale, pos + Vector3.new(-0.3, 8.6 * scale, -0.2), C.LeafLight)
end

-- Peça "inclinada" entre dois pontos (vigas diagonais, galhos, cordas)
local function beam(parent: Instance, a: Vector3, b: Vector3, thickness: number, depth: number, color: Color3): BasePart
	local mid = (a + b) / 2
	local dir = b - a
	local cf = CFrame.lookAt(mid, mid + dir) * CFrame.Angles(0, math.rad(90), 0)
	return part(parent, Vector3.new(dir.Magnitude, thickness, depth), cf, color)
end

local COTTAGE = {
	Stone = rgb(178, 168, 154),
	StoneDark = rgb(146, 136, 124),
	StoneLight = rgb(200, 192, 178),
	Plaster = rgb(248, 238, 216),
	Timber = rgb(86, 58, 42),
	Roof = rgb(172, 80, 64),
	RoofLine = rgb(138, 60, 50),
	Shutter = rgb(120, 160, 136),
	Soil = rgb(98, 72, 54),
	Picket = rgb(248, 246, 238),
}

local FLOWERS = {
	rgb(244, 150, 176),
	rgb(236, 96, 110),
	rgb(250, 212, 96),
	rgb(196, 160, 232),
	rgb(252, 252, 246),
	rgb(250, 160, 110),
	rgb(150, 180, 240),
}

-- Fachada estilo cottage: base de pedra, enxaimel, telhado de duas águas e chaminé
function buildCottage(parent: Instance)
	local m = folder("Cottage", parent)
	local R = Layout.Room
	local fz = R.MinZ - 1 -- face externa da parede da frente
	local cz = fz - 0.1 -- plano do revestimento
	local doorA0, doorA1 = Layout.DoorX - 2, Layout.DoorX + 2
	local windows = { { -11, -4 }, { -2, 4 } }

	-- revestimento (recorta janelas e porta)
	local openings: { Opening } = {
		{ a0 = -11.4, a1 = -3.6, y0 = 3.6, y1 = 10.9, kind = "window" },
		{ a0 = -2.4, a1 = 4.4, y0 = 3.6, y1 = 10.9, kind = "window" },
		{ a0 = doorA0 - 0.5, a1 = doorA1 + 0.5, y0 = 0, y1 = 9, kind = "door" },
	}
	buildWall(m, R.MinX - 0.5, R.MaxX + 0.5, openings, function(a, y)
		return Vector3.new(a, y, cz)
	end, function(len, h)
		return Vector3.new(len, h, 0.2)
	end, { { 0, 2.4, COTTAGE.Stone }, { 2.4, 14, COTTAGE.Plaster } })

	-- pedrinhas saltadas na base
	local stones = { COTTAGE.StoneDark, COTTAGE.StoneLight, COTTAGE.Stone }
	for row = 0, 2 do
		local x = R.MinX - 0.3 + (row % 2) * 0.7
		while x < R.MaxX do
			local w = rng:NextNumber(0.9, 1.5)
			local inDoor = x + w > doorA0 - 0.6 and x < doorA1 + 0.6
			if not inDoor then
				part(m, Vector3.new(w - 0.12, 0.62, 0.14), Vector3.new(x + w / 2, 0.36 + row * 0.72, cz - 0.16), stones[rng:NextInteger(1, 3)])
			end
			x += w
		end
	end

	-- enxaimel: vigas horizontais, pilares e mãos-francesas
	local timber = COTTAGE.Timber
	local tz = cz - 0.22
	part(m, Vector3.new(R.MaxX - R.MinX + 1, 0.4, 0.3), Vector3.new(0, 13.7, tz), timber)
	part(m, Vector3.new(R.MaxX - R.MinX + 1, 0.35, 0.3), Vector3.new(0, 11.35, tz), timber)
	for _, seg in { { R.MinX - 0.5, doorA0 - 0.5 }, { doorA1 + 0.5, R.MaxX + 0.5 } } do
		part(m, Vector3.new(seg[2] - seg[1], 0.35, 0.3), Vector3.new((seg[1] + seg[2]) / 2, 2.55, tz), timber)
	end
	local posts = { R.MinX - 0.2, -12.2, -3, 5.4, doorA0 - 0.75, doorA1 + 0.75, 12.4, R.MaxX + 0.2 }
	for _, x in posts do
		local y0 = if x > doorA0 - 1 and x < doorA1 + 1 then 0 else 2.55
		part(m, Vector3.new(0.4, 13.7 - y0, 0.3), Vector3.new(x, (13.7 + y0) / 2, tz), timber)
	end
	for _, panel in { { R.MinX - 0.2, -12.2 }, { 12.4, R.MaxX + 0.2 } } do
		local a, b = panel[1], panel[2]
		beam(m, Vector3.new(a, 2.7, tz), Vector3.new(b, 11.2, tz), 0.32, 0.3, timber)
		beam(m, Vector3.new(b, 2.7, tz), Vector3.new(a, 11.2, tz), 0.32, 0.3, timber)
	end
	-- mãos-francesas acima das janelas
	for _, w in windows do
		beam(m, Vector3.new(w[1] - 0.5, 11.2, tz), Vector3.new((w[1] + w[2]) / 2, 13.5, tz), 0.28, 0.3, timber)
		beam(m, Vector3.new(w[2] + 0.5, 11.2, tz), Vector3.new((w[1] + w[2]) / 2, 13.5, tz), 0.28, 0.3, timber)
	end

	-- janelas: venezianas e floreiras do lado de fora
	for _, w in windows do
		for _, side in { -1, 1 } do
			local x = if side < 0 then w[1] - 1.05 else w[2] + 1.05
			part(m, Vector3.new(1.3, 6.8, 0.2), Vector3.new(x, 7.25, cz - 0.3), COTTAGE.Shutter)
			for i = 0, 4 do
				part(m, Vector3.new(1.1, 0.12, 0.22), Vector3.new(x, 4.6 + i * 1.3, cz - 0.34), COTTAGE.Shutter:Lerp(Color3.new(0, 0, 0), 0.2))
			end
		end
		local width = w[2] - w[1]
		local boxCF = CFrame.new((w[1] + w[2]) / 2, 3.35, fz - 0.65)
		part(m, Vector3.new(width + 0.4, 0.8, 0.9), boxCF, C.Terracotta)
		part(m, Vector3.new(width + 0.6, 0.2, 1), boxCF * CFrame.new(0, 0.45, 0), rgb(176, 96, 66))
		local n = math.floor(width / 0.7)
		for i = 0, n - 1 do
			local x = -width / 2 + 0.4 + i * ((width - 0.8) / math.max(n - 1, 1))
			part(m, Vector3.new(0.5, 0.5, 0.55), boxCF * CFrame.new(x, 0.75, 0), C.Leaf)
			part(m, Vector3.new(0.4, 0.4, 0.4), boxCF * CFrame.new(x + 0.1, 1.15, -0.1), FLOWERS[rng:NextInteger(1, #FLOWERS)])
			if i % 3 == 0 then
				part(m, Vector3.new(0.3, 0.9, 0.3), boxCF * CFrame.new(x, -0.7, -0.45), C.LeafDark) -- folhagem caindo
			end
		end
	end

	-- toldo listrado + lanterninhas na porta
	for i = 0, 5 do
		local x = doorA0 - 0.5 + i * ((doorA1 - doorA0 + 1) / 6) + (doorA1 - doorA0 + 1) / 12
		part(m, Vector3.new((doorA1 - doorA0 + 1) / 6, 0.2, 2.2), CFrame.new(x, 9.75, fz - 1) * CFrame.Angles(math.rad(-22), 0, 0), if i % 2 == 0 then C.Cream else C.Rose)
	end
	part(m, Vector3.new(doorA1 - doorA0 + 1.2, 0.3, 0.3), Vector3.new(Layout.DoorX, 9.35, fz - 2), C.Rose)
	for _, x in { doorA0 - 1.3, doorA1 + 1.3 } do
		part(m, Vector3.new(0.2, 0.2, 0.7), Vector3.new(x, 7.4, fz - 0.45), rgb(40, 36, 36))
		part(m, Vector3.new(0.7, 0.9, 0.7), Vector3.new(x, 6.9, fz - 0.8), rgb(40, 36, 36))
		local glow = part(m, Vector3.new(0.5, 0.6, 0.5), Vector3.new(x, 6.9, fz - 0.8), C.Warm, { Material = Enum.Material.Neon, CastShadow = false })
		glow.Size = Vector3.new(0.55, 0.65, 0.75)
		light(glow, 0.8, 10)
	end

	-- telhado de duas águas (cumeeira perpendicular à fachada)
	local half = (R.MaxX - R.MinX) / 2 + 1
	local rise = 9
	local slope = math.sqrt(half * half + rise * rise)
	local angle = math.atan2(rise, half)
	local roofZ0, roofZ1 = R.MinZ - 2.2, R.MaxZ + 1.5
	local depth = roofZ1 - roofZ0
	local zc = (roofZ0 + roofZ1) / 2
	for _, side in { -1, 1 } do
		local cf = CFrame.new(side * half / 2, R.Height + rise / 2 + 0.45, zc) * CFrame.Angles(0, 0, -side * angle)
		part(m, Vector3.new(slope + 0.6, 0.8, depth), cf, COTTAGE.Roof)
		local u = -slope / 2 + 0.8
		while u < slope / 2 do
			part(m, Vector3.new(0.22, 0.25, depth + 0.05), cf * CFrame.new(u, 0.45, 0), COTTAGE.RoofLine)
			u += 1.3
		end
		-- beiral (tábua clara acompanhando a borda da frente)
		part(m, Vector3.new(slope + 0.6, 0.5, 0.35), cf * CFrame.new(0, -0.35, -depth / 2 - 0.1), C.Cream)
	end
	part(m, Vector3.new(0.9, 0.6, depth + 0.2), Vector3.new(0, R.Height + rise + 0.8, zc), COTTAGE.RoofLine) -- cumeeira

	-- oitão (triângulo da frente) em "escadinha" pixel
	for i = 0, rise - 1 do
		local w = 2 * half * (1 - (i + 0.5) / rise)
		part(m, Vector3.new(w, 1, 0.9), Vector3.new(0, R.Height + i + 0.5, R.MinZ - 0.55), COTTAGE.Plaster)
	end
	part(m, Vector3.new(0.4, rise - 0.5, 0.3), Vector3.new(0, R.Height + (rise - 0.5) / 2, fz - 0.2), timber)
	beam(m, Vector3.new(-9, R.Height + 0.2, fz - 0.2), Vector3.new(-0.2, R.Height + 4.5, fz - 0.2), 0.3, 0.3, timber)
	beam(m, Vector3.new(9, R.Height + 0.2, fz - 0.2), Vector3.new(0.2, R.Height + 4.5, fz - 0.2), 0.3, 0.3, timber)
	-- janelinha do sótão com luz quente
	local atticY = R.Height + 2.4
	part(m, Vector3.new(2.6, 2.6, 0.3), Vector3.new(0, atticY, fz - 0.25), C.Cream)
	local attic = part(m, Vector3.new(2, 2, 0.32), Vector3.new(0, atticY, fz - 0.26), rgb(255, 214, 150), { Material = Enum.Material.Neon })
	part(m, Vector3.new(0.18, 2, 0.36), Vector3.new(0, atticY, fz - 0.3), C.Cream)
	part(m, Vector3.new(2, 0.18, 0.36), Vector3.new(0, atticY, fz - 0.3), C.Cream)
	light(attic, 0.4, 8)

	-- chaminé de pedra com fumacinha
	local chimney = Vector3.new(-9, 0, -4)
	local chimneyH = R.Height + 12
	part(m, Vector3.new(2.4, chimneyH - R.Height, 2.4), Vector3.new(chimney.X, (chimneyH + R.Height) / 2, chimney.Z), COTTAGE.Stone)
	for y = R.Height + 1, chimneyH - 1, 1.2 do
		part(m, Vector3.new(2.5, 0.15, 2.5), Vector3.new(chimney.X, y, chimney.Z), COTTAGE.StoneDark)
	end
	local cap = part(m, Vector3.new(2.9, 0.5, 2.9), Vector3.new(chimney.X, chimneyH + 0.25, chimney.Z), COTTAGE.StoneDark)
	local smoke = Instance.new("Smoke")
	smoke.Color = rgb(236, 232, 228)
	smoke.Opacity = 0.12
	smoke.RiseVelocity = 3
	smoke.Size = 2.5
	smoke.Parent = cap
end

local function flower(parent: Instance, pos: Vector3)
	local h = rng:NextNumber(0.5, 1.1)
	part(parent, Vector3.new(0.12, h, 0.12), pos + Vector3.new(0, h / 2, 0), C.LeafDark, { CastShadow = false })
	if rng:NextNumber() < 0.5 then
		part(parent, Vector3.new(0.35, 0.12, 0.2), pos + Vector3.new(0.15, h * 0.4, 0), C.Leaf, { CastShadow = false })
	end
	part(parent, Vector3.new(0.42, 0.42, 0.42), pos + Vector3.new(0, h + 0.15, 0), FLOWERS[rng:NextInteger(1, #FLOWERS)], { CastShadow = false })
end

local function flowerBed(parent: Instance, x0: number, x1: number, z0: number, z1: number, density: number)
	part(parent, Vector3.new(x1 - x0, 0.25, z1 - z0), Vector3.new((x0 + x1) / 2, 0, (z0 + z1) / 2), COTTAGE.Soil)
	local count = math.floor((x1 - x0) * (z1 - z0) * density)
	for _ = 1, count do
		flower(parent, Vector3.new(rng:NextNumber(x0 + 0.2, x1 - 0.2), 0.12, rng:NextNumber(z0 + 0.2, z1 - 0.2)))
	end
end

local function bush(parent: Instance, pos: Vector3, bloom: Color3, scale: number)
	part(parent, Vector3.new(1.8, 1.3, 1.8) * scale, pos + Vector3.new(0, 0.65 * scale, 0), C.LeafDark)
	part(parent, Vector3.new(1.4, 0.9, 1.4) * scale, pos + Vector3.new(0.2, 1.4 * scale, -0.1), C.Leaf)
	for _ = 1, 5 do
		local o = Vector3.new(rng:NextNumber(-0.7, 0.7), rng:NextNumber(0.9, 1.8), rng:NextNumber(-0.7, 0.7)) * scale
		part(parent, Vector3.new(0.6, 0.6, 0.6) * scale, pos + o, bloom:Lerp(Color3.new(1, 1, 1), rng:NextNumber(0, 0.25)))
	end
end

local function bigTree(parent: Instance, base: Vector3)
	local m = folder("BigTree", parent)
	local bark, barkDark = rgb(112, 76, 52), rgb(84, 56, 40)
	-- raízes + tronco grosso em dois estágios
	for _, o in { Vector3.new(1.6, 0, 0.3), Vector3.new(-1.5, 0, -0.4), Vector3.new(0.2, 0, 1.5), Vector3.new(-0.3, 0, -1.5) } do
		part(m, Vector3.new(1.4, 0.7, 1.4), base + o + Vector3.new(0, 0.3, 0), barkDark)
	end
	part(m, Vector3.new(3, 5, 3), base + Vector3.new(0, 2.5, 0), bark)
	part(m, Vector3.new(2.4, 6, 2.4), base + Vector3.new(0.3, 7.8, 0.2), bark)
	part(m, Vector3.new(0.4, 3, 0.2), base + Vector3.new(-0.6, 2.4, -1.55), barkDark) -- textura da casca
	part(m, Vector3.new(0.3, 2, 0.2), base + Vector3.new(0.8, 5.5, -1.55), barkDark)
	-- galhos
	local swingBranchEnd = base + Vector3.new(-6.5, 10.6, -0.2)
	beam(m, base + Vector3.new(0, 9, 0), swingBranchEnd, 0.9, 0.9, bark)
	beam(m, base + Vector3.new(0.5, 10, 0), base + Vector3.new(5, 13, 1), 0.8, 0.8, bark)
	beam(m, base + Vector3.new(0, 11, 0), base + Vector3.new(-2, 15, -2), 0.8, 0.8, bark)
	-- copa: blocos grandes em tons de verde
	local greens = { C.LeafDark, C.Leaf, C.LeafLight, rgb(86, 138, 76) }
	local clusters = {
		{ Vector3.new(12, 5, 11), Vector3.new(0, 14, 0) },
		{ Vector3.new(9, 4.5, 9), Vector3.new(-4.5, 16.5, 1) },
		{ Vector3.new(9, 4, 8), Vector3.new(4, 17, -1.5) },
		{ Vector3.new(7, 3.6, 7), Vector3.new(-0.5, 19.8, 0.5) },
		{ Vector3.new(7, 3, 6), Vector3.new(-6.5, 12.8, -0.5) },
		{ Vector3.new(6, 3, 6), Vector3.new(5.5, 12.6, 2) },
		{ Vector3.new(4.5, 2.5, 4.5), Vector3.new(2, 21.4, -1) },
	}
	for i, c in clusters do
		part(m, c[1], base + c[2], greens[(i - 1) % #greens + 1])
	end
	for _ = 1, 14 do
		local o = Vector3.new(rng:NextNumber(-7, 7), rng:NextNumber(11, 21), rng:NextNumber(-5.5, 5.5))
		part(m, Vector3.new(1.4, 1.4, 1.4), base + o, if rng:NextNumber() < 0.5 then C.LeafLight else rgb(160, 200, 120))
	end
	-- balanço pendurado no galho
	local swingX = swingBranchEnd.X + 1.3
	for _, dz in { -0.55, 0.55 } do
		local top = Vector3.new(swingX, 10.15, base.Z - 0.2 + dz)
		part(m, Vector3.new(0.1, 8, 0.1), top - Vector3.new(0, 4, 0), rgb(214, 190, 150), { CastShadow = false })
	end
	part(m, Vector3.new(0.9, 0.2, 1.8), Vector3.new(swingX, 2.1, base.Z - 0.2), C.Wood)
end

-- Jardim da frente: canteiros floridos, arbustos, cerquinha branca, banco e a árvore grande
function buildGarden(parent: Instance)
	local m = folder("Garden", parent)
	local R = Layout.Room
	local doorA0, doorA1 = Layout.DoorX - 2, Layout.DoorX + 2
	local fenceZ = R.MinZ - 10.3

	-- canteiros junto da fachada e junto da cerca
	flowerBed(m, R.MinX + 1, doorA0 - 1, R.MinZ - 3.2, R.MinZ - 1.4, 2.2)
	flowerBed(m, doorA1 + 1, R.MaxX - 1, R.MinZ - 3.2, R.MinZ - 1.4, 2.2)
	flowerBed(m, -8, doorA0 - 0.8, fenceZ + 0.6, fenceZ + 1.8, 2.4)
	flowerBed(m, doorA1 + 0.8, 15, fenceZ + 0.6, fenceZ + 1.8, 2.4)
	-- flores soltas pelo gramado
	for _ = 1, 40 do
		local x = rng:NextNumber(-10, 26)
		if x > doorA0 - 0.5 and x < doorA1 + 0.5 then
			continue
		end
		flower(m, Vector3.new(x, -0.1, rng:NextNumber(fenceZ + 2.2, R.MinZ - 3.6)))
	end
	bush(m, Vector3.new(doorA0 - 1.6, 0, R.MinZ - 2.4), rgb(160, 170, 240), 1)
	bush(m, Vector3.new(doorA1 + 1.6, 0, R.MinZ - 2.4), rgb(244, 160, 190), 1)
	bush(m, Vector3.new(-9.5, 0, R.MinZ - 3), rgb(196, 160, 232), 1.2)
	bush(m, Vector3.new(18.5, 0, R.MinZ - 3), rgb(252, 252, 246), 1.2)

	-- pedras do caminho até a porta
	for i = 0, 5 do
		local z = R.MinZ - 1.8 - i * 1.6
		part(m, Vector3.new(1.6, 0.12, 1.1), Vector3.new(Layout.DoorX + (if i % 2 == 0 then -0.5 else 0.5), -0.02, z), COTTAGE.StoneLight)
	end

	-- cerquinha branca (com o vão do portão)
	local function fence(x0: number, x1: number)
		part(m, Vector3.new(x1 - x0, 0.2, 0.15), Vector3.new((x0 + x1) / 2, 0.5, fenceZ), COTTAGE.Picket)
		part(m, Vector3.new(x1 - x0, 0.2, 0.15), Vector3.new((x0 + x1) / 2, 1.15, fenceZ), COTTAGE.Picket)
		local x = x0 + 0.2
		while x <= x1 do
			part(m, Vector3.new(0.34, 1.5, 0.18), Vector3.new(x, 0.65, fenceZ - 0.05), COTTAGE.Picket)
			part(m, Vector3.new(0.24, 0.24, 0.18), CFrame.new(x, 1.45, fenceZ - 0.05) * CFrame.Angles(0, 0, math.rad(45)), COTTAGE.Picket)
			x += 0.8
		end
	end
	fence(-12, doorA0 - 0.6)
	fence(doorA1 + 0.6, 26)
	for _, x in { doorA0 - 0.6, doorA1 + 0.6 } do
		part(m, Vector3.new(0.5, 2.1, 0.5), Vector3.new(x, 1, fenceZ), COTTAGE.Picket)
		part(m, Vector3.new(0.6, 0.6, 0.6), Vector3.new(x, 2.3, fenceZ), COTTAGE.Picket, { Shape = Enum.PartType.Ball })
	end
	-- caixa de correio
	part(m, Vector3.new(0.25, 1.6, 0.25), Vector3.new(doorA1 + 1.8, 0.8, fenceZ - 0.9), C.WoodDark)
	part(m, Vector3.new(0.7, 0.6, 1), Vector3.new(doorA1 + 1.8, 1.8, fenceZ - 0.9), rgb(206, 80, 76))
	part(m, Vector3.new(0.1, 0.4, 0.1), Vector3.new(doorA1 + 2.2, 2.2, fenceZ - 0.7), rgb(250, 210, 90))

	-- banquinho de jardim
	local bench = Vector3.new(0.5, 0, R.MinZ - 6.5)
	part(m, Vector3.new(3.2, 0.25, 1), bench + Vector3.new(0, 1.2, 0), C.WoodLight)
	part(m, Vector3.new(3.2, 0.9, 0.2), bench + Vector3.new(0, 1.9, 0.45), C.WoodLight)
	for _, dx in { -1.3, 1.3 } do
		part(m, Vector3.new(0.25, 1.1, 0.8), bench + Vector3.new(dx, 0.55, 0), C.WoodDark)
	end

	bigTree(m, Vector3.new(23, 0, R.MinZ - 4.5))
end

local function buildOutside()
	local m = folder("Outside")
	part(m, Vector3.new(220, 1, 220), Vector3.new(0, -0.62, 0), rgb(120, 170, 96))
	-- calçada até a porta
	part(m, Vector3.new(4, 1, 14), Vector3.new(Layout.DoorX, -0.55, Layout.Room.MinZ - 7), rgb(210, 196, 176))
	part(m, Vector3.new(80, 1, 5), Vector3.new(0, -0.55, Layout.Room.MinZ - 15), rgb(200, 186, 166))
	part(m, Vector3.new(80, 1, 8), Vector3.new(0, -0.58, Layout.Room.MinZ - 21.5), rgb(90, 90, 98))
	for x = -36, 36, 6 do
		part(m, Vector3.new(3, 0.05, 0.5), Vector3.new(x, -0.05, Layout.Room.MinZ - 21.5), rgb(240, 230, 190))
	end
	for _, x in { -22, -12, 30 } do
		tree(m, Vector3.new(x + rng:NextNumber(-1, 1), 0, Layout.Room.MinZ - 9 - rng:NextNumber(0, 2)), rng:NextNumber(0.9, 1.3))
	end
	for _, x in { -30, 32 } do
		tree(m, Vector3.new(x, 0, -4), 1.4)
		tree(m, Vector3.new(x, 0, 8), 1.2)
	end
	-- poste de luz
	local lampPos = Vector3.new(-13, 0, Layout.Room.MinZ - 11.5)
	part(m, Vector3.new(0.5, 9, 0.5), lampPos + Vector3.new(0, 4.5, 0), rgb(50, 56, 60))
	local bulb = part(m, Vector3.new(1.2, 1.2, 1.2), lampPos + Vector3.new(0, 9.4, 0), C.Warm, { Material = Enum.Material.Neon })
	light(bulb, 1, 16)
	-- placa do café
	local sign = part(m, Vector3.new(5, 1.4, 0.3), Vector3.new(Layout.DoorX, 12.3, Layout.Room.MinZ - 1.45), C.Sage)
	local plate = part(m, Vector3.new(4.4, 0.9, 0.1), sign.CFrame * CFrame.new(0, 0, -0.2), C.Cream)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 40
	gui.Parent = plate
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "Café Cozy"
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = C.WoodDark
	label.Parent = gui

	buildCottage(m)
	buildGarden(m)
end

---------------------------------------------------------------- balcão

local function buildCounter()
	local m = folder("Counter")
	local z = Layout.CounterZ
	local w = 16
	local h = Layout.CounterHeight

	part(m, Vector3.new(w, h - 0.4, 2.2), Vector3.new(0, (h - 0.4) / 2, z + 0.1), C.WoodDark)
	part(m, Vector3.new(w + 0.2, 0.4, 2.3), Vector3.new(0, 0.2, z + 0.1), rgb(64, 40, 30))
	-- ripas na frente (lado do cliente)
	local x = -w / 2 + 0.5
	while x < w / 2 do
		part(m, Vector3.new(0.5, h - 1.2, 0.15), Vector3.new(x, (h - 0.4) / 2 + 0.2, z - 1.05), C.Wood)
		x += 0.9
	end
	-- tampo
	part(m, Vector3.new(w + 0.8, 0.4, 3), Vector3.new(0, h - 0.2, z), C.WoodLight)
	part(m, Vector3.new(w + 0.8, 0.1, 0.2), Vector3.new(0, h - 0.35, z - 1.45), C.WoodPale)

	local top = h

	-- máquina de espresso
	local mx, mz = -5.2, z + 0.3
	local mint = rgb(150, 206, 190)
	part(m, Vector3.new(3.2, 2.2, 1.8), Vector3.new(mx, top + 1.1, mz), mint)
	part(m, Vector3.new(3.4, 0.3, 2), Vector3.new(mx, top + 2.35, mz), rgb(210, 214, 218))
	part(m, Vector3.new(3.4, 0.2, 2), Vector3.new(mx, top + 0.1, mz), rgb(210, 214, 218))
	for _, dx in { -0.8, 0.8 } do
		part(m, Vector3.new(0.6, 0.5, 0.5), Vector3.new(mx + dx, top + 1.1, mz + 1.05), rgb(70, 70, 76))
		part(m, Vector3.new(0.3, 0.2, 1.1), Vector3.new(mx + dx, top + 0.95, mz + 1.6), rgb(40, 34, 32))
		part(m, Vector3.new(0.5, 0.5, 0.5), upright(Vector3.new(mx + dx, top + 0.45, mz + 1.1)), C.Cream, { Shape = Enum.PartType.Cylinder })
	end
	part(m, Vector3.new(0.1, 0.7, 0.7), CFrame.new(mx, top + 1.75, mz + 0.92) * CFrame.Angles(0, math.rad(90), 0), C.Cream, { Shape = Enum.PartType.Cylinder })
	-- xícaras em cima da máquina
	for i = 0, 3 do
		part(m, Vector3.new(0.45, 0.5, 0.5), upright(Vector3.new(mx - 1.1 + i * 0.7, top + 2.75, mz)), C.Cream, { Shape = Enum.PartType.Cylinder })
	end

	-- vitrine de doces
	local px = -2.6
	part(m, Vector3.new(2.4, 0.2, 1.8), Vector3.new(px, top + 0.1, z), C.WoodPale)
	part(m, Vector3.new(2.4, 1.3, 1.8), Vector3.new(px, top + 0.85, z), C.Glass, { Transparency = 0.7, CastShadow = false })
	part(m, Vector3.new(2.5, 0.15, 1.9), Vector3.new(px, top + 1.55, z), C.WoodPale)
	local cakes = { C.Rose, rgb(120, 70, 44), rgb(250, 230, 170) }
	for i, col in cakes do
		local cp = Vector3.new(px - 1.2 + i * 0.6, top + 0.45, z)
		part(m, Vector3.new(0.4, 0.5, 0.5), upright(cp), col, { Shape = Enum.PartType.Cylinder })
		part(m, Vector3.new(0.15, 0.15, 0.15), cp + Vector3.new(0, 0.28, 0), rgb(220, 50, 60))
	end

	-- caixa registradora
	local rx = 5.4
	part(m, Vector3.new(2, 0.8, 1.6), Vector3.new(rx, top + 0.4, z + 0.2), rgb(220, 196, 150))
	part(m, Vector3.new(1.6, 1, 0.2), CFrame.new(rx, top + 1.3, z + 0.3) * CFrame.Angles(math.rad(-20), 0, 0), rgb(60, 70, 72))
	part(m, Vector3.new(1.3, 0.7, 0.05), CFrame.new(rx, top + 1.3, z + 0.18) * CFrame.Angles(math.rad(-20), 0, 0), rgb(160, 220, 180), { Material = Enum.Material.Neon })

	-- pote de gorjeta, planta e jarra de biscoitos
	part(m, Vector3.new(0.9, 0.7, 0.7), upright(Vector3.new(7.2, top + 0.35, z - 0.6)), C.Glass, { Shape = Enum.PartType.Cylinder, Transparency = 0.4 })
	part(m, Vector3.new(0.9, 0.9, 0.9), upright(Vector3.new(-7.3, top + 0.45, z - 0.3)), C.Terracotta, { Shape = Enum.PartType.Cylinder })
	part(m, Vector3.new(0.7, 0.8, 0.7), Vector3.new(-7.3, top + 1.3, z - 0.3), C.Leaf)
	part(m, Vector3.new(0.5, 0.6, 0.5), Vector3.new(-7.1, top + 1.9, z - 0.4), C.LeafLight)

	-- bancada de trás (lado do barista)
	part(m, Vector3.new(w, 3, 1.6), Vector3.new(0, 1.5, Layout.Room.MaxZ - 0.8), C.WoodDark)
	part(m, Vector3.new(w + 0.4, 0.3, 1.8), Vector3.new(0, 3.15, Layout.Room.MaxZ - 0.9), C.WoodLight)
end

---------------------------------------------------------------- mobília

local function chair(parent: Instance, pos: Vector3, facing: Vector3, cushion: Color3)
	local cf = CFrame.lookAt(pos, pos + facing)
	part(parent, Vector3.new(1.6, 0.3, 1.6), cf * CFrame.new(0, 1.6, 0), C.Wood)
	part(parent, Vector3.new(1.4, 0.2, 1.4), cf * CFrame.new(0, 1.85, 0), cushion)
	for _, o in { Vector2.new(-0.6, -0.6), Vector2.new(0.6, -0.6), Vector2.new(-0.6, 0.6), Vector2.new(0.6, 0.6) } do
		part(parent, Vector3.new(0.25, 1.5, 0.25), cf * CFrame.new(o.X, 0.75, o.Y), C.WoodDark)
	end
	part(parent, Vector3.new(1.6, 1.8, 0.25), cf * CFrame.new(0, 2.65, 0.7), C.Wood)
end

local function tableSet(parent: Instance, pos: Vector3, cushion: Color3)
	local m = folder("Table", parent)
	part(m, Vector3.new(0.3, 3.8, 3.8), upright(pos + Vector3.new(0, 2.85, 0)), C.WoodLight, { Shape = Enum.PartType.Cylinder })
	part(m, Vector3.new(2.6, 0.4, 0.4), upright(pos + Vector3.new(0, 1.4, 0)), C.WoodDark, { Shape = Enum.PartType.Cylinder })
	part(m, Vector3.new(0.2, 1.6, 1.6), upright(pos + Vector3.new(0, 0.1, 0)), C.WoodDark, { Shape = Enum.PartType.Cylinder })
	chair(m, pos + Vector3.new(-2.3, 0, 0), Vector3.new(1, 0, 0), cushion)
	chair(m, pos + Vector3.new(2.3, 0, 0), Vector3.new(-1, 0, 0), cushion)
	-- xícara + vasinho
	part(m, Vector3.new(0.5, 0.55, 0.55), upright(pos + Vector3.new(0.6, 3.25, 0.4)), C.Cream, { Shape = Enum.PartType.Cylinder })
	part(m, Vector3.new(0.12, 0.4, 0.4), upright(pos + Vector3.new(0.6, 3.5, 0.4)), rgb(120, 76, 50), { Shape = Enum.PartType.Cylinder })
	part(m, Vector3.new(0.5, 0.5, 0.5), upright(pos + Vector3.new(-0.5, 3.25, -0.3)), C.Sage, { Shape = Enum.PartType.Cylinder })
	part(m, Vector3.new(0.35, 0.35, 0.35), pos + Vector3.new(-0.5, 3.7, -0.3), C.Rose)
end

local function plant(parent: Instance, pos: Vector3, height: number)
	local m = folder("Plant", parent)
	part(m, Vector3.new(1.6, 1.8, 1.8), upright(pos + Vector3.new(0, 0.8, 0)), C.Terracotta, { Shape = Enum.PartType.Cylinder })
	part(m, Vector3.new(0.3, 2.1, 2.1), upright(pos + Vector3.new(0, 1.65, 0)), rgb(176, 96, 64), { Shape = Enum.PartType.Cylinder })
	local greens = { C.Leaf, C.LeafDark, C.LeafLight }
	for i = 1, math.floor(height * 2) do
		local y = 1.8 + i * 0.45
		local s = math.max(0.6, 1.8 - i * 0.12) * rng:NextNumber(0.8, 1.1)
		local off = Vector3.new(rng:NextNumber(-0.5, 0.5), 0, rng:NextNumber(-0.5, 0.5))
		part(m, Vector3.new(s, 0.6, s), CFrame.new(pos + off + Vector3.new(0, y, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), greens[rng:NextInteger(1, 3)])
	end
end

local function bookshelf(parent: Instance, pos: Vector3, facing: Vector3)
	local m = folder("Bookshelf", parent)
	local cf = CFrame.lookAt(pos, pos + facing)
	local W, H, D = 4.4, 8, 1.4
	part(m, Vector3.new(W, H, 0.2), cf * CFrame.new(0, H / 2, D / 2 - 0.1), C.WoodDark)
	part(m, Vector3.new(0.3, H, D), cf * CFrame.new(-W / 2, H / 2, 0), C.Wood)
	part(m, Vector3.new(0.3, H, D), cf * CFrame.new(W / 2, H / 2, 0), C.Wood)
	local bookColors = { C.Rose, C.Sage, C.Mustard, C.Terracotta, rgb(120, 150, 200), C.Cream, rgb(160, 110, 170) }
	for shelf = 0, 3 do
		local y = 0.3 + shelf * 1.95
		part(m, Vector3.new(W, 0.25, D), cf * CFrame.new(0, y, 0), C.Wood)
		local x = -W / 2 + 0.3
		while x < W / 2 - 0.6 do
			local bw = rng:NextNumber(0.25, 0.45)
			local bh = rng:NextNumber(1, 1.5)
			if rng:NextNumber() < 0.12 then
				x += 0.4 -- espaço vazio
			else
				part(m, Vector3.new(bw, bh, 0.9), cf * CFrame.new(x + bw / 2, y + 0.12 + bh / 2, 0.05), bookColors[rng:NextInteger(1, #bookColors)])
				x += bw + 0.03
			end
		end
	end
	part(m, Vector3.new(W, 0.3, D), cf * CFrame.new(0, H, 0), C.Wood)
end

local function chalkboard(parent: Instance, center: Vector3)
	local board = part(parent, Vector3.new(5, 4, 0.2), center, C.Chalk)
	part(parent, Vector3.new(5.5, 4.5, 0.15), center - Vector3.new(0, 0, 0.1), C.Wood)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.PixelsPerStud = 40
	gui.Parent = board
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 4)
	list.Parent = gui
	for i, text in { "~ MENU ~", "Espresso", "Macchiato", "Latte", "Mocha", "Matcha" } do
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 0, if i == 1 then 30 else 22)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.TextColor3 = if i == 1 then C.Mustard else rgb(236, 236, 226)
		label.LayoutOrder = i
		label.Parent = gui
	end
end

local function frame(parent: Instance, center: Vector3, size: Vector2, color: Color3)
	part(parent, Vector3.new(size.X + 0.4, size.Y + 0.4, 0.15), center, C.WoodDark)
	part(parent, Vector3.new(size.X, size.Y, 0.2), center + Vector3.new(0, 0, 0.05), color)
	part(parent, Vector3.new(size.X * 0.5, size.Y * 0.3, 0.25), center + Vector3.new(0, -size.Y * 0.15, 0.05), C.LeafLight)
	part(parent, Vector3.new(size.X * 0.2, size.X * 0.2, 0.25), center + Vector3.new(size.X * 0.2, size.Y * 0.2, 0.05), C.Mustard)
end

local function buildFurniture()
	local m = folder("Furniture")
	local R = Layout.Room
	tableSet(m, Vector3.new(-13, 0, -6.5), C.Rose)
	tableSet(m, Vector3.new(-10, 0, -14.5), C.Mustard)
	tableSet(m, Vector3.new(14, 0, -5), C.Sage)

	bookshelf(m, Vector3.new(-15.2, 0, R.MinZ + 0.8), Vector3.new(0, 0, 1))
	chalkboard(m, Vector3.new(14.5, 6.8, R.MinZ + 0.3))
	frame(m, Vector3.new(-7.5, 11.8, R.MinZ + 0.2), Vector2.new(2, 1.4), rgb(170, 210, 230))
	frame(m, Vector3.new(0.5, 11.8, R.MinZ + 0.2), Vector2.new(1.6, 1.6), rgb(250, 220, 190))

	plant(m, Vector3.new(R.MinX + 1.6, 0, R.MinZ + 4), 3)
	plant(m, Vector3.new(R.MaxX - 1.6, 0, R.MinZ + 1.6), 3.5)
	plant(m, Vector3.new(4.5, 0, R.MinZ + 1.4), 1.6)
	plant(m, Vector3.new(-9, 0, 1.2), 2.2)
	plant(m, Vector3.new(9.4, 0, 1.2), 2.2)
end

---------------------------------------------------------------- luzes

local function pendant(parent: Instance, pos: Vector3, shadeColor: Color3, brightness: number)
	local top = Layout.Room.Height
	part(parent, Vector3.new(0.1, top - pos.Y, 0.1), Vector3.new(pos.X, (top + pos.Y) / 2, pos.Z), rgb(40, 34, 32), { CastShadow = false })
	part(parent, Vector3.new(1.8, 0.7, 1.8), pos, shadeColor, { CastShadow = false })
	part(parent, Vector3.new(1.2, 0.4, 1.2), pos + Vector3.new(0, 0.5, 0), shadeColor, { CastShadow = false })
	local bulb = part(parent, Vector3.new(0.6, 0.6, 0.6), pos - Vector3.new(0, 0.5, 0), C.Warm, { Material = Enum.Material.Neon, Shape = Enum.PartType.Ball, CastShadow = false })
	light(bulb, brightness, 20, nil, true)
end

local function buildLights()
	local m = folder("Lights")
	pendant(m, Vector3.new(-4, 9.5, 0), C.Mustard, 0.85)
	pendant(m, Vector3.new(4, 9.5, 0), C.Sage, 0.85)
	pendant(m, Vector3.new(-13, 9, -6.5), C.Rose, 0.6)
	pendant(m, Vector3.new(-10, 9, -14.5), C.Mustard, 0.6)
	pendant(m, Vector3.new(14, 9, -5), C.Sage, 0.6)
	pendant(m, Vector3.new(4, 10, -12), C.Cream, 0.65)

	-- varal de luzinhas atravessando a sala
	local colors = { rgb(255, 214, 140), rgb(255, 170, 150), rgb(255, 236, 190) }
	local z = -1.6
	local i = 0
	for x = -17, 17, 1.4 do
		i += 1
		local sag = 12.8 - 0.9 * math.abs(math.sin((x + 17) / 34 * math.pi * 2))
		local b = part(m, Vector3.new(0.35, 0.35, 0.35), Vector3.new(x, sag, z), colors[i % #colors + 1], { Material = Enum.Material.Neon, Shape = Enum.PartType.Ball, CastShadow = false })
		if i % 6 == 0 then
			light(b, 0.4, 8)
		end
	end
	local j = 0
	for x = -17, 17, 1.4 do
		j += 1
		local sag = 12.4 - 0.9 * math.abs(math.sin((x + 17) / 34 * math.pi * 2))
		part(m, Vector3.new(0.3, 0.3, 0.3), Vector3.new(x, sag, -12), colors[j % #colors + 1], { Material = Enum.Material.Neon, Shape = Enum.PartType.Ball, CastShadow = false })
	end
end

local function setupLighting()
	Lighting.ClockTime = 17.2
	Lighting.Brightness = 1.3
	Lighting.ExposureCompensation = -0.35
	Lighting.Ambient = rgb(70, 56, 48)
	Lighting.OutdoorAmbient = rgb(110, 96, 86)
	Lighting.GlobalShadows = true

	local function effect(className: string, props: { [string]: any })
		local existing = Lighting:FindFirstChildOfClass(className)
		if existing then
			existing:Destroy()
		end
		local e = Instance.new(className)
		for k, v in props do
			(e :: any)[k] = v
		end
		e.Parent = Lighting
	end

	effect("Atmosphere", { Density = 0.12, Offset = 0.25, Color = rgb(255, 222, 190), Decay = rgb(200, 150, 120), Glare = 0, Haze = 0.2 })
	effect("ColorCorrectionEffect", { Brightness = 0, Contrast = 0.1, Saturation = 0.08, TintColor = rgb(255, 242, 226) })
	effect("BloomEffect", { Intensity = 0.25, Size = 18, Threshold = 2.2 })
	effect("SunRaysEffect", { Intensity = 0.04, Spread = 0.6 })
end

function Scenery.build()
	local existing = workspace:FindFirstChild("Cafe")
	if existing then
		existing:Destroy()
	end
	root = Instance.new("Model")
	root.Name = "Cafe"

	buildFloor()
	buildWalls()
	buildOutside()
	buildCounter()
	buildFurniture()
	buildLights()
	setupLighting()

	root.Parent = workspace
	return root
end

return Scenery
