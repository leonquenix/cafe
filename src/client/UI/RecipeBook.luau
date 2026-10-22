--!strict
-- Livro de receitas: todas as bebidas (bloqueadas aparecem como "???") com a missão de
-- maestria de cada uma: sirva N -> colete a recompensa -> selo "MESTRE DO ..." na receita.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Recipes = require(ReplicatedStorage.Shared.Recipes)
local Glass = require(script.Parent.Parent.Art.Glass)
local PixelArt = require(script.Parent.Parent.Art.PixelArt)
local Sprites = require(script.Parent.Parent.Art.Sprites)
local Pause = require(script.Parent.Parent.Pause)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Theme)

local Children, OnEvent, peek = Fusion.Children, Fusion.OnEvent, Fusion.peek

local RecipeBook = {}
local playerGui: PlayerGui
local isOpen = false

RecipeBook.onClaim = nil :: ((drink: string) -> ())?

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

local function recipeCard(scope: any, order: number, id: string): Frame
	local d = Recipes.Drinks[id]
	local target = Recipes.masteryTarget(id)
	local reward = Recipes.masteryReward(id)

	local unlocked = scope:Computed(function(use)
		return use(State.Level) >= d.Level
	end)
	local count = scope:Computed(function(use)
		return use(State.Stats)[id] or 0
	end)
	local mastered = scope:Computed(function(use)
		return use(State.Mastered)[id] == true
	end)
	local claimable = scope:Computed(function(use)
		return use(unlocked) and not use(mastered) and use(count) >= target
	end)
	local pulse = scope:Value(1)

	local glass = Glass.new()
	glass:setPortions(Recipes.portions(id))
	glass:setMix(if d.Mix then 1 else 0, 0)
	glass:setLevel(glass:targetLevel())

	local lock = PixelArt.draw(Sprites.Lock)
	lock.Size = UDim2.fromScale(0.5, 0.5)

	local sealScale = scope:New("UIScale")({ Scale = 1 })
	local card: Frame

	card = scope:New("Frame")({
		Name = id,
		LayoutOrder = order,
		BackgroundColor3 = scope:Computed(function(use)
			return if not use(unlocked) then Theme.PaperShade elseif use(mastered) then Color3.fromRGB(255, 244, 214) else Theme.Paper
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
			scope:New("UIStroke")({
				Thickness = scope:Computed(function(use)
					return if use(mastered) then 4 else 3
				end),
				Color = scope:Computed(function(use)
					return if use(mastered) then Color3.fromRGB(214, 160, 40) else Theme.Ink
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
						[Children] = glass.Root,
					}),
					label(scope, d.Name, {
						Position = UDim2.fromScale(0.32, 0.08),
						Size = UDim2.fromScale(0.64, 0.19),
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					label(scope, Recipes.describe(id) .. ` · {Recipes.mixText(id)}  ·  ${d.Price}`, {
						Position = UDim2.fromScale(0.32, 0.29),
						Size = UDim2.fromScale(0.64, 0.2),
						TextXAlignment = Enum.TextXAlignment.Left,
						TextWrapped = true,
						Font = Enum.Font.Gotham,
						TextColor3 = Theme.WoodDark,
					}),
					-- barra de maestria
					label(scope, scope:Computed(function(use)
						if use(mastered) then
							return `Dominada! Paga +{math.floor(Recipes.MasteryBonus * 100)}% para sempre`
						end
						return `Missão: sirva {target}  ({math.min(use(count), target)}/{target})`
					end), {
						Position = UDim2.fromScale(0.32, 0.52),
						Size = UDim2.fromScale(0.64, 0.14),
						TextXAlignment = Enum.TextXAlignment.Left,
						TextColor3 = scope:Computed(function(use)
							return if use(mastered) then Color3.fromRGB(176, 124, 20) else Theme.Ink
						end),
					}),
					scope:New("Frame")({
						Name = "Bar",
						Position = UDim2.fromScale(0.32, 0.7),
						Size = scope:Computed(function(use)
							return if use(claimable) then UDim2.fromScale(0.3, 0.14) else UDim2.fromScale(0.64, 0.14)
						end),
						BackgroundColor3 = Theme.PaperShade,
						Visible = scope:Computed(function(use)
							return not use(mastered)
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
									return UDim2.fromScale(math.clamp(use(count) / target, 0.03, 1), 1)
								end),
								[Children] = scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
							}),
						},
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
						Text = `Coletar ${reward}!`,
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
					-- selo de mestre
					scope:New("Frame")({
						Name = "Seal",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.64, 0.8),
						Size = UDim2.fromScale(0.64, 0.2),
						Rotation = -4,
						ZIndex = 5,
						BackgroundColor3 = Color3.fromRGB(246, 196, 70),
						Visible = mastered,
						[Children] = {
							sealScale,
							scope:New("UICorner")({ CornerRadius = UDim.new(0.4, 0) }),
							scope:New("UIStroke")({ Thickness = 3, Color = Theme.Ink }),
							label(scope, `MESTRE DO {string.upper(d.Name)}`, {
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
					label(scope, `Aprenda no nível {d.Level}`, {
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
	scope:Observer(mastered):onChange(function()
		if peek(mastered) then
			sealScale.Scale = 2.2
			TweenService:Create(sealScale, TweenInfo.new(0.45, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			confetti(card, 40)
		end
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

	local recipeCards = {}
	for i, id in Recipes.DrinkOrder do
		table.insert(recipeCards, recipeCard(scope, i, id))
	end

	local function page(id: string, cards: { Frame }, cellHeight: number, columns: number): ScrollingFrame
		return scope:New("ScrollingFrame")({
			Name = id,
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
						Size = UDim2.fromScale(0.5, 0.09),
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					scope:New("TextButton")({
						Name = "Close",
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
							page("Recipes", recipeCards, 150, 3),
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
