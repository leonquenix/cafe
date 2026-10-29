--!strict
-- Tela "Antes de abrir": loja (melhorias, doces, decoração) e cardápio do dia.
-- Compras e cardápio vão pro servidor; a tela reage ao State que volta.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Recipes = require(ReplicatedStorage.Shared.Recipes)
local Glass = require(script.Parent.Parent.Art.Glass)
local PixelArt = require(script.Parent.Parent.Art.PixelArt)
local Sprites = require(script.Parent.Parent.Art.Sprites)
local Sfx = require(script.Parent.Parent.Sfx)
local State = require(script.Parent.Parent.State)
local CatPicker = require(script.Parent.CatPicker)
local Theme = require(script.Parent.Theme)

local Children, OnEvent, peek = Fusion.Children, Fusion.OnEvent, Fusion.peek

local PrepScreen = {}

PrepScreen.onBuy = nil :: ((id: string) -> ())?
PrepScreen.onSetMenu = nil :: ((list: { string }) -> ())?
PrepScreen.onSetCatColor = nil :: ((color: string) -> ())?
PrepScreen.onOpenBook = nil :: (() -> ())?
PrepScreen.onWalk = nil :: (() -> ())?

-- fecha a tela atual sem abrir o café (usado pela animação de decoração nova)
local closeCurrent: ((onClosed: () -> ()) -> ())? = nil

local playerGui: PlayerGui

local TABS = {
	{ Id = "Upgrades", Name = "Melhorias" },
	{ Id = "Pastries", Name = "Doces" },
	{ Id = "Decor", Name = "Decoração" },
	{ Id = "Menu", Name = "Cardápio" },
}

function PrepScreen.init(gui: PlayerGui)
	playerGui = gui
	CatPicker.init(gui)
end

local function label(scope: any, text: any, props: { [string]: any }): TextLabel
	props.BackgroundTransparency = 1
	props.Font = props.Font or Theme.Font
	props.TextScaled = true
	props.TextColor3 = props.TextColor3 or Theme.Ink
	props.Text = text
	return scope:New("TextLabel")(props)
end

local function icon(name: string): Frame
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	local art = PixelArt.draw((Sprites :: any)[name])
	art.Size = UDim2.fromScale(0.9, 0.9)
	art.Parent = holder
	return holder
end

