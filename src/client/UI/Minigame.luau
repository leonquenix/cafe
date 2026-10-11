--!strict
-- Minigame de preparo: arrastar ingredientes da barra de baixo até o copo (painel direito),
-- mexer em círculos quando a receita pede, e servir.
-- Estrutura/estado com Fusion; o desenho do copo e efeitos são imperativos (muitos pixels).

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Recipes = require(ReplicatedStorage.Shared.Recipes)
local Glass = require(script.Parent.Parent.Art.Glass)
local PixelArt = require(script.Parent.Parent.Art.PixelArt)
local Sprites = require(script.Parent.Parent.Art.Sprites)
local State = require(script.Parent.Parent.State)
local Oven = require(script.Parent.Oven)
local Theme = require(script.Parent.Theme)

local Children, OnEvent, peek = Fusion.Children, Fusion.OnEvent, Fusion.peek

local STIR_TURNS = 2.2 -- voltas completas pra misturar (antes do batedor)
local POUR_TIME = 0.55 -- segundos por porção (antes da máquina turbo)
local ROWS_PER_PORTION = 4

export type Order = { orderId: number, customerId: number, drink: string, modifier: string, pastry: string }
type Phase = "Idle" | "Making" | "Ready" | "Serving"

local Minigame = {}
Minigame.__index = Minigame

local function tween(inst: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function pointerPosition(input: InputObject): Vector2
	local inset = GuiService:GetGuiInset()
	return Vector2.new(input.Position.X, input.Position.Y) + inset
end

local function inside(gui: GuiObject, p: Vector2): boolean
	local a, s = gui.AbsolutePosition, gui.AbsoluteSize
	return p.X >= a.X and p.Y >= a.Y and p.X <= a.X + s.X and p.Y <= a.Y + s.Y
end

-- Segue um ponteiro (mouse ou toque) até soltar.
local function trackPointer(input: InputObject, onMove: (Vector2) -> (), onEnd: (Vector2) -> ())
	local last = pointerPosition(input)
	local moveConn, endConn
	moveConn = UserInputService.InputChanged:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseMovement or i == input then
			last = pointerPosition(i)
			onMove(last)
		end
	end)
	endConn = UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i == input then
			moveConn:Disconnect()
			endConn:Disconnect()
			onEnd(last)
		end
	end)
end

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

