--!strict
-- Rádio da gameplay: música de fundo que começa com o expediente e um painel (aberto pelo
-- botão abaixo do livro de receitas) para trocar de estação e ajustar o volume.
-- A escolha fica salva no perfil (atributos RadioTrack/RadioVolume vindos do servidor).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local Theme = require(script.Parent.Theme)

local Radio = {}

-- estações (todas cozy/lo-fi); a primeira é a padrão
Radio.Tracks = {
	{ Name = "Bossa Nova", Id = "rbxassetid://91689040007075", Color = Theme.Mustard },
	{ Name = "Metal Lo-fi", Id = "rbxassetid://71592508493849", Color = Color3.fromRGB(150, 140, 170) },
	{ Name = "K-pop Lo-fi", Id = "rbxassetid://86664488694082", Color = Color3.fromRGB(240, 160, 190) },
	{ Name = "Jazz", Id = "rbxassetid://140331368291861", Color = Theme.Wood },
	{ Name = "Lo-fi Hip Hop", Id = "rbxassetid://9047104336", Color = Theme.Sage },
	{ Name = "New Age", Id = "rbxassetid://128130163260275", Color = Color3.fromRGB(150, 200, 220) },
}
-- volume do Sound com o controle no máximo
Radio.MaxVolume = 0.6
Radio.DefaultVolume = 70 -- %

local player = Players.LocalPlayer
local track = 1
local volume = Radio.DefaultVolume
local music: Sound? = nil
local switching = 0

local gui: ScreenGui
local anchor: GuiObject
local backdrop: TextButton
local panel: Frame
local panelScale: UIScale
local stationButtons: { TextButton } = {}
local fill: Frame
local knob: Frame
local percent: TextLabel

local function tween(obj: Instance, time: number, props: { [string]: any }): Tween
	local t = TweenService:Create(obj, TweenInfo.new(time, Enum.EasingStyle.Sine), props)
	t:Play()
	return t
end

local function targetVolume(): number
	return Radio.MaxVolume * volume / 100
end

local function save()
	Net.SetRadio.send({ track = track, volume = volume })
end

local function loadSettings()
	local t = player:GetAttribute("RadioTrack")
	local v = player:GetAttribute("RadioVolume")
	if typeof(t) == "number" and Radio.Tracks[t] then
		track = t
	end
	if typeof(v) == "number" then
		volume = math.clamp(math.floor(v), 0, 100)
	end
end

local function refreshPanel()
	if not panel then
		return
	end
	for i, button in stationButtons do
		local on = i == track
		button.BackgroundColor3 = if on then Radio.Tracks[i].Color else Theme.PaperShade
		local stroke = button:FindFirstChildOfClass("UIStroke") :: UIStroke
		stroke.Thickness = if on then 3 else 2
		local note = button:FindFirstChild("Note") :: TextLabel
		note.Visible = on
	end
	fill.Size = UDim2.fromScale(volume / 100, 1)
	knob.Position = UDim2.fromScale(volume / 100, 0.5)
	percent.Text = `{volume}%`
end

-- começa a tocar (no início do expediente); chamadas repetidas não fazem nada
function Radio.play()
	if music then
		return
	end
	loadSettings()
	local sound = Instance.new("Sound")
	sound.Name = "RadioMusic"
	sound.SoundId = Radio.Tracks[track].Id
	sound.Looped = true
	sound.Volume = 0
	sound.Parent = SoundService
	sound:Play()
	music = sound
	tween(sound, 2.5, { Volume = targetVolume() })
	refreshPanel()
end

function Radio.setTrack(index: number)
	if not Radio.Tracks[index] or index == track then
		return
	end
	track = index
	refreshPanel()
	save()
	local sound = music
	if not sound then
		return
	end
	-- troca com um fade curtinho (cliques rápidos: só a última troca vale)
	switching += 1
	local mine = switching
	tween(sound, 0.35, { Volume = 0 }).Completed:Once(function()
		if mine ~= switching then
			return
		end
		sound.SoundId = Radio.Tracks[track].Id
		sound.TimePosition = 0
		sound:Play()
		tween(sound, 0.8, { Volume = targetVolume() })
	end)
end

function Radio.setVolume(percentValue: number)
	volume = math.clamp(math.floor(percentValue + 0.5), 0, 100)
	if music then
		switching += 1 -- cancela um fade de troca em andamento
		music.Volume = targetVolume()
	end
	refreshPanel()
end

function Radio.close()
	if panel then
		panel.Visible = false
		backdrop.Visible = false
	end
end

function Radio.isOpen(): boolean
	return panel ~= nil and panel.Visible
end

-- posiciona o painel logo abaixo do botão do rádio, sem sair da tela
local function place()
	local viewport = gui.AbsoluteSize
	panelScale.Scale = math.clamp(viewport.Y / 520, 0.62, 1)
	local w = panel.AbsoluteSize.X
	local center = anchor.AbsolutePosition.X - gui.AbsolutePosition.X + anchor.AbsoluteSize.X / 2
	local x = math.clamp(center - w / 2, 8, math.max(8, viewport.X - w - 8))
	local y = anchor.AbsolutePosition.Y - gui.AbsolutePosition.Y + anchor.AbsoluteSize.Y + 10
	panel.Position = UDim2.fromOffset(x, y)
end

function Radio.toggle()
	if not panel then
		return
	end
	if panel.Visible then
		Radio.close()
		return
	end
	loadSettings()
	refreshPanel()
	backdrop.Visible = true
	panel.Visible = true
	place()
	panelScale.Scale *= 0.85
	tween(panelScale, 0.18, { Scale = panelScale.Scale / 0.85 })
end

