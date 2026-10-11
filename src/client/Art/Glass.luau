--!strict
-- Copo de vidro pixel-art desenhado com Frames.
-- O líquido é um grid de "pixels" recoloridos a cada render: camadas separadas
-- enquanto não misturado, redemoinho durante a mistura e cor única no final.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Recipes = require(ReplicatedStorage.Shared.Recipes)
local PixelArt = require(script.Parent.PixelArt)
local Sprites = require(script.Parent.Sprites)

local GRID_W, GRID_H = 20, 27
local IN_X0, IN_W = 4, 12 -- colunas internas
local IN_Y_TOP, IN_H = 4, 17 -- linhas internas (de cima pra baixo)
local ROWS_PER_PORTION = 4

local OUTLINE = Color3.fromRGB(70, 60, 72)
local GLASS = Color3.fromRGB(200, 226, 236)
local WHITE = Color3.new(1, 1, 1)

local Z_TINT, Z_SPOON, Z_LIQUID, Z_STREAM, Z_WALL, Z_SHINE = 1, 2, 3, 4, 5, 6

export type Glass = {
	Root: Frame,
	Portions: { string },
	Level: number,
	Mix: number,
	Swirl: number,
	_pixels: { { Frame } },
	_spoon: Frame,
	_stream: Frame,
	setPortions: (self: Glass, list: { string }) -> (),
	setLevel: (self: Glass, level: number) -> (),
	targetLevel: (self: Glass) -> number,
	setMix: (self: Glass, mix: number, swirl: number) -> (),
	setSpoon: (self: Glass, visible: boolean, angle: number?) -> (),
	setStream: (self: Glass, color: Color3?) -> (),
	render: (self: Glass) -> (),
	Destroy: (self: Glass) -> (),
}

local Glass = {}
Glass.__index = Glass

local function rect(parent: Instance, x: number, y: number, w: number, h: number, color: Color3, z: number, transparency: number?): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency or 0
	f.Position, f.Size = PixelArt.cell(x, y, w, h, GRID_W, GRID_H)
	f.ZIndex = z
	f.Parent = parent
	return f
end

function Glass.new(): Glass
	local root = Instance.new("Frame")
	root.Name = "Glass"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromScale(1, 1)

	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = GRID_W / GRID_H
	aspect.Parent = root

	-- fundo levemente azulado do vidro
	rect(root, IN_X0, IN_Y_TOP - 1, IN_W, IN_H + 1, GLASS, Z_TINT, 0.78)

	-- paredes
	rect(root, IN_X0 - 1, IN_Y_TOP - 1, 1, IN_H + 3, OUTLINE, Z_WALL)
	rect(root, IN_X0 + IN_W, IN_Y_TOP - 1, 1, IN_H + 3, OUTLINE, Z_WALL)
	rect(root, IN_X0 - 2, IN_Y_TOP - 1, 1, 1, OUTLINE, Z_WALL) -- borda
	rect(root, IN_X0 + IN_W + 1, IN_Y_TOP - 1, 1, 1, OUTLINE, Z_WALL)
	-- fundo grosso de vidro
	rect(root, IN_X0, IN_Y_TOP + IN_H, IN_W, 2, GLASS, Z_WALL, 0.25)
	rect(root, IN_X0 - 1, IN_Y_TOP + IN_H + 2, IN_W + 2, 1, OUTLINE, Z_WALL)

	-- brilho do vidro
	rect(root, IN_X0 + 1, IN_Y_TOP + 2, 1, 10, WHITE, Z_SHINE, 0.45)
	rect(root, IN_X0 + 2, IN_Y_TOP + 2, 1, 2, WHITE, Z_SHINE, 0.55)
	rect(root, IN_X0 + IN_W - 2, IN_Y_TOP + 9, 1, 5, WHITE, Z_SHINE, 0.7)

	-- pires de madeira
	local base = IN_Y_TOP + IN_H + 3
	rect(root, 1, base, GRID_W - 2, 1, Color3.fromRGB(196, 140, 92), Z_WALL)
	rect(root, 2, base + 1, GRID_W - 4, 1, Color3.fromRGB(150, 98, 62), Z_WALL)
	rect(root, 0, base, 1, 1, OUTLINE, Z_WALL)
	rect(root, GRID_W - 1, base, 1, 1, OUTLINE, Z_WALL)

	-- pixels do líquido
	local pixels: { { Frame } } = {}
	for r = 0, IN_H - 1 do
		local row = {}
		for c = 0, IN_W - 1 do
			local y = IN_Y_TOP + IN_H - 1 - r
			local px = rect(root, IN_X0 + c, y, 1, 1, WHITE, Z_LIQUID)
			px.Visible = false
			row[c + 1] = px
		end
		pixels[r + 1] = row
	end

	-- colher (fica atrás do líquido, então só o cabo aparece acima da superfície)
	local spoon = PixelArt.draw(Sprites.Spoon, Z_SPOON)
	spoon.AnchorPoint = Vector2.new(0.5, 0)
	spoon.Size = UDim2.fromScale(5 / GRID_W, 15 / GRID_H)
	spoon.Visible = false
	spoon.Parent = root

	-- jato ao despejar
	local stream = rect(root, IN_X0 + IN_W / 2 - 1, 0, 2, 1, WHITE, Z_STREAM)
	stream.Visible = false

	local self = setmetatable({
		Root = root,
		Portions = {},
		Level = 0,
		Mix = 0,
		Swirl = 0,
		_pixels = pixels,
		_spoon = spoon,
		_stream = stream,
	}, Glass)
	return (self :: any) :: Glass
