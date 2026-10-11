--!strict
-- Comemorações do Modo Livre, no meio da tela:
--  * receita conhecida: copo grande, raios girando, nome da bebida e confete
--  * criação própria: o copo dá uns pulinhos e some

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Glass = require(script.Parent.Parent.Art.Glass)
local Theme = require(script.Parent.Theme)

local FreeCelebration = {}

local gui: ScreenGui

function FreeCelebration.init(playerGui: PlayerGui)
	gui = Instance.new("ScreenGui")
	gui.Name = "FreeCelebration"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 25
	gui.Parent = playerGui
end

local function tween(inst: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function drawGlass(portions: { string }, mix: number): Frame
	local glass = Glass.new()
	glass:setPortions(portions)
	glass:setMix(if mix >= 1 then 1 else 0, 0)
	glass:setLevel(glass:targetLevel())
	return glass.Root
end

local function confetti(parent: GuiObject, amount: number)
	local rng = Random.new()
	local colors = { Theme.Mustard, Theme.Rose, Theme.Sage, Theme.Paper, Color3.fromRGB(150, 196, 226) }
	for i = 1, amount do
		task.delay(i * 0.012, function()
			local c = Instance.new("Frame")
			c.BorderSizePixel = 0
			c.BackgroundColor3 = colors[rng:NextInteger(1, #colors)]
			c.Size = UDim2.fromOffset(rng:NextInteger(8, 14), rng:NextInteger(8, 14))
			c.AnchorPoint = Vector2.new(0.5, 0.5)
			c.Position = UDim2.fromScale(0.5, 0.45)
			c.Parent = parent
			local angle = rng:NextNumber(0, math.pi * 2)
			local dist = rng:NextNumber(0.15, 0.45)
			local t = TweenService:Create(c, TweenInfo.new(rng:NextNumber(0.8, 1.3), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.fromScale(0.5 + math.cos(angle) * dist, 0.45 + math.sin(angle) * dist + 0.1),
				Rotation = rng:NextNumber(-540, 540),
				BackgroundTransparency = 1,
			})
			t.Completed:Once(function()
				c:Destroy()
			end)
			t:Play()
		end)
	end
end

local function label(text: string, color: Color3, strokeThickness: number): TextLabel
	local l = Theme.label(text, color)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = strokeThickness
	stroke.Color = Theme.Ink
	stroke.Parent = l
	return l
end

-- Receita conhecida
function FreeCelebration.known(title: string, subtitle: string, portions: { string }, mix: number)
	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui

	local rays = Instance.new("Frame")
	rays.BackgroundTransparency = 1
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.42)
	rays.Size = UDim2.fromScale(0.7, 0.7)
	rays.SizeConstraint = Enum.SizeConstraint.RelativeYY
	rays.Parent = root
	for i = 0, 11 do
		local r = Instance.new("Frame")
		r.BorderSizePixel = 0
		r.AnchorPoint = Vector2.new(0.5, 0.5)
		r.Position = UDim2.fromScale(0.5, 0.5)
		r.Size = UDim2.fromScale(0.07, 1)
		r.Rotation = i * 15
		r.BackgroundColor3 = if i % 2 == 0 then Theme.Mustard else Theme.Paper
		r.BackgroundTransparency = 0.55
		r.Parent = rays
	end
	local raysScale = Instance.new("UIScale")
	raysScale.Scale = 0
	raysScale.Parent = rays

	local glassFrame = Instance.new("Frame")
	glassFrame.BackgroundTransparency = 1
	glassFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	glassFrame.Position = UDim2.fromScale(0.5, 0.42)
	glassFrame.Size = UDim2.fromScale(0.36, 0.36)
	glassFrame.SizeConstraint = Enum.SizeConstraint.RelativeYY
	glassFrame.Parent = root
	drawGlass(portions, mix).Parent = glassFrame
	local glassScale = Instance.new("UIScale")
	glassScale.Scale = 0
	glassScale.Parent = glassFrame

	local name = label(title, Theme.Mustard, 5)
	name.AnchorPoint = Vector2.new(0.5, 0.5)
	name.Position = UDim2.fromScale(0.5, 0.68)
	name.Size = UDim2.fromScale(0.6, 0.11)
	name.Parent = root
	local nameScale = Instance.new("UIScale")
	nameScale.Scale = 0
	nameScale.Parent = name

	local sub = label(subtitle, Theme.Paper, 3)
	sub.AnchorPoint = Vector2.new(0.5, 0.5)
	sub.Position = UDim2.fromScale(0.5, 0.77)
	sub.Size = UDim2.fromScale(0.5, 0.05)
	sub.TextTransparency = 1
	sub.Parent = root

	tween(raysScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(glassScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(0.15, function()
		tween(nameScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
		tween(sub, 0.4, { TextTransparency = 0 })
	end)
	confetti(root, 50)

	local spin = RunService.RenderStepped:Connect(function(dt)
		rays.Rotation += dt * 25
	end)

	task.delay(1.9, function()
		tween(raysScale, 0.3, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		tween(glassScale, 0.3, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		tween(nameScale, 0.3, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		tween(sub, 0.25, { TextTransparency = 1 })
		task.delay(0.35, function()
			spin:Disconnect()
			root:Destroy()
		end)
	end)
end

-- Criação própria (não é nenhuma receita conhecida): pulinhos no meio da tela
function FreeCelebration.unknown(portions: { string }, mix: number)
	local glassFrame = Instance.new("Frame")
	glassFrame.BackgroundTransparency = 1
	glassFrame.AnchorPoint = Vector2.new(0.5, 1)
	glassFrame.Position = UDim2.fromScale(0.5, 0.6)
	glassFrame.Size = UDim2.fromScale(0.22, 0.22)
	glassFrame.SizeConstraint = Enum.SizeConstraint.RelativeYY
	glassFrame.Parent = gui
	drawGlass(portions, mix).Parent = glassFrame
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = glassFrame

	local caption = label("Criação sua!", Theme.Paper, 3)
	caption.AnchorPoint = Vector2.new(0.5, 0)
	caption.Position = UDim2.fromScale(0.5, 0.62)
	caption.Size = UDim2.fromScale(0.3, 0.05)
	caption.TextTransparency = 1
	caption.Parent = gui

	task.spawn(function()
		tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back).Completed:Wait()
		tween(caption, 0.25, { TextTransparency = 0 })
		for _ = 1, 2 do
			tween(glassFrame, 0.18, { Position = UDim2.fromScale(0.5, 0.52) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out).Completed:Wait()
			tween(glassFrame, 0.18, { Position = UDim2.fromScale(0.5, 0.6) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Wait()
		end
		task.wait(0.35)
		tween(caption, 0.2, { TextTransparency = 1 })
		tween(scale, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In).Completed:Wait()
		glassFrame:Destroy()
		caption:Destroy()
	end)
end

return FreeCelebration
