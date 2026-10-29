--!strict
-- Pop-up dos temas da fachada: a câmera fica lá fora olhando a loja e o painel embaixo troca o tema ao vivo.
-- As setinhas passam pelos temas (só prévia); o botão compra, põe em uso ou mostra "Em uso".

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

local ThemePicker = {}

-- de onde a câmera olha a fachada enquanto o pop-up está aberto (o painel cobre a parte de baixo da tela)
ThemePicker.CameraPosition = Vector3.new(Layout.DoorX + 1, 6, Layout.Room.MinZ - 30)
ThemePicker.CameraTarget = Vector3.new(Layout.DoorX + 1, 8.5, Layout.Room.MinZ)
ThemePicker.FieldOfView = 66

export type Options = {
	OnPreview: (id: string) -> (), -- mostrar este tema lá fora
	OnBuy: (id: string) -> (),
	OnUse: (id: string) -> (),
	OnClose: () -> (),
}

local playerGui: PlayerGui
local isOpen = false

function ThemePicker.init(gui: PlayerGui)
	playerGui = gui
end

function ThemePicker.show(options: Options)
	if isOpen then
		return
	end
	isOpen = true
	local scope = Fusion.scoped(Fusion)
	local order = Catalog.ThemeOrder
	local index = scope:Value(table.find(order, peek(State.Theme) :: string) or 1)
	local selected = scope:Computed(function(use)
		return order[use(index)]
	end)

	-- Using = em uso · Owned = dá pra usar · Level/Poor = falta nível/moeda · Buy = dá pra comprar
	local status = scope:Computed(function(use)
		local id = use(selected)
		local th = Catalog.Themes[id]
		if use(State.Theme) == id then
			return "Using"
		elseif th.Cost == 0 or use(State.Themes)[id] then
			return "Owned"
		elseif use(State.Level) < th.Level then
			return "Level"
		elseif use(State.Money) < th.Cost then
			return "Poor"
		end
		return "Buy"
	end)

	local function label(text: any, props: { [string]: any }): TextLabel
		props.BackgroundTransparency = 1
		props.Font = props.Font or Theme.Font
		props.TextScaled = true
		props.TextColor3 = props.TextColor3 or Theme.Ink
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

	local iconHolder = scope:New("Frame")({
		Name = "Icon",
		BackgroundColor3 = Theme.PaperShade,
		Position = UDim2.fromScale(0.1, 0.1),
		Size = UDim2.fromScale(0.5, 0.5),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0.15, 0) }),
			scope:New("UIStroke")({ Thickness = 3, Color = Theme.Ink }),
		},
	}) :: Frame
	local art: Frame? = nil
	local function drawIcon()
		if art then
			art:Destroy()
		end
		local a = PixelArt.draw((Sprites :: any)[Catalog.Themes[peek(selected) :: string].Icon])
		a.Size = UDim2.fromScale(0.78, 0.78)
		a.Parent = iconHolder
		art = a
	end
	drawIcon()
	scope:Observer(selected):onChange(drawIcon)

	local confirm = button(
		"Confirm",
		scope:Computed(function(use)
			local s = use(status)
			local th = Catalog.Themes[use(selected)]
			if s == "Using" then
				return "Em uso"
			elseif s == "Owned" then
				return "Usar este tema"
			elseif s == "Level" then
				return `Nível {th.Level}`
			elseif s == "Poor" then
				return `${th.Cost}`
			end
			return `Comprar  ${th.Cost}`
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
		BackgroundColor3 = Theme.Paper,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 16) }),
			scope:New("UIStroke")({ Thickness = 4, Color = Theme.Ink }),
			scope:New("UIAspectRatioConstraint")({ AspectRatio = 3.1 }),
			scope:New("UISizeConstraint")({ MaxSize = Vector2.new(820, 265) }),
			arrow("Prev", "<", 0.05, -1),
			arrow("Next", ">", 0.95, 1),
			iconHolder,
			label(scope:Computed(function(use)
				return Catalog.Themes[use(selected)].Name
			end), {
				Name = "Title",
				Position = UDim2.fromScale(0.29, 0.08),
				Size = UDim2.fromScale(0.55, 0.2),
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			label(scope:Computed(function(use)
				return Catalog.Themes[use(selected)].Description
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
				local th = Catalog.Themes[use(selected)]
				if s == "Using" then
					return "Tema da sua loja agora"
				elseif s == "Owned" then
					return if th.Cost == 0 then "Grátis · sempre seu" else "Já é seu: troque quando quiser"
				elseif s == "Level" then
					return `Libera no nível {th.Level}`
				end
				return `Só visual · {use(index)}/{#order}`
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
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					scope:New("UIStroke")({ Thickness = 3, Color = Theme.Ink }),
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
		Name = "ThemePicker",
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

return ThemePicker
