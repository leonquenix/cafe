--!strict
-- Pop-up das cores das paredes: a câmera olha a loja por dentro e o painel embaixo troca a cor ao vivo.
-- As setinhas passam pelas cores (só prévia); o botão compra o kit de tintas (libera todas), põe em uso
-- ou mostra "Em uso". Mesmo visual do pop-up de temas da fachada (painel 70% transparente).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Layout = require(ReplicatedStorage.Shared.Layout)
local PixelArt = require(script.Parent.Parent.Art.PixelArt)
local Sprites = require(script.Parent.Parent.Art.Sprites)
local Sfx = require(script.Parent.Parent.Sfx)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Theme)

local Children, OnEvent, peek = Fusion.Children, Fusion.OnEvent, Fusion.peek

local WallPicker = {}

-- de onde a câmera olha as paredes enquanto o pop-up está aberto (o painel cobre a parte de baixo da tela)
WallPicker.CameraPosition = Vector3.new(-1, 9, Layout.Room.MaxZ - 3)
WallPicker.CameraTarget = Vector3.new(-1, 5.2, Layout.Room.MinZ)
WallPicker.FieldOfView = 78

export type Options = {
	OnPreview: (id: string) -> (), -- pintar as paredes com esta cor
	OnBuy: (id: string) -> (),
	OnUse: (id: string) -> (),
	OnClose: () -> (),
}

local playerGui: PlayerGui
local isOpen = false

function WallPicker.init(gui: PlayerGui)
	playerGui = gui
end

