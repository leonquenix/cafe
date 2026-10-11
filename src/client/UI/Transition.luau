--!strict
-- Transição entre dias: a tela escurece, aparece "Dia N" com o solzinho nascendo e clareia.

local TweenService = game:GetService("TweenService")

local PixelArt = require(script.Parent.Parent.Art.PixelArt)
local Sprites = require(script.Parent.Parent.Art.Sprites)
local Theme = require(script.Parent.Theme)

local Transition = {}

local gui: ScreenGui

function Transition.init(playerGui: PlayerGui)
	gui = Instance.new("ScreenGui")
	gui.Name = "CafeTransition"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.Parent = playerGui
end

local function tween(inst: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?): Tween
	local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), props)
	t:Play()
	return t
end

-- onCovered roda com a tela coberta (bom pra trocar luz/estado); onDone ao final.
function Transition.play(day: number, onCovered: (() -> ())?, onDone: (() -> ())?)
	local cover = Instance.new("Frame")
	cover.Size = UDim2.fromScale(1, 1)
	cover.BackgroundColor3 = Color3.fromRGB(40, 28, 30)
	cover.BackgroundTransparency = 1
	cover.Parent = gui

	-- faixas "pixel" descendo como cortina
	local stripes = {}
	for i = 0, 9 do
		local s = Instance.new("Frame")
		s.BorderSizePixel = 0
		s.BackgroundColor3 = if i % 2 == 0 then Color3.fromRGB(58, 40, 40) else Color3.fromRGB(48, 34, 36)
		s.Position = UDim2.fromScale(i / 10, -1)
		s.Size = UDim2.new(0.1, 1, 1, 0)
		s.Parent = cover
		table.insert(stripes, s)
	end

	local sun = PixelArt.draw(Sprites.Sun, 3)
	sun.Size = UDim2.fromScale(0.14, 0.14)
	sun.SizeConstraint = Enum.SizeConstraint.RelativeYY
	sun.Position = UDim2.fromScale(0.5, 0.75)
	sun.Visible = false
	sun.Parent = cover

	local title = Theme.label(`Dia {day}`, Theme.Paper)
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.52)
	title.Size = UDim2.fromScale(0.5, 0.14)
	title.TextTransparency = 1
	title.ZIndex = 3
	title.Parent = cover

	local subtitle = Theme.label("Bom dia! O café está abrindo...", Theme.Mustard)
	subtitle.AnchorPoint = Vector2.new(0.5, 0.5)
	subtitle.Position = UDim2.fromScale(0.5, 0.63)
	subtitle.Size = UDim2.fromScale(0.5, 0.05)
	subtitle.TextTransparency = 1
	subtitle.ZIndex = 3
	subtitle.Parent = cover

	task.spawn(function()
		for i, s in stripes do
			task.delay((i - 1) * 0.04, function()
				tween(s, 0.35, { Position = UDim2.fromScale((i - 1) / 10, 0) }, Enum.EasingStyle.Quad)
			end)
		end
		task.wait(0.8)
		cover.BackgroundTransparency = 0
		for _, s in stripes do
			s.Visible = false
		end
		if onCovered then
			onCovered()
		end

		sun.Visible = true
		tween(sun, 0.9, { Position = UDim2.fromScale(0.5, 0.3) }, Enum.EasingStyle.Back)
		tween(title, 0.5, { TextTransparency = 0 })
		task.wait(0.3)
		tween(subtitle, 0.5, { TextTransparency = 0 })
		task.wait(1.6)

		tween(title, 0.4, { TextTransparency = 1 })
		tween(subtitle, 0.4, { TextTransparency = 1 })
		tween(sun, 0.4, { Position = UDim2.fromScale(0.5, -0.2) })
		task.wait(0.3)
		tween(cover, 0.7, { BackgroundTransparency = 1 }).Completed:Wait()
		cover:Destroy()
		if onDone then
			onDone()
		end
	end)
end

-- Faixa no rodapé anunciando algo ("Nova decoração: Gatinho!")
function Transition.banner(title: string, subtitle: string, iconSprite: string?, duration: number?)
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -40)
	panel.Size = UDim2.fromOffset(520, 96)
	panel.BackgroundColor3 = Theme.Paper
	panel.Parent = gui
	Theme.corner(panel, 0, 16)
	Theme.stroke(panel, 4)
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = panel

	local textX = 20
	if iconSprite then
		local art = PixelArt.draw((Sprites :: any)[iconSprite])
		art.AnchorPoint = Vector2.new(0, 0.5)
		art.Position = UDim2.new(0, 16, 0.5, 0)
		art.Size = UDim2.fromOffset(70, 70)
		art.Parent = panel
		textX = 100
	end
	local t1 = Theme.label(title, Theme.Ink)
	t1.Position = UDim2.fromOffset(textX, 12)
	t1.Size = UDim2.new(1, -textX - 16, 0, 42)
	t1.TextXAlignment = Enum.TextXAlignment.Left
	t1.Parent = panel
	local t2 = Theme.label(subtitle, Theme.WoodDark)
	t2.Position = UDim2.fromOffset(textX, 56)
	t2.Size = UDim2.new(1, -textX - 16, 0, 26)
	t2.TextXAlignment = Enum.TextXAlignment.Left
	t2.Parent = panel

	tween(scale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(duration or 2.4, function()
		local t = TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
		t.Completed:Once(function()
			panel:Destroy()
		end)
		t:Play()
	end)
end

return Transition