-- Card genérico de item da loja
local function shopCard(
	scope: any,
	order: number,
	iconName: string,
	title: string,
	description: string,
	pips: any?, -- Computed<{ number, number }> (nível atual, máximo) para melhorias
	buttonText: any,
	buttonEnabled: any,
	onClick: () -> ()
): Frame
	local pipRow = nil
	if pips then
		pipRow = scope:New("Frame")({
			Name = "Pips",
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.04, 0.78),
			Size = UDim2.fromScale(0.4, 0.1),
			[Children] = {
				scope:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 4),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				scope:ForPairs(pips, function(use, pipScope, i: number, filled: boolean)
					return i,
						pipScope:New("Frame")({
							LayoutOrder = i,
							Size = UDim2.fromScale(1, 1),
							SizeConstraint = Enum.SizeConstraint.RelativeYY,
							BackgroundColor3 = if filled then Theme.Mustard else Theme.PaperShade,
							[Children] = {
								pipScope:New("UICorner")({ CornerRadius = UDim.new(0.3, 0) }),
								pipScope:New("UIStroke")({ Thickness = 2, Color = Theme.Ink }),
							},
						})
				end),
			},
		})
	end

	local buyButton = scope:New("TextButton")({
		Name = "Buy",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(0.96, 0.93),
		Size = UDim2.fromScale(0.5, 0.2),
		BackgroundColor3 = scope:Computed(function(use)
			return if use(buttonEnabled) then Theme.SageDark else Theme.PaperShade
		end),
		AutoButtonColor = buttonEnabled,
		Font = Theme.Font,
		TextScaled = true,
		TextColor3 = scope:Computed(function(use)
			return if use(buttonEnabled) then Theme.Paper else Theme.WoodDark
		end),
		Text = buttonText,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0.3, 0) }),
			scope:New("UIStroke")({ Thickness = 2, Color = Theme.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			scope:New("UIPadding")({ PaddingTop = UDim.new(0.16, 0), PaddingBottom = UDim.new(0.16, 0) }),
		},
		[OnEvent("Activated")] = function()
			if peek(buttonEnabled) then
				onClick()
			else
				-- já comprado, no máximo, nível baixo ou sem moedas
				Sfx.play("Denied")
			end
		end,
	})
	-- compra tem som próprio (caixa registradora ou negação), não o pop
	buyButton:SetAttribute("NoClickSound", true)

	return scope:New("Frame")({
		Name = title,
		LayoutOrder = order,
		BackgroundColor3 = Theme.Paper,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
			scope:New("UIStroke")({ Thickness = 3, Color = Theme.Ink }),
			scope:New("Frame")({
				Name = "Icon",
				BackgroundColor3 = Theme.PaperShade,
				Position = UDim2.fromScale(0.04, 0.08),
				Size = UDim2.fromScale(0.25, 0.6),
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0.15, 0) }),
					scope:New("UIAspectRatioConstraint")({ AspectRatio = 1 }),
					icon(iconName),
				},
			}),
			label(scope, title, {
				Position = UDim2.fromScale(0.32, 0.08),
				Size = UDim2.fromScale(0.64, 0.2),
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			label(scope, description, {
				Position = UDim2.fromScale(0.32, 0.29),
				Size = UDim2.fromScale(0.64, 0.27),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextWrapped = true,
				TextColor3 = Theme.WoodDark,
				Font = Enum.Font.Gotham,
			}),
			pipRow or {},
			buyButton,
		},
	})
end

-- o servidor não responde a compra: ela vale quando o State volta com menos moedas
local BUY_TIMEOUT = 2

local function buy(id: string)
	if not PrepScreen.onBuy then
		return
	end
	local before = peek(State.Money) :: number
	PrepScreen.onBuy(id)
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < BUY_TIMEOUT do
			if (peek(State.Money) :: number) < before then
				Sfx.play("Cash")
				task.delay(0.25, Sfx.play, "CutePop")
				return
			end
			task.wait()
		end
		-- recusada pelo servidor
		Sfx.play("Denied")
	end)
end

local function upgradeCards(scope: any): { Frame }
	local cards = {}
	for i, id in Catalog.UpgradeOrder do
		local u = Catalog.Upgrades[id]
		local lvl = scope:Computed(function(use)
			return use(State.Upgrades)[id] or 0
		end)
		local cost = scope:Computed(function(use)
			return u.Costs[use(lvl) + 1]
		end)
		local text = scope:Computed(function(use)
			local c = use(cost)
			if use(State.Level) < u.Level then
				return `Nível {u.Level}`
			end
			return if c then `${c}` else "Máximo!"
		end)
		local enabled = scope:Computed(function(use)
			local c = use(cost)
			return c ~= nil and use(State.Level) >= u.Level and use(State.Money) >= c
		end)
		local pips = scope:Computed(function(use)
			local list = {}
			for p = 1, #u.Costs do
				list[p] = p <= use(lvl)
			end
			return list
		end)
		table.insert(cards, shopCard(scope, i, u.Icon, u.Name, u.Description, pips, text, enabled, function()
			buy(id)
		end))
	end
	return cards
end

local function ownableCard(scope: any, order: number, id: string, iconName: string, title: string, description: string, cost: number, level: number): Frame
	local owned = scope:Computed(function(use)
		return use(State.Owned)[id] == true
	end)
	local text = scope:Computed(function(use)
		if use(owned) then
			return "Comprado"
		elseif use(State.Level) < level then
			return `Nível {level}`
		end
		return `${cost}`
	end)
	local enabled = scope:Computed(function(use)
		return not use(owned) and use(State.Level) >= level and use(State.Money) >= cost
	end)
	return shopCard(scope, order, iconName, title, description, nil, text, enabled, function()
		buy(id)
	end)