function Minigame.new(playerGui: PlayerGui)
	local scope = Fusion.scoped(Fusion)
	local self = setmetatable({}, Minigame) :: any

	self.scope = scope
	self.order = nil :: Order?
	self.busy = false
	self.onServe = nil :: ((orderId: number, ingredients: { string }, mixed: boolean, stirred: boolean, pastryQuality: number) -> ())?
	self.swirl = 0

	local phase = scope:Value("Idle" :: Phase)
	local drinkId = scope:Value("Espresso")
	local modifierId = scope:Value("")
	local pastryId = scope:Value("")
	local pastryQuality = scope:Value(0) -- 0 = não assado, 1 = ok, 2 = perfeito
	local portions = scope:Value({} :: { string })
	local mix = scope:Value(0)
	local elapsed = scope:Value(0)
	self.phase, self.drinkId, self.portions, self.mix, self.elapsed = phase, drinkId, portions, mix, elapsed
	self.modifierId, self.pastryId, self.pastryQuality = modifierId, pastryId, pastryQuality
	self.openedAt = 0
	-- Modo Livre: sem pedido; qualquer combinação pode ser servida
	local free = scope:Value(false)
	self.free = free
	self.onFreeServe = nil :: ((portions: { string }, mix: number) -> ())?

	---------------------------------------------------------- estado derivado
	local drink = scope:Computed(function(use)
		return Recipes.Drinks[use(drinkId)]
	end)
	-- ingredientes exigidos + regra de mistura ("required" | "forbidden" | "none")
	local requirements = scope:Computed(function(use)
		local m = use(modifierId)
		local req, rule = Recipes.requirements(use(drinkId), if m ~= "" then m else nil)
		return { Ingredients = req, Mix = rule }
	end)
	local stirred = scope:Computed(function(use)
		return use(mix) > 0
	end)
	-- ingrediente a mais / errado (não dá pra consertar sem jogar fora)
	local wrongIngredients = scope:Computed(function(use)
		if use(free) then
			return false
		end
		local req = use(requirements)
		for id, n in Recipes.count(use(portions)) do
			if n > (req.Ingredients[id] or 0) then
				return true
			end
		end
		return false
	end)
	local wrong = scope:Computed(function(use)
		return use(wrongIngredients) or (not use(free) and use(requirements).Mix == "forbidden" and use(stirred))
	end)
	local ingredientsOk = scope:Computed(function(use)
		return Recipes.countsMatch(use(requirements).Ingredients, use(portions))
	end)
	local mixDone = scope:Computed(function(use)
		return use(mix) >= 1
	end)
	local pastryDone = scope:Computed(function(use)
		return use(pastryId) == "" or use(pastryQuality) > 0
	end)
	local canStir = scope:Computed(function(use)
		-- dá pra mexer mesmo com a receita errada ou pedida sem mexer (o cliente reclama depois)
		local p = use(phase)
		return #use(portions) >= 2 and not use(mixDone) and (p == "Making" or p == "Ready")
	end)
	local ready = scope:Computed(function(use)
		if use(free) then
			return false
		end
		local rule = use(requirements).Mix
		local mixOk = if rule == "required" then use(mixDone) elseif rule == "forbidden" then not use(stirred) else true
		return use(ingredientsOk) and mixOk and use(pastryDone) and not use(wrong)
	end)
	self.ready = ready

	local hint = scope:Computed(function(use)
		local p = use(phase)
		local rule = use(requirements).Mix
		if use(free) then
			local n = #use(portions)
			if n == 0 then
				return "Crie o que quiser! Arraste os ingredientes"
			elseif n >= 2 and use(mix) < 1 then
				return "Mexa se quiser... e toque em Servir"
			end
			return "Toque em Servir quando estiver pronto"
		end
		if p == "Ready" or p == "Serving" then
			return "Prontinho! Toque em Servir"
		elseif use(wrong) then
			if rule == "forbidden" and use(stirred) then
				return "Era SEM mexer... o cliente vai reclamar!"
			end
			return "Ops, não é essa receita... o cliente vai reclamar!"
		elseif #use(portions) == 0 then
			return if rule == "forbidden" then "Em camadas! Arraste sem mexer" else "Arraste os ingredientes até o copo"
		elseif not use(ingredientsOk) then
			return "Continue adicionando..."
		elseif rule == "required" and not use(mixDone) then
			return "Agora mexa em círculos no copo!"
		elseif not use(pastryDone) then
			return `Falta o {Catalog.Pastries[use(pastryId)].Name} no forno!`
		end
		return ""
	end)

	-- linhas do cartão de receita
	type Line = { Key: string, Text: string, Sprite: string?, Done: boolean, Order: number }
	local lines = scope:Computed(function(use): { Line }
		if use(free) then
			-- Modo Livre: anota o que foi entrando no copo, na ordem
			local list: { Line } = {}
			local counts = Recipes.count(use(portions))
			local seen = {}
			for _, id in use(portions) do
				if not seen[id] then
					seen[id] = true
					table.insert(list, {
						Key = id,
						Text = `{counts[id]}x {Recipes.Ingredients[id].Name}`,
						Sprite = id,
						Done = true,
						Order = #list + 1,
					})
				end
			end
			local m = use(mix)
			if m > 0 then
				table.insert(list, { Key = "Mix", Text = if m >= 1 then "Misturado" else "Mexendo...", Sprite = "Spoon", Done = m >= 1, Order = 50 })
			end
			return list
		end
		local req = use(requirements)
		local counts = Recipes.count(use(portions))
		local list: { Line } = {}
		for i, id in Recipes.IngredientOrder do
			local need = req.Ingredients[id]
			if need then
				table.insert(list, {
					Key = id,
					Text = `{need}x {Recipes.Ingredients[id].Name}`,
					Sprite = id,
					Done = counts[id] == need,
					Order = i,
				})
			end
		end
		if req.Mix == "required" then
			table.insert(list, { Key = "Mix", Text = "Misturar", Sprite = "Spoon", Done = use(mixDone), Order = 50 })
		elseif req.Mix == "forbidden" then
			table.insert(list, {
				Key = "NoMix",
				Text = "NÃO mexer!",
				Sprite = "Spoon",
				Done = use(ingredientsOk) and not use(stirred),
				Order = 50,
			})
		end
		local pastry = use(pastryId)
		if pastry ~= "" then
			table.insert(list, {
				Key = "Pastry",
				Text = `1x {Catalog.Pastries[pastry].Name} (forno)`,
				Sprite = pastry,
				Done = use(pastryQuality) > 0,
				Order = 60,
			})
		end
		return list
	end)
	local price = scope:Computed(function(use)
		local d = use(drink)
		local m = use(modifierId)
		local p = use(pastryId)
		local value = d.Price * (if m ~= "" then 1 + Recipes.Modifiers[m].Bonus else 1)
		if p ~= "" then
			value += Catalog.Pastries[p].Price
		end
		return math.floor(value + 0.5)
	end)

	---------------------------------------------------------- animações de painel
	local open = scope:Computed(function(use)
		return use(phase) ~= "Idle"
	end)
	local benchPos = scope:Spring(
		scope:Computed(function(use)
			return if use(open) then UDim2.new(1, -16, 0.5, 0) else UDim2.new(1.5, 0, 0.5, 0)
		end),
		22,
		0.78
	)
	local barPos = scope:Spring(
		scope:Computed(function(use)
			return if use(open) then UDim2.new(0, 16, 1, -16) else UDim2.new(0, 16, 1.4, 0)
		end),
		22,
		0.78
	)
	local waiting = scope:Value(false)
	self.waiting = waiting
	local idleTransparency = scope:Spring(
		scope:Computed(function(use)
			return if use(open) or not use(waiting) then 1 else 0
		end),
		14,
		1
	)
	local serveScale = scope:Value(1)
	-- Servir fica sempre à mão; se estiver errado o cliente leva, mas não paga
	local serveVisible = scope:Computed(function(use)
		local p = use(phase)
		return p == "Making" or p == "Ready"
	end)
	local serveEnabled = scope:Computed(function(use)
		return #use(portions) > 0
	end)

	---------------------------------------------------------- copo
	local glass = Glass.new()
	self.glass = glass

	local glassScale = scope:New("UIScale")({ Scale = 1 })
	local glassHolder = scope:New("Frame")({
		Name = "GlassHolder",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 0.96),
		[Children] = { glassScale, glass.Root },
	})
	self.glassHolder = glassHolder
	self.glassScale = glassScale

	local effects = scope:New("Frame")({
		Name = "Effects",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
	})
	self.effects = effects

	local mixBar = scope:New("Frame")({
		Name = "MixBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(0.5, 0.05),
		BackgroundColor3 = Theme.PaperShade,
		ZIndex = 21,
		Visible = scope:Computed(function(use)
			return use(canStir) and use(mix) > 0
		end),
		[Children] = {
			scope:New("UIStroke")({ Thickness = 2, Color = Theme.Ink }),
			scope:New("Frame")({
				BorderSizePixel = 0,
				BackgroundColor3 = Theme.Sage,
				ZIndex = 22,
				Size = scope:Computed(function(use)
					return UDim2.fromScale(math.clamp(use(mix), 0, 1), 1)
				end),
			}),
		},
	})

	local glassZone = scope:New("TextButton")({
		Name = "GlassZone",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0.435),
		Size = UDim2.fromScale(1, 0.435),
		[Children] = { glassHolder, effects, mixBar },
		[OnEvent("InputBegan")] = function(input: InputObject)
			if isPress(input) then
				self:_beginStir(input)
			end
		end,
	})
	self.glassZone = glassZone
	self.canStir = canStir

	scope:Observer(canStir):onBind(function()
		glass:setSpoon(peek(canStir), self.swirl)
	end)

	---------------------------------------------------------- cartão de receita
	-- bônus de velocidade: a barra esvazia com o tempo (mesmo relógio pra toda receita)
	local multiplier = scope:Computed(function(use)
		return Progression.multiplier(use(elapsed))
	end)
	local tier = scope:Computed(function(use)
		return Progression.tier(use(multiplier))
	end)
	local TIER_COLORS = { [0] = Theme.Rose, [1] = Color3.fromRGB(232, 156, 96), [2] = Theme.Mustard, [3] = Theme.Sage }

	local timerBar = scope:New("Frame")({
		Name = "Timer",
		Visible = scope:Computed(function(use)
			return not use(free)
		end),
		Position = UDim2.fromScale(0, 0.215),
		Size = UDim2.fromScale(1, 0.085),
		BackgroundColor3 = Theme.PaperShade,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			scope:New("UIStroke")({ Thickness = 2, Color = Theme.Ink }),
			scope:New("Frame")({
				Name = "Fill",
				BorderSizePixel = 0,
				BackgroundColor3 = scope:Spring(
					scope:Computed(function(use)
						return TIER_COLORS[use(tier)]
					end),
					12,
					1
				),
				Size = scope:Computed(function(use)
					local range = Progression.MaxMultiplier - Progression.MinMultiplier
					return UDim2.fromScale(math.clamp((use(multiplier) - Progression.MinMultiplier) / range, 0.02, 1), 1)
				end),
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
				},
			}),
			scope:New("TextLabel")({
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromScale(0.6, 0.85),
				Font = Theme.Font,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = Theme.Ink,
				ZIndex = 3,
				Text = scope:Computed(function(use)
					return Progression.TierNames[use(tier)]
				end),
			}),
		},
	})

	local coinIcon = PixelArt.draw(Sprites.Coin)
	coinIcon.AnchorPoint = Vector2.new(0, 0.5)
	coinIcon.Position = UDim2.fromScale(0, 0.5)
	coinIcon.Size = UDim2.fromScale(0.8, 0.8)
	coinIcon.SizeConstraint = Enum.SizeConstraint.RelativeYY

	local recipeCard = scope:New("Frame")({
		Name = "RecipeCard",
		BackgroundColor3 = Theme.Paper,
		Size = UDim2.fromScale(1, 0.36),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
			scope:New("UIStroke")({ Thickness = 3, Color = Theme.Ink }),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0.05, 0),
				PaddingBottom = UDim.new(0.03, 0),
				PaddingLeft = UDim.new(0.05, 0),
				PaddingRight = UDim.new(0.05, 0),
			}),
			scope:New("TextLabel")({
				Name = "Title",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(0.75, 0.19),
				Font = Theme.Font,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Theme.Ink,
				Text = scope:Computed(function(use)
					return if use(free) then "Seu copo" else use(drink).Name
				end),
			}),
			scope:New("Frame")({
				Name = "Price",
				Visible = scope:Computed(function(use)
					return not use(free)
				end),
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0.02),
				Size = UDim2.fromScale(0.22, 0.16),
				[Children] = {
					coinIcon,
					scope:New("TextLabel")({
						BackgroundTransparency = 1,
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.fromScale(0.62, 1),
						Font = Theme.Font,
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Right,
						TextColor3 = Theme.WoodDark,
						Text = scope:Computed(function(use)
							return `${use(price)}`
						end),
					}),
				},
			}),
			timerBar,
			scope:New("Frame")({
				Name = "NewRecipe",
				Visible = scope:Computed(function(use)
					local level = use(State.Level)
					return level > 1 and use(drink).Level == level
				end),
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 0, 0, -6),
				Size = UDim2.fromScale(0.42, 0.11),
				Rotation = -3,
				ZIndex = 5,
				BackgroundColor3 = Theme.Rose,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					scope:New("UIStroke")({ Thickness = 2, Color = Theme.Ink }),
					scope:New("TextLabel")({
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.06, 0.12),
						Size = UDim2.fromScale(0.88, 0.76),
						ZIndex = 6,
						Font = Theme.Font,
						TextScaled = true,
						TextColor3 = Theme.Paper,
						Text = "RECEITA NOVA!",
					}),
				},
			}),
			scope:New("Frame")({
				Name = "Lines",
				BackgroundTransparency = 1,
				Position = scope:Computed(function(use)
					return if use(free) then UDim2.fromScale(0, 0.25) else UDim2.fromScale(0, 0.34)
				end),
				Size = UDim2.fromScale(1, 0.66),
				[Children] = {
					scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0.01, 0),
					}),
					scope:ForValues(lines, function(use, lineScope, line: Line)
						local icon = PixelArt.draw((Sprites :: any)[line.Sprite or "Spoon"])
						return lineScope:New("Frame")({
							BackgroundTransparency = 1,
							Size = UDim2.fromScale(1, 1 / math.max(5, #use(lines)) - 0.01),
							LayoutOrder = line.Order,
							[Children] = {
								lineScope:New("Frame")({
									Name = "Check",
									AnchorPoint = Vector2.new(0, 0.5),
									Position = UDim2.fromScale(0, 0.5),
									Size = UDim2.fromScale(0.75, 0.75),
									SizeConstraint = Enum.SizeConstraint.RelativeYY,
									BackgroundColor3 = if line.Done then Theme.Sage else Theme.Paper,
									[Children] = {
										lineScope:New("UICorner")({ CornerRadius = UDim.new(0.2, 0) }),
										lineScope:New("UIStroke")({ Thickness = 2, Color = Theme.Ink }),
										lineScope:New("Frame")({
											Visible = line.Done,
											BorderSizePixel = 0,
											AnchorPoint = Vector2.new(0.5, 0.5),
											Position = UDim2.fromScale(0.5, 0.5),
											Size = UDim2.fromScale(0.4, 0.4),
											BackgroundColor3 = Theme.Paper,
										}),
									},
								}),
								lineScope:New("Frame")({
									Name = "Icon",
									BackgroundTransparency = 1,
									AnchorPoint = Vector2.new(0, 0.5),
									Position = UDim2.new(0.1, 0, 0.5, 0),
									Size = UDim2.fromScale(1, 1),
									SizeConstraint = Enum.SizeConstraint.RelativeYY,
									[Children] = icon,
								}),
								lineScope:New("TextLabel")({
									BackgroundTransparency = 1,
									Position = UDim2.fromScale(0.24, 0.1),
									Size = UDim2.fromScale(0.76, 0.8),
									Font = Theme.Font,
									TextScaled = true,
									TextXAlignment = Enum.TextXAlignment.Left,
									TextColor3 = if line.Done then Theme.SageDark else Theme.Ink,
									Text = line.Text,
								}),
							},
						})
					end),
				},
			}),
		},
	})

	---------------------------------------------------------- botões
	local trashSprite = PixelArt.draw(Sprites.Trash)
	trashSprite.Size = UDim2.fromScale(0.7, 0.7)
	local trashButton = scope:New("TextButton")({
		Name = "Trash",
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = Theme.PaperShade,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromScale(1, 1),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0.2, 0) }),
			scope:New("UIStroke")({ Thickness = 3, Color = Theme.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			trashSprite,
		},
		[OnEvent("Activated")] = function()
			self:_trash()
		end,
	})

	local serveButton = scope:New("TextButton")({
		Name = "Serve",
		Text = "Servir",
		Font = Theme.Font,
		TextScaled = true,
		TextColor3 = Theme.Paper,
		BackgroundColor3 = scope:Computed(function(use)
			return if use(serveEnabled) then Theme.SageDark else Theme.PaperShade
		end),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromScale(0.62, 1),
		Visible = serveVisible,
		Active = serveEnabled,
		AutoButtonColor = serveEnabled,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0.25, 0) }),
			scope:New("UIStroke")({ Thickness = 3, Color = Theme.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			scope:New("UIPadding")({ PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.18, 0) }),
			scope:New("UIScale")({ Scale = serveScale }),
		},
		[OnEvent("Activated")] = function()
			self:_serve()
		end,
	})

	---------------------------------------------------------- painel direito (bancada)
	local bench = scope:New("Frame")({
		Name = "Bench",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = benchPos,
		Size = UDim2.new(0.38, 0, 1, -32),
		BackgroundColor3 = Theme.Wood,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 14) }),
			scope:New("UIStroke")({ Thickness = 4, Color = Theme.Ink }),
			scope:New("UISizeConstraint")({ MaxSize = Vector2.new(560, math.huge) }),
			scope:New("Frame")({
				Name = "Inner",
				BackgroundColor3 = Theme.WoodLight,
				Position = UDim2.fromOffset(10, 10),
				Size = UDim2.new(1, -20, 1, -20),
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
					scope:New("UIPadding")({
						PaddingTop = UDim.new(0, 12),
						PaddingBottom = UDim.new(0, 12),
						PaddingLeft = UDim.new(0, 12),
						PaddingRight = UDim.new(0, 12),
					}),
					recipeCard,
					scope:New("TextLabel")({
						Name = "Hint",
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0, 0.375),
						Size = UDim2.fromScale(1, 0.05),
						Font = Theme.Font,
						TextScaled = true,
						TextColor3 = Theme.Ink,
						Text = hint,
					}),
					glassZone,
					scope:New("Frame")({
						Name = "Buttons",
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0, 0.88),
						Size = UDim2.fromScale(1, 0.12),
						[Children] = { trashButton, serveButton },
					}),
				},
			}),
		},
	})
	self.bench = bench

	---------------------------------------------------------- barra de ingredientes
	local slots = {}
	for i, id in Recipes.IngredientOrder do
		table.insert(slots, self:_makeSlot(id, i))
	end

	local bar = scope:New("Frame")({
		Name = "IngredientBar",
		AnchorPoint = Vector2.new(0, 1),
		Position = barPos,
		Size = UDim2.new(0.62, -48, 0.24, 0),
		BackgroundColor3 = Theme.Wood,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 14) }),
			scope:New("UIStroke")({ Thickness = 4, Color = Theme.Ink }),
			scope:New("Frame")({
				Name = "Tab",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 18, 0, 4),
				Size = UDim2.new(0, 150, 0, 30),
				BackgroundColor3 = Theme.WoodDark,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
					scope:New("UIStroke")({ Thickness = 3, Color = Theme.Ink }),
					scope:New("TextLabel")({
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 0.8),
						Position = UDim2.fromScale(0, 0.1),
						Font = Theme.Font,
						TextScaled = true,
						TextColor3 = Theme.Paper,
						Text = "Ingredientes",
					}),
				},
			}),
			scope:New("Frame")({
				Name = "Slots",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(12, 12),
				Size = UDim2.new(1, -24, 1, -24),
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0.025, 0),
					}),
					slots,
				},
			}),
		},
	})

	local oven = Oven.new(scope, pastryId, pastryQuality, phase)
	self.oven = oven

	local idlePill = scope:New("Frame")({
		Name = "Waiting",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.31, 0, 0, 96),
		Size = UDim2.fromOffset(280, 44),
		BackgroundColor3 = Theme.Paper,
		BackgroundTransparency = idleTransparency,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			scope:New("UIStroke")({
				Thickness = 3,
				Color = Theme.Ink,
				Transparency = idleTransparency,
			}),
			scope:New("TextLabel")({
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 0.6),
				Position = UDim2.fromScale(0, 0.2),
				Font = Theme.Font,
				TextScaled = true,
				TextColor3 = Theme.Ink,
				TextTransparency = idleTransparency,
				Text = "Esperando clientes...",
			}),
		},
	})

	scope:New("ScreenGui")({
		Name = "CafeUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
		[Children] = { bench, bar, idlePill, oven.Root },
	})

	self.dragGui = scope:New("ScreenGui")({
		Name = "CafeDrag",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 10,
		Parent = playerGui,
	})

	---------------------------------------------------------- reações
	scope:Observer(ready):onChange(function()
		if peek(ready) and peek(phase) == "Making" and not self.busy then
			phase:set("Ready")
		end
	end)
	scope:Observer(phase):onChange(function()
		if peek(phase) == "Ready" then
			self:_celebrate()
		end
	end)

	-- botão servir pulsando
	RunService.RenderStepped:Connect(function()
		local p = peek(phase)
		if p == "Making" or p == "Ready" then
			elapsed:set(os.clock() - self.openedAt)
		end
		if p == "Ready" then
			serveScale:set(1 + math.sin(os.clock() * 6) * 0.05)
		end
	end)

	return self