local function build()
	backdrop = Instance.new("TextButton")
	backdrop.Name = "RadioBackdrop"
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.BackgroundTransparency = 1
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.Visible = false
	backdrop.ZIndex = 20
	backdrop.Activated:Connect(Radio.close)
	backdrop.Parent = gui

	panel = Instance.new("Frame")
	panel.Name = "RadioPanel"
	panel.BackgroundColor3 = Theme.Paper
	panel.Size = UDim2.fromOffset(300, 262)
	panel.Visible = false
	panel.ZIndex = 21
	Theme.corner(panel, 0, 16)
	Theme.stroke(panel, 3)
	panelScale = Instance.new("UIScale")
	panelScale.Parent = panel
	panel.Parent = gui

	local title = Theme.label("Rádio", Theme.Ink)
	title.Position = UDim2.fromOffset(16, 10)
	title.Size = UDim2.new(1, -60, 0, 30)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 22
	title.Parent = panel

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Text = "X"
	close.Font = Theme.Font
	close.TextScaled = true
	close.TextColor3 = Theme.Paper
	close.BackgroundColor3 = Theme.Rose
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 10)
	close.Size = UDim2.fromOffset(30, 30)
	close.ZIndex = 22
	Theme.corner(close, 0.5, 0)
	Theme.stroke(close, 2)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 5)
	pad.PaddingBottom = UDim.new(0, 5)
	pad.Parent = close
	close.Activated:Connect(Radio.close)
	close.Parent = panel

	-- estações em duas colunas
	local grid = Instance.new("Frame")
	grid.Name = "Stations"
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.fromOffset(14, 50)
	grid.Size = UDim2.new(1, -28, 0, 144)
	grid.ZIndex = 22
	grid.Parent = panel
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0.5, -5, 0, 42)
	layout.CellPadding = UDim2.fromOffset(10, 9)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	for i, info in Radio.Tracks do
		local button = Instance.new("TextButton")
		button.Name = info.Name
		button.LayoutOrder = i
		button.Text = ""
		button.AutoButtonColor = true
		button.BackgroundColor3 = Theme.PaperShade
		button.ZIndex = 23
		Theme.corner(button, 0, 10)
		Theme.stroke(button, 2)
		local name = Theme.label(info.Name, Theme.Ink)
		name.Position = UDim2.fromOffset(10, 9)
		name.Size = UDim2.new(1, -34, 1, -18)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.ZIndex = 24
		name.Parent = button
		local note = Theme.label("♪", Theme.Ink)
		note.Name = "Note"
		note.AnchorPoint = Vector2.new(1, 0.5)
		note.Position = UDim2.new(1, -8, 0.5, 0)
		note.Size = UDim2.fromOffset(20, 24)
		note.ZIndex = 24
		note.Visible = false
		note.Parent = button
		button.Activated:Connect(function()
			Radio.setTrack(i)
		end)
		button.Parent = grid
		stationButtons[i] = button
	end

	-- volume
	local volLabel = Theme.label("Volume", Theme.Ink)
	volLabel.Position = UDim2.fromOffset(16, 208)
	volLabel.Size = UDim2.fromOffset(70, 22)
	volLabel.TextXAlignment = Enum.TextXAlignment.Left
	volLabel.ZIndex = 22
	volLabel.Parent = panel

	percent = Theme.label("", Theme.Ink)
	percent.AnchorPoint = Vector2.new(1, 0)
	percent.Position = UDim2.new(1, -14, 0, 208)
	percent.Size = UDim2.fromOffset(46, 22)
	percent.TextXAlignment = Enum.TextXAlignment.Right
	percent.ZIndex = 22
	percent.Parent = panel

	-- área de toque maior que a barra visível
	local hit = Instance.new("TextButton")
	hit.Name = "VolumeBar"
	hit.Text = ""
	hit.AutoButtonColor = false
	hit.BackgroundTransparency = 1
	hit.Position = UDim2.fromOffset(96, 202)
	hit.Size = UDim2.new(1, -164, 0, 34)
	hit.ZIndex = 22
	hit.Parent = panel

	local bar = Instance.new("Frame")
	bar.Name = "Track"
	bar.AnchorPoint = Vector2.new(0, 0.5)
	bar.Position = UDim2.fromScale(0, 0.5)
	bar.Size = UDim2.new(1, 0, 0, 12)
	bar.BackgroundColor3 = Theme.PaperShade
	bar.ZIndex = 23
	Theme.corner(bar, 0.5, 0)
	Theme.stroke(bar, 2)
	bar.Parent = hit

	fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Theme.Sage
	fill.BorderSizePixel = 0
	fill.ZIndex = 24
	Theme.corner(fill, 0.5, 0)
	fill.Parent = bar

	knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Size = UDim2.fromOffset(22, 22)
	knob.BackgroundColor3 = Theme.Mustard
	knob.ZIndex = 25
	Theme.corner(knob, 0.5, 0)
	Theme.stroke(knob, 2)
	knob.Parent = bar

	local dragging: InputObject? = nil
	local function setFromX(x: number)
		local rel = (x - bar.AbsolutePosition.X) / math.max(1, bar.AbsoluteSize.X)
		Radio.setVolume(math.clamp(rel, 0, 1) * 100)
	end
	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = input
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input == dragging then
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input == dragging or input.UserInputType == Enum.UserInputType.MouseButton1) then
			dragging = nil
			save()
		end
	end)

	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if panel.Visible then
			place()
		end
	end)
	refreshPanel()
end

-- liga o painel à ScreenGui do HUD e ao botão do rádio (o painel abre logo abaixo dele)
function Radio.attach(screenGui: ScreenGui, button: GuiObject)
	gui = screenGui
	anchor = button
	build()
	-- HUD escondido (fim do dia, loja): fecha o painel
	gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if not gui.Enabled then
			Radio.close()
		end
	end)
end

return Radio
