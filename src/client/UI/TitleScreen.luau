--!strict
-- Tela de início: a câmera mostra a fachada do café, título pixel, xícara soltando vapor
-- e um botão PLAY. Ao apertar, a UI sai e quem chamou cuida da câmera/transição.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Layout = require(ReplicatedStorage.Shared.Layout)
local PixelArt = require(script.Parent.Parent.Art.PixelArt)
local Sprites = require(script.Parent.Parent.Art.Sprites)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Theme)

local Children = Fusion.Children

local TitleScreen = {}

-- enquadramento da fachada (fora do café, olhando a placa e a porta)
-- (a linha reta até a câmera do balcão passa pelo vão da porta)
TitleScreen.CameraPosition = Vector3.new(Layout.DoorX + 4.2, 7, Layout.Room.MinZ - 24)
TitleScreen.CameraTarget = Vector3.new(Layout.DoorX, 9.5, Layout.Room.MinZ)
TitleScreen.FieldOfView = 60

-- trilha do menu: bossa nova de violão, simples e leve (Creator Store), em loop com fade
TitleScreen.MusicId = "rbxassetid://89325176578939"
TitleScreen.MusicVolume = 0.45
-- um pouco mais rápida/aguda e com menos grave: fica mais fofinha, tipo caixinha de música
TitleScreen.MusicSpeed = 1.12

local playerGui: PlayerGui
-- a música do menu continua depois do PLAY (loja/cardápio) e só para quando o dia começa
local music: Sound?

function TitleScreen.init(gui: PlayerGui)
	playerGui = gui
end

