--!strict
-- Tutorial do forno: aparece uma vez só, no primeiro dia em que os quitutes já estão liberados
-- (logo depois de "Abrir o café", antes de chegar o primeiro cliente). O servidor guarda que já foi
-- visto (PastryTutorialSeen) quando o dia começa.
-- Demonstração em cadeia, com pouco texto: cliente pede -> arrasta pro forno -> tira no verde -> perfeito paga +25%.
-- Tela larga: os 4 passos numa linha. Tela estreita (celular em pé): 2 linhas, com uma seta para baixo no meio.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local PixelArt = require(script.Parent.Parent.Art.PixelArt)
local Sprites = require(script.Parent.Parent.Art.Sprites)
local Sfx = require(script.Parent.Parent.Sfx)
local Theme = require(script.Parent.Theme)

local PastryTutorial = {}

-- mesmas zonas e cores da barra do forno (PastryPopup)
local RAW_END = 0.5
local PERFECT_START, PERFECT_END = 0.62, 0.82
local BURN_START = 0.9
local RAW_COLOR = Color3.fromRGB(214, 206, 196)
local BURN_COLOR = Color3.fromRGB(90, 60, 50)

local TOUCH = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

local gui: ScreenGui

-- nível em que o primeiro quitute libera (hoje 3)
function PastryTutorial.unlockLevel(): number
	local level = math.huge
	for _, id in Catalog.PastryOrder do
		level = math.min(level, Catalog.Pastries[id].Level)
	end
	return level
end

function PastryTutorial.init(playerGui: PlayerGui)
	gui = Instance.new("ScreenGui")
	gui.Name = "PastryTutorial"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 30
	gui.Enabled = false
	gui.Parent = playerGui
end

------------------------------------------------------------------ peças

-- seta da cadeia, feita a partir da ArrowLeft (virada pra direita ou pra baixo) e pintada de mostarda
local function arrowSprite(dir: "Right" | "Down"): Sprites.Sprite
	local rows = Sprites.ArrowLeft.Rows
	local out = {}
	if dir == "Right" then
		for _, row in rows do
			table.insert(out, string.reverse(row))
		end
	else
		-- transposta da seta pra direita: a ponta fica embaixo
		local right = {}
		for _, row in rows do
			table.insert(right, string.reverse(row))
		end
		for x = 1, #right[1] do
			local line = {}
			for y = 1, #right do
				table.insert(line, string.sub(right[y], x, x))
			end
			table.insert(out, table.concat(line))
		end
	end
	return { Rows = out, Palette = { o = Sprites.ArrowLeft.Palette.o, P = Theme.Mustard } }
end

local function sprite(name: string, parent: GuiObject, pos: UDim2, size: UDim2, z: number?): Frame
	local holder = Instance.new("Frame")
	holder.Name = name
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = pos
	holder.Size = size
	holder.ZIndex = z or 3
	holder.Parent = parent
	PixelArt.draw((Sprites :: any)[name], z or 3).Parent = holder
	return holder
end

local function text(parent: GuiObject, s: string, pos: UDim2, size: UDim2, color: Color3?, z: number?): TextLabel
	local l = Theme.label(s, color)
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = pos
	l.Size = size
	l.ZIndex = z or 3
	l.Parent = parent
	return l
end

-- card de um passo: número no canto, área da imagem em cima e legenda embaixo
local function stepCard(parent: GuiObject, index: number, caption: string): (Frame, Frame)
	local card = Instance.new("Frame")
	card.Name = "Step" .. index
	card.BackgroundColor3 = Color3.fromRGB(244, 230, 206)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.ZIndex = 2
	card.Parent = parent
	Theme.corner(card, 0.08)
	Theme.stroke(card, 2)

	local art = Instance.new("Frame")
	art.Name = "Art"
	art.BackgroundTransparency = 1
	art.Position = UDim2.fromScale(0.06, 0.06)
	art.Size = UDim2.fromScale(0.88, 0.62)
	art.ZIndex = 3
	art.Parent = card

	local cap = text(card, caption, UDim2.fromScale(0.5, 0.84), UDim2.fromScale(0.9, 0.24), Theme.Ink)
	cap.TextWrapped = true
	local capLimit = Instance.new("UITextSizeConstraint")
	capLimit.MaxTextSize = 30
	capLimit.Parent = cap

	local badge = Instance.new("Frame")
	badge.Name = "Number"
	badge.BackgroundColor3 = Theme.SageDark
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.fromScale(0.1, 0.08)
	badge.Size = UDim2.fromScale(0.2, 0.2)
	badge.SizeConstraint = Enum.SizeConstraint.RelativeXX
	badge.ZIndex = 5
	badge.Parent = card
	Theme.corner(badge, 0.5)
	Theme.stroke(badge, 2)
	text(badge, tostring(index), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.7, 0.7), Theme.Paper, 6)

	return card, art
