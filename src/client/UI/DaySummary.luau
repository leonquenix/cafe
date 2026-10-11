--!strict
-- Placar do fim do dia: faturamento, bebidas entregues, reviews divertidos,
-- XP subindo e — se subir de nível — uma tela de "você aprendeu receitas novas!".

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Recipes = require(ReplicatedStorage.Shared.Recipes)
local Glass = require(script.Parent.Parent.Art.Glass)
local PixelArt = require(script.Parent.Parent.Art.PixelArt)
local Sprites = require(script.Parent.Parent.Art.Sprites)
local Reviews = require(script.Parent.Reviews)
local Theme = require(script.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

export type Summary = {
	day: number,
	earned: number,
	tips: number,
	wrong: number,
	orders: { Reviews.DeliveredOrder },
	xpGained: number,
	levelBefore: number,
	xpBefore: number,
	levelAfter: number,
	xpAfter: number,
}

local DaySummary = {}

local playerGui: PlayerGui

local function tween(inst: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function popIn(inst: GuiObject, delay: number?)
	local scale = inst:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = inst
	task.delay(delay or 0, function()
		tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
end

local function drinkGlass(drinkId: string): Frame
	local d = Recipes.Drinks[drinkId]
	local glass = Glass.new()
	glass:setPortions(Recipes.portions(drinkId))
	glass:setMix(if d.Mix then 1 else 0, 0)
	glass:setLevel(glass:targetLevel())
	return glass.Root
end

local function starsRow(count: number, height: UDim2, align: Enum.HorizontalAlignment?): Frame
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = height
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.Padding = UDim.new(0, 2)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = align or Enum.HorizontalAlignment.Left
	list.Parent = row
	for i = 1, 5 do
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromScale(1, 1)
		holder.SizeConstraint = Enum.SizeConstraint.RelativeYY
		holder.LayoutOrder = i
		PixelArt.draw(if i <= count then Sprites.Star else Sprites.StarOff).Parent = holder
		holder.Parent = row
	end
	return row
end

local function panel(scope: any, props: { [string]: any }): Frame
	local children = props[Children] or {}
	props[Children] = {
		scope:New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
		scope:New("UIStroke")({ Thickness = 3, Color = Theme.Ink }),
		children,
	}
	props.BackgroundColor3 = props.BackgroundColor3 or Theme.PaperShade
	return scope:New("Frame")(props)
end

local function label(scope: any, text: any, props: { [string]: any }): TextLabel
	props.BackgroundTransparency = 1
	props.Font = props.Font or Theme.Font
	props.TextScaled = true
	props.TextColor3 = props.TextColor3 or Theme.Ink
	props.Text = text
	return scope:New("TextLabel")(props)
end

------------------------------------------------------------------ tela de desbloqueio

local function confetti(parent: GuiObject, amount: number)
	local rng = Random.new()
	local colors = { Theme.Mustard, Theme.Rose, Theme.Sage, Theme.Paper, Color3.fromRGB(150, 196, 226) }
	for i = 1, amount do
		task.delay(i * 0.02, function()
			local c = Instance.new("Frame")
			c.BorderSizePixel = 0
			c.BackgroundColor3 = colors[rng:NextInteger(1, #colors)]
			c.Size = UDim2.fromOffset(rng:NextInteger(8, 14), rng:NextInteger(8, 14))
			c.AnchorPoint = Vector2.new(0.5, 0.5)
			local x = rng:NextNumber(0.05, 0.95)
			c.Position = UDim2.fromScale(x, -0.05)
			c.ZIndex = 40
			c.Parent = parent
			local t = TweenService:Create(c, TweenInfo.new(rng:NextNumber(1.6, 2.6), Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.fromScale(x + rng:NextNumber(-0.1, 0.1), 1.05),
				Rotation = rng:NextNumber(-540, 540),
			})
			t.Completed:Once(function()
				c:Destroy()
			end)
			t:Play()
		end)
	end
end

type UnlockKind = "drink" | "ingredient" | "shop" | "modifier"

local UNLOCK_TAGS = {
	drink = { "NOVA RECEITA!", Theme.Rose },
	ingredient = { "NOVO INGREDIENTE!", Theme.Sage },
	shop = { "NA LOJA!", Theme.Mustard },
	modifier = { "PEDIDO ESPECIAL!", Color3.fromRGB(150, 130, 200) },
}

local function unlockCard(scope: any, kind: UnlockKind, id: string, order: number, width: number): Frame
	local art: GuiObject
	local title: string
	local subtitle: string
	if kind == "drink" then
		art = drinkGlass(id)
		title = Recipes.Drinks[id].Name
		subtitle = Recipes.describe(id) .. (if Recipes.Drinks[id].Mix then " + mexer" else "")
	elseif kind == "ingredient" then
		art = PixelArt.ingredient(id)
		title = Recipes.Ingredients[id].Name
		subtitle = "Novo ingrediente na bancada!"
	elseif kind == "modifier" then
		art = PixelArt.draw(Sprites.Spoon)
		title = Recipes.Modifiers[id].Name
		subtitle = "Clientes vão pedir. Paga +25%!"
	else
		local item: any = Catalog.Upgrades[id] or Catalog.Pastries[id] or Catalog.Decor[id]
		art = PixelArt.draw((Sprites :: any)[item.Icon])
		title = item.Name
		subtitle = "Disponível na loja!"
	end

	local card = panel(scope, {
		Name = id,
		LayoutOrder = order,
		BackgroundColor3 = Theme.Paper,
		Size = UDim2.fromScale(width, 1),
		[Children] = {
			scope:New("UIAspectRatioConstraint")({ AspectRatio = 0.72 }),
			scope:New("Frame")({
				Name = "Tag",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0),
				Size = UDim2.fromScale(0.8, 0.11),
				BackgroundColor3 = UNLOCK_TAGS[kind][2],
				ZIndex = 3,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					scope:New("UIStroke")({ Thickness = 3, Color = Theme.Ink }),
					label(scope, UNLOCK_TAGS[kind][1], {
						Position = UDim2.fromScale(0.05, 0.15),
						Size = UDim2.fromScale(0.9, 0.7),
						TextColor3 = Theme.Paper,
						ZIndex = 4,
					}),
				},
			}),
			scope:New("Frame")({
				Name = "Art",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.12, 0.1),
				Size = UDim2.fromScale(0.76, 0.52),
				[Children] = art,
			}),
			label(scope, title, {
				Position = UDim2.fromScale(0.06, 0.64),
				Size = UDim2.fromScale(0.88, 0.13),
			}),
			label(scope, subtitle, {
				Position = UDim2.fromScale(0.06, 0.79),
				Size = UDim2.fromScale(0.88, 0.14),
				TextColor3 = Theme.WoodDark,
				TextWrapped = true,
			}),
		},
	})
	return card
end

local function showLevelUp(scope: any, parent: GuiObject, levelBefore: number, levelAfter: number, onClose: () -> ())
	local drinks, ingredients = Progression.unlocksBetween(levelBefore, levelAfter)

	local rays = scope:New("Frame")({
		Name = "Rays",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(1.6, 1.6),
		SizeConstraint = Enum.SizeConstraint.RelativeXX,
	})
	for i = 0, 11 do
		local r = Instance.new("Frame")
		r.BorderSizePixel = 0
		r.AnchorPoint = Vector2.new(0.5, 0.5)
		r.Position = UDim2.fromScale(0.5, 0.5)
		r.Size = UDim2.fromScale(0.05, 1)
		r.Rotation = i * 15
		r.BackgroundColor3 = if i % 2 == 0 then Theme.Mustard else Theme.Paper
		r.BackgroundTransparency = 0.82
		r.Parent = rays
	end

	local entries: { { kind: UnlockKind, id: string } } = {}
	for _, id in drinks do
		table.insert(entries, { kind = "drink", id = id })
	end
	for _, id in ingredients do
		table.insert(entries, { kind = "ingredient", id = id })
	end
	for _, id in Recipes.ModifierOrder do
		local lv = Recipes.Modifiers[id].Level
		if lv > levelBefore and lv <= levelAfter then
			table.insert(entries, { kind = "modifier", id = id })
		end
	end
	for _, group in { { Catalog.UpgradeOrder, Catalog.Upgrades }, { Catalog.PastryOrder, Catalog.Pastries }, { Catalog.DecorOrder, Catalog.Decor } } do
		for _, id in group[1] :: { string } do
			local lv = (group[2] :: any)[id].Level
			if lv > levelBefore and lv <= levelAfter then
				table.insert(entries, { kind = "shop", id = id })
			end
		end
	end
	local width = math.min(0.22, 0.95 / math.max(#entries, 1) - 0.02)
	local cards = {}
	for i, e in entries do
		table.insert(cards, unlockCard(scope, e.kind, e.id, i, width))
	end

	local banner = label(scope, `NÍVEL {levelAfter}!`, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.13),
		Size = UDim2.fromScale(0.6, 0.13),
		TextColor3 = Theme.Mustard,
		ZIndex = 5,
		[Children] = scope:New("UIStroke")({ Thickness = 5, Color = Theme.Ink }),
	})
	local caption = label(scope, if #cards > 0 then "Você aprendeu coisas novas:" else "Continue assim, barista!", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.23),
		Size = UDim2.fromScale(0.6, 0.05),
		TextColor3 = Theme.Paper,
		ZIndex = 5,
	})

	local closeButton = scope:New("TextButton")({
		Name = "Close",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.88),
		Size = UDim2.fromScale(0.2, 0.09),
		BackgroundColor3 = Theme.SageDark,
		Font = Theme.Font,
		Text = "Oba!",
		TextScaled = true,
		TextColor3 = Theme.Paper,
		ZIndex = 6,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0.3, 0) }),
			scope:New("UIStroke")({ Thickness = 3, Color = Theme.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			scope:New("UIPadding")({ PaddingTop = UDim.new(0.15, 0), PaddingBottom = UDim.new(0.15, 0) }),
		},
	})

	local overlay = scope:New("Frame")({
		Name = "LevelUp",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(30, 20, 24),
		BackgroundTransparency = 1,
		ZIndex = 30,
		ClipsDescendants = true,
		Parent = parent,
		[Children] = {
			rays,
			banner,
			caption,
			scope:New("Frame")({
				Name = "Cards",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.54),
				Size = UDim2.fromScale(0.94, 0.5),
				ZIndex = 5,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0.025, 0),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					cards,
				},
			}),
			closeButton,
		},
	})

	tween(overlay, 0.3, { BackgroundTransparency = 0.25 })
	popIn(banner, 0.1)
	popIn(caption, 0.35)
	for i, card in cards do
		popIn(card, 0.6 + i * 0.25)
		card.Rotation = -8
		task.delay(0.6 + i * 0.25, function()
			tween(card, 0.5, { Rotation = 0 }, Enum.EasingStyle.Back)
		end)
	end
	popIn(closeButton, 0.9 + #cards * 0.25)
	confetti(overlay, 60)

	local spin = RunService.RenderStepped:Connect(function(dt)
		rays.Rotation += dt * 12
	end)

	local closed = false
	closeButton.Activated:Connect(function()
		if closed then
			return
		end
		closed = true
		spin:Disconnect()
		overlay:Destroy()
		onClose()
	end)
end

------------------------------------------------------------------ placar

function DaySummary.init(gui: PlayerGui)
	playerGui = gui
end

function DaySummary.show(summary: Summary, onContinue: () -> ())
	local scope = Fusion.scoped(Fusion)

	local totalStars = 0
	local drinkCounts: { [string]: number } = {}
	local wrongCounts: { [string]: number } = {}
	local served = 0
	for _, o in summary.orders do
		if o.wrong then
			totalStars += 1 -- pedido errado vale 1 estrela
			wrongCounts[o.drink] = (wrongCounts[o.drink] or 0) + 1
		else
			served += 1
			totalStars += Reviews.stars(o.tier)
			drinkCounts[o.drink] = (drinkCounts[o.drink] or 0) + 1
		end
	end
	local rated = #summary.orders
	local avgStars = if rated > 0 then math.floor(totalStars / rated + 0.5) else 0

	local shownMoney = scope:Value(0)
	local xpLevel = scope:Value(summary.levelBefore)
	local xpFill = scope:Value(summary.xpBefore / Progression.xpToNext(summary.levelBefore))
	local xpText = scope:Value("")
	local continueVisible = scope:Value(false)

	-- bebidas entregues (as erradas/incompletas também, num card avermelhado logo depois)
	local tiles = {}
	local tileOrder = 0
	local shownDrinks = table.clone(Recipes.DrinkOrder)
	table.move(Recipes.SecretDrinkOrder, 1, #Recipes.SecretDrinkOrder, #shownDrinks + 1, shownDrinks)
	local function addTile(id: string, n: number, wrong: boolean)
		tileOrder += 1
		local tile = panel(scope, {
			Name = if wrong then `{id}Wrong` else id,
			LayoutOrder = tileOrder,
			BackgroundColor3 = if wrong then Theme.Paper:Lerp(Theme.Rose, 0.35) else Theme.Paper,
			[Children] = {
				scope:New("Frame")({
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.1, 0.04),
					Size = UDim2.fromScale(0.8, 0.58),
					[Children] = drinkGlass(id),
				}),
				label(scope, `x{n}`, {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(0.98, 0.02),
					Size = UDim2.fromScale(0.45, 0.2),
					TextColor3 = Theme.WoodDark,
				}),
				label(scope, Recipes.Drinks[id].Name, {
					Position = UDim2.fromScale(0.05, 0.64),
					Size = UDim2.fromScale(0.9, 0.3),
					TextWrapped = true,
					TextColor3 = if wrong then Color3.fromRGB(180, 40, 40) else nil,
				}),
			},
		})
		table.insert(tiles, tile)
	end
	for _, id in shownDrinks do
		if drinkCounts[id] then
			addTile(id, drinkCounts[id], false)
		end
		if wrongCounts[id] then
			addTile(id, wrongCounts[id], true)
		end
	end

	-- reviews
	local reviewCards = {}
	for i, review in Reviews.generate(summary.orders, 3) do
		local stars = starsRow(review.Stars, UDim2.fromScale(0.5, 0.22))
		stars.Position = UDim2.fromScale(0.04, 0.08)
		local tag = nil
		if review.Tag then
			tag = scope:New("Frame")({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(0.97, 0.06),
				Size = UDim2.fromScale(0.26, 0.24),
				BackgroundColor3 = if review.Tag == "CRÍTICO" then Color3.fromRGB(150, 40, 60) else Theme.Sage,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0.4, 0) }),
					scope:New("UIStroke")({ Thickness = 2, Color = Theme.Ink }),
					label(scope, review.Tag, {
						Position = UDim2.fromScale(0.06, 0.12),
						Size = UDim2.fromScale(0.88, 0.76),
						TextColor3 = Theme.Paper,
					}),
				},
			})
		end
		local card = panel(scope, {
			Name = `Review{i}`,
			LayoutOrder = i,
			BackgroundColor3 = Theme.Paper,
			Size = UDim2.fromScale(1, 0.31),
			[Children] = {
				stars,
				tag or {},
				label(scope, `"{review.Text}"`, {
					Position = UDim2.fromScale(0.04, 0.32),
					Size = UDim2.fromScale(0.92, 0.42),
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					Font = Enum.Font.Gotham,
				}),
				label(scope, `— {review.Name}`, {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(0.96, 0.76),
					Size = UDim2.fromScale(0.6, 0.18),
					TextXAlignment = Enum.TextXAlignment.Right,
					TextColor3 = Theme.WoodDark,
				}),
			},
		})
		table.insert(reviewCards, card)
	end

	local moon = PixelArt.draw(Sprites.Moon)
	moon.AnchorPoint = Vector2.new(0, 0)
	moon.Position = UDim2.fromScale(0, 0)
	moon.Size = UDim2.fromScale(1, 1)
	moon.SizeConstraint = Enum.SizeConstraint.RelativeYY

	local ratingStars = starsRow(avgStars, UDim2.fromScale(0.9, 0.26), Enum.HorizontalAlignment.Center)
	ratingStars.AnchorPoint = Vector2.new(0.5, 0)
	ratingStars.Position = UDim2.fromScale(0.5, 0.56)

	local coin = PixelArt.draw(Sprites.Coin)
	coin.AnchorPoint = Vector2.new(0, 0.5)
	coin.Position = UDim2.fromScale(0.06, 0.68)
	coin.Size = UDim2.fromScale(0.3, 0.3)
	coin.SizeConstraint = Enum.SizeConstraint.RelativeYY

	local function stat(title: string, order: number, content: { any }): Frame
		return panel(scope, {
			Name = title,
			LayoutOrder = order,
			BackgroundColor3 = Theme.Paper,
			Size = UDim2.fromScale(0.31, 1),
			[Children] = {
				label(scope, title, {
					Position = UDim2.fromScale(0.05, 0.1),
					Size = UDim2.fromScale(0.9, 0.3),
					TextColor3 = Theme.WoodDark,
				}),
				content,
			},
		})
	end

	local levelBadgeScale = scope:New("UIScale")({ Scale = 1 })
	local nextButton = scope:New("TextButton")({
		Name = "Next",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromScale(0.3, 0.72),
		BackgroundColor3 = Theme.SageDark,
		Font = Theme.Font,
		TextScaled = true,
		TextColor3 = Theme.Paper,
		Text = `Começar Dia {summary.day + 1}  >`,
		Visible = continueVisible,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0.3, 0) }),
			scope:New("UIStroke")({ Thickness = 3, Color = Theme.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0.22, 0),
				PaddingBottom = UDim.new(0.22, 0),
				PaddingLeft = UDim.new(0.06, 0),
				PaddingRight = UDim.new(0.06, 0),
			}),
		},
	})

	local card = scope:New("Frame")({
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 1.6),
		Size = UDim2.fromScale(0.84, 0.88),
		BackgroundColor3 = Theme.Wood,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 16) }),
			scope:New("UIStroke")({ Thickness = 4, Color = Theme.Ink }),
			scope:New("UISizeConstraint")({ MaxSize = Vector2.new(1180, 780) }),
			scope:New("Frame")({
				Name = "Inner",
				Position = UDim2.fromOffset(12, 12),
				Size = UDim2.new(1, -24, 1, -24),
				BackgroundColor3 = Theme.WoodLight,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 12) }),
					scope:New("UIPadding")({
						PaddingTop = UDim.new(0.03, 0),
						PaddingBottom = UDim.new(0.03, 0),
						PaddingLeft = UDim.new(0.025, 0),
						PaddingRight = UDim.new(0.025, 0),
					}),
					-- cabeçalho
					scope:New("Frame")({
						Name = "Header",
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 0.1),
						[Children] = {
							moon,
							label(scope, `Fim do Dia {summary.day}`, {
								Position = UDim2.fromScale(0.07, 0),
								Size = UDim2.fromScale(0.5, 1),
								TextXAlignment = Enum.TextXAlignment.Left,
							}),
							label(scope, "O café fechou. Hora de descansar!", {
								AnchorPoint = Vector2.new(1, 0.5),
								Position = UDim2.fromScale(1, 0.55),
								Size = UDim2.fromScale(0.42, 0.45),
								TextXAlignment = Enum.TextXAlignment.Right,
								TextColor3 = Theme.WoodDark,
							}),
						},
					}),
					-- coluna esquerda: números + bebidas
					scope:New("Frame")({
						Name = "Left",
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0, 0.14),
						Size = UDim2.fromScale(0.48, 0.64),
						[Children] = {
							scope:New("Frame")({
								Name = "Stats",
								BackgroundTransparency = 1,
								Size = UDim2.fromScale(1, 0.3),
								[Children] = {
									scope:New("UIListLayout")({
										FillDirection = Enum.FillDirection.Horizontal,
										Padding = UDim.new(0.035, 0),
										SortOrder = Enum.SortOrder.LayoutOrder,
									}),
									stat("Faturamento", 1, {
										coin,
										label(scope, if summary.tips > 0 then `inclui ${summary.tips} de gorjeta` else "", {
											Position = UDim2.fromScale(0.05, 0.84),
											Size = UDim2.fromScale(0.9, 0.13),
											TextColor3 = Theme.WoodDark,
										}),
										label(scope, scope:Computed(function(use)
											return `${use(shownMoney)}`
										end), {
											Position = UDim2.fromScale(0.34, 0.45),
											Size = UDim2.fromScale(0.62, 0.45),
											TextXAlignment = Enum.TextXAlignment.Left,
										}),
									}),
									stat("Clientes", 2, {
										-- um label só, em duas linhas, pra ficarem sempre com o mesmo tamanho de fonte (dia sem erro: só os parabéns)
										label(
											scope,
											if summary.wrong == 0
												then "Parabéns,\nnenhum pedido incompleto!"
												else `{served} {if served == 1 then "completo" else "completos"}\n{summary.wrong} {if summary.wrong == 1 then "incompleto" else "incompletos"}`,
											{
												Position = UDim2.fromScale(0.05, 0.4),
												Size = UDim2.fromScale(0.9, 0.54),
											}
										),
									}),
									stat("Avaliação", 3, { ratingStars }),
								},
							}),
							label(scope, "Bebidas entregues", {
								Position = UDim2.fromScale(0, 0.35),
								Size = UDim2.fromScale(1, 0.08),
								TextXAlignment = Enum.TextXAlignment.Left,
							}),
							scope:New("Frame")({
								Name = "Drinks",
								BackgroundTransparency = 1,
								Position = UDim2.fromScale(0, 0.46),
								Size = UDim2.fromScale(1, 0.54),
								[Children] = {
									scope:New("UIGridLayout")({
										CellSize = UDim2.fromScale(0.185, 0.47),
										CellPadding = UDim2.fromScale(0.018, 0.04),
										SortOrder = Enum.SortOrder.LayoutOrder,
									}),
									tiles,
								},
							}),
						},
					}),
					-- coluna direita: reviews
					scope:New("Frame")({
						Name = "Right",
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.52, 0.14),
						Size = UDim2.fromScale(0.48, 0.64),
						[Children] = {
							label(scope, "O que os clientes disseram", {
								Size = UDim2.fromScale(1, 0.08),
								TextXAlignment = Enum.TextXAlignment.Left,
							}),
							scope:New("Frame")({
								Name = "Reviews",
								BackgroundTransparency = 1,
								Position = UDim2.fromScale(0, 0.1),
								Size = UDim2.fromScale(1, 0.9),
								[Children] = {
									scope:New("UIListLayout")({
										Padding = UDim.new(0.02, 0),
										SortOrder = Enum.SortOrder.LayoutOrder,
									}),
									reviewCards,
								},
							}),
						},
					}),
					-- rodapé: XP + botão
					scope:New("Frame")({
						Name = "Footer",
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0, 0.82),
						Size = UDim2.fromScale(1, 0.18),
						[Children] = {
							panel(scope, {
								Name = "XP",
								BackgroundColor3 = Theme.Paper,
								Size = UDim2.fromScale(0.66, 1),
								[Children] = {
									scope:New("Frame")({
										Name = "Badge",
										AnchorPoint = Vector2.new(0, 0.5),
										Position = UDim2.fromScale(0.02, 0.5),
										Size = UDim2.fromScale(0.8, 0.8),
										SizeConstraint = Enum.SizeConstraint.RelativeYY,
										BackgroundColor3 = Theme.Mustard,
										[Children] = {
											levelBadgeScale,
											scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
											scope:New("UIStroke")({ Thickness = 3, Color = Theme.Ink }),
											label(scope, scope:Computed(function(use)
												return tostring(use(xpLevel))
											end), {
												Position = UDim2.fromScale(0.15, 0.2),
												Size = UDim2.fromScale(0.7, 0.6),
											}),
										},
									}),
									label(scope, scope:Computed(function(use)
										return `Nível {use(xpLevel)}`
									end), {
										Position = UDim2.fromScale(0.16, 0.12),
										Size = UDim2.fromScale(0.4, 0.34),
										TextXAlignment = Enum.TextXAlignment.Left,
									}),
									label(scope, xpText, {
										AnchorPoint = Vector2.new(1, 0),
										Position = UDim2.fromScale(0.97, 0.14),
										Size = UDim2.fromScale(0.4, 0.3),
										TextXAlignment = Enum.TextXAlignment.Right,
										TextColor3 = Theme.SageDark,
									}),
									scope:New("Frame")({
										Name = "Bar",
										Position = UDim2.fromScale(0.16, 0.56),
										Size = UDim2.fromScale(0.81, 0.26),
										BackgroundColor3 = Theme.PaperShade,
										[Children] = {
											scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
											scope:New("UIStroke")({ Thickness = 2, Color = Theme.Ink }),
											scope:New("Frame")({
												BorderSizePixel = 0,
												BackgroundColor3 = Theme.Sage,
												Size = scope:Computed(function(use)
													return UDim2.fromScale(math.clamp(use(xpFill), 0.03, 1), 1)
												end),
												[Children] = scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
											}),
										},
									}),
								},
							}),
							nextButton,
						},
					}),
				},
			}),
		},
	})

	local gui = scope:New("ScreenGui")({
		Name = "DaySummary",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 20,
		Parent = playerGui,
		[Children] = {
			scope:New("Frame")({
				Name = "Dim",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(20, 14, 20),
				BackgroundTransparency = 0.45,
			}),
			card,
		},
	}) :: ScreenGui

	-- esconde os itens que vão aparecer em sequência
	for _, item in { tiles, reviewCards } do
		for _, inst in item do
			local s = Instance.new("UIScale")
			s.Scale = 0
			s.Parent = inst
		end
	end

	local continued = false
	nextButton.Activated:Connect(function()
		if continued then
			return
		end
		continued = true
		tween(card, 0.4, { Position = UDim2.fromScale(0.5, 1.6) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.delay(0.35, function()
			onContinue()
			task.delay(1, function()
				gui:Destroy()
				Fusion.doCleanup(scope)
			end)
		end)
	end)

	-- sequência de animação
	task.spawn(function()
		tween(card, 0.6, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Back)
		task.wait(0.6)

		-- faturamento contando
		local t0 = os.clock()
		while true do
			local a = math.min(1, (os.clock() - t0) / 1.2)
			shownMoney:set(math.floor(summary.earned * (1 - (1 - a) ^ 3)))
			if a >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end

		for i, t in tiles do
			local s = t:FindFirstChildOfClass("UIScale") :: UIScale
			task.delay((i - 1) * 0.08, function()
				tween(s, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
			end)
		end
		task.wait(0.3 + #tiles * 0.08)

		for _, r in reviewCards do
			local s = r:FindFirstChildOfClass("UIScale") :: UIScale
			tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
			task.wait(0.7)
		end

		-- XP enchendo (pode atravessar vários níveis)
		xpText:set(`+{summary.xpGained} XP`)
		local level, xp, remaining = summary.levelBefore, summary.xpBefore, summary.xpGained
		local leveled = false
		while remaining > 0 do
			local need = Progression.xpToNext(level)
			local step = math.min(remaining, need - xp)
			local from, to = xp / need, (xp + step) / need
			local dur = 0.4 + 0.8 * (to - from)
			local s0 = os.clock()
			while true do
				local a = math.min(1, (os.clock() - s0) / dur)
				xpFill:set(from + (to - from) * a)
				if a >= 1 then
					break
				end
				RunService.RenderStepped:Wait()
			end
			xp += step
			remaining -= step
			if xp >= need then
				level += 1
				xp = 0
				leveled = true
				xpLevel:set(level)
				xpFill:set(0)
				levelBadgeScale.Scale = 1.5
				tween(levelBadgeScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
				task.wait(0.25)
			end
		end

		task.wait(0.4)
		if leveled then
			showLevelUp(scope, gui :: any, summary.levelBefore, summary.levelAfter, function()
				continueVisible:set(true)
				popIn(nextButton)
			end)
		else
			continueVisible:set(true)
			popIn(nextButton)
		end
	end)
end

return DaySummary