end

------------------------------------------------------------------ slots / arrastar

function Minigame._makeSlot(self: any, id: string, order: number): GuiObject
	local scope = self.scope
	local ingredient = Recipes.Ingredients[id]
	local hovered = scope:Value(false)
	local dragging = scope:Value(false)
	local locked = scope:Computed(function(use)
		return not Progression.ingredientUnlocked(id, use(State.Level))
	end)
	local scale = scope:Spring(
		scope:Computed(function(use)
			if use(locked) then
				return 0.92
			end
			return if use(dragging) then 0.9 elseif use(hovered) then 1.08 else 1
		end),
		30,
		0.6
	)

	local sprite = PixelArt.ingredient(id)
	sprite.Size = UDim2.fromScale(0.8, 0.8)
	local lockSprite = PixelArt.draw(Sprites.Lock, 3)
	lockSprite.Size = UDim2.fromScale(0.45, 0.45)
	lockSprite.Position = UDim2.fromScale(0.5, 0.42)

	local slot
	slot = scope:New("TextButton")({
		Name = id,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = order,
		BackgroundColor3 = scope:Computed(function(use)
			return if use(locked) then Theme.PaperShade else Theme.Paper
		end),
		Size = UDim2.fromScale(0.125, 1),
		[Children] = {
			scope:New("UIAspectRatioConstraint")({ AspectRatio = 0.85 }),
			scope:New("UICorner")({ CornerRadius = UDim.new(0.12, 0) }),
			scope:New("UIStroke")({ Thickness = 3, Color = Theme.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			scope:New("UIScale")({ Scale = scale }),
			scope:New("Frame")({
				Name = "Art",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.08, 0.04),
				Size = UDim2.fromScale(0.84, 0.7),
				[Children] = sprite,
			}),
			scope:New("Frame")({
				Name = "NewBadge",
				Visible = scope:Computed(function(use)
					local level = use(State.Level)
					return level > 1 and ingredient.Level == level
				end),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.85, 0.02),
				Size = UDim2.fromScale(0.62, 0.2),
				Rotation = 12,
				ZIndex = 5,
				BackgroundColor3 = Theme.Rose,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0.4, 0) }),
					scope:New("UIStroke")({ Thickness = 2, Color = Theme.Ink }),
					scope:New("TextLabel")({
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.08, 0.12),
						Size = UDim2.fromScale(0.84, 0.76),
						ZIndex = 6,
						Font = Theme.Font,
						TextScaled = true,
						TextColor3 = Theme.Paper,
						Text = "NOVO!",
					}),
				},
			}),
			scope:New("Frame")({
				Name = "Locked",
				Visible = locked,
				ZIndex = 2,
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.Ink,
				BackgroundTransparency = 0.35,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0.12, 0) }),
					lockSprite,
				},
			}),
			scope:New("TextLabel")({
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.05, 0.74),
				Size = UDim2.fromScale(0.9, 0.2),
				ZIndex = 3,
				Font = Theme.Font,
				TextScaled = true,
				TextColor3 = scope:Computed(function(use)
					return if use(locked) then Theme.Paper else Theme.Ink
				end),
				Text = scope:Computed(function(use)
					return if use(locked) then `Nível {ingredient.Level}` else ingredient.Name
				end),
			}),
		},
		[OnEvent("MouseEnter")] = function()
			hovered:set(true)
		end,
		[OnEvent("MouseLeave")] = function()
			hovered:set(false)
		end,
		[OnEvent("InputBegan")] = function(input: InputObject)
			if isPress(input) and not peek(locked) then
				self:_beginDrag(id, input, slot, dragging)
			end
		end,
	})
	return slot
