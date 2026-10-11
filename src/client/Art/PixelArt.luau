--!strict
-- Renderiza sprites (grids de caracteres) como Frames 2D.
-- Pixels vizinhos da mesma cor em uma linha viram um único Frame (menos instâncias).

local Sprites = require(script.Parent.Sprites)

local PixelArt = {}

-- 1px extra evita frestas de arredondamento entre linhas/colunas
local SEAM = UDim2.fromOffset(1, 1)

function PixelArt.cell(x: number, y: number, w: number, h: number, gridW: number, gridH: number): (UDim2, UDim2)
	return UDim2.fromScale(x / gridW, y / gridH), UDim2.fromScale(w / gridW, h / gridH) + SEAM
end

-- Cria um Frame transparente contendo o sprite. O Frame mantém a proporção do grid.
function PixelArt.draw(sprite: Sprites.Sprite, zIndex: number?): Frame
	local rows = sprite.Rows
	local gridH = #rows
	local gridW = #rows[1]

	local root = Instance.new("Frame")
	root.Name = "Sprite"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)

	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = gridW / gridH
	aspect.Parent = root

	for y, row in rows do
		local x = 1
		while x <= gridW do
			local ch = string.sub(row, x, x)
			if ch == "." or ch == "" then
				x += 1
				continue
			end
			local run = 1
			while x + run <= gridW and string.sub(row, x + run, x + run) == ch do
				run += 1
			end
			local px = Instance.new("Frame")
			px.BorderSizePixel = 0
			px.BackgroundColor3 = sprite.Palette[ch] or Color3.new(1, 0, 1)
			px.Position, px.Size = PixelArt.cell(x - 1, y - 1, run, 1, gridW, gridH)
			px.ZIndex = zIndex or 1
			px.Parent = root
			x += run
		end
	end

	return root
end

function PixelArt.ingredient(id: string, zIndex: number?): Frame
	local sprite = (Sprites :: any)[id] :: Sprites.Sprite
	return PixelArt.draw(sprite, zIndex)
end

return PixelArt
