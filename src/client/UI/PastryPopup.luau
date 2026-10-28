--!strict
-- Pop-up do forno: quando o cliente pede doce, abre no centro da tela ANTES do preparo da bebida.
-- Arrastar o doce pedido até o forno -> o ponteiro corre pela barra -> "Tirar!" na hora certa.
-- Zona verde = perfeito, amarela = ok, começo = cru, fim = queimado.
-- Perfeito ou ok é entregue sozinho e a janela fecha logo depois da mensagem.
-- Cru ou queimado ainda pode ser entregue (paga menos) ou assado de novo pagando (Catalog.retryCost).
-- O X fecha sem o doce: o cliente paga só a bebida.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local PixelArt = require(script.Parent.Parent.Art.PixelArt)
local Sprites = require(script.Parent.Parent.Art.Sprites)
local Pause = require(script.Parent.Parent.Pause)
local Sfx = require(script.Parent.Parent.Sfx)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Theme)

local Children, OnEvent, peek = Fusion.Children, Fusion.OnEvent, Fusion.peek
local Quality = Catalog.PastryQuality

-- zonas da barra (fração do tempo de forno)
local RAW_END = 0.5
local PERFECT_START, PERFECT_END = 0.62, 0.82
local BURN_START = 0.9

local AUTO_DELIVER_DELAY = 0.8 -- tempo para ler "Perfeito!" / "Tá bom!" antes de entregar sozinho

type Status = "idle" | "flying" | "baking" | "done" | "waiting"

local PastryPopup = {}

local scope = Fusion.scoped(Fusion)
local visible = scope:Value(false)
local pastryId = scope:Value("")
local status = scope:Value("idle" :: Status)
local quality = scope:Value(Quality.Skipped)
local needle = scope:Value(0)
local message = scope:Value("")
local bakeStart = 0
local bakeToken = 0 -- muda a cada fornada, invalida entregas automáticas antigas

local finishCallback: ((quality: number) -> ())? = nil
local retryCallback: ((done: (ok: boolean) -> ()) -> ())? = nil

local gui: ScreenGui
local panel: Frame
local ovenFrame: Frame
local tray: Frame
local trayGrid: UIGridLayout
local pastryHolder: Frame

------------------------------------------------------------------ ponteiro

local function pointerPosition(input: InputObject): Vector2
	local inset = GuiService:GetGuiInset()
	return Vector2.new(input.Position.X, input.Position.Y) + inset
end

local function inside(g: GuiObject, p: Vector2, margin: number?): boolean
	local m = margin or 0
	local a, s = g.AbsolutePosition, g.AbsoluteSize
	return p.X >= a.X - m and p.Y >= a.Y - m and p.X <= a.X + s.X + m and p.Y <= a.Y + s.Y + m
end

-- Segue um ponteiro (mouse ou toque) até soltar. No toque escuta também o próprio
-- InputObject e os eventos Touch*, porque no celular nem sempre o InputChanged chega.
local function trackPointer(input: InputObject, onMove: (Vector2) -> (), onEnd: (Vector2) -> ())
	local touch = input.UserInputType == Enum.UserInputType.Touch
	local last = pointerPosition(input)
	local finished = false
	local conns: { RBXScriptConnection } = {}
	local function move(i: InputObject)
		-- a posição do evento de soltar não é confiável no celular: fica a do último movimento
		if not finished and i.UserInputState ~= Enum.UserInputState.End and i.UserInputState ~= Enum.UserInputState.Cancel then
			last = pointerPosition(i)
			onMove(last)
		end
	end
	local function stop()
		if finished then
			return
		end
		finished = true
		for _, c in conns do
			c:Disconnect()
		end
		onEnd(last)
	end
	table.insert(conns, UserInputService.InputChanged:Connect(function(i)
		if i == input or (if touch then i.UserInputType == Enum.UserInputType.Touch else i.UserInputType == Enum.UserInputType.MouseMovement) then
			move(i)
		end
	end))
	table.insert(conns, UserInputService.InputEnded:Connect(function(i)
		if i == input or i.UserInputType == (if touch then Enum.UserInputType.Touch else Enum.UserInputType.MouseButton1) then
			stop()
		end
	end))
	if touch then
		table.insert(conns, UserInputService.TouchMoved:Connect(move))
		table.insert(conns, UserInputService.TouchEnded:Connect(stop))
		table.insert(conns, input.Changed:Connect(function(prop)
			if prop == "Position" then
				move(input)
			elseif prop == "UserInputState" and input.UserInputState ~= Enum.UserInputState.Begin and input.UserInputState ~= Enum.UserInputState.Change then
				stop()
			end
		end))
	end
