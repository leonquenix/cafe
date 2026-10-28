--!strict
-- HUD do topo (centralizado): dinheiro e livro de receitas (com o rádio logo abaixo). Também mostra o "+$" ao entregar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Recipes = require(ReplicatedStorage.Shared.Recipes)
local PixelArt = require(script.Parent.Parent.Art.PixelArt)
local Sprites = require(script.Parent.Parent.Art.Sprites)
local Sfx = require(script.Parent.Parent.Sfx)
local State = require(script.Parent.Parent.State)
local Radio = require(script.Parent.Radio)
local Theme = require(script.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

local Hud = {}

-- largura natural da fileira do topo (pílula 160, livro 52, 1 espaço de 14)
local TOP_WIDTH = 160 + 52 + 14
-- a bancada do preparo (Minigame) ocupa a direita: 38% da tela, no máximo 560, a 16 da borda
local BENCH_FRACTION, BENCH_MAX, BENCH_MARGIN = 0.38, 560, 16

local gui: ScreenGui
local moneyPill: Frame
local moneyPop: UIScale

local function pill(scope: any, name: string, width: number, order: number, children: { any }): Frame
	return scope:New("Frame")({
		Name = name,
		LayoutOrder = order,
		BackgroundColor3 = Theme.Paper,
		Size = UDim2.new(0, width, 1, 0),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			scope:New("UIStroke")({ Thickness = 3, Color = Theme.Ink }),
			children,
		},
	})
end

Hud.onOpenBook = nil :: (() -> ())?

function Hud.new(playerGui: PlayerGui)
	local scope = State.scope

	local shownMoney = scope:Spring(State.Money, 8, 1)
	moneyPop = scope:New("UIScale")({ Scale = 1 }) :: UIScale

	local coin = PixelArt.draw(Sprites.Coin)
	coin.AnchorPoint = Vector2.new(0, 0.5)
	coin.Position = UDim2.new(0, 8, 0.5, 0)
	coin.Size = UDim2.fromScale(0.7, 0.7)
	coin.SizeConstraint = Enum.SizeConstraint.RelativeYY

	moneyPill = pill(scope, "Money", 160, 1, {
		moneyPop,
		coin,
		scope:New("TextLabel")({
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 52, 0.18, 0),
			Size = UDim2.new(1, -64, 0.64, 0),
			Font = Theme.Font,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Theme.Ink,
			Text = scope:Computed(function(use)
				return `${math.floor(use(shownMoney) + 0.5)}`
			end),
		}),
	})

	-- botão do livro de receitas
	local bookArt = PixelArt.draw(Sprites.Book)
	bookArt.Size = UDim2.fromScale(0.7, 0.7)
	local bookButton = scope:New("TextButton")({
		Name = "Book",
		LayoutOrder = 2,
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = Theme.Paper,
		Size = UDim2.fromScale(1, 1),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0.3, 0) }),
			scope:New("UIStroke")({ Thickness = 3, Color = Theme.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			bookArt,
			-- bolinha de alerta: tem recompensa de maestria para coletar
			scope:New("Frame")({
				Name = "Alert",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.9, 0.1),
				Size = UDim2.fromScale(0.36, 0.36),
				BackgroundColor3 = Theme.Rose,
				ZIndex = 3,
				Visible = scope:Computed(function(use)
					local stats, mastered = use(State.Stats), use(State.Mastered)
					for id in Recipes.Drinks do
						if not mastered[id] and (stats[id] or 0) >= Recipes.masteryTarget(id) then
							return true
						end
					end
					return false
				end),
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					scope:New("UIStroke")({ Thickness = 2, Color = Theme.Ink }),
					scope:New("TextLabel")({
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 1),
						Font = Theme.Font,
						TextScaled = true,
						TextColor3 = Theme.Paper,
						Text = "!",
						ZIndex = 4,
					}),
				},
			}),
		},
		[OnEvent("Activated")] = function()
			if Hud.onOpenBook then
				Hud.onOpenBook()
			end
		end,
	})

	-- botão do rádio: logo abaixo do livro (acompanha o encolhimento da fileira)
	local radioArt = PixelArt.draw(Sprites.Radio)
	radioArt.Size = UDim2.fromScale(0.72, 0.6)
	radioArt.AnchorPoint = Vector2.new(0.5, 0.5)
	radioArt.Position = UDim2.fromScale(0.5, 0.5)
	local radioButton = scope:New("TextButton")({
		Name = "Radio",
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = Theme.Paper,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 10),
		Size = UDim2.fromScale(0.85, 0.85),
		Parent = bookButton,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0.3, 0) }),
			scope:New("UIStroke")({ Thickness = 3, Color = Theme.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			radioArt,
		},
		[OnEvent("Activated")] = function()
			Radio.toggle()
		end,
	})

	-- encolhe a fileira se não couber antes da bancada (celular pequeno)
	local fit = scope:New("UIScale")({ Scale = 1 }) :: UIScale

	-- no topo da tela (altura original), centralizado entre os botões do Roblox e fora do entalhe do celular
	gui = scope:New("ScreenGui")({
		Name = "CafeHud",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		DisplayOrder = 2,
		Parent = playerGui,
		[Children] = {
			scope:New("Frame")({
				Name = "Top",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 18),
				Size = UDim2.fromOffset(TOP_WIDTH, 52),
				Visible = State.Loaded,
				[Children] = {
					fit,
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0, 14),
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
					moneyPill,
					bookButton,
				},
			}),
		},
	}) :: ScreenGui

	Radio.attach(gui, radioButton)

	local top = gui:FindFirstChild("Top") :: Frame
	local function refit()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local width = camera.ViewportSize.X
		local benchLeft = width - BENCH_MARGIN - math.min(width * BENCH_FRACTION, BENCH_MAX)
		local limit = benchLeft - 12 - gui.AbsolutePosition.X
		local scale = math.clamp((limit - 16) / TOP_WIDTH, 0.4, 1)
		fit.Scale = scale
		-- centralizado na tela; se a borda direita encostar na bancada, desliza para a esquerda
		local half = TOP_WIDTH * scale / 2
		local shift = math.min(0, limit - (gui.AbsoluteSize.X / 2 + half))
		top.Position = UDim2.new(0.5, shift, 0, 18)
	end
	refit()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
	gui:GetPropertyChangedSignal("AbsolutePosition"):Connect(refit)
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(refit)
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(refit)
	end