local function tween(inst: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

function TitleScreen.show(onPlay: () -> (), onFree: (() -> ())?)
	local scope = Fusion.scoped(Fusion)

	if not music then
		local sound = Instance.new("Sound")
		sound.Name = "TitleMusic"
		sound.SoundId = TitleScreen.MusicId
		sound.Looped = true
		sound.Volume = 0
		sound.PlaybackSpeed = TitleScreen.MusicSpeed
		local eq = Instance.new("EqualizerSoundEffect")
		eq.LowGain = -4
		eq.MidGain = 0
		eq.HighGain = 2
		eq.Parent = sound
		sound.Parent = SoundService
		sound:Play()
		tween(sound, 2.5, { Volume = TitleScreen.MusicVolume }, Enum.EasingStyle.Sine)
		music = sound
	end

	local cup = PixelArt.draw(Sprites.Coffee)
	cup.Size = UDim2.fromScale(1, 1)

	local titleScale = scope:New("UIScale")({ Scale = 0 })
	local buttonScale = scope:New("UIScale")({ Scale = 0 })

	local steam = scope:New("Frame")({
		Name = "Steam",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.05),
		Size = UDim2.fromScale(1, 1),
	})

	local title = scope:New("Frame")({
		Name = "Title",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromScale(0.7, 0.26),
		[Children] = {
			titleScale,
			scope:New("UISizeConstraint")({ MaxSize = Vector2.new(900, 260) }),
			scope:New("Frame")({
				Name = "Cup",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0, 0.45),
				Size = UDim2.fromScale(0.8, 0.8),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				[Children] = { cup, steam },
			}),
			scope:New("TextLabel")({
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.25, 0),
				Size = UDim2.fromScale(0.75, 0.72),
				Font = Theme.Font,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Theme.Paper,
				Text = "Café Cozy",
				[Children] = scope:New("UIStroke")({ Thickness = 6, Color = Theme.Ink }),
			}),
			scope:New("TextLabel")({
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.26, 0.72),
				Size = UDim2.fromScale(0.72, 0.2),
				Font = Theme.Font,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Theme.Mustard,
				Text = "um cafezinho pixelado, feito com carinho",
				[Children] = scope:New("UIStroke")({ Thickness = 3, Color = Theme.Ink }),
			}),
		},
	})

	local playButton = scope:New("TextButton")({
		Name = "Play",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.fromScale(0.24, 0.13),
		BackgroundColor3 = Theme.SageDark,
		Font = Theme.Font,
		TextScaled = true,
		TextColor3 = Theme.Paper,
		Text = "PLAY",
		[Children] = {
			buttonScale,
			scope:New("UISizeConstraint")({ MinSize = Vector2.new(220, 70), MaxSize = Vector2.new(380, 120) }),
			scope:New("UICorner")({ CornerRadius = UDim.new(0.3, 0) }),
			scope:New("UIStroke")({ Thickness = 5, Color = Theme.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			scope:New("UIPadding")({ PaddingTop = UDim.new(0.16, 0), PaddingBottom = UDim.new(0.16, 0) }),
		},
	})

	local freeScale = scope:New("UIScale")({ Scale = 0 })
	local freeButton = scope:New("TextButton")({
		Name = "Free",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.75),
		Size = UDim2.fromScale(0.18, 0.08),
		BackgroundColor3 = Theme.Paper,
		Font = Theme.Font,
		TextScaled = true,
		TextColor3 = Theme.Ink,
		Text = "Modo Livre",
		[Children] = {
			freeScale,
			scope:New("UISizeConstraint")({ MinSize = Vector2.new(170, 46), MaxSize = Vector2.new(300, 80) }),
			scope:New("UICorner")({ CornerRadius = UDim.new(0.3, 0) }),
			scope:New("UIStroke")({ Thickness = 4, Color = Theme.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			scope:New("UIPadding")({ PaddingTop = UDim.new(0.2, 0), PaddingBottom = UDim.new(0.2, 0) }),
		},
	})

	local info = scope:New("TextLabel")({
		Name = "Info",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.83),
		Size = UDim2.fromScale(0.5, 0.045),
		Font = Theme.Font,
		TextScaled = true,
		TextColor3 = Theme.Paper,
		TextTransparency = 1,
		Text = scope:Computed(function(use)
			if not use(State.Loaded) then
				return "carregando..."
			end
			local day = use(State.Day)
			return if day <= 1 then "Seu primeiro dia te espera!" else `Dia {day}  ·  Nível {use(State.Level)}  ·  ${use(State.Money)}`
		end),
		[Children] = scope:New("UIStroke")({ Thickness = 3, Color = Theme.Ink }),
	})

	local gradient = scope:New("Frame")({
		Name = "Shade",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(30, 20, 24),
		BackgroundTransparency = 0.35,
		[Children] = scope:New("UIGradient")({
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.2),
				NumberSequenceKeypoint.new(0.45, 1),
				NumberSequenceKeypoint.new(0.7, 1),
				NumberSequenceKeypoint.new(1, 0.1),
			}),
		}),
	})

	local gui = scope:New("ScreenGui")({
		Name = "TitleScreen",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 40,
		Parent = playerGui,
		[Children] = { gradient, title, playButton, freeButton, info },
	}) :: ScreenGui

	-- Em tela baixa (celular) os tamanhos mínimos fazem os botões se encostarem:
	-- empilha "Modo Livre" e o texto de baixo a partir do PLAY
	local function stack()
		local h = gui.AbsoluteSize.Y
		local playH = math.clamp(h * 0.13, 70, 120)
		local freeH = math.clamp(h * 0.08, 46, 80)
		local freeY = math.max(h * 0.75, h * 0.62 + playH / 2 + 14 + freeH / 2)
		freeButton.Position = UDim2.new(0.5, 0, 0, freeY)
		info.Position = UDim2.new(0.5, 0, 0, math.max(h * 0.83, freeY + freeH / 2 + 10))
	end
	stack()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(stack)

	tween(titleScale, 0.7, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(0.35, function()
		tween(buttonScale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
		tween(info, 0.5, { TextTransparency = 0 })
	end)
	task.delay(0.5, function()
		tween(freeScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	end)

	-- botão pulsando + vapor saindo da xícara
	local rng = Random.new()
	local lastPuff = 0
	local conn = RunService.RenderStepped:Connect(function()
		buttonScale.Scale = if buttonScale.Scale > 0.95 then 1 + math.sin(os.clock() * 4) * 0.04 else buttonScale.Scale
		if os.clock() - lastPuff > 0.25 then
			lastPuff = os.clock()
			local puff = Instance.new("Frame")
			puff.BorderSizePixel = 0
			puff.BackgroundColor3 = Theme.Paper
			puff.BackgroundTransparency = 0.2
			puff.Size = UDim2.fromScale(0.09, 0.09)
			local x = 0.5 + rng:NextNumber(-0.15, 0.15)
			puff.Position = UDim2.fromScale(x, 1)
			puff.Parent = steam
			local t = TweenService:Create(puff, TweenInfo.new(1.4, Enum.EasingStyle.Sine), {
				Position = UDim2.fromScale(x + rng:NextNumber(-0.1, 0.1), 0.3),
				BackgroundTransparency = 1,
			})
			t.Completed:Once(function()
				puff:Destroy()
			end)
			t:Play()
		end
	end)
	table.insert(scope, conn)

	local pressed = false
	local function leave(pressedScale: UIScale, callback: () -> ())
		if pressed or not Fusion.peek(State.Loaded) then
			return
		end
		pressed = true
		conn:Disconnect()
		tween(pressedScale, 0.12, { Scale = 0.85 }).Completed:Wait()
		tween(buttonScale, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		tween(freeScale, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		tween(titleScale, 0.35, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		tween(info, 0.3, { TextTransparency = 1 })
		tween(gradient, 0.6, { BackgroundTransparency = 1 })
		task.delay(0.6, function()
			gui:Destroy()
			Fusion.doCleanup(scope)
		end)
		callback()
	end
	playButton.Activated:Connect(function()
		leave(buttonScale, onPlay)
	end)
	freeButton.Activated:Connect(function()
		if onFree then
			leave(freeScale, onFree)
		end
	end)
end

-- para a música do menu com fade (chamado quando o dia começa; o rádio assume)
function TitleScreen.stopMusic(fade: number?)
	local sound = music
	if not sound then
		return
	end
	music = nil
	tween(sound, fade or 2, { Volume = 0 }, Enum.EasingStyle.Sine).Completed:Once(function()
		sound:Destroy()
	end)
end

return TitleScreen