end

function Minigame._beginDrag(self: any, id: string, input: InputObject, slot: GuiObject, dragging: any)
	if peek(self.phase) ~= "Making" or self.busy or self.draggingIngredient then
		return
	end
	self.draggingIngredient = true
	dragging:set(true)

	local ghost = Instance.new("Frame")
	ghost.Name = "Ghost"
	ghost.BackgroundTransparency = 1
	ghost.AnchorPoint = Vector2.new(0.5, 0.5)
	ghost.Size = UDim2.fromOffset(slot.AbsoluteSize.X * 1.1, slot.AbsoluteSize.X * 1.1)
	local sprite = PixelArt.ingredient(id)
	sprite.Parent = ghost
	ghost.Parent = self.dragGui

	local start = pointerPosition(input)
	local last = start
	ghost.Position = UDim2.fromOffset(start.X, start.Y)

	trackPointer(input, function(p)
		local vx = p.X - last.X
		last = p
		ghost.Position = UDim2.fromOffset(p.X, p.Y)
		ghost.Rotation = math.clamp(ghost.Rotation * 0.7 + vx * 0.8, -25, 25)
	end, function(p)
		self.draggingIngredient = false
		dragging:set(false)
		if peek(self.phase) == "Making" and inside(self.bench, p) then
			ghost:Destroy()
			self:_addIngredient(id)
		else
			-- volta pro slot
			local home = slot.AbsolutePosition + slot.AbsoluteSize / 2
			tween(ghost, 0.2, { Position = UDim2.fromOffset(home.X, home.Y), Size = UDim2.fromOffset(0, 0), Rotation = 0 }).Completed:Once(function()
				ghost:Destroy()
			end)
		end
	end)
