--!strict
-- Balões sobre a cabeça dos clientes: pedido, agradecimento e humor (paciência).
-- Também o balãozinho de coração do gato do balcão quando ganha carinho.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Recipes = require(ReplicatedStorage.Shared.Recipes)
local Glass = require(script.Parent.Parent.Art.Glass)
local PixelArt = require(script.Parent.Parent.Art.PixelArt)
local Sprites = require(script.Parent.Parent.Art.Sprites)
local Theme = require(script.Parent.Theme)

export type OrderInfo = {
	drink: string,
	modifier: string,
	pastry: string,
	tag: string?, -- "CRÍTICO", "O de sempre!" etc.
	tagColor: Color3?,
}

local Bubble = {}

local function base(head: BasePart, widthStuds: number, heightStuds: number, offsetY: number?): (BillboardGui, Frame)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Bubble"
	gui.Adornee = head
	gui.Size = UDim2.fromScale(widthStuds, heightStuds)
	gui.StudsOffsetWorldSpace = Vector3.new(0, (offsetY or 1.4) + heightStuds / 2, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 200
	gui.ResetOnSpawn = false

	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromScale(1, 0.84)
	panel.BackgroundColor3 = Theme.Paper
	panel.Parent = gui
	Theme.corner(panel, 0.18)
	Theme.stroke(panel, 3)

	-- rabinho do balão (quadradinhos em escada, estilo pixel)
	for i = 0, 2 do
		local step = Instance.new("Frame")
		step.BorderSizePixel = 0
		step.BackgroundColor3 = if i == 2 then Theme.Ink else Theme.Paper
		step.AnchorPoint = Vector2.new(0.5, 0)
		step.Size = UDim2.fromScale(0.09 - i * 0.025, 0.06)
		step.Position = UDim2.fromScale(0.5 - i * 0.03, 0.82 + i * 0.05)
		step.Parent = gui
		if i < 2 then
			Theme.stroke(step, 2)
		end
	end

	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	return gui, panel
end

local function tagLabel(parent: GuiObject, text: string, color: Color3)
	local tag = Instance.new("Frame")
	tag.AnchorPoint = Vector2.new(0.5, 0.5)
	tag.Position = UDim2.fromScale(0.5, 0)
	tag.Size = UDim2.fromScale(0.6, 0.24)
	tag.BackgroundColor3 = color
	tag.ZIndex = 3
	tag.Parent = parent
	Theme.corner(tag, 0.5)
	Theme.stroke(tag, 2)
	local l = Theme.label(text, Theme.Paper)
	l.Position = UDim2.fromScale(0.06, 0.12)
	l.Size = UDim2.fromScale(0.88, 0.76)
	l.ZIndex = 4
	l.Parent = tag
end

function Bubble.order(head: BasePart, info: OrderInfo): BillboardGui
	local drink = Recipes.Drinks[info.drink]
	local modifier = if info.modifier ~= "" then info.modifier else nil
	local hasExtra = modifier ~= nil or info.pastry ~= ""
	local gui, panel = base(head, 6, if hasExtra then 3.3 else 2.6, 1.9)

	local icon = Instance.new("Frame")
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromScale(0.27, 0.86)
	icon.Position = UDim2.fromScale(0.03, 0.07)
	icon.Parent = panel
	local glass = Glass.new()
	glass:setPortions(Recipes.orderPortions(info.drink, modifier))
	glass:setMix(if drink.Mix and modifier ~= "NoMix" then 1 else 0, 0)
	glass:setLevel(glass:targetLevel())
	glass.Root.Parent = icon

	local label = Theme.label(drink.Name, Theme.Ink)
	label.Size = UDim2.fromScale(0.64, if hasExtra then 0.36 else 0.56)
	label.Position = UDim2.fromScale(0.32, if hasExtra then 0.1 else 0.22)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = panel

	if hasExtra then
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Position = UDim2.fromScale(0.32, 0.52)
		row.Size = UDim2.fromScale(0.64, 0.34)
		row.Parent = panel
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Horizontal
		list.VerticalAlignment = Enum.VerticalAlignment.Center
		list.Padding = UDim.new(0.04, 0)
		list.Parent = row
		if modifier then
			local m = Instance.new("Frame")
			m.BackgroundColor3 = Theme.Mustard
			m.Size = UDim2.fromScale(if info.pastry ~= "" then 0.7 else 1, 0.9)
			m.Parent = row
			Theme.corner(m, 0.4)
			Theme.stroke(m, 2)
			local t = Theme.label(Recipes.Modifiers[modifier].Name, Theme.Ink)
			t.Position = UDim2.fromScale(0.05, 0.12)
			t.Size = UDim2.fromScale(0.9, 0.76)
			t.Parent = m
		end
		if info.pastry ~= "" then
			local holder = Instance.new("Frame")
			holder.BackgroundTransparency = 1
			holder.Size = UDim2.fromScale(1, 1)
			holder.SizeConstraint = Enum.SizeConstraint.RelativeYY
			holder.Parent = row
			PixelArt.draw((Sprites :: any)[info.pastry]).Parent = holder
		end
	end

	if info.tag then
		tagLabel(panel, info.tag, info.tagColor or Theme.Rose)
	end

	gui.Parent = head
	return gui
end

function Bubble.heart(head: BasePart, text: string?): BillboardGui
	local gui, panel = base(head, 4.6, 2.1, 1.9)
	local heart = PixelArt.draw(Sprites.Heart)
	heart.AnchorPoint = Vector2.new(0, 0.5)
	heart.Size = UDim2.fromScale(0.26, 0.7)
	heart.Position = UDim2.fromScale(0.06, 0.5)
	heart.Parent = panel

	local label = Theme.label(text or "Obrigado!", Theme.Ink)
	label.Size = UDim2.fromScale(0.6, 0.6)
	label.Position = UDim2.fromScale(0.36, 0.2)
	label.Parent = panel

	gui.Parent = head
	return gui
end

-- balãozinho só com o coração (carinho no gato)
function Bubble.love(head: BasePart, offsetY: number?): BillboardGui
	local gui, panel = base(head, 1.9, 2, offsetY or 0.7)
	local heart = PixelArt.draw(Sprites.Heart)
	heart.Size = UDim2.fromScale(0.72, 0.72)
	heart.Parent = panel
	gui.Parent = head
	return gui
end

function Bubble.sad(head: BasePart, text: string?): BillboardGui
	local gui, panel = base(head, 5, 2.1, 1.9)
	local face = PixelArt.draw(Sprites.FaceNeutral)
	face.AnchorPoint = Vector2.new(0, 0.5)
	face.Size = UDim2.fromScale(0.24, 0.7)
	face.Position = UDim2.fromScale(0.05, 0.5)
	face.Parent = panel
	local label = Theme.label(text or "Não era isso...", Theme.Ink)
	label.Size = UDim2.fromScale(0.64, 0.56)
	label.Position = UDim2.fromScale(0.32, 0.22)
	label.Parent = panel
	gui.Parent = head
	return gui
end

function Bubble.pop(gui: BillboardGui)
	local scale = gui:FindFirstChildOfClass("UIScale")
	if not scale then
		gui:Destroy()
		return
	end
	local tween = TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
	tween.Completed:Once(function()
		gui:Destroy()
	end)
	tween:Play()
end

return Bubble