end

local function pastryCards(scope: any): { Frame }
	local cards = {}
	for i, id in Catalog.PastryOrder do
		local p = Catalog.Pastries[id]
		local desc = `Aprenda a assar. Pedidos com {p.Name} pagam +${p.Price}.`
		table.insert(cards, ownableCard(scope, i, id, p.Icon, p.Name, desc, p.Cost, p.Level))
	end
	return cards
end

-- Gatinho: o botão abre o pop-up de cores (comprar já escolhendo a pelagem; depois, trocar de graça)
local function catCard(scope: any, order: number, d: Catalog.Decor): Frame
	local owned = scope:Computed(function(use)
		return use(State.Owned)[d.Id] == true
	end)
	local text = scope:Computed(function(use)
		if use(owned) then
			return "Mudar cor"
		elseif use(State.Level) < d.Level then
			return `Nível {d.Level}`
		end
		return `${d.Cost}`
	end)
	local enabled = scope:Computed(function(use)
		return use(owned) or (use(State.Level) >= d.Level and use(State.Money) >= d.Cost)
	end)
	local desc = `{d.Description} Aconchego +{d.Cozy}.`
	return shopCard(scope, order, d.Icon, d.Name, desc, nil, text, enabled, function()
		local wasOwned = peek(owned) :: boolean
		CatPicker.show({
			Owned = wasOwned,
			Cost = d.Cost,
			Current = peek(State.CatColor) :: string,
			OnConfirm = function(color)
				if PrepScreen.onSetCatColor then
					PrepScreen.onSetCatColor(color)
				end
				if wasOwned then
					Sfx.play("CutePop")
				else
					buy(d.Id)
				end
			end,
		})
	end)
end

local function decorCards(scope: any): { Frame }
	local cards = {}
	for i, id in Catalog.DecorOrder do
		local d = Catalog.Decor[id]
		if id == "Cat" then
			table.insert(cards, catCard(scope, i, d))
			continue
		end
		local desc = `{d.Description} Aconchego +{d.Cozy}.`
		table.insert(cards, ownableCard(scope, i, id, d.Icon, d.Name, desc, d.Cost, d.Level))
	end
	return cards
end

local function menuCards(scope: any, selection: any): { Frame }
	local cards = {}
	for i, id in Recipes.DrinkOrder do
		local d = Recipes.Drinks[id]
		local unlocked = scope:Computed(function(use)
			return d.Level <= use(State.Level)
		end)
		local selected = scope:Computed(function(use)
			return table.find(use(selection), id) ~= nil
		end)
		local glass = Glass.new()
		glass:setPortions(Recipes.portions(id))
		glass:setMix(if d.Mix then 1 else 0, 0)
		glass:setLevel(glass:targetLevel())

		table.insert(
			cards,
			scope:New("TextButton")({
				Name = id,
				LayoutOrder = i,
				Text = "",
				AutoButtonColor = unlocked,
				BackgroundColor3 = scope:Computed(function(use)
					return if not use(unlocked) then Theme.PaperShade elseif use(selected) then Theme.Paper else Color3.fromRGB(226, 214, 196)
				end),
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
					scope:New("UIStroke")({
						Thickness = scope:Computed(function(use)
							return if use(selected) then 4 else 2
						end),
						Color = scope:Computed(function(use)
							return if use(selected) then Theme.SageDark else Theme.Ink
						end),
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}),
					scope:New("Frame")({
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.05, 0.08),
						Size = UDim2.fromScale(0.3, 0.84),
						Visible = unlocked,
						[Children] = glass.Root,
					}),
					label(scope, d.Name, {
						Position = UDim2.fromScale(0.38, 0.1),
						Size = UDim2.fromScale(0.58, 0.28),
						TextXAlignment = Enum.TextXAlignment.Left,
						Visible = unlocked,
					}),
					label(scope, `${d.Price}  ·  {Recipes.describe(id)} · {Recipes.mixText(id)}`, {
						Position = UDim2.fromScale(0.38, 0.42),
						Size = UDim2.fromScale(0.58, 0.24),
						TextXAlignment = Enum.TextXAlignment.Left,
						TextWrapped = true,
						TextColor3 = Theme.WoodDark,
						Font = Enum.Font.Gotham,
						Visible = unlocked,
					}),
					label(scope, scope:Computed(function(use)
						return if use(selected) then "No cardápio" else "Fora"
					end), {
						Position = UDim2.fromScale(0.38, 0.7),
						Size = UDim2.fromScale(0.58, 0.2),
						TextXAlignment = Enum.TextXAlignment.Left,
						TextColor3 = scope:Computed(function(use)
							return if use(selected) then Theme.SageDark else Theme.Rose
						end),
						Visible = unlocked,
					}),
					label(scope, `Nível {d.Level}`, {
						Position = UDim2.fromScale(0.1, 0.35),
						Size = UDim2.fromScale(0.8, 0.3),
						TextColor3 = Theme.WoodDark,
						Visible = scope:Computed(function(use)
							return not use(unlocked)
						end),
					}),
				},
				[OnEvent("Activated")] = function()
					if not peek(unlocked) then
						return
					end
					local list = table.clone(peek(selection) :: { string })
					local at = table.find(list, id)
					local minimum = math.min(Progression.MinMenu, #Progression.drinksForLevel(peek(State.Level)))
					if at then
						if #list <= minimum then
							return
						end
						table.remove(list, at)
					else
						table.insert(list, id)
					end
					selection:set(list)
					if PrepScreen.onSetMenu then
						PrepScreen.onSetMenu(list)
					end
				end,
			})
		)
	end
	return cards
