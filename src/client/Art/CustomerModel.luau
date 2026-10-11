--!strict
-- Cliente "pixel 3D" feito de blocos. As partes são animadas manualmente
-- a partir de um CFrame raiz (nos pés), sem Humanoid.

export type Limb = {
	Part: BasePart,
	Pivot: CFrame, -- articulação relativa à raiz
	Offset: CFrame, -- posição relativa à articulação
	Swing: number, -- quanto balança ao andar (sinal = fase)
}

export type CustomerModel = {
	Model: Model,
	Head: BasePart,
	Cup: BasePart,
	Limbs: { Limb },
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Characters = require(ReplicatedStorage.Shared.Characters)

local rgb = Color3.fromRGB

local SKIN = { rgb(255, 219, 186), rgb(241, 194, 150), rgb(214, 158, 112), rgb(170, 116, 78), rgb(122, 80, 54) }
local HAIR = { rgb(56, 38, 30), rgb(92, 58, 38), rgb(196, 140, 80), rgb(236, 206, 140), rgb(40, 40, 46), rgb(176, 84, 60), rgb(210, 150, 170) }
local SHIRT = { rgb(240, 160, 150), rgb(150, 190, 220), rgb(170, 206, 160), rgb(246, 210, 120), rgb(200, 170, 220), rgb(250, 240, 226), rgb(230, 130, 100) }
local PANTS = { rgb(70, 80, 110), rgb(90, 70, 60), rgb(60, 60, 66), rgb(140, 120, 90), rgb(110, 130, 150) }
local ACCENT = { rgb(214, 80, 76), rgb(246, 202, 96), rgb(120, 170, 220), rgb(150, 190, 150), rgb(250, 250, 244) }

local CustomerModel = {}

local function pick<T>(rng: Random, list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

export type Style = "Normal" | "Kid" | "Critic" | "Regular"

-- style muda a silhueta: criança é menor, crítico usa boina e óculos,
-- regular tem aparência fixa (rng com seed) e um cachecol listrado.
-- look (opcional) define o visual exato de um personagem (ver Characters.Look).
function CustomerModel.build(rng: Random, style: Style?, look: Characters.Look?): CustomerModel
	style = style or "Normal"
	local model = Instance.new("Model")
	model.Name = "Customer"
	local limbs: { Limb } = {}
	local scale = if style == "Kid" or (look and look.Kid) then 0.72 else 1

	local skin = pick(rng, SKIN)
	local hair = pick(rng, HAIR)
	local shirt = pick(rng, SHIRT)
	local pants = pick(rng, PANTS)
	local accent = pick(rng, ACCENT)
	local shoes = rgb(60, 44, 40)
	if look then
		skin = look.Skin or skin
		hair = look.Hair or hair
		shirt = look.Top or look.Dress or shirt
		pants = look.Pants or (if look.Dress then skin else pants)
		shoes = look.Shoes or shoes
	end
	if style == "Critic" then
		shirt = rgb(60, 58, 66)
		pants = rgb(40, 40, 46)
		accent = rgb(150, 40, 60)
	end

	local function add(name: string, size: Vector3, color: Color3, pivot: CFrame, offset: CFrame, swing: number, shape: Enum.PartType?): BasePart
		local p = Instance.new("Part")
		p.Name = name
		if shape then
			p.Shape = shape
		end
		p.Size = size * scale
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Parent = model
		local function scaled(cf: CFrame): CFrame
			return cf - cf.Position + cf.Position * scale
		end
		table.insert(limbs, { Part = p, Pivot = scaled(pivot), Offset = scaled(offset), Swing = swing })
		return p
	end

	local I = CFrame.identity
	-- pernas + sapatos
	for _, side in { -1, 1 } do
		local hip = CFrame.new(side * 0.5, 2, 0)
		add("Leg", Vector3.new(0.9, 1.8, 0.95), pants, hip, CFrame.new(0, -0.9, 0), side)
		add("Shoe", Vector3.new(0.95, 0.35, 1.2), shoes, hip, CFrame.new(0, -1.82, -0.1), side)
	end
	-- tronco
	local torsoPivot = CFrame.new(0, 3.1, 0)
	add("Torso", Vector3.new(2.2, 2.2, 1.2), shirt, torsoPivot, I, 0)
	if look then
		if look.Dress then
			-- vestido camponês: saia rodada, barrado e bordadinho no decote
			local trim = look.DressTrim or accent
			add("Skirt", Vector3.new(2.5, 1.5, 1.5), look.Dress, torsoPivot, CFrame.new(0, -1.55, 0), 0)
			add("SkirtTrim", Vector3.new(2.56, 0.2, 1.56), trim, torsoPivot, CFrame.new(0, -2.2, 0), 0)
			add("Neckline", Vector3.new(1.3, 0.16, 0.08), trim, torsoPivot, CFrame.new(0, 0.78, -0.62), 0)
			add("Waist", Vector3.new(2.26, 0.22, 1.26), trim, torsoPivot, CFrame.new(0, -0.55, 0), 0)
			if look.DressFlowers then
				-- florzinhas: pétalas na cor da estampa com miolo amarelo, na frente e atrás
				local spots = {
					Vector2.new(-0.7, 0.35), Vector2.new(0.55, 0.1), Vector2.new(-0.1, -0.2),
					Vector2.new(-0.8, -1.2), Vector2.new(0.2, -1.05), Vector2.new(0.85, -1.5),
					Vector2.new(-0.35, -1.8), Vector2.new(0.6, -1.95),
				}
				for _, face in { -1, 1 } do
					for _, sp in spots do
						local skirt = sp.Y < -0.6
						local z = face * (if skirt then 0.77 else 0.62)
						add("Flower", Vector3.new(0.3, 0.3, 0.05), look.DressFlowers, torsoPivot, CFrame.new(sp.X, sp.Y, z), 0)
						add("FlowerCenter", Vector3.new(0.12, 0.12, 0.06), rgb(250, 214, 96), torsoPivot, CFrame.new(sp.X, sp.Y, z + face * 0.01), 0)
					end
				end
			end
		end
		if look.TopStripe then
			-- camisa xadrez
			for _, x in { -0.62, 0.18 } do
				add("Plaid", Vector3.new(0.26, 2.22, 1.24), look.TopStripe, torsoPivot, CFrame.new(x, 0, 0), 0)
			end
			for _, y in { 0.45, -0.45 } do
				add("Plaid", Vector3.new(2.24, 0.24, 1.24), look.TopStripe, torsoPivot, CFrame.new(0, y, 0), 0)
			end
		end
	else
		add("Scarf", Vector3.new(2.3, 0.4, 1.3), accent, torsoPivot, CFrame.new(0, 0.95, 0), 0)
		if rng:NextNumber() < 0.5 then
			add("Pocket", Vector3.new(0.5, 0.5, 0.1), accent, torsoPivot, CFrame.new(-0.5, 0.1, -0.62), 0)
		end
	end
	-- braços + mãos
	local cup: BasePart? = nil
	for _, side in { -1, 1 } do
		local shoulder = CFrame.new(side * 1.45, 4.0, 0)
		if look and look.ShortSleeves then
			-- manga curta: só o topo do braço tem a cor da camiseta
			local forearm = if side == 1 and look.RightArm then look.RightArm else skin
			add("Sleeve", Vector3.new(0.76, 0.7, 0.86), shirt, shoulder, CFrame.new(0, -0.25, 0), -side)
			add("Arm", Vector3.new(0.7, 1.25, 0.8), forearm, shoulder, CFrame.new(0, -1.15, 0), -side)
			if side == 1 and look.Tattoo then
				-- traços de tatuagem por cima do braço preto
				local ink = rgb(92, 92, 104)
				add("Tattoo", Vector3.new(0.46, 0.07, 0.04), ink, shoulder, CFrame.new(0, -0.8, -0.41), -side)
				add("Tattoo", Vector3.new(0.46, 0.07, 0.04), ink, shoulder, CFrame.new(0, -1.5, -0.41), -side)
				add("Tattoo", Vector3.new(0.2, 0.2, 0.04), rgb(176, 44, 56), shoulder, CFrame.new(0, -1.15, -0.41) * CFrame.Angles(0, 0, math.rad(45)), -side)
				add("Tattoo", Vector3.new(0.1, 0.1, 0.05), rgb(96, 150, 84), shoulder, CFrame.new(0.16, -1.3, -0.41), -side)
				add("Tattoo", Vector3.new(0.04, 0.9, 0.08), ink, shoulder, CFrame.new(0.36, -1.15, 0), -side)
				add("Tattoo", Vector3.new(0.04, 0.12, 0.3), ink, shoulder, CFrame.new(0.36, -0.95, 0), -side)
				add("Tattoo", Vector3.new(0.04, 0.12, 0.3), ink, shoulder, CFrame.new(0.36, -1.35, 0), -side)
			end
		else
			local armColor = if side == 1 and look and look.RightArm then look.RightArm else shirt
			add("Arm", Vector3.new(0.7, 1.9, 0.8), armColor, shoulder, CFrame.new(0, -0.85, 0), -side)
		end
		add("Hand", Vector3.new(0.6, 0.5, 0.7), skin, shoulder, CFrame.new(0, -2.0, 0), -side)
		if look and look.Dress then
			add("Puff", Vector3.new(0.85, 0.6, 0.95), look.Dress, shoulder, CFrame.new(0, -0.25, 0), -side)
		end
		if look and look.TopStripe then
			add("PlaidArm", Vector3.new(0.74, 0.24, 0.84), look.TopStripe, shoulder, CFrame.new(0, -0.7, 0), -side)
		end
		if side == 1 then
			local c = add("Cup", Vector3.new(0.7, 0.55, 0.55), rgb(250, 242, 226), shoulder, CFrame.new(0, -2.05, -0.55) * CFrame.Angles(0, 0, math.rad(90)), -side, Enum.PartType.Cylinder)
			c.Transparency = 1
			cup = c
		end
	end
	-- cabeça + rosto
	local neck = CFrame.new(0, 5.1, 0)
	local head = add("Head", Vector3.new(1.8, 1.8, 1.8), skin, neck, I, 0)
	local beard = look and look.Beard
	for _, side in { -1, 1 } do
		add("Eye", Vector3.new(0.22, 0.42, 0.1), rgb(40, 30, 30), neck, CFrame.new(side * 0.42, 0.05, -0.91), 0)
		if not beard then
			add("Cheek", Vector3.new(0.34, 0.18, 0.08), rgb(240, 150, 150), neck, CFrame.new(side * 0.64, -0.32, -0.91), 0)
		end
	end
	if look and look.Glasses then
		-- óculos de grau: armação em volta dos olhos (os olhos continuam aparecendo)
		local g = look.Glasses
		for _, side in { -1, 1 } do
			local x = side * 0.42
			add("GlassTop", Vector3.new(0.66, 0.09, 0.06), g, neck, CFrame.new(x, 0.33, -0.94), 0)
			add("GlassBottom", Vector3.new(0.66, 0.09, 0.06), g, neck, CFrame.new(x, -0.23, -0.94), 0)
			add("GlassOuter", Vector3.new(0.09, 0.62, 0.06), g, neck, CFrame.new(x + side * 0.29, 0.05, -0.94), 0)
			add("GlassInner", Vector3.new(0.09, 0.62, 0.06), g, neck, CFrame.new(x - side * 0.29, 0.05, -0.94), 0)
			add("GlassArm", Vector3.new(0.06, 0.09, 0.9), g, neck, CFrame.new(side * 0.93, 0.3, -0.5), 0)
		end
		add("GlassBridge", Vector3.new(0.2, 0.08, 0.06), g, neck, CFrame.new(0, 0.2, -0.94), 0)
	end
	if beard and look and look.ShortBeard then
		-- barba rente: faixa fina contornando o queixo
		add("BeardChin", Vector3.new(1.3, 0.28, 0.1), beard, neck, CFrame.new(0, -0.76, -0.88), 0)
		add("Mustache", Vector3.new(0.6, 0.1, 0.08), beard, neck, CFrame.new(0, -0.36, -0.92), 0)
		for _, side in { -1, 1 } do
			add("BeardSide", Vector3.new(0.14, 0.6, 0.5), beard, neck, CFrame.new(side * 0.86, -0.46, -0.6), 0)
		end
	elseif beard then
		add("BeardChin", Vector3.new(1.5, 0.5, 0.22), beard, neck, CFrame.new(0, -0.68, -0.84), 0)
		add("Mustache", Vector3.new(0.8, 0.14, 0.1), beard, neck, CFrame.new(0, -0.32, -0.93), 0)
		for _, side in { -1, 1 } do
			add("BeardSide", Vector3.new(0.28, 0.85, 0.6), beard, neck, CFrame.new(side * 0.82, -0.38, -0.58), 0)
		end
	end
	-- acessórios especiais
	if style == "Critic" then
		add("Beret", Vector3.new(2.1, 0.45, 2.1), rgb(150, 40, 60), neck, CFrame.new(0.15, 1.05, 0) * CFrame.Angles(0, 0, math.rad(-8)), 0)
		add("BeretTip", Vector3.new(0.25, 0.3, 0.25), rgb(150, 40, 60), neck, CFrame.new(0.15, 1.4, 0), 0)
		for _, side in { -1, 1 } do
			add("Lens", Vector3.new(0.55, 0.5, 0.08), rgb(30, 30, 34), neck, CFrame.new(side * 0.42, 0.08, -0.95), 0)
		end
		add("Bridge", Vector3.new(0.35, 0.1, 0.08), rgb(30, 30, 34), neck, CFrame.new(0, 0.15, -0.95), 0)
		add("Notebook", Vector3.new(0.7, 0.9, 0.15), rgb(240, 230, 200), CFrame.new(-1.45, 4.0, 0), CFrame.new(0.1, -2.0, -0.45), 1)
	elseif style == "Regular" and not look then
		for i = 0, 2 do
			add("Stripe", Vector3.new(2.34, 0.14, 1.34), if i % 2 == 0 then rgb(250, 244, 230) else accent, torsoPivot, CFrame.new(0, 0.82 + i * 0.13, 0), 0)
		end
	end

	-- cabelo / chapéu
	local hairStyle = rng:NextInteger(1, 4)
	if style == "Critic" then
		hairStyle = 1
	end
	local named = look and look.HairStyle
	if named == "Long" then
		-- cabelo comprido até os ombros, repartido de lado
		add("Hair", Vector3.new(1.95, 0.5, 1.95), hair, neck, CFrame.new(0, 0.85, 0), 0)
		add("HairBack", Vector3.new(1.95, 2.7, 0.5), hair, neck, CFrame.new(0, -0.45, 0.78), 0)
		add("SideBangs", Vector3.new(1.3, 0.32, 0.26), hair, neck, CFrame.new(-0.3, 0.68, -0.86), 0)
		for _, side in { -1, 1 } do
			add("Lock", Vector3.new(0.3, 2.2, 1.2), hair, neck, CFrame.new(side * 0.98, -0.35, 0.25), 0)
		end
		hairStyle = 0
	elseif named == "Fringe" then
		-- cabelo "compridinho" com franja cobrindo a testa
		add("Hair", Vector3.new(1.95, 0.55, 1.95), hair, neck, CFrame.new(0, 0.85, 0), 0)
		add("HairBack", Vector3.new(1.95, 1.7, 0.5), hair, neck, CFrame.new(0, 0.05, 0.77), 0)
		add("Fringe", Vector3.new(1.95, 0.5, 0.34), hair, neck, CFrame.new(0, 0.55, -0.86), 0)
		for _, side in { -1, 1 } do
			add("Side", Vector3.new(0.26, 1.1, 1.5), hair, neck, CFrame.new(side * 0.98, 0.2, 0.15), 0)
		end
		hairStyle = 0
	elseif named == "Bangs" then
		hairStyle = 1
	elseif named == "Bun" then
		hairStyle = 2
	elseif named == "Short" then
		hairStyle = 5
	end
	if look and look.Bow then
		-- lacinho preso na lateral da cabeça (fora do volume do cabelo)
		for _, dz in { -0.28, 0.28 } do
			add("Bow", Vector3.new(0.26, 0.42, 0.38), look.Bow, neck, CFrame.new(1.12, 0.8, -0.2 + dz), 0)
		end
		add("BowKnot", Vector3.new(0.3, 0.22, 0.22), look.Bow:Lerp(Color3.new(0, 0, 0), 0.2), neck, CFrame.new(1.14, 0.8, -0.2), 0)
	end
	if hairStyle == 0 then
		return {
			Model = model,
			Head = head,
			Cup = cup :: BasePart,
			Limbs = limbs,
		}
	end
	add("Hair", Vector3.new(1.95, 0.5, 1.95), hair, neck, CFrame.new(0, 0.85, 0), 0)
	add("HairBack", Vector3.new(1.95, 1.3, 0.45), hair, neck, CFrame.new(0, 0.25, 0.77), 0)
	if hairStyle == 1 then
		add("Bangs", Vector3.new(1.95, 0.4, 0.3), hair, neck, CFrame.new(0, 0.62, -0.86), 0)
	elseif hairStyle == 2 then
		add("Bun", Vector3.new(0.8, 0.8, 0.8), hair, neck, CFrame.new(0, 1.35, 0.3), 0)
	elseif hairStyle == 3 and style ~= "Critic" then
		add("Beanie", Vector3.new(2.05, 0.8, 2.05), accent, neck, CFrame.new(0, 1.05, 0), 0)
		add("Pompom", Vector3.new(0.5, 0.5, 0.5), rgb(250, 250, 244), neck, CFrame.new(0, 1.6, 0), 0, Enum.PartType.Ball)
	elseif hairStyle == 4 then
		add("LongHair", Vector3.new(1.95, 1.9, 0.5), hair, neck, CFrame.new(0, -0.1, 0.8), 0)
	end

	return {
		Model = model,
		Head = head,
		Cup = cup :: BasePart,
		Limbs = limbs,
	}
end

return CustomerModel