end

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function tween(inst: Instance, time: number, props: { [string]: any }): Tween
	local t = TweenService:Create(inst, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function shake(g: GuiObject)
	task.spawn(function()
		for _, a in { 4, -3, 2, 0 } do
			tween(g, 0.05, { Rotation = a })
			task.wait(0.05)
		end
	end)
end

------------------------------------------------------------------ forno

local function pastryName(): string
	local id = peek(pastryId)
	return if id ~= "" then Catalog.Pastries[id].Name else ""
end

local function showInOven(id: string?)
	pastryHolder:ClearAllChildren()
	if id then
		PixelArt.draw((Sprites :: any)[Catalog.Pastries[id].Icon], 3).Parent = pastryHolder
	end
end

local close: (q: number) -> ()

local function finish(q: number)
	bakeToken += 1
	-- porta do forno abrindo para tirar o doce
	Sfx.play("OvenOut")
	quality:set(q)
	status:set("done")
	if q == Quality.Perfect then
		message:set("Perfeito!")
	elseif q == Quality.Ok then
		message:set("Tá bom!")
	elseif q == Quality.Raw then
		message:set("Ainda cru... o cliente não vai pagar o doce")
	else
		message:set("Queimou! O cliente não vai pagar o doce")
	end
	shake(panel)
	if not Catalog.isBadPastry(q) then
		local token = bakeToken
		task.delay(AUTO_DELIVER_DELAY, function()
			if token == bakeToken and peek(status) == "done" then
				close(q)
			end
		end)
	end
end

local function startBake()
	showInOven(peek(pastryId))
	-- assadeira entra na grade e a porta fecha
	Sfx.play("OvenIn")
	task.delay(0.25, function()
		if peek(status) == "baking" then
			Sfx.play("OvenDoor")
		end
	end)
	needle:set(0)
	message:set("")
	bakeStart = Pause.clock()
	status:set("baking")
end

local function takeOut()
	if peek(status) ~= "baking" then
		return
	end
	local t = peek(needle)
	if t >= PERFECT_START and t <= PERFECT_END then
		finish(Quality.Perfect)
	elseif t >= RAW_END and t < BURN_START then
		finish(Quality.Ok)
	elseif t < RAW_END then
		finish(Quality.Raw)
	else
		finish(Quality.Burnt)
	end
end

local function reset()
	bakeToken += 1
	status:set("idle")
	quality:set(Quality.Skipped)
	needle:set(0)
	message:set("Arraste o doce até o forno")
	showInOven(nil)
end

function close(q: number)
	if not peek(visible) then
		return
	end
	visible:set(false)
	if q ~= Quality.Skipped then
		-- o doce vai pro prato no balcão
		Sfx.play("Plate")
	end
	local cb = finishCallback
	finishCallback = nil
	retryCallback = nil
	if cb then
		cb(q)
	end
end

local function deliver()
	if peek(status) == "done" then
		close(peek(quality))
	end
end

local function retry()
	if peek(status) ~= "done" or not Catalog.isBadPastry(peek(quality)) or not retryCallback then
		return
	end
	if peek(State.Money) < Catalog.retryCost(peek(pastryId)) then
		message:set("Moedas insuficientes para assar de novo")
		shake(panel)
		return
	end
	status:set("waiting")
	retryCallback(function(ok)
		if peek(status) ~= "waiting" then
			return
		end
		if ok then
			reset()
			message:set("Mais uma chance! Arraste de novo")
		else
			status:set("done")
			message:set("Moedas insuficientes para assar de novo")
		end
	end)
end

------------------------------------------------------------------ bandeja de doces

local TAP_DISTANCE = 12 -- até aqui o arrasto conta como toque simples
local dragMoved = false

local function makeGhost(id: string, card: GuiObject): Frame
	local ghost = Instance.new("Frame")
	ghost.Name = "Ghost"
	ghost.BackgroundTransparency = 1
	ghost.AnchorPoint = Vector2.new(0.5, 0.5)
	ghost.Size = UDim2.fromOffset(card.AbsoluteSize.X * 0.9, card.AbsoluteSize.X * 0.9)
	ghost.ZIndex = 20
	PixelArt.draw((Sprites :: any)[Catalog.Pastries[id].Icon], 20).Parent = ghost
	ghost.Parent = gui
	return ghost
end

-- Toque simples numa carta: o doce certo voa sozinho até o forno
local function tapCard(id: string, card: GuiObject)
	if peek(status) ~= "idle" or dragMoved then
		return
	end
	if id ~= peek(pastryId) then
		message:set(`Esse não! O pedido é {pastryName()}`)
		shake(panel)
		return
	end
	status:set("flying")
	local ghost = makeGhost(id, card)
	local from = card.AbsolutePosition + card.AbsoluteSize / 2
	local to = ovenFrame.AbsolutePosition + ovenFrame.AbsoluteSize / 2
	ghost.Position = UDim2.fromOffset(from.X, from.Y)
	tween(ghost, 0.25, { Position = UDim2.fromOffset(to.X, to.Y) }).Completed:Once(function()
		ghost:Destroy()
		if peek(status) == "flying" and peek(visible) then
			startBake()
		end
	end)
end

local function beginDrag(id: string, input: InputObject, card: GuiObject)
	if peek(status) ~= "idle" then
		return
	end
	local ghost = makeGhost(id, card)
	local start = pointerPosition(input)
	ghost.Position = UDim2.fromOffset(start.X, start.Y)
	dragMoved = false

	trackPointer(input, function(p)
		ghost.Position = UDim2.fromOffset(p.X, p.Y)
		if (p - start).Magnitude > TAP_DISTANCE then
			dragMoved = true
		end
	end, function(_p)
		-- decide pelo doce que o jogador está vendo (o fantasma), não pela posição do evento
		local p = ghost.AbsolutePosition + ghost.AbsoluteSize / 2
		if not dragMoved then
			-- foi só um toque: quem resolve é o Activated da carta
			ghost:Destroy()
			return
		end
		if peek(status) == "idle" and inside(ovenFrame, p, ovenFrame.AbsoluteSize.Y * 0.25) then
			if id == peek(pastryId) then
				ghost:Destroy()
				startBake()
				return
			end
			message:set(`Esse não! O pedido é {pastryName()}`)
			shake(panel)
		end
		local home = card.AbsolutePosition + card.AbsoluteSize / 2
		tween(ghost, 0.2, { Position = UDim2.fromOffset(home.X, home.Y), Size = UDim2.fromOffset(0, 0) }).Completed:Once(function()
			ghost:Destroy()
		end)
	end)
end

local function makeCard(id: string, order: number): GuiObject
	local pastry = Catalog.Pastries[id]
	local art = PixelArt.draw((Sprites :: any)[pastry.Icon])
	art.Size = UDim2.fromScale(0.8, 0.8)
	local card
	card = scope:New("TextButton")({
		Name = id,
		Text = "",
		AutoButtonColor = true,
		LayoutOrder = order,
		BackgroundColor3 = Theme.Paper,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0.14, 0) }),
			scope:New("UIStroke")({ Thickness = 2, Color = Theme.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			scope:New("Frame")({
				Name = "Art",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.1, 0.04),
				Size = UDim2.fromScale(0.8, 0.66),
				[Children] = art,
			}),
			scope:New("TextLabel")({
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.05, 0.72),
				Size = UDim2.fromScale(0.9, 0.24),
				Font = Theme.Font,
				TextScaled = true,
				TextColor3 = Theme.Ink,
				Text = pastry.Name,
			}),
		},
		[OnEvent("InputBegan")] = function(input: InputObject)
			if isPress(input) then
				beginDrag(id, input, card)
			end
		end,
		[OnEvent("Activated")] = function()
			tapCard(id, card)
		end,
	})
	-- o doce é item de jogo: o som é o do forno
	card:SetAttribute("NoClickSound", true)
	return card
