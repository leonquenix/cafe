--!strict
-- Livro de receitas: abas Bebidas e Doces (bloqueados aparecem como "???"). Cada receita tem
-- conquistas em marcos (Recipes.Milestones: sirva 5, 10, 25, 50 e 100), cada uma com recompensa em
-- moedas, resgatadas uma de cada vez. Bebida vira "Dominada" (+10%) no marco de 50; com todos os
-- marcos resgatados a receita ganha o selo "MESTRE".

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Recipes = require(ReplicatedStorage.Shared.Recipes)
local Achievements = require(script.Parent.Parent.Achievements)
local Glass = require(script.Parent.Parent.Art.Glass)
local PixelArt = require(script.Parent.Parent.Art.PixelArt)
local Sprites = require(script.Parent.Parent.Art.Sprites)
local Pause = require(script.Parent.Parent.Pause)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Theme)
local BookAlert = require(script.Parent.BookAlert)

local Children, OnEvent, peek = Fusion.Children, Fusion.OnEvent, Fusion.peek

local RecipeBook = {}
local playerGui: PlayerGui
local isOpen = false

RecipeBook.onClaim = nil :: ((id: string) -> ())? -- resgata o próximo marco da receita (bebida ou doce)

function RecipeBook.init(gui: PlayerGui)
	playerGui = gui
end

local function label(scope: any, text: any, props: { [string]: any }): TextLabel
	props.BackgroundTransparency = 1
	props.Font = props.Font or Theme.Font
	props.TextScaled = true
	props.TextColor3 = props.TextColor3 or Theme.Ink
	props.Text = text
	return scope:New("TextLabel")(props)
end