end

function PrepScreen.close(onClosed: () -> ())
	if closeCurrent then
		closeCurrent(onClosed)
	else
		onClosed()
	end
end

function PrepScreen.show(onOpen: () -> (), initialTab: string?)
	local scope = Fusion.scoped(Fusion)
	local tab = scope:Value(initialTab or "Upgrades")
	local selection = scope:Value(table.clone(peek(State.Menu) :: { string }))

	local pages = {
		Upgrades = upgradeCards(scope),
		Pastries = pastryCards(scope),
		Decor = decorCards(scope),
		Menu = menuCards(scope, selection),
	}

	local tabButtons = {}
	for i, t in TABS do
		table.insert(
			tabButtons,
			scope:New("TextButton")({
				Name = t.Id,
				LayoutOrder = i,
				Size = UDim2.fromScale(0.23, 1),
				-- cardápio só aparece quando há escolha de verdade (novato não precisa)
				Visible = if t.Id == "Menu"
					then scope:Computed(function(use)
						return #Progression.drinksForLevel(use(State.Level)) > Progression.MinMenu
					end)
					else true,
				BackgroundColor3 = scope:Computed(function(use)
					return if use(tab) == t.Id then Theme.Paper else Theme.WoodDark
				end),
				Font = Theme.Font,
				TextScaled = true,
				TextColor3 = scope:Computed(function(use)
					return if use(tab) == t.Id then Theme.Ink else Theme.Paper
				end),
				Text = t.Name,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0.3, 0) }),
					scope:New("UIStroke")({ Thickness = 3, Color = Theme.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
					scope:New("UIPadding")({ PaddingTop = UDim.new(0.2, 0), PaddingBottom = UDim.new(0.2, 0) }),
				},
				[OnEvent("Activated")] = function()
					tab:set(t.Id)
				end,
			})
		)
	end

	local function page(id: string, cellHeight: number): Frame
		return scope:New("ScrollingFrame")({
			Name = id,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ScrollBarThickness = 8,
			ScrollBarImageColor3 = Theme.WoodDark,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			Visible = scope:Computed(function(use)
				return use(tab) == id
			end),
			[Children] = {
				scope:New("UIGridLayout")({
					CellSize = UDim2.new(0.32, 0, 0, cellHeight),
					CellPadding = UDim2.new(0.015, 0, 0, 12),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				scope:New("UIPadding")({
					PaddingTop = UDim.new(0, 6),
					PaddingLeft = UDim.new(0, 6),
					PaddingRight = UDim.new(0, 14),
					PaddingBottom = UDim.new(0, 6),
				}),
				pages[id],
			},
		})
	end

	local coin = PixelArt.draw(Sprites.Coin)
	coin.AnchorPoint = Vector2.new(0, 0.5)
	coin.Position = UDim2.fromScale(0.04, 0.5)
	coin.Size = UDim2.fromScale(0.7, 0.7)
	coin.SizeConstraint = Enum.SizeConstraint.RelativeYY

	local cozyArt = PixelArt.draw(Sprites.Heart)
	cozyArt.AnchorPoint = Vector2.new(0, 0.5)
	cozyArt.Position = UDim2.fromScale(0.04, 0.5)
	cozyArt.Size = UDim2.fromScale(0.6, 0.6)
	cozyArt.SizeConstraint = Enum.SizeConstraint.RelativeYY

	local openButton = scope:New("TextButton")({
		Name = "Open",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromScale(0.3, 0.9),
		BackgroundColor3 = Theme.SageDark,
		Font = Theme.Font,
		TextScaled = true,
		TextColor3 = Theme.Paper,
		Text = "Abrir o café!  >",
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0.3, 0) }),
			scope:New("UIStroke")({ Thickness = 3, Color = Theme.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			scope:New("UIPadding")({ PaddingTop = UDim.new(0.2, 0), PaddingBottom = UDim.new(0.2, 0) }),
		},
	})

	local card = scope:New("Frame")({
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 1.6),
		Size = UDim2.fromScale(0.86, 0.88),
		BackgroundColor3 = Theme.Wood,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 16) }),
			scope:New("UIStroke")({ Thickness = 4, Color = Theme.Ink }),
			scope:New("UISizeConstraint")({ MaxSize = Vector2.new(1200, 800) }),
			scope:New("Frame")({
				Name = "Inner",
				Position = UDim2.fromOffset(12, 12),
				Size = UDim2.new(1, -24, 1, -24),
				BackgroundColor3 = Theme.WoodLight,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 12) }),
					scope:New("UIPadding")({
						PaddingTop = UDim.new(0.025, 0),
						PaddingBottom = UDim.new(0.025, 0),
						PaddingLeft = UDim.new(0.02, 0),
						PaddingRight = UDim.new(0.02, 0),
					}),
					label(scope, scope:Computed(function(use)
						return `Antes de abrir · Dia {use(State.Day)}`
					end), {
						Size = UDim2.fromScale(0.6, 0.08),
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					label(scope, "Gaste suas moedas e prepare o café de hoje", {
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromScale(1, 0.02),
						Size = UDim2.fromScale(0.4, 0.05),
						TextXAlignment = Enum.TextXAlignment.Right,
						TextColor3 = Theme.WoodDark,
						Visible = scope:Computed(function(use)
							return use(tab) ~= "Decor"
						end),
					}),
					scope:New("TextButton")({
						Name = "Walk",
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.fromScale(0.24, 0.085),
						BackgroundColor3 = Theme.Mustard,
						Font = Theme.Font,
						TextScaled = true,
						TextColor3 = Theme.Ink,
						Text = "ANDAR pelo café",
						Visible = scope:Computed(function(use)
							return use(tab) == "Decor"
						end),
						[Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0.3, 0) }),
							scope:New("UIStroke")({ Thickness = 3, Color = Theme.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
							scope:New("UIPadding")({ PaddingTop = UDim.new(0.2, 0), PaddingBottom = UDim.new(0.2, 0) }),
						},
						[OnEvent("Activated")] = function()
							if PrepScreen.onWalk then
								PrepScreen.onWalk()
							end
						end,
					}),
					scope:New("Frame")({
						Name = "Tabs",
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0, 0.11),
						Size = UDim2.fromScale(1, 0.08),
						[Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								Padding = UDim.new(0.02, 0),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),
							tabButtons,
						},
					}),
					scope:New("Frame")({
						Name = "Content",
						Position = UDim2.fromScale(0, 0.22),
						Size = UDim2.fromScale(1, 0.6),
						BackgroundColor3 = Theme.PaperShade,
						[Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
							scope:New("UIStroke")({ Thickness = 3, Color = Theme.Ink }),
							page("Upgrades", 150),
							page("Pastries", 150),
							page("Decor", 150),
							page("Menu", 120),
							label(scope, scope:Computed(function(use)
								return `{#use(selection)} receitas no cardápio (mínimo {Progression.MinMenu}) · clique para tirar/colocar`
							end), {
								AnchorPoint = Vector2.new(0.5, 1),
								Position = UDim2.new(0.5, 0, 1, 24),
								Size = UDim2.new(1, 0, 0, 20),
								TextColor3 = Theme.Ink,
								Visible = scope:Computed(function(use)
									return use(tab) == "Menu"
								end),
							}),
						},
					}),
					scope:New("Frame")({
						Name = "Footer",
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0, 0.9),
						Size = UDim2.fromScale(1, 0.1),
						[Children] = {
							scope:New("Frame")({
								Name = "Money",
								BackgroundColor3 = Theme.Paper,
								Size = UDim2.fromScale(0.2, 0.9),
								[Children] = {
									scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
									scope:New("UIStroke")({ Thickness = 3, Color = Theme.Ink }),
									coin,
									label(scope, scope:Computed(function(use)
										return `${use(State.Money)}`
									end), {
										Position = UDim2.fromScale(0.3, 0.18),
										Size = UDim2.fromScale(0.62, 0.64),
										TextXAlignment = Enum.TextXAlignment.Left,
									}),
								},
							}),
							scope:New("Frame")({
								Name = "Cozy",
								BackgroundColor3 = Theme.Paper,
								Position = UDim2.fromScale(0.22, 0),
								Size = UDim2.fromScale(0.34, 0.9),
								[Children] = {
									scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
									scope:New("UIStroke")({ Thickness = 3, Color = Theme.Ink }),
									cozyArt,
									label(scope, scope:Computed(function(use)
										local c = use(State.Cozy)
										return `Aconchego {c}  (+{math.floor(c * Catalog.CozyBonus * 100 + 0.5)}% nos pagamentos)`
									end), {
										Position = UDim2.fromScale(0.16, 0.22),
										Size = UDim2.fromScale(0.8, 0.56),
										TextXAlignment = Enum.TextXAlignment.Left,
									}),
								},
							}),
							scope:New("TextButton")({
								Name = "Book",
								[Fusion.Attribute("ClickSound")] = "BookOpen",
								Position = UDim2.fromScale(0.58, 0),
								Size = UDim2.fromScale(0.1, 0.9),
								BackgroundColor3 = Theme.Paper,
								Text = "",
								[Children] = {
									scope:New("UICorner")({ CornerRadius = UDim.new(0.3, 0) }),
									scope:New("UIStroke")({ Thickness = 3, Color = Theme.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
									icon("Book"),
								},
								[OnEvent("Activated")] = function()
									if PrepScreen.onOpenBook then
										PrepScreen.onOpenBook()
									end
								end,
							}),
							openButton,
						},
					}),
				},
			}),
		},
	})

	local gui = scope:New("ScreenGui")({
		Name = "PrepScreen",
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

	TweenService:Create(card, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, 0.5),
	}):Play()

	local closed = false
	local function close(after: () -> ())
		if closed then
			return
		end
		closed = true
		closeCurrent = nil
		local dim = gui:FindFirstChild("Dim") :: Frame
		TweenService:Create(dim, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
		local t = TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Position = UDim2.fromScale(0.5, 1.6),
		})
		t.Completed:Once(function()
			gui:Destroy()
			Fusion.doCleanup(scope)
		end)
		t:Play()
		task.delay(0.25, after)
	end
	closeCurrent = close
	openButton.Activated:Connect(function()
		close(onOpen)
	end)
end

return PrepScreen