end

-- Bandeja sem rolagem (no celular a rolagem roubava o toque do arrastar):
-- escolhe o número de colunas que deixa as cartas maiores cabendo todas.
local CARD_ASPECT = 0.85
local CARD_SCALE = 0.9 -- cartas 10% menores que o máximo que cabe
local function layoutTray()
	local count = 0
	for _, c in tray:GetChildren() do
		if c:IsA("GuiObject") then
			count += 1
		end
	end
	local pad = 6
	local w, h = tray.AbsoluteSize.X - 2 * pad, tray.AbsoluteSize.Y - 2 * pad
	local best = 0
	for cols = 1, math.max(count, 1) do
		local rows = math.ceil(count / cols)
		local cw = (w - pad * (cols - 1)) / cols
		local ch = (h - pad * (rows - 1)) / rows
		best = math.max(best, math.min(cw, ch * CARD_ASPECT))
	end
	local cell = math.max(16, math.floor(best * CARD_SCALE))
	trayGrid.CellSize = UDim2.fromOffset(cell, math.floor(cell / CARD_ASPECT))
end

local function fillTray()
	for _, c in tray:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local owned = peek(State.Owned)
	for i, id in Catalog.PastryOrder do
		if owned[id] or id == peek(pastryId) then
			makeCard(id, i).Parent = tray
		end
	end
	layoutTray()