local function confetti(parent: GuiObject, amount: number)
	local rng = Random.new()
	local colors = { Theme.Mustard, Theme.Rose, Theme.Sage, Theme.Paper }
	for i = 1, amount do
		task.delay(i * 0.015, function()
			local c = Instance.new("Frame")
			c.BorderSizePixel = 0
			c.BackgroundColor3 = colors[rng:NextInteger(1, #colors)]
			c.Size = UDim2.fromOffset(rng:NextInteger(6, 11), rng:NextInteger(6, 11))
			c.AnchorPoint = Vector2.new(0.5, 0.5)
			c.Position = UDim2.fromScale(0.5, 0.5)
			c.ZIndex = 20
			c.Parent = parent
			local angle = rng:NextNumber(0, math.pi * 2)
			local dist = rng:NextNumber(0.3, 0.8)
			local t = TweenService:Create(c, TweenInfo.new(rng:NextNumber(0.6, 1), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.fromScale(0.5 + math.cos(angle) * dist, 0.5 + math.sin(angle) * dist),
				Rotation = rng:NextNumber(-360, 360),
				BackgroundTransparency = 1,
			})
			t.Completed:Once(function()
				c:Destroy()
			end)
			t:Play()
		end)
	end
end

local MILESTONES = #Recipes.Milestones
local GOLD = Color3.fromRGB(214, 160, 40)

-- Selo "MESTRE DO ..." (artigo certo para os doces no plural)
local function masterTitle(name: string): string
	local article = if string.sub(name, -1) == "s" then "DAS" else "DO"
	return `MESTRE {article} {string.upper(name)}`
end

local function recipeCard(scope: any, order: number, kind: Achievements.Kind, id: string): Frame
	local isDrink = kind == "Drink"
	local drink = if isDrink then Recipes.Drinks[id] else nil
	local pastry = if isDrink then nil else Catalog.Pastries[id]
	local name = Achievements.name(kind, id)
	local level = if drink then drink.Level else (pastry :: Catalog.Pastry).Level

	-- bebida: aprendida no nível; doce: comprado na loja
	local unlocked = scope:Computed(function(use)
		if isDrink then
			return use(State.Level) >= level
		end
		return use(State.Owned)[id] == true
	end)
	local count = scope:Computed(function(use)
		return (if isDrink then use(State.Stats) else use(State.PastryStats))[id] or 0
	end)
	local claimed = scope:Computed(function(use)
		return math.clamp(use(State.Claims)[id] or 0, 0, MILESTONES)
	end)
	local complete = scope:Computed(function(use)
		return use(claimed) >= MILESTONES
	end)
	local mastered = scope:Computed(function(use)
		return isDrink and use(State.Mastered)[id] == true
	end)
	-- próximo marco (o primeiro ainda não resgatado)
	local nextMilestone = scope:Computed(function(use)
		return Recipes.Milestones[math.min(use(claimed) + 1, MILESTONES)]
	end)
	local claimable = scope:Computed(function(use)
		return use(unlocked) and Recipes.claimableMilestone(use(count), use(claimed)) ~= nil
	end)
	local gold = scope:Computed(function(use)
		return use(unlocked) and (use(mastered) or use(complete))
	end)
	local pulse = scope:Value(1)

	local art: GuiObject
	if drink then
		local glass = Glass.new()
		glass:setPortions(Recipes.portions(id))
		glass:setMix(if drink.Mix then 1 else 0, 0)
		glass:setLevel(glass:targetLevel())
		art = glass.Root
	else
		local sprite = PixelArt.draw((Sprites :: any)[(pastry :: Catalog.Pastry).Icon])
		sprite.Size = UDim2.fromScale(0.9, 0.9)
		art = sprite
	end

	local lock = PixelArt.draw(Sprites.Lock)
	lock.Size = UDim2.fromScale(0.5, 0.5)

	local details = if drink
		then Recipes.describe(id) .. ` · {Recipes.mixText(id)}  ·  ${drink.Price}`
		else `Quitute do forno  ·  ${(pastry :: Catalog.Pastry).Price}`

	local sealScale = scope:New("UIScale")({ Scale = 1 })
	local card: Frame

	card = scope:New("Frame")({
		Name = id,
		LayoutOrder = order,
		BackgroundColor3 = scope:Computed(function(use)
			return if not use(unlocked) then Theme.PaperShade elseif use(gold) then Color3.fromRGB(255, 244, 214) else Theme.Paper
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
			scope:New("UIStroke")({
				Thickness = scope:Computed(function(use)
					return if use(gold) then 4 else 3
				end),
				Color = scope:Computed(function(use)
					return if use(gold) then GOLD else Theme.Ink
				end),
			}),
			-- desbloqueada
			scope:New("Frame")({
				Name = "Unlocked",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Visible = unlocked,
				[Children] = {
					scope:New("Frame")({
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.03, 0.1),
						Size = UDim2.fromScale(0.26, 0.8),
						[Children] = art,
					}),
					label(scope, name, {
						Position = UDim2.fromScale(0.32, 0.08),
						Size = UDim2.fromScale(0.64, 0.19),
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					label(scope, scope:Computed(function(use)
						return if use(mastered) then `{details}  ·  +{math.floor(Recipes.MasteryBonus * 100)}%` else details
					end), {
						Position = UDim2.fromScale(0.32, 0.29),
						Size = UDim2.fromScale(0.64, 0.2),
						TextXAlignment = Enum.TextXAlignment.Left,
						TextWrapped = true,
						Font = Enum.Font.Gotham,
						TextColor3 = Theme.WoodDark,
					}),
					-- conquista atual: "Sirva 10 (7/10) · 2/5" (marco 2 de 5), barra até ele e a recompensa
					label(scope, scope:Computed(function(use)
						local m = use(nextMilestone)
						return `Sirva {m.Count} ({math.min(use(count), m.Count)}/{m.Count})  ·  {math.min(use(claimed) + 1, MILESTONES)}/{MILESTONES}`
					end), {
						Name = "Goal",
						Position = UDim2.fromScale(0.32, 0.52),
						Size = UDim2.fromScale(0.64, 0.14),
						TextXAlignment = Enum.TextXAlignment.Left,
						Visible = scope:Computed(function(use)
							return not use(complete)
						end),
					}),
					scope:New("Frame")({
						Name = "Bar",
						Position = UDim2.fromScale(0.32, 0.7),
						Size = scope:Computed(function(use)
							return if use(claimable) then UDim2.fromScale(0.3, 0.14) else UDim2.fromScale(0.46, 0.14)
						end),
						BackgroundColor3 = Theme.PaperShade,
						Visible = scope:Computed(function(use)
							return not use(complete)
						end),
						[Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
							scope:New("UIStroke")({ Thickness = 2, Color = Theme.Ink }),
							scope:New("Frame")({
								BorderSizePixel = 0,
								BackgroundColor3 = scope:Computed(function(use)
									return if use(claimable) then Theme.Mustard else Theme.Sage
								end),
								Size = scope:Computed(function(use)
									return UDim2.fromScale(math.clamp(use(count) / use(nextMilestone).Count, 0.03, 1), 1)
								end),
								[Children] = scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
							}),
						},
					}),
					-- recompensa do próximo marco (some quando o botão de coletar aparece)
					label(scope, scope:Computed(function(use)
						return `+${use(nextMilestone).Reward}`
					end), {
						Name = "Reward",
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromScale(0.97, 0.66),
						Size = UDim2.fromScale(0.17, 0.2),
						TextXAlignment = Enum.TextXAlignment.Right,
						TextColor3 = Color3.fromRGB(176, 124, 20),
						Visible = scope:Computed(function(use)
							return not use(complete) and not use(claimable)
						end),
					}),
					scope:New("TextButton")({
						Name = "Claim",
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.fromScale(0.97, 0.77),
						Size = UDim2.fromScale(0.33, 0.26),
						BackgroundColor3 = Theme.SageDark,
						Font = Theme.Font,
						TextScaled = true,
						TextColor3 = Theme.Paper,
						Text = scope:Computed(function(use)
							local index = Recipes.claimableMilestone(use(count), use(claimed))
							return `Coletar ${if index then Recipes.Milestones[index].Reward else 0}!`
						end),
						Visible = claimable,
						ZIndex = 3,
						[Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0.3, 0) }),
							scope:New("UIStroke")({ Thickness = 2, Color = Theme.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
							scope:New("UIPadding")({ PaddingTop = UDim.new(0.14, 0), PaddingBottom = UDim.new(0.14, 0) }),
							scope:New("UIScale")({ Scale = pulse }),
						},
						[OnEvent("Activated")] = function()
							if peek(claimable) and RecipeBook.onClaim then
								RecipeBook.onClaim(id)
							end
						end,
					}),
					-- selo de mestre: todos os marcos resgatados
					scope:New("Frame")({
						Name = "Seal",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.64, 0.72),
						Size = UDim2.fromScale(0.64, 0.2),
						Rotation = -4,
						ZIndex = 5,
						BackgroundColor3 = Color3.fromRGB(246, 196, 70),
						Visible = complete,
						[Children] = {
							sealScale,
							scope:New("UICorner")({ CornerRadius = UDim.new(0.4, 0) }),
							scope:New("UIStroke")({ Thickness = 3, Color = Theme.Ink }),
							label(scope, masterTitle(name), {
								Position = UDim2.fromScale(0.05, 0.14),
								Size = UDim2.fromScale(0.9, 0.72),
								ZIndex = 6,
							}),
						},
					}),
				},
			}),
			-- bloqueada
			scope:New("Frame")({
				Name = "Locked",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Visible = scope:Computed(function(use)
					return not use(unlocked)
				end),
				[Children] = {
					scope:New("Frame")({
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.06, 0.15),
						Size = UDim2.fromScale(0.24, 0.7),
						[Children] = lock,
					}),
					label(scope, "???", {
						Position = UDim2.fromScale(0.35, 0.15),
						Size = UDim2.fromScale(0.6, 0.3),
						TextXAlignment = Enum.TextXAlignment.Left,
						TextColor3 = Theme.WoodDark,
					}),
					label(scope, scope:Computed(function(use)
						if not isDrink and use(State.Level) >= level then
							return "Compre na loja"
						end
						return `Aprenda no nível {level}`
					end), {
						Position = UDim2.fromScale(0.35, 0.52),
						Size = UDim2.fromScale(0.6, 0.22),
						TextXAlignment = Enum.TextXAlignment.Left,
						TextColor3 = Theme.WoodDark,
					}),
				},
			}),
		},
	})

	-- botão pulsando e carimbo do selo ao coletar
	local conn = RunService.RenderStepped:Connect(function()
		if peek(claimable) then
			pulse:set(1 + math.sin(os.clock() * 6) * 0.06)
		end
	end)
	table.insert(scope, conn)
	-- confete a cada marco resgatado; o selo carimba quando o último sai
	local lastClaimed = peek(claimed)
	scope:Observer(claimed):onChange(function()
		local now = peek(claimed)
		if now > lastClaimed then
			if now >= MILESTONES then
				sealScale.Scale = 2.2
				TweenService:Create(sealScale, TweenInfo.new(0.45, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), { Scale = 1 }):Play()
				confetti(card, 40)
			else
				confetti(card, 18)
			end
		end
		lastClaimed = now
	end)
	return card