end

function Glass.setPortions(self: Glass, list: { string })
	self.Portions = table.clone(list)
	self:render()
end

function Glass.targetLevel(self: Glass): number
	return #self.Portions * ROWS_PER_PORTION
end

function Glass.setLevel(self: Glass, level: number)
	self.Level = level
	self:render()
end

function Glass.setMix(self: Glass, mix: number, swirl: number)
	self.Mix = math.clamp(mix, 0, 1)
	self.Swirl = swirl
	self:render()
end

function Glass.setSpoon(self: Glass, visible: boolean, angle: number?)
	self._spoon.Visible = visible
	local a = angle or 0
	local cx = IN_X0 + IN_W / 2 + math.cos(a) * 3.2
	self._spoon.Position = UDim2.fromScale(cx / GRID_W, (IN_Y_TOP - 4 + math.sin(a) * 0.6) / GRID_H)
end

function Glass.setStream(self: Glass, color: Color3?)
	local stream = self._stream
	if not color then
		stream.Visible = false
		return
	end
	local surface = IN_Y_TOP + IN_H - math.floor(self.Level + 0.5)
	stream.BackgroundColor3 = color
	stream.Position, stream.Size = PixelArt.cell(IN_X0 + IN_W / 2 - 1, 0, 2, surface, GRID_W, GRID_H)
	stream.Visible = true
end

function Glass.render(self: Glass)
	local portions = self.Portions
	local visibleRows = math.floor(self.Level + 0.5)
	local blend = Recipes.blend(portions)
	local mix = self.Mix
	local swirl = self.Swirl

	for r = 0, IN_H - 1 do
		local row = self._pixels[r + 1]
		local portionIndex = r // ROWS_PER_PORTION + 1
		local id = portions[math.min(portionIndex, #portions)]
		local visible = id ~= nil and r < visibleRows
		for c = 0, IN_W - 1 do
			local px = row[c + 1]
			px.Visible = visible
			if not visible then
				continue
			end
			local base = Recipes.Ingredients[id].Liquid
			local t
			if mix >= 1 then
				t = 1
			elseif mix <= 0 then
				t = 0
			else
				t = math.clamp(mix * 1.6 - 0.3 + 0.5 * math.sin(swirl * 1.5 + r * 0.8 + c * 0.55) * (1 - mix), 0, 1)
			end
			local color = base:Lerp(blend, t)
			-- superfície mais clara, lateral direita mais escura (volume cilíndrico)
			if r == visibleRows - 1 then
				color = color:Lerp(WHITE, 0.2)
			end
			if c >= IN_W - 3 then
				color = color:Lerp(Color3.new(0, 0, 0), 0.12)
			elseif c == 0 then
				color = color:Lerp(Color3.new(0, 0, 0), 0.06)
			end
			px.BackgroundColor3 = color
		end
	end
end

function Glass.Destroy(self: Glass)
	self.Root:Destroy()
end

return Glass