end

------------------------------------------------------------------ copo: despejar / mexer / lixo

function Minigame._shake(self: any)
	local holder = self.glassHolder :: Frame
	task.spawn(function()
		for _, r in { 8, -7, 5, -3, 0 } do
			tween(holder, 0.06, { Rotation = r }).Completed:Wait()
		end
	end)
end

function Minigame._addIngredient(self: any, id: string)
	local current = peek(self.portions) :: { string }
	if #current >= Recipes.MaxPortions or self.busy then
		self:_shake()
		return
	end
	self.busy = true

	local list = table.clone(current)
	table.insert(list, id)
	local glass = self.glass
	self.mix:set(0)
	glass:setMix(0, self.swirl)
	glass:setPortions(list)
	glass:setSpoon(false)

	task.spawn(function()
		-- ingrediente aparece em cima do copo e inclina pra despejar
		local pourer = Instance.new("Frame")
		pourer.BackgroundTransparency = 1
		pourer.AnchorPoint = Vector2.new(0.5, 0.5)
		pourer.Size = UDim2.fromScale(0.3, 0.3)
		pourer.Position = UDim2.fromScale(0.36, 0.02)
		pourer.Rotation = 0
		pourer.ZIndex = 15
		local sprite = PixelArt.ingredient(id, 15)
		sprite.Parent = pourer
		local ps = Instance.new("UIScale")
		ps.Scale = 0
		ps.Parent = pourer
		pourer.Parent = self.effects

		tween(ps, 0.15, { Scale = 1 }, Enum.EasingStyle.Back)
		tween(pourer, 0.25, { Rotation = 115, Position = UDim2.fromScale(0.4, 0.04) }, Enum.EasingStyle.Back).Completed:Wait()

		local color = Recipes.Ingredients[id].Liquid
		local from = glass.Level
		local to = #list * ROWS_PER_PORTION
		local turbo = (peek(State.Upgrades) :: any).Espresso or 0
		local duration = POUR_TIME * (1 - 0.2 * turbo)
		local t0 = os.clock()
		while true do
			local a = math.min(1, (os.clock() - t0) / duration)
			glass:setLevel(from + (to - from) * a)
			glass:setStream(if a < 0.95 then color else nil)
			if a >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
		glass:setStream(nil)

		tween(pourer, 0.2, { Rotation = 0 })
		tween(ps, 0.2, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In).Completed:Wait()
		pourer:Destroy()

		self.portions:set(list)
		self.busy = false
		glass:setSpoon(peek(self.canStir), self.swirl)
		if peek(self.ready) and peek(self.phase) == "Making" then
			self.phase:set("Ready")
		end
	end)