end

------------------------------------------------------------------ montagem

local function zone(x0: number, x1: number, color: Color3): Frame
	return scope:New("Frame")({
		BorderSizePixel = 0,
		Position = UDim2.fromScale(x0, 0),
		Size = UDim2.fromScale(x1 - x0, 1),
		BackgroundColor3 = color,
	})
end

local function button(props: { [any]: any }): TextButton
	local children = props[Children] or {}
	props[Children] = {
		scope:New("UICorner")({ CornerRadius = UDim.new(0.3, 0) }),
		scope:New("UIStroke")({ Thickness = 3, Color = Theme.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		scope:New("UIPadding")({ PaddingTop = UDim.new(0.16, 0), PaddingBottom = UDim.new(0.16, 0), PaddingLeft = UDim.new(0.04, 0), PaddingRight = UDim.new(0.04, 0) }),
		children,
	}
	props.AutoButtonColor = true
	props.Font = Theme.Font
	props.TextScaled = true
	props.TextColor3 = props.TextColor3 or Theme.Paper
	return scope:New("TextButton")(props) :: TextButton
end

function PastryPopup.init(playerGui: PlayerGui)
	local scale = scope:Spring(
		scope:Computed(function(use)
			return if use(visible) then 1 else 0.85
		end),
		28,
		0.7
	)
	local glow = scope:Computed(function(use)
		return if use(status) == "baking" then 0.35 else 1
	end)
	local bad = scope:Computed(function(use)
		return use(status) == "done" and Catalog.isBadPastry(use(quality))
	end)

	local ovenArt = PixelArt.draw(Sprites.Oven)
	pastryHolder = scope:New("Frame")({
		Name = "Pastry",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.56),
		Size = UDim2.fromScale(0.36, 0.36),
		ZIndex = 3,
	}) :: Frame

	ovenFrame = scope:New("Frame")({
		Name = "Oven",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.44, 0.17),
		Size = UDim2.fromScale(0.52, 0.42),
		[Children] = {
			ovenArt,
			scope:New("Frame")({
				Name = "Glow",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.56),
				Size = UDim2.fromScale(0.34, 0.3),
				BackgroundColor3 = Color3.fromRGB(255, 200, 90),
				BackgroundTransparency = glow,
				ZIndex = 2,
			}),
			pastryHolder,
		},
		-- tocar no forno também tira o doce
		[OnEvent("InputBegan")] = function(input: InputObject)
			if isPress(input) then
				takeOut()
			end
		end,
	}) :: Frame

	tray = scope:New("Frame")({
		Name = "Tray",
		BackgroundColor3 = Theme.PaperShade,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.04, 0.17),
		Size = UDim2.fromScale(0.36, 0.79),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
			}),
		},
	}) :: Frame
	trayGrid = scope:New("UIGridLayout")({
		CellPadding = UDim2.fromOffset(6, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = tray,
	}) :: UIGridLayout
	tray:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutTray)

	panel = scope:New("Frame")({
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.6, 0.6),
		BackgroundColor3 = Theme.Wood,
		[Children] = {
			scope:New("UISizeConstraint")({ MinSize = Vector2.new(360, 260) }),
			scope:New("UIScale")({ Scale = scale }),
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 14) }),
			scope:New("UIStroke")({ Thickness = 4, Color = Theme.Ink }),
			scope:New("Frame")({
				Name = "Inner",
				BackgroundColor3 = Theme.Paper,
				Position = UDim2.fromOffset(8, 8),
				Size = UDim2.new(1, -16, 1, -16),
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
					scope:New("TextLabel")({
						Name = "Title",
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.04, 0.03),
						Size = UDim2.fromScale(0.78, 0.11),
						Font = Theme.Font,
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextColor3 = Theme.Ink,
						Text = scope:Computed(function(use)
							local id = use(pastryId)
							return if id ~= "" then `Pedido: {Catalog.Pastries[id].Name}` else "Forno"
						end),
					}),
					button({
						Name = "Close",
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, -6, 0, 6),
						Size = UDim2.fromScale(0.1, 0.12),
						BackgroundColor3 = Theme.Rose,
						Text = "X",
						[Children] = scope:New("UIAspectRatioConstraint")({ AspectRatio = 1 }),
						[OnEvent("Activated")] = function()
							close(Quality.Skipped)
						end,
					}),
					tray,
					ovenFrame,
					scope:New("Frame")({
						Name = "Bar",
						Position = UDim2.fromScale(0.46, 0.62),
						Size = UDim2.fromScale(0.48, 0.06),
						BackgroundColor3 = Theme.PaperShade,
						[Children] = {
							scope:New("UIStroke")({ Thickness = 2, Color = Theme.Ink }),
							zone(0, RAW_END, Color3.fromRGB(214, 206, 196)),
							zone(RAW_END, PERFECT_START, Theme.Mustard),
							zone(PERFECT_START, PERFECT_END, Theme.Sage),
							zone(PERFECT_END, BURN_START, Theme.Mustard),
							zone(BURN_START, 1, Color3.fromRGB(90, 60, 50)),
							scope:New("Frame")({
								Name = "Needle",
								BorderSizePixel = 0,
								AnchorPoint = Vector2.new(0.5, 0.5),
								Position = scope:Computed(function(use)
									return UDim2.fromScale(use(needle), 0.5)
								end),
								Size = UDim2.new(0, 5, 1.8, 0),
								BackgroundColor3 = Theme.Ink,
								ZIndex = 3,
							}),
						},
					}),
					scope:New("TextLabel")({
						Name = "Message",
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.44, 0.7),
						Size = UDim2.fromScale(0.52, 0.09),
						Font = Theme.Font,
						TextScaled = true,
						TextColor3 = scope:Computed(function(use)
							return if use(bad) then Theme.Rose else Theme.SageDark
						end),
						Text = message,
					}),
					button({
						Name = "Main",
						Position = UDim2.fromScale(0.44, 0.82),
						Size = scope:Computed(function(use)
							return if use(bad) then UDim2.fromScale(0.21, 0.14) else UDim2.fromScale(0.52, 0.14)
						end),
						Visible = scope:Computed(function(use)
							local s = use(status)
							return s == "baking" or s == "done"
						end),
						BackgroundColor3 = scope:Computed(function(use)
							return if use(status) == "baking" then Theme.Rose else Theme.SageDark
						end),
						Text = scope:Computed(function(use)
							return if use(status) == "baking" then "Tirar!" else "Entregar"
						end),
						[OnEvent("Activated")] = function()
							if peek(status) == "baking" then
								takeOut()
							else
								deliver()
							end
						end,
					}),
					button({
						Name = "Retry",
						Position = UDim2.fromScale(0.67, 0.82),
						Size = UDim2.fromScale(0.29, 0.14),
						Visible = scope:Computed(function(use)
							return use(bad) or use(status) == "waiting"
						end),
						BackgroundColor3 = scope:Computed(function(use)
							local id = use(pastryId)
							local afford = id ~= "" and use(State.Money) >= Catalog.retryCost(id)
							return if afford then Theme.Mustard else Theme.PaperShade
						end),
						TextColor3 = Theme.Ink,
						Text = scope:Computed(function(use)
							local id = use(pastryId)
							if use(status) == "waiting" then
								return "..."
							end
							return if id ~= "" then `Assar de novo -${Catalog.retryCost(id)}` else ""
						end),
						[OnEvent("Activated")] = retry,
					}),
				},
			}),
		},
	}) :: Frame

	gui = scope:New("ScreenGui")({
		Name = "CafePastry",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 8,
		Enabled = visible,
		Parent = playerGui,
		[Children] = {
			-- escurece o fundo e segura os cliques
			scope:New("TextButton")({
				Name = "Dim",
				Text = "",
				AutoButtonColor = false,
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.5,
			}),
			panel,
		},
	}) :: ScreenGui
	-- o fundo escuro só segura os cliques: sem pop
	local dim = gui:FindFirstChild("Dim") :: GuiButton
	dim:SetAttribute("NoClickSound", true)

	RunService.RenderStepped:Connect(function()
		if peek(status) ~= "baking" then
			return
		end
		local id = peek(pastryId)
		if id == "" then
			return
		end
		local t = (Pause.clock() - bakeStart) / Catalog.Pastries[id].BakeTime
		needle:set(math.min(t, 1))
		if t >= 1 then
			finish(Quality.Burnt)
		end
	end)
end

------------------------------------------------------------------ API pública

-- Abre o pop-up para o doce pedido. onFinish recebe a Catalog.PastryQuality (Skipped = fechou no X).
-- onRetry cobra no servidor e chama done(ok) com a resposta.
function PastryPopup.open(id: string, onFinish: (quality: number) -> (), onRetry: (done: (ok: boolean) -> ()) -> ())
	pastryId:set(id)
	finishCallback = onFinish
	retryCallback = onRetry
	reset()
	fillTray()
	panel.Rotation = 0
	visible:set(true)
end

function PastryPopup.isOpen(): boolean
	return peek(visible)
end

-- Fecha sem avisar ninguém (fim de dia forçado)
function PastryPopup.dismiss()
	finishCallback = nil
	retryCallback = nil
	visible:set(false)
end

return PastryPopup