end

function RecipeBook.show()
	if isOpen then
		return
	end
	isOpen = true
	-- no meio do expediente o jogo pausa até o livro fechar
	if peek(State.DayActive) then
		Pause.set(true)
	end
	local scope = Fusion.scoped(Fusion)
	local tab = scope:Value("Drink" :: Achievements.Kind)

	local function cardsOf(kind: Achievements.Kind): { Frame }
		local cards = {}
		for i, id in Achievements.ids(kind) do
			table.insert(cards, recipeCard(scope, i, kind, id))
		end
		return cards
	end

	local function page(id: Achievements.Kind, cards: { Frame }, cellHeight: number, columns: number): ScrollingFrame
		return scope:New("ScrollingFrame")({
			Name = id,
			Visible = scope:Computed(function(use)
				return use(tab) == id
			end),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ScrollBarThickness = 8,
			ScrollBarImageColor3 = Theme.WoodDark,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			[Children] = {
				scope:New("UIGridLayout")({
					CellSize = UDim2.new(1 / columns - 0.015, 0, 0, cellHeight),
					CellPadding = UDim2.new(0.015, 0, 0, 12),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				scope:New("UIPadding")({
					PaddingTop = UDim.new(0, 6),
					PaddingLeft = UDim.new(0, 6),
					PaddingRight = UDim.new(0, 14),
					PaddingBottom = UDim.new(0, 6),
				}),
				cards,
			},
		})
	end

	local function tabButton(kind: Achievements.Kind, text: string, order: number): TextButton
		-- bolinha maior que a do HUD (a aba é baixinha e o padding encolhe a área dos filhos)
		local alert = BookAlert(scope, kind)
		alert.Size = UDim2.fromScale(1.1, 1.1)
		alert.Position = UDim2.fromScale(0.94, 0.05)
		return scope:New("TextButton")({
			Name = kind,
			LayoutOrder = order,
			Size = UDim2.fromScale(0.48, 1),
			BackgroundColor3 = scope:Computed(function(use)
				return if use(tab) == kind then Theme.Mustard else Theme.PaperShade
			end),
			Font = Theme.Font,
			TextScaled = true,
			TextColor3 = Theme.Ink,
			Text = text,
			[Fusion.Attribute("ClickSound")] = "BookOpen", -- mesmo som de abrir o livro
			[Children] = {
				scope:New("UICorner")({ CornerRadius = UDim.new(0.3, 0) }),
				scope:New("UIStroke")({ Thickness = 3, Color = Theme.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
				scope:New("UIPadding")({ PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.18, 0) }),
				alert,
			},
			[OnEvent("Activated")] = function()
				tab:set(kind)
			end,
		}) :: TextButton
	end

	local card = scope:New("Frame")({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 1.6),
		Size = UDim2.fromScale(0.8, 0.84),
		BackgroundColor3 = Color3.fromRGB(176, 82, 72),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 16) }),
			scope:New("UIStroke")({ Thickness = 4, Color = Theme.Ink }),
			scope:New("UISizeConstraint")({ MaxSize = Vector2.new(1100, 760) }),
			scope:New("Frame")({
				Position = UDim2.fromOffset(14, 14),
				Size = UDim2.new(1, -28, 1, -28),
				BackgroundColor3 = Theme.Paper,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
					scope:New("UIPadding")({
						PaddingTop = UDim.new(0.03, 0),
						PaddingBottom = UDim.new(0.03, 0),
						PaddingLeft = UDim.new(0.025, 0),
						PaddingRight = UDim.new(0.025, 0),
					}),
					label(scope, "Livro de Receitas", {
						Size = UDim2.fromScale(0.4, 0.09),
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					-- abas Bebidas / Doces, cada uma com a bolinha "!" dos marcos prontos dela
					scope:New("Frame")({
						Name = "Tabs",
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.42, 0.005),
						Size = UDim2.fromScale(0.44, 0.08),
						[Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								Padding = UDim.new(0.04, 0),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),
							tabButton("Drink", "Bebidas", 1),
							tabButton("Pastry", "Quitutes", 2),
						},
					}),
					scope:New("TextButton")({
						Name = "Close",
						[Fusion.Attribute("ClickSound")] = "BookClose",
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.fromScale(0.09, 0.09),
						SizeConstraint = Enum.SizeConstraint.RelativeYY,
						BackgroundColor3 = Theme.Rose,
						Font = Theme.Font,
						TextScaled = true,
						TextColor3 = Theme.Paper,
						Text = "X",
						[Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0.3, 0) }),
							scope:New("UIStroke")({ Thickness = 3, Color = Theme.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
							scope:New("UIPadding")({ PaddingTop = UDim.new(0.2, 0), PaddingBottom = UDim.new(0.2, 0) }),
						},
						[OnEvent("Activated")] = function()
							RecipeBook.close()
						end,
					}),
					scope:New("Frame")({
						Position = UDim2.fromScale(0, 0.12),
						Size = UDim2.fromScale(1, 0.88),
						BackgroundColor3 = Theme.PaperShade,
						[Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
							scope:New("UIStroke")({ Thickness = 3, Color = Theme.Ink }),
							page("Drink", cardsOf("Drink"), 150, 3),
							page("Pastry", cardsOf("Pastry"), 150, 3),
						},
					}),
				},
			}),
		},
	})

	local gui = scope:New("ScreenGui")({
		Name = "RecipeBook",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 30,
		Parent = playerGui,
		[Children] = {
			scope:New("TextButton")({
				Name = "Dim",
				Text = "",
				AutoButtonColor = false,
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(20, 14, 20),
				BackgroundTransparency = 0.45,
				[OnEvent("Activated")] = function()
					RecipeBook.close()
				end,
			}),
			card,
		},
	}) :: ScreenGui

	TweenService:Create(card, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, 0.5),
	}):Play()

	RecipeBook.close = function()
		if not isOpen then
			return
		end
		isOpen = false
		Pause.set(false)
		local t = TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Position = UDim2.fromScale(0.5, 1.6),
		})
		t.Completed:Once(function()
			gui:Destroy()
			Fusion.doCleanup(scope)
		end)
		t:Play()
	end
end

function RecipeBook.close() end

return RecipeBook
