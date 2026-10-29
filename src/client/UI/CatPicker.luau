--!strict
-- Pop-up do gatinho da vitrine: prévia 3D do gato e quadradinhos com as pelagens.
-- Clicar numa cor troca a prévia; o nome da cor aparece com o cursor em cima (no celular, ao tocar).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Decor = require(script.Parent.Parent.Decor)
local Sfx = require(script.Parent.Parent.Sfx)
local Theme = require(script.Parent.Theme)

local Children, OnEvent, peek = Fusion.Children, Fusion.OnEvent, Fusion.peek

local CatPicker = {}

export type Options = {
	Owned: boolean, -- já comprado: só troca a cor (de graça)
	Cost: number,
	Current: string, -- pelagem que já vem marcada
	OnConfirm: (color: string) -> (),
}

local playerGui: PlayerGui
local isOpen = false

function CatPicker.init(gui: PlayerGui)
	playerGui = gui
end

-- quadradinho da cor: faixas verticais, cada uma com suas cores de cima pra baixo
local function swatchArt(scope: any, coatId: string): { Frame }
	local bands = Decor.CatCoats[coatId].Swatch
	local out = {}
	for i, colors in bands do
		local cells = {}
		for j, color in colors do
			table.insert(
				cells,
				scope:New("Frame")({
					BorderSizePixel = 0,
					BackgroundColor3 = color,
					Position = UDim2.fromScale(0, (j - 1) / #colors),
					Size = UDim2.fromScale(1, 1 / #colors),
				})
			)
		end
		table.insert(
			out,
			scope:New("Frame")({
				BorderSizePixel = 0,
				BackgroundTransparency = 1,
				Position = UDim2.fromScale((i - 1) / #bands, 0),
				Size = UDim2.fromScale(1 / #bands, 1),
				[Children] = cells,
			})
		)
	end
	return out
end

function CatPicker.show(options: Options)
	if isOpen then
		return
	end
	isOpen = true
	local scope = Fusion.scoped(Fusion)
	local selected = scope:Value(if Decor.CatCoats[options.Current] then options.Current else Catalog.DefaultCatColor)
	local hovered = scope:Value(nil :: string?)

	-- prévia: o gatinho de verdade (mesmas peças do balcão) num ViewportFrame, respirando
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	local worldModel = Instance.new("WorldModel")
	local viewport = scope:New("ViewportFrame")({
		Name = "Preview",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.15),
		Size = UDim2.fromScale(0.9, 0.42),
		BackgroundColor3 = Theme.PaperShade,
		CurrentCamera = camera,
		Ambient = Color3.fromRGB(190, 180, 170),
		LightColor = Color3.fromRGB(255, 244, 230),
		LightDirection = Vector3.new(-0.4, -1, -0.6),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 12) }),
			scope:New("UIStroke")({ Thickness = 3, Color = Theme.Ink }),
		},
	}) :: ViewportFrame
	camera.Parent = viewport
	worldModel.Parent = viewport

	local model: Model? = nil
	local animate: ((t: number) -> ())? = nil
	local function showCoat(coatId: string)
		if model then
			model:Destroy()
		end
		local m, fn, face = Decor.catPreview(coatId)
		m.Parent = worldModel
		model, animate = m, fn
		local box, size = m:GetBoundingBox()
		local center = box.Position
		-- de frente e um pouquinho de cima, enquadrando o gato inteiro
		local target = center:Lerp(face, 0.25)
		local distance = math.max(size.X, size.Y) * 2.1
		camera.CFrame = CFrame.lookAt(target + Vector3.new(0.6, 0.9, 1).Unit * distance, target)
	end
	showCoat(peek(selected))
	local breathing = RunService.RenderStepped:Connect(function()
		if animate then
			animate(os.clock())
		end
	end)
	scope:Observer(selected):onChange(function()
		showCoat(peek(selected))
	end)

	-- nome da cor: a que está sob o cursor (ou a tocada por último no celular)
	local touchToken = 0
	local swatches = {}
	for i, id in Catalog.CatColorOrder do
		local isSelected = scope:Computed(function(use)
			return use(selected) == id
		end)
		table.insert(
			swatches,
			scope:New("TextButton")({
				Name = id,
				LayoutOrder = i,
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = Theme.Paper,
				Size = UDim2.fromScale(1, 1),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0.18, 0) }),
					scope:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Thickness = scope:Computed(function(use)
							return if use(isSelected) then 5 else 3
						end),
						Color = scope:Computed(function(use)
							return if use(isSelected) then Theme.SageDark else Theme.Ink
						end),
					}),
					scope:New("Frame")({
						Name = "Fur",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(0.78, 0.78),
						BackgroundTransparency = 1,
						ClipsDescendants = true,
						[Children] = swatchArt(scope, id),
					}),
					-- etiqueta com o nome, em cima do quadradinho
					scope:New("TextLabel")({
						Name = "Tip",
						AnchorPoint = Vector2.new(0.5, 1),
						Position = UDim2.new(0.5, 0, 0, -8),
						Size = UDim2.new(2.4, 0, 0.5, 0),
						BackgroundColor3 = Theme.Ink,
						Font = Theme.Font,
						TextScaled = true,
						TextColor3 = Theme.Paper,
						Text = Catalog.CatColors[id].Name,
						ZIndex = 5,
						Visible = scope:Computed(function(use)
							return use(hovered) == id
						end),
						[Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0.3, 0) }),
							scope:New("UIPadding")({
								PaddingTop = UDim.new(0.15, 0),
								PaddingBottom = UDim.new(0.15, 0),
								PaddingLeft = UDim.new(0.08, 0),
								PaddingRight = UDim.new(0.08, 0),
							}),
						},
					}),
				},
				[OnEvent("MouseEnter")] = function()
					hovered:set(id)
				end,
				[OnEvent("MouseLeave")] = function()
					if peek(hovered) == id then
						hovered:set(nil)
					end
				end,
				[OnEvent("Activated")] = function(input: InputObject?)
					selected:set(id)
					hovered:set(id)
					-- toque não tem "sair de cima": o nome some sozinho depois de um tempinho
					if (input and input.UserInputType == Enum.UserInputType.Touch) or UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
						touchToken += 1
						local token = touchToken
						task.delay(1.6, function()
							if token == touchToken and peek(hovered) == id then
								hovered:set(nil)
							end
						end)
					end
				end,
			})
		)
	end

	local function button(name: string, text: string, color: Color3, textColor: Color3, x: number): TextButton
		return scope:New("TextButton")({
			Name = name,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(x, 0.96),
			Size = UDim2.fromScale(0.4, 0.1),
			BackgroundColor3 = color,
			Font = Theme.Font,
			TextScaled = true,
			TextColor3 = textColor,
			Text = text,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = UDim.new(0.3, 0) }),
				scope:New("UIStroke")({ Thickness = 3, Color = Theme.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
				scope:New("UIPadding")({ PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.18, 0) }),
			},
		}) :: TextButton
	end

	local cancel = button("Cancel", "Voltar", Theme.PaperShade, Theme.Ink, 0.27)
	local confirm = button("Confirm", if options.Owned then "Usar esta cor" else `Comprar  ${options.Cost}`, Theme.SageDark, Theme.Paper, 0.73)
	-- a compra tem som próprio (caixa registradora), não o pop
	confirm:SetAttribute("NoClickSound", not options.Owned)

	local card = scope:New("Frame")({
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 1.6),
		Size = UDim2.fromScale(0.5, 0.82),
		BackgroundColor3 = Theme.Paper,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 16) }),
			scope:New("UIStroke")({ Thickness = 4, Color = Theme.Ink }),
			scope:New("UIAspectRatioConstraint")({ AspectRatio = 0.95 }),
			scope:New("TextLabel")({
				Name = "Title",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.05, 0.03),
				Size = UDim2.fromScale(0.9, 0.09),
				Font = Theme.Font,
				TextScaled = true,
				TextColor3 = Theme.Ink,
				Text = Catalog.Decor.Cat.Name,
			}),
			viewport,
			scope:New("TextLabel")({
				Name = "Prompt",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.05, 0.6),
				Size = UDim2.fromScale(0.9, 0.065),
				Font = Theme.Font,
				TextScaled = true,
				TextColor3 = Theme.Ink,
				Text = "Escolha a cor do seu gatinho:",
			}),
			scope:New("Frame")({
				Name = "Colors",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0.7),
				Size = UDim2.fromScale(0.9, 0.11),
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0.025, 0),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					swatches,
				},
			}),
			cancel,
			confirm,
		},
	})

	local gui = scope:New("ScreenGui")({
		Name = "CatPicker",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 25,
		Parent = playerGui,
		[Children] = {
			scope:New("TextButton")({
				Name = "Dim",
				Text = "",
				AutoButtonColor = false,
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(20, 14, 20),
				BackgroundTransparency = 0.45,
			}),
			card,
		},
	}) :: ScreenGui
	;(gui:FindFirstChild("Dim") :: TextButton):SetAttribute("NoClickSound", true)

	TweenService:Create(card, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, 0.5),
	}):Play()

	local closed = false
	local function close(after: (() -> ())?)
		if closed then
			return
		end
		closed = true
		local dim = gui:FindFirstChild("Dim") :: TextButton
		TweenService:Create(dim, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		local t = TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Position = UDim2.fromScale(0.5, 1.6),
		})
		t.Completed:Once(function()
			breathing:Disconnect()
			gui:Destroy()
			Fusion.doCleanup(scope)
			isOpen = false
		end)
		t:Play()
		if after then
			after()
		end
	end
	cancel.Activated:Connect(function()
		close()
	end)
	confirm.Activated:Connect(function()
		local color = peek(selected) :: string
		close(function()
			options.OnConfirm(color)
		end)
	end)
	Sfx.play("CutePop")
end

return CatPicker