end

-- 1) balão de pedido com o quitute
local function artOrder(art: Frame, pastryIcon: string)
	local bubble = Instance.new("Frame")
	bubble.BackgroundColor3 = Theme.Paper
	bubble.AnchorPoint = Vector2.new(0.5, 0.5)
	bubble.Position = UDim2.fromScale(0.5, 0.45)
	bubble.Size = UDim2.fromScale(0.62, 0.62)
	bubble.SizeConstraint = Enum.SizeConstraint.RelativeYY
	bubble.ZIndex = 3
	bubble.Parent = art
	Theme.corner(bubble, 0.25)
	Theme.stroke(bubble, 2)
	-- rabinho do balão
	local tail = Instance.new("Frame")
	tail.BackgroundColor3 = Theme.Paper
	tail.AnchorPoint = Vector2.new(0.5, 0.5)
	tail.Position = UDim2.fromScale(0.3, 1)
	tail.Size = UDim2.fromScale(0.2, 0.2)
	tail.Rotation = 45
	tail.ZIndex = 2
	tail.Parent = bubble
	Theme.stroke(tail, 2)
	local icon = sprite(pastryIcon, bubble, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.72, 0.72), 4)
	return icon
end

-- 2) quitute indo até o forno (animado)
local function artDrag(art: Frame, pastryIcon: string): Frame
	sprite("Oven", art, UDim2.fromScale(0.68, 0.55), UDim2.fromScale(0.62, 0.9), 3)
	local mover = sprite(pastryIcon, art, UDim2.fromScale(0.2, 0.3), UDim2.fromScale(0.32, 0.42), 5)
	return mover
end

-- 3) barra do forno com o ponteiro correndo e o botão "Tirar!"
local function artBar(art: Frame): Frame
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.BackgroundColor3 = RAW_COLOR
	bar.AnchorPoint = Vector2.new(0.5, 0.5)
	bar.Position = UDim2.fromScale(0.5, 0.32)
	bar.Size = UDim2.fromScale(0.94, 0.24)
	bar.ClipsDescendants = true
	bar.ZIndex = 3
	bar.Parent = art
	Theme.corner(bar, 0.3)
	local function zone(a: number, b: number, color: Color3)
		local z = Instance.new("Frame")
		z.BorderSizePixel = 0
		z.BackgroundColor3 = color
		z.Position = UDim2.fromScale(a, 0)
		z.Size = UDim2.fromScale(b - a, 1)
		z.ZIndex = 3
		z.Parent = bar
	end
	zone(0, RAW_END, RAW_COLOR)
	zone(RAW_END, PERFECT_START, Theme.Mustard)
	zone(PERFECT_START, PERFECT_END, Theme.Sage)
	zone(PERFECT_END, BURN_START, Theme.Mustard)
	zone(BURN_START, 1, BURN_COLOR)
	local outline = Instance.new("Frame")
	outline.BackgroundTransparency = 1
	outline.Position = bar.Position
	outline.AnchorPoint = bar.AnchorPoint
	outline.Size = bar.Size
	outline.ZIndex = 5
	outline.Parent = art
	Theme.corner(outline, 0.3)
	Theme.stroke(outline, 2)

	local needle = Instance.new("Frame")
	needle.Name = "Needle"
	needle.BackgroundColor3 = Theme.Ink
	needle.BorderSizePixel = 0
	needle.AnchorPoint = Vector2.new(0.5, 0.5)
	needle.Position = UDim2.new(0, 0, 0.32, 0)
	needle.Size = UDim2.fromScale(0.035, 0.38)
	needle.ZIndex = 6
	needle.Parent = art
	Theme.corner(needle, 0.5)

	-- setinha em cima da zona verde
	local mark = sprite("Star", art, UDim2.fromScale(0.05 + 0.9 * (PERFECT_START + PERFECT_END) / 2, 0.06), UDim2.fromScale(0.16, 0.16), 6)
	mark.SizeConstraint = Enum.SizeConstraint.RelativeYY

	local button = Instance.new("Frame")
	button.Name = "Take"
	button.BackgroundColor3 = Theme.Rose
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.fromScale(0.5, 0.78)
	button.Size = UDim2.fromScale(0.62, 0.3)
	button.ZIndex = 4
	button.Parent = art
	Theme.corner(button, 0.3)
	Theme.stroke(button, 2)
	text(button, "Tirar!", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.8, 0.72), Theme.Paper, 5)
	return needle