end

function Minigame._beginStir(self: any, input: InputObject)
	if not peek(self.canStir) or self.busy then
		return
	end
	local glass = self.glass
	local root = glass.Root :: Frame
	local lastAngle: number? = nil
	local progress = peek(self.mix) :: number

	local function angleAt(p: Vector2): number
		local c = root.AbsolutePosition + root.AbsoluteSize / 2
		return math.atan2(p.Y - c.Y, p.X - c.X)
	end

	lastAngle = angleAt(pointerPosition(input))
	trackPointer(input, function(p)
		if not peek(self.canStir) then
			return
		end
		local a = angleAt(p)
		local d = (a - (lastAngle :: number) + math.pi) % (2 * math.pi) - math.pi
		lastAngle = a
		local whisk = (peek(State.Upgrades) :: any).Whisk or 0
		local turns = math.max(0.9, STIR_TURNS - 0.45 * whisk)
		progress = math.min(1, progress + math.abs(d) / (2 * math.pi * turns))
		self.swirl += d
		if progress > 0 and peek(self.phase) == "Ready" then
			-- mexeu um copo já pronto (ex.: pedido sem mexer): volta a ser preparo
			self.phase:set("Making")
		end
		glass:setMix(progress, self.swirl)
		glass:setSpoon(true, self.swirl)
		self.mix:set(progress)
	end, function() end)
