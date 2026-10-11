--!strict
-- Paleta e helpers visuais da UI (tons de madeira/creme, cantos levemente arredondados).

local rgb = Color3.fromRGB

local Theme = {
	Ink = rgb(70, 44, 34),
	Paper = rgb(252, 244, 228),
	PaperShade = rgb(236, 220, 194),
	Wood = rgb(186, 132, 88),
	WoodDark = rgb(120, 78, 52),
	WoodLight = rgb(214, 170, 120),
	Sage = rgb(140, 184, 140),
	SageDark = rgb(92, 140, 96),
	Rose = rgb(232, 132, 128),
	Mustard = rgb(240, 190, 96),
	Font = Enum.Font.FredokaOne,
}

function Theme.corner(parent: GuiObject, scale: number?, offset: number?): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(scale or 0, offset or 0)
	c.Parent = parent
	return c
end

function Theme.stroke(parent: GuiObject, thickness: number?, color: Color3?): UIStroke
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 3
	s.Color = color or Theme.Ink
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function Theme.label(text: string, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextScaled = true
	l.Font = Theme.Font
	l.TextColor3 = color or Theme.Ink
	return l
end

return Theme