end

-- "+$18 Relâmpago!" subindo e moedinhas voando até o contador
function Hud.payout(earned: number, tier: number, tip: number?)
	local rng = Random.new()
	if earned + (tip or 0) > 0 then
		-- dinheiro do cliente entrando no caixa
		Sfx.play("Coins")
	end
	local origin = UDim2.fromScale(0.31, 0.36)

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = origin
	label.Size = UDim2.fromOffset(260, 64)
	label.Font = Theme.Font
	label.TextScaled = true
	label.Text = `+${earned + (tip or 0)}`
	label.TextColor3 = Theme.Mustard
	label.ZIndex = 10
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Theme.Ink
	stroke.Parent = label
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = label
	label.Parent = gui

	local sub = label:Clone()
	sub.Text = (Progression.TierNames[tier] or "") .. (if tip and tip > 0 then `  +${tip} gorjeta` else "")
	sub.TextColor3 = Theme.Paper
	sub.Size = UDim2.fromOffset(300, 34)
	sub.Position = origin + UDim2.fromOffset(0, 48)
	sub.Parent = gui

	for _, l in { label, sub } do
		local s = l:FindFirstChildOfClass("UIScale") :: UIScale
		TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		task.delay(1.1, function()
			local t = TweenService:Create(l, TweenInfo.new(0.5), {
				Position = l.Position - UDim2.fromOffset(0, 40),
				TextTransparency = 1,
			})
			TweenService:Create(l:FindFirstChildOfClass("UIStroke") :: UIStroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
			t.Completed:Once(function()
				l:Destroy()
			end)
			t:Play()
		end)
	end

	-- moedas voando até a pílula de dinheiro
	local target = moneyPill.AbsolutePosition + Vector2.new(24, moneyPill.AbsoluteSize.Y / 2)
	local count = math.clamp(math.floor((earned + (tip or 0)) / 4), 3, 10)
	for i = 1, count do
		task.delay(0.25 + i * 0.06, function()
			local c = PixelArt.draw(Sprites.Coin, 11)
			c.AnchorPoint = Vector2.new(0.5, 0.5)
			c.Size = UDim2.fromOffset(26, 26)
			c.Position = origin + UDim2.fromOffset(rng:NextInteger(-60, 60), rng:NextInteger(-20, 30))
			c.Parent = gui
			local t = TweenService:Create(c, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.fromOffset(target.X, target.Y),
				Size = UDim2.fromOffset(16, 16),
			})
			t.Completed:Once(function()
				c:Destroy()
				moneyPop.Scale = 1.12
				TweenService:Create(moneyPop, TweenInfo.new(0.2), { Scale = 1 }):Play()
			end)
			t:Play()
		end)
	end
end

-- Mensagem rápida no meio-topo da tela ("O cliente desistiu...")
function Hud.toast(text: string, color: Color3?)
	local label = Theme.label(text, color or Theme.Paper)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.31, 0.3)
	label.Size = UDim2.fromOffset(420, 40)
	label.ZIndex = 10
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Theme.Ink
	stroke.Parent = label
	label.Parent = gui
	local t = TweenService:Create(label, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 1.4), {
		Position = label.Position - UDim2.fromOffset(0, 30),
		TextTransparency = 1,
	})
	TweenService:Create(stroke, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 1.4), { Transparency = 1 }):Play()
	t.Completed:Once(function()
		label:Destroy()
	end)
	t:Play()
end

function Hud.setVisible(visible: boolean)
	if gui then
		gui.Enabled = visible
	end
end

return Hud