function WallPicker.show(options: Options)
	if isOpen then
		return
	end
	isOpen = true
	local scope = Fusion.scoped(Fusion)
	local order = Catalog.WallColorOrder
	local kit = Catalog.WallPaint
	local index = scope:Value(table.find(order, peek(State.WallColor) :: string) or 1)
	local selected = scope:Computed(function(use)
		return order[use(index)]
	end)

	-- Using = em uso · Owned = dá pra usar · Level/Poor = falta nível/moeda · Buy = dá pra comprar
	local status = scope:Computed(function(use)
		local id = use(selected)
		if use(State.WallColor) == id then
			return "Using"
		elseif id == Catalog.DefaultWallColor or use(State.WallPaint) then
			return "Owned"
		elseif use(State.Level) < kit.Level then
			return "Level"
		elseif use(State.Money) < kit.Cost then
			return "Poor"
		end
		return "Buy"
	end)

	local function label(text: any, props: { [string]: any }): TextLabel
		props.BackgroundTransparency = 1
		props.Font = props.Font or Theme.Font
		props.TextScaled = true
		props.TextColor3 = props.TextColor3 or Theme.Ink
		-- contorno claro: o painel é translúcido, o texto precisa continuar legível em cima da cena
		props.TextStrokeColor3 = Theme.Paper
		props.TextStrokeTransparency = 0
		props.Text = text
		return scope:New("TextLabel")(props)
	end

	local function button(name: string, text: any, props: { [string]: any }): TextButton
		props.Name = name
		props.Font = Theme.Font
		props.TextScaled = true
		props.Text = text
		props[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0.3, 0) }),
			scope:New("UIStroke")({ Thickness = 3, Color = Theme.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			scope:New("UIPadding")({ PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.18, 0) }),
		}
		return scope:New("TextButton")(props) :: TextButton
	end

	local function step(delta: number)
		local i = (peek(index) :: number) + delta
		if i < 1 then
			i = #order
		elseif i > #order then
			i = 1
		end
		index:set(i)
		options.OnPreview(order[i])
	end

	-- amostra: um pedacinho de parede (faixa de cima, reboco e lambri de madeira) com a cor escolhida
	local wall = scope:Computed(function(use)
		return Catalog.WallColors[use(selected)]
	end)
	local iconHolder = scope:New("Frame")({
		Name = "Icon",
		BackgroundColor3 = scope:Computed(function(use)
			return use(wall).Plaster
		end),
		ClipsDescendants = true,
		Position = UDim2.fromScale(0.1, 0.1),
		Size = UDim2.fromScale(0.5, 0.5),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0.15, 0) }),
			scope:New("UIStroke")({ Thickness = 3, Color = Theme.Ink }),
			scope:New("Frame")({
				Name = "Shade",
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 0.16),
				BackgroundColor3 = scope:Computed(function(use)
					return use(wall).Shade
				end),
			}),
			scope:New("Frame")({
				Name = "Trim",
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0, 0.66),
				Size = UDim2.fromScale(1, 0.05),
				BackgroundColor3 = Color3.fromRGB(250, 242, 226),
			}),
			scope:New("Frame")({
				Name = "Wainscot",
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0, 0.71),
				Size = UDim2.fromScale(1, 0.29),
				BackgroundColor3 = Color3.fromRGB(140, 92, 60),
			}),
		},
	}) :: Frame
	-- quadrinho pendurado, pra dar escala
	local frameArt = PixelArt.draw(Sprites.Painting)
	frameArt.AnchorPoint = Vector2.new(0.5, 0.5)
	frameArt.Position = UDim2.fromScale(0.5, 0.42)
	frameArt.Size = UDim2.fromScale(0.42, 0.42)
	frameArt.Parent = iconHolder

	local confirm = button(
		"Confirm",
		scope:Computed(function(use)
			local s = use(status)
			if s == "Using" then
				return "Em uso"
			elseif s == "Owned" then
				return "Usar esta cor"
			elseif s == "Level" then
				return `Nível {kit.Level}`
			elseif s == "Poor" then
				return `${kit.Cost}`
			end
			return `Comprar  ${kit.Cost}`
		end),
		{
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.72, 0.93),
			Size = UDim2.fromScale(0.4, 0.27),
			BackgroundColor3 = scope:Computed(function(use)
				local s = use(status)
				return if s == "Owned" or s == "Buy" then Theme.SageDark else Theme.PaperShade
			end),
			TextColor3 = scope:Computed(function(use)
				local s = use(status)
				return if s == "Owned" or s == "Buy" then Theme.Paper else Theme.WoodDark
			end),
		}
	)
	-- cada resultado tem seu som (caixa registradora, pop ou negação)
	confirm:SetAttribute("NoClickSound", true)
	local back = button("Back", "Voltar", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.28, 0.93),
		Size = UDim2.fromScale(0.4, 0.27),
		BackgroundColor3 = Theme.PaperShade,
		TextColor3 = Theme.Ink,
	})

	local function arrow(name: string, text: string, x: number, delta: number): TextButton
		return button(name, text, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, 0.34),
			Size = UDim2.fromScale(0.07, 0.34),
			BackgroundColor3 = Theme.Mustard,
			TextColor3 = Theme.Ink,
			[OnEvent("Activated")] = function()
				step(delta)
			end,
		})
	end

	local coin = PixelArt.draw(Sprites.Coin)
	coin.AnchorPoint = Vector2.new(0, 0.5)
	coin.Position = UDim2.fromScale(0.06, 0.5)
	coin.Size = UDim2.fromScale(0.7, 0.7)
	coin.SizeConstraint = Enum.SizeConstraint.RelativeYY

	local card = scope:New("Frame")({
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1.6),
		Size = UDim2.fromScale(0.62, 0.3),
		-- painel 70% transparente pra não esconder a fachada; botões, textos e o ícone continuam opacos
		BackgroundColor3 = Theme.Paper,
		BackgroundTransparency = 0.7,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 16) }),
			scope:New("UIStroke")({ Thickness = 4, Color = Theme.Ink, Transparency = 0.7 }),
			scope:New("UIAspectRatioConstraint")({ AspectRatio = 3.1 }),
			scope:New("UISizeConstraint")({ MaxSize = Vector2.new(820, 265) }),
			arrow("Prev", "<", 0.05, -1),
			arrow("Next", ">", 0.95, 1),
			iconHolder,
			label(scope:Computed(function(use)
				return use(wall).Name
			end), {
				Name = "Title",
				Position = UDim2.fromScale(0.29, 0.08),
				Size = UDim2.fromScale(0.55, 0.2),
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			label(scope:Computed(function(use)
				return use(wall).Description
			end), {
				Name = "Description",
				Position = UDim2.fromScale(0.29, 0.3),
				Size = UDim2.fromScale(0.6, 0.14),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Theme.WoodDark,
				Font = Enum.Font.Gotham,
			}),
			label(scope:Computed(function(use)
				local s = use(status)
				if s == "Using" then
					return "Cor da sua loja agora"
				elseif s == "Owned" then
					return if use(selected) == Catalog.DefaultWallColor then "Grátis · sempre sua" else "Já é sua: troque quando quiser"
				elseif s == "Level" then
					return `Libera no nível {kit.Level}`
				end
				return `Uma compra libera todas · {use(index)}/{#order}`
			end), {
				Name = "Status",
				Position = UDim2.fromScale(0.29, 0.47),
				Size = UDim2.fromScale(0.6, 0.12),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = scope:Computed(function(use)
					local s = use(status)
					return if s == "Using" or s == "Owned" then Theme.SageDark else Theme.WoodDark
				end),
			}),
			scope:New("Frame")({
				Name = "Money",
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, 0, 0, -10),
				Size = UDim2.fromScale(0.2, 0.2),
				BackgroundColor3 = Theme.Paper,
				BackgroundTransparency = 0.7,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					scope:New("UIStroke")({ Thickness = 3, Color = Theme.Ink, Transparency = 0.7 }),
					coin,
					label(scope:Computed(function(use)
						return `${use(State.Money)}`
					end), {
						Position = UDim2.fromScale(0.32, 0.18),
						Size = UDim2.fromScale(0.6, 0.64),
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
				},
			}),
			back,
			confirm,
		},
	})

	local gui = scope:New("ScreenGui")({
		Name = "WallPicker",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 25,
		Parent = playerGui,
		[Children] = { card },
	}) :: ScreenGui

	TweenService:Create(card, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, 0.97),
	}):Play()

	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		local t = TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Position = UDim2.fromScale(0.5, 1.6),
		})
		t.Completed:Once(function()
			gui:Destroy()
			Fusion.doCleanup(scope)
			isOpen = false
		end)
		t:Play()
		options.OnClose()
	end
	back.Activated:Connect(close)
	confirm.Activated:Connect(function()
		local s = peek(status)
		local id = peek(selected) :: string
		if s == "Buy" then
			options.OnBuy(id)
		elseif s == "Owned" then
			Sfx.play("CutePop")
			options.OnUse(id)
		else
			Sfx.play("Denied")
		end
	end)
	Sfx.play("CutePop")
	options.OnPreview(peek(selected) :: string)
end

return WallPicker