end

-- 4) resultado: estrela + moeda "+25%"
local function artPay(art: Frame): Frame
	local star = sprite("Star", art, UDim2.fromScale(0.3, 0.42), UDim2.fromScale(0.42, 0.62), 4)
	sprite("Coin", art, UDim2.fromScale(0.66, 0.42), UDim2.fromScale(0.36, 0.52), 4)
	local plus = text(art, "+25%", UDim2.fromScale(0.5, 0.9), UDim2.fromScale(0.8, 0.26), Theme.SageDark, 5)
	local s = Instance.new("UIStroke")
	s.Thickness = 1.5
	s.Color = Theme.Paper
	s.Parent = plus
	return star
end

------------------------------------------------------------------ montagem

local function arrow(parent: GuiObject, dir: "Right" | "Down", pos: UDim2, size: UDim2): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Arrow" .. dir
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = pos
	holder.Size = size
	holder.ZIndex = 3
	holder.Parent = parent
	PixelArt.draw(arrowSprite(dir), 3).Parent = holder
	return holder
end

-- Mostra o tutorial e espera o jogador tocar em "Entendi!" (bloqueia a thread que chamou).
-- pastryId: quitute de exemplo (o primeiro que o jogador tem, ou o primeiro do catálogo)
function PastryTutorial.show(pastryId: string?)
	local id = pastryId
	if not id or not Catalog.Pastries[id] then
		id = Catalog.PastryOrder[1]
	end
	local icon = Catalog.Pastries[id :: string].Icon

	local viewport = workspace.CurrentCamera.ViewportSize
	local narrow = viewport.X / math.max(viewport.Y, 1) < 1.25

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundColor3 = Color3.new(0, 0, 0)
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Active = true -- segura os toques: nada atrás reage enquanto o tutorial está aberto
	root.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.BackgroundColor3 = Theme.Paper
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = if narrow then UDim2.fromScale(0.94, 0.9) else UDim2.fromScale(0.9, 0.86)
	panel.ZIndex = 1
	panel.Parent = root
	Theme.corner(panel, 0.04)
	Theme.stroke(panel, 4)
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = if narrow then 0.62 else 1.75
	ratio.Parent = panel
	local maxSize = Instance.new("UISizeConstraint")
	maxSize.MaxSize = if narrow then Vector2.new(520, 840) else Vector2.new(980, 560)
	maxSize.Parent = panel
	local scale = Instance.new("UIScale")
	scale.Scale = 0.85
	scale.Parent = panel

	local title = text(panel, "Como assar quitutes", UDim2.fromScale(0.5, if narrow then 0.065 else 0.1), UDim2.fromScale(0.8, if narrow then 0.065 else 0.1), Theme.Ink)
	local titleStroke = Instance.new("UIStroke")
	titleStroke.Thickness = 2
	titleStroke.Color = Theme.PaperShade
	titleStroke.Parent = title

	local captions = { "Cliente pede", "Arraste pro forno", "Tire no verde!", "Perfeito paga mais" }
	local cards: { Frame } = {}
	local arts: { Frame } = {}
	for i, cap in captions do
		local card, art = stepCard(panel, i, cap)
		cards[i] = card
		arts[i] = art
	end
	local arrows: { Frame } = {}

	if narrow then
		-- 1 -> 2 / seta pra baixo / 3 -> 4
		local w, h = 0.4, 0.29
		local rowY = { 0.27, 0.66 }
		for i, card in cards do
			local row = if i <= 2 then 1 else 2
			local col = if i % 2 == 1 then 0.26 else 0.74
			card.Size = UDim2.fromScale(w, h)
			card.Position = UDim2.fromScale(col, rowY[row])
		end
		table.insert(arrows, arrow(panel, "Right", UDim2.fromScale(0.5, rowY[1]), UDim2.fromScale(0.07, 0.06)))
		table.insert(arrows, arrow(panel, "Down", UDim2.fromScale(0.5, 0.465), UDim2.fromScale(0.06, 0.07)))
		table.insert(arrows, arrow(panel, "Right", UDim2.fromScale(0.5, rowY[2]), UDim2.fromScale(0.07, 0.06)))
	else
		local w, gap = 0.19, 0.05
		local start = (1 - (4 * w + 3 * gap)) / 2
		for i, card in cards do
			card.Size = UDim2.fromScale(w, 0.52)
			card.Position = UDim2.fromScale(start + w / 2 + (i - 1) * (w + gap), 0.45)
		end
		for i = 1, 3 do
			local x = start + i * w + (i - 1) * gap + gap / 2
			table.insert(arrows, arrow(panel, "Right", UDim2.fromScale(x, 0.45), UDim2.fromScale(0.04, 0.07)))
		end
	end

	artOrder(arts[1], icon)
	local mover = artDrag(arts[2], icon)
	local needle = artBar(arts[3])
	local star = artPay(arts[4])

	-- aviso curtinho dos erros
	local note = text(
		panel,
		if narrow then "Cru ou queimado: não paga o quitute\nAssar de novo: 70% do preço" else "Cru ou queimado: não paga o quitute  ·  Assar de novo: 70% do preço",
		UDim2.fromScale(0.5, if narrow then 0.845 else 0.755),
		UDim2.fromScale(0.9, if narrow then 0.07 else 0.055),
		Theme.WoodDark
	)
	note.Font = Enum.Font.GothamMedium
	note.TextWrapped = true

	local button = Instance.new("TextButton")
	button.Name = "Ok"
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.fromScale(0.5, if narrow then 0.935 else 0.9)
	button.Size = if narrow then UDim2.fromScale(0.6, 0.08) else UDim2.fromScale(0.28, 0.11)
	button.BackgroundColor3 = Theme.SageDark
	button.Font = Theme.Font
	button.TextScaled = true
	button.TextColor3 = Theme.Paper
	button.Text = "Entendi!"
	button.ZIndex = 4
	button.Parent = panel
	Theme.corner(button, 0.3)
	Theme.stroke(button, 3)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.18, 0)
	pad.PaddingBottom = UDim.new(0.18, 0)
	pad.Parent = button
	-- no celular o botão nunca fica menor que a ponta do dedo (44 pt de altura)
	local minButton = Instance.new("UISizeConstraint")
	minButton.MinSize = if TOUCH then Vector2.new(150, 44) else Vector2.new(120, 36)
	minButton.Parent = button

	-- entrada: fundo escurece, painel cresce, depois os passos aparecem um por um
	for _, card in cards do
		card.Visible = false
	end
	for _, a in arrows do
		a.Visible = false
	end
	button.Visible = false
	gui.Enabled = true
	Sfx.play("CutePop")
	TweenService:Create(root, TweenInfo.new(0.25), { BackgroundTransparency = 0.45 }):Play()
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	local alive = true
	task.spawn(function()
		task.wait(0.3)
		for i, card in cards do
			if not alive then
				return
			end
			card.Visible = true
			local cardScale = Instance.new("UIScale")
			cardScale.Scale = 0.6
			cardScale.Parent = card
			TweenService:Create(cardScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			task.wait(0.35)
			local a = arrows[i] -- seta que sai deste passo (o último não tem)
			if a and alive then
				a.Visible = true
				task.wait(0.2)
			end
		end
		if alive then
			button.Visible = true
		end
	end)

	-- animações em loop: setas pulsando, quitute indo pro forno, ponteiro andando, estrela piscando
	local t0 = os.clock()
	local arrowBase = {}
	for i, a in arrows do
		arrowBase[i] = a.Size
	end
	local conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		for i, a in arrows do
			local s = 1 + 0.12 * math.sin(t * 5 - i * 0.8)
			local base = arrowBase[i]
			a.Size = UDim2.fromScale(base.X.Scale * s, base.Y.Scale * s)
		end
		-- arrasto: vai do canto até a porta do forno em 1,2 s, some, recomeça
		local d = (t % 1.8) / 1.2
		if d <= 1 then
			local e = 1 - (1 - d) ^ 2
			mover.Position = UDim2.fromScale(0.2 + 0.46 * e, 0.3 + 0.28 * e)
			mover.Visible = true
		else
			mover.Visible = false
		end
		-- ponteiro: cruza a barra em 2 s e para um instante no verde
		local cycle = t % 2.6
		local p = if cycle < 1.45 then (cycle / 1.45) * 0.72 else 0.72
		needle.Position = UDim2.new(0.03 + 0.94 * p, 0, 0.32, 0)
		-- estrela "respira"
		local k = 1 + 0.08 * math.sin(t * 4)
		star.Size = UDim2.fromScale(0.42 * k, 0.62 * k)
	end)

	local closed = Instance.new("BindableEvent")
	button.Activated:Connect(function()
		if not alive then
			return
		end
		alive = false
		conn:Disconnect()
		TweenService:Create(root, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
		local out = TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0.01 })
		out.Completed:Once(function()
			root:Destroy()
			gui.Enabled = false
			closed:Fire()
		end)
		out:Play()
	end)
	closed.Event:Wait()
	closed:Destroy()
end

return PastryTutorial