end

function Minigame._trash(self: any)
	if self.busy or peek(self.phase) ~= "Making" then
		return
	end
	if #(peek(self.portions) :: { string }) == 0 then
		return
	end
	self.busy = true
	self:_shake()
	local glass = self.glass
	task.spawn(function()
		local from = glass.Level
		local t0 = os.clock()
		while true do
			local a = math.min(1, (os.clock() - t0) / 0.3)
			glass:setLevel(from * (1 - a))
			if a >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
		self.portions:set({})
		self.mix:set(0)
		glass:setPortions({})
		glass:setMix(0, 0)
		glass:setSpoon(false)
		self.busy = false
	end)
end

------------------------------------------------------------------ feedback de pronto

function Minigame._celebrate(self: any)
	local glassScale = self.glassScale :: UIScale
	local glass = self.glass
	glass:setSpoon(false)
	tween(glassScale, 0.12, { Scale = 1.12 }).Completed:Once(function()
		tween(glassScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	end)

	-- estrelinhas pixel subindo
	local rng = Random.new()
	for i = 1, 9 do
		task.delay(i * 0.04, function()
			local star = PixelArt.draw(Sprites.Star, 25)
			star.Size = UDim2.fromScale(0.09, 0.09)
			local x = 0.5 + rng:NextNumber(-0.32, 0.32)
			local y = 0.5 + rng:NextNumber(-0.25, 0.3)
			star.Position = UDim2.fromScale(x, y)
			star.Parent = self.effects
			tween(star, 0.7, { Position = UDim2.fromScale(x, y - 0.25), Rotation = rng:NextNumber(-90, 90), Size = UDim2.fromScale(0, 0) }, Enum.EasingStyle.Sine).Completed:Once(function()
				star:Destroy()
			end)
		end)
	end

	-- vapor saindo enquanto espera servir
	task.spawn(function()
		while peek(self.phase) == "Ready" do
			local puff = Instance.new("Frame")
			puff.BorderSizePixel = 0
			puff.BackgroundColor3 = Color3.new(1, 1, 1)
			puff.BackgroundTransparency = 0.3
			puff.ZIndex = 24
			puff.Size = UDim2.fromScale(0.035, 0.035)
			puff.SizeConstraint = Enum.SizeConstraint.RelativeYY
			local x = 0.5 + rng:NextNumber(-0.12, 0.12)
			puff.Position = UDim2.fromScale(x, 0.14)
			puff.Parent = self.effects
			tween(puff, 1.2, {
				Position = UDim2.fromScale(x + rng:NextNumber(-0.05, 0.05), -0.05),
				BackgroundTransparency = 1,
			}, Enum.EasingStyle.Sine).Completed:Once(function()
				puff:Destroy()
			end)
			task.wait(0.18)
		end
	end)
end

------------------------------------------------------------------ API pública

function Minigame.open(self: any, order: Order)
	self.free:set(false)
	self.order = order
	self.busy = false
	self.swirl = 0
	self.drinkId:set(order.drink)
	self.modifierId:set(order.modifier)
	self.pastryId:set(order.pastry)
	self.pastryQuality:set(0)
	self.oven:reset()
	self.portions:set({})
	self.mix:set(0)
	local glass = self.glass
	glass:setPortions({})
	glass:setLevel(0)
	glass:setMix(0, 0)
	glass:setSpoon(false)
	glass:setStream(nil)
	self.glassHolder.Position = UDim2.fromScale(0.5, 0.5)
	self.glassHolder.Rotation = 0
	self.glassScale.Scale = 1
	self.openedAt = os.clock()
	self.elapsed:set(0)
	self.phase:set("Making")
end

function Minigame._serve(self: any)
	local p = peek(self.phase)
	if peek(self.free) then
		if p == "Making" and not self.busy then
			self:_freeServe()
		end
		return
	end
	if (p ~= "Ready" and p ~= "Making") or not self.order or self.busy then
		return
	end
	if #(peek(self.portions) :: { string }) == 0 then
		self:_shake()
		return
	end
	self.phase:set("Serving")
	if self.onServe then
		local m = peek(self.mix) :: number
		self.onServe(self.order.orderId, peek(self.portions), m >= 1, m > 0, peek(self.pastryQuality))
	end
end

function Minigame.currentPortions(self: any): { string }
	return peek(self.portions)
end

local function resetGlass(self: any)
	self.busy = false
	self.swirl = 0
	self.portions:set({})
	self.mix:set(0)
	local glass = self.glass
	glass:setPortions({})
	glass:setLevel(0)
	glass:setMix(0, 0)
	glass:setSpoon(false)
	glass:setStream(nil)
	self.glassHolder.Position = UDim2.fromScale(0.5, 0.5)
	self.glassHolder.Rotation = 0
	self.glassScale.Scale = 1
end

-- Modo Livre: abre só o copo e os ingredientes, sem pedido
function Minigame.openFree(self: any)
	self.order = nil
	self.free:set(true)
	self.drinkId:set("Espresso")
	self.modifierId:set("")
	self.pastryId:set("")
	self.pastryQuality:set(0)
	self.oven:reset()
	resetGlass(self)
	self.phase:set("Making")
end

function Minigame.close(self: any)
	self.order = nil
	self.phase:set("Idle")
	task.delay(0.4, function()
		if peek(self.phase) == "Idle" then
			self.free:set(false)
			resetGlass(self)
		end
	end)
end

-- Servir no Modo Livre: o copo sai, quem chamou comemora, e volta um copo vazio
function Minigame._freeServe(self: any)
	local portions = peek(self.portions) :: { string }
	if #portions == 0 then
		self:_shake()
		return
	end
	self.busy = true
	local mix = peek(self.mix) :: number
	if self.onFreeServe then
		self.onFreeServe(table.clone(portions), mix)
	end
	local holder = self.glassHolder :: Frame
	tween(holder, 0.3, { Position = UDim2.fromScale(-0.8, 0.3), Rotation = -15 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	task.delay(1.6, function()
		if not peek(self.free) then
			return
		end
		resetGlass(self)
		self.glassHolder.Position = UDim2.fromScale(0.5, -0.6)
		tween(self.glassHolder, 0.45, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Back)
	end)
end

-- Entrega feita (certa ou errada): o copo desliza até o cliente e o painel fecha
function Minigame.serveDone(self: any, correct: boolean)
	local holder = self.glassHolder :: Frame
	if not correct then
		self:_shake()
	end
	tween(holder, 0.35, { Position = UDim2.fromScale(-0.8, 0.3), Rotation = -15 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	task.delay(0.4, function()
		self.order = nil
		self.phase:set("Idle")
	end)
end

return Minigame
